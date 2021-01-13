set -e

if [[ "$CI_TRIGGERING_EVENT" == 'schedule' ]]; then
	
	# Many cron-based CI triggers don't consider if there have been changes or not, so we rely on 
	# git commits to check that. This isn't perfect (eg, last build could have failed due to network problems,
	# not necessarily the code itself), but good enough in most cases. 
	#
	nchanges=1
	[[ -z "$CI_SCHEDULE_PERIOD" ]] \
	  && echo -e "\n\nWARNING: No CI_SCHEDULE_PERIOD defined, I'll build unconditionally as per schedule\n" \
	  || nchanges=$(git log --since '$CI_SCHEDULE_PERIOD hours ago' --format=oneline | wc -l)

	if [[ $(($nchanges)) == 0  ]]; then
		cat <<EOT


	This is a cron-triggered build and the code didn't change since the latest build, so we're not rebuilding.
	This is based on github logs (--since '$CI_SCHEDULE_PERIOD hours ago'). Please, launch a new build manually 
	if I didn't get it right.
	
EOT
	  exit
  else
  	echo "Proceeding with periodic build"
	fi
fi


cd `dirname "$0"`
cd ..

# TODO: document these two
export CI_SKIP_TAG='[ci skip]'
export MAVEN_ARGS='--no-transfer-progress --batch-mode'

if [[ `git log -1 --pretty=format:"%s"` =~ "$CI_SKIP_TAG" ]]; then
	echo -e "\n$CI_SKIP_TAG prefix, ignoring this commit\n"
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
  mvn versions:set -DnewVersion="${NEW_RELEASE_VER}" -DallowSnapshots=true $MAVEN_ARGS
  # Commit immediately, even if it fails, we will have a chance to give up
  mvn versions:commit $MAVEN_ARGS
fi

if [[ "$GIT_BRANCH" == 'master' ]]; then 
	echo -e "\n\n\tMaven Deployment\n"
	export MAVEN_GOAL='deploy'
else
	echo -e "\n\n\tNot in the main repo, and/or not in the master branch, building only, without deployment\n"
	export MAVEN_GOAL='install'
fi

# TODO: document the handlers.
[[ -e ./ci-build/build-before.sh ]] && . ./ci-build/build-before.sh
[[ -e ./ci-build/build-body.sh ]] \
  && . ./ci-build/build-body.sh \
  || mvn $MAVEN_GOAL --settings "ci-build/maven-settings.xml" $MAVEN_ARGS
[[ -e ./ci-build/build-after.sh ]] && . ./ci-build/build-after.sh

if [[ "$GIT_BRANCH" != 'master' ]]; then
  echo -e "\n\n\tNot in the main repo, and/or not in the master branch, build ends here. Bye.\n"
	exit
fi


if ! git diff --exit-code --quiet HEAD; then
	needs_push='true'
	git commit -a -m "Updating CI auto-generated files. ${CI_SKIP_TAG}"
fi

# Will git need to be updated on remote?
[[ ! -z "$is_release" || ! -z "$needs_push" ]] && needs_push='true'


# And now manage the release too
#
if [[ ! -z "$is_release" ]]; then
	echo -e "\n\n\tCommitting ${NEW_RELEASE_VER} to github\n"
  # TODO: --force was used in Travis, cause it seems to place a tag automatically
	git tag --force --annotate "${NEW_RELEASE_VER}" -m "Releasing ${NEW_RELEASE_VER}. ${CI_SKIP_TAG}"
	
	echo -e "\n\n\tSwitching codebase version to ${NEW_SNAPSHOT_VER}\n"
	mvn versions:set -DnewVersion="${NEW_SNAPSHOT_VER}" -DallowSnapshots=true $MAVEN_ARGS
	mvn versions:commit $MAVEN_ARGS
	git commit -a -m "Switching version to ${NEW_SNAPSHOT_VER}. ${CI_SKIP_TAG}"
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
