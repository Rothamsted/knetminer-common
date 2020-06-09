set -e -x

cd `dirname "$0"`
cd ..

ci_skip_tag=' [ci skip]'

# Manage releasing too, when these vars are defined
#
if [[ ! -z "${NEW_RELEASE_VER}" ]] && [[ ! -z "${NEW_SNAPSHOT_VER}" ]]; then 
  echo -e "\n\n\tRELEASING ${NEW_RELEASE_VER}, new snapshot will be: ${NEW_SNAPSHOT_VER}\n" 
  is_release='true'
fi
  
if [[ ! -z "$is_release" ]]; then
  mvn versions:set -DnewVersion="${NEW_RELEASE_VER}" -DallowSnapshots=true
  # Commit immediately, even if it fails, we will have a chance to give up
  mvn versions:commit
fi

echo -e "\n\n\tMaven Depolyment\n"
mvn deploy --settings "travis/maven-settings.xml"

if ! git diff --exit-code HEAD; then
	needs_push='true'
	git commit -a -m "Updating Travis auto-generated files.${ci_skip_tag}"
fi

# Will git need to be updated on remote?
[[ ! -z "$is_release" || ! -z "$needs_push" ]] && needs_push='true'


# And now manage the release too
#
if [[ ! -z "$is_release" ]]; then
	echo -e "\n\n\tCommitting ${NEW_RELEASE_VER} to github\n"
	msg="Releasing ${NEW_RELEASE_VER}.${ci_skip_tag}"
	git commit -a -m "$msg"
	# For some reason, in Travis it results already tagged at this point.
	git tag --force --annotate "${NEW_RELEASE_VER}" -m "$msg"
	
	echo -e "\n\n\tSwitching codebase version to ${NEW_SNAPSHOT_VER}\n"
	mvn versions:set -DnewVersion="${NEW_SNAPSHOT_VER}" -DallowSnapshots=true
	mvn versions:commit
	git commit -a -m "Switching version to ${NEW_SNAPSHOT_VER}.${ci_skip_tag}"
fi

# Do we need to git-push?
#
if [[ ! -z "$needs_push" ]]; then
	echo -e "\n\n\tPushing changes to github\n"
	
	git_url=`git remote -v | awk '$NR=2 {print $2; exit}'`
	if [[ ! "$git_url" =~ ^https?://.+ ]]; then
		echo "ERROR: No remote git URL or unsupported format for '$git_url'."
		exit 1
	fi
	
	git_url=`echo "$git_url" | sed -E "s|http(s?)://|http\1://$GIT_USER:$GIT_PASSWORD@|"`
	git remote set-url origin https://$GIT_USER:$GIT_PASSWORD@github.com/Rothamsted/knetminer-common.git

	# It seems that Travis auto-pushes tags
	git push --force --tags origin HEAD:"$TRAVIS_BRANCH"
fi

echo -e "\n\nThe End."
