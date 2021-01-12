set -e

cd `dirname "$0"`
cd ..

ci_skip_tag='[ci skip]'
mvn_opts='--no-transfer-progress --batch-mode'

if [[ `git log -1 --pretty=format:"%s"` =~ "$ci_skip_tag" ]]; then
	echo -e "\n$ci_skip_tag prefix, ignoring this commit\n"
	exit
fi


# These need to be configured by the CI
git config --global user.name "$GIT_USER"
git config --global user.email "$GIT_USER_EMAIL"
git config --global "url.https://$GIT_USER:$GIT_PASSWORD@github.com.insteadof" "https://github.com"	

# PRs are checked out in detach mode, so they haven't any branch, so checking if this is != master
# filters them away too
export GIT_BRANCH=`git branch --show-current`

# Manage releasing too, when these vars are defined
#
if [[ ! -z "${NEW_RELEASE_VER}" ]] && [[ ! -z "${NEW_SNAPSHOT_VER}" ]]; then
	if [[ "$GIT_BRANCH" != 'master' ]]; then
		echo -e "\n\nERROR: use releasing parameters with the main repo and the master branch only!\n"
		exit 1
	fi 
  echo -e "\n\n\tRELEASING ${NEW_RELEASE_VER}, new snapshot will be: ${NEW_SNAPSHOT_VER}\n" 
  is_release='true'
fi
  
if [[ ! -z "$is_release" ]]; then
  mvn versions:set -DnewVersion="${NEW_RELEASE_VER}" -DallowSnapshots=true $mvn_opts
  # Commit immediately, even if it fails, we will have a chance to give up
  mvn versions:commit $mvn_opts
fi

if [[ "$GIT_BRANCH" == 'master' ]]; then 
	echo -e "\n\n\tMaven Deployment\n"
	maven_goal='deploy'
else
	echo -e "\n\n\tNot in the main repo, and/or not in the master branch, building only, without deployment\n"
	maven_goal='install'
fi

mvn $maven_goal --settings "ci-build/maven-settings.xml" $mvn_opts

if [[ "$GIT_BRANCH" != 'master' ]]; then
  echo -e "\n\n\tNot in the main repo, and/or not in the master branch, build ends here. Bye.\n"
	exit
fi


if ! git diff --exit-code --quiet HEAD; then
	needs_push='true'
	git commit -a -m "Updating CI auto-generated files. ${ci_skip_tag}"
fi

# Will git need to be updated on remote?
[[ ! -z "$is_release" || ! -z "$needs_push" ]] && needs_push='true'


# And now manage the release too
#
if [[ ! -z "$is_release" ]]; then
	echo -e "\n\n\tCommitting ${NEW_RELEASE_VER} to github\n"
  # TODO: --force was used in Travis, cause it seems to place a tag automatically
	git tag --force --annotate "${NEW_RELEASE_VER}" -m "Releasing ${NEW_RELEASE_VER}. ${ci_skip_tag}"
	
	echo -e "\n\n\tSwitching codebase version to ${NEW_SNAPSHOT_VER}\n"
	mvn versions:set -DnewVersion="${NEW_SNAPSHOT_VER}" -DallowSnapshots=true $mvn_opts
	mvn versions:commit $mvn_opts
	git commit -a -m "Switching version to ${NEW_SNAPSHOT_VER}. ${ci_skip_tag}"
fi

# Do we need to git-push?
#
if [[ ! -z "$needs_push" ]]; then
	echo -e "\n\n\tPushing changes to github\n"
	
	# It seems that Travis auto-pushes tags
	# TODO: Still neded? Requires testing, maybe it messes up with the assigned release tag
  git push --force --tags origin HEAD:"$GIT_BRANCH"
fi

echo -e "\n\nThe End.\n"
