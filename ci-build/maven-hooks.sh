function build_local_body
{
	set_maven_goal
	manage_new_snapshot	
		
	mvn $MAVEN_GOAL --settings ci-build/maven-settings.xml $MAVEN_ARGS
}


function deploy_distro_body
{
	echo -e "\n\n\tSwitching codebase version to ${NEW_SNAPSHOT_VER}\n"
	
	mvn versions:set -DnewVersion="${NEW_SNAPSHOT_VER}" -DallowSnapshots=true $MAVEN_ARGS
	mvn versions:commit $MAVEN_ARGS
}


function set_maven_goal
{
	if $IS_DEPLOY; then 
		printf "\n\n  Maven Deployment\n"
		export MAVEN_GOAL='deploy'
	else
		printf "\n\n  Not in the main repo, and/or not in the master branch, building only, without deployment\n"
		export MAVEN_GOAL='install'
	fi
}

function manage_new_release
{
  $IS_RELEASE || return
  
	printf "\n\n  Switching codebase version to %s\n" ${NEW_RELEASE_VER}
  mvn versions:set -DnewVersion="${NEW_RELEASE_VER}" -DallowSnapshots=true $MAVEN_ARGS
  
  # Commit immediately, even if it fails, we will have a chance to give up
  mvn versions:commit $MAVEN_ARGS
}

function manage_new_snapshot
{
	$IS_RELEASE || return

	printf "\n\n  Switching codebase version to %s\n" ${NEW_SNAPSHOT_VER}

	mvn versions:set -DnewVersion="${NEW_SNAPSHOT_VER}" -DallowSnapshots=true $MAVEN_ARGS
	mvn versions:commit $MAVEN_ARGS
	
	git commit -a -m "Switching version to ${NEW_SNAPSHOT_VER}. ${CI_SKIP_TAG}"
}
