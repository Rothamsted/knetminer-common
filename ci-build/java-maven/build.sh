# TODO: install.sh
# TODO: _common.sh

# TODO: comment me!
#

function get_maven_goal
{
	with_log="${1:-false}"
	
	if is_deploy_mode; then 
		! $with_log || printf "\n\n\tMaven Deployment\n" >&2
		echo deploy
		return
	fi
		
	! $with_log \
		&& printf "\n\n\tNot in the main repo, and/or not in the master branch, building only, without deployment\n" >&2
	echo install
}

function stage_init_release
{
	is_release_mode || return
	 
  mvn versions:set -DnewVersion="${NEW_RELEASE_VER}" -DallowSnapshots=true $MAVEN_ARGS
  # Commit immediately, even if it fails, we will have a chance to give up
  mvn versions:commit $MAVEN_ARGS
}

function stage_build
{
	maven_goal="$(get_maven_goal true)"
	mvn $maven_goal --settings ci-build/maven-settings.xml $MAVEN_BUILD_ARGS
}


function stage_release
{
	is_release_mode || return

	echo -e "\n\n\tCommitting ${NEW_RELEASE_VER} to github\n"
	# --allow-empty is needed cause previous steps might have their own commits, with their
	# own messages
	git commit -a --allow-empty -m "Releasing ${NEW_RELEASE_VER}. ${CI_SKIP_TAG}"
	
  # TODO: --force was used in Travis, cause it seems to place a tag automatically
	git tag --force --annotate "${NEW_RELEASE_VER}" -m "Releasing ${NEW_RELEASE_VER}. ${CI_SKIP_TAG}"
	
	echo -e "\n\n\tSwitching codebase version to ${NEW_SNAPSHOT_VER}\n"
	mvn versions:set -DnewVersion="${NEW_SNAPSHOT_VER}" -DallowSnapshots=true $MAVEN_ARGS
	mvn versions:commit $MAVEN_ARGS
	
	git commit -a -m "Switching version to ${NEW_SNAPSHOT_VER}. ${CI_SKIP_TAG}"
	export NEEDS_PUSH=true	
}
