#!/usr/bin/env bash
set -e

. ./ci-build-v2/_common.sh

# TODO: comment me!
#

function get_maven_goal
{
	with_log="${1:-false}"
	
	if is_deploy_mode; then 
		! $with_log || printf "\n\n\tMaven Deployment\n" >&2
		echo deploy
		return 0
	fi
		
	! $with_log \
		|| printf "\n\n\tNot in the main repo, and/or not in the master branch, building only, without deployment\n" >&2
	echo install
}

function stage_build_setup
{	
	# When using the ACT utility, this isn't installed by default
	if [[ "${CI_IS_ACT_TOOL}" == 'true' ]]; then
		printf "== Installing Maven (ACT Mode)\n"
		apt update
		apt install -y maven
	fi
}



function stage_init_release
{
	is_release_mode true || return 0
	 
	printf "== Preparing Maven for release '%s'" "${CI_NEW_RELEASE_VER}"
  mvn versions:set -DnewVersion="${CI_NEW_RELEASE_VER}" -DallowSnapshots=true $MAVEN_ARGS
  # Commit immediately, even if it fails, we will have a chance to give up
  mvn versions:commit $MAVEN_ARGS
}

function stage_build
{
	maven_goal="$(get_maven_goal true)"
	mvn $maven_goal --settings ci-build-v2/java-maven/maven-settings.xml $MAVEN_BUILD_ARGS
}


function stage_release
{
	is_release_mode || return 0
		
	release_commit_and_tag
		
	printf "== Switching codebase version to ${CI_NEW_SNAPSHOT_VER}\n"
	mvn versions:set -DnewVersion="${CI_NEW_SNAPSHOT_VER}" -DallowSnapshots=true $MAVEN_ARGS
	mvn versions:commit $MAVEN_ARGS

	release_commit_new_snapshot
	# CI_NEEDS_PUSH was set	
}

