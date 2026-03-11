#!/usr/bin/env bash

# The common stage implementations for projects based on Java and Maven.
# 

set -eE -o pipefail

# A flavour starts with importing the core functions
. ./ci-build-v2/_common.sh


function stage_build_setup
{	
	# When using the ACT utility, this isn't installed by default
	# 
	if [[ "${CI_IS_ACT_TOOL}" == 'true' ]]; then
		printf "== Installing Maven (ACT Mode)\n"
		apt update
		apt install -y maven
	fi
}



function stage_init_release
{
	is_release_mode true || return 0
	 
	printf "== Preparing Maven for release '%s'\n" "${CI_NEW_RELEASE_VER}"
  mvn versions:set -DnewVersion="${CI_NEW_RELEASE_VER}" -DallowSnapshots=true $MAVEN_ARGS
  # Commit immediately, even if it fails, we will have a chance to give up
  mvn versions:commit $MAVEN_ARGS
}

# Calls Maven with the goal established by get_maven_goal()
# It also uses ci-build-v2/java-maven/maven-settings.xml, which should contain the 
# credentials and coordinates for the deployment repository. See the default version
# of this file for details.
#
function stage_build
{
	maven_goal="$(get_maven_goal true)"
	mvn $maven_goal --settings ci-build-v2/java-maven/maven-settings.xml $MAVEN_BUILD_ARGS
}


# Manages a Maven release by means of the 'versions' Maven plug-in.
function stage_release
{
	is_release_mode || return 0
		
	release_commit_and_tag
		
	printf "== Switching codebase version to ${CI_NEW_SNAPSHOT_VER}\n"
	mvn versions:set -DnewVersion="${CI_NEW_SNAPSHOT_VER}" -DallowSnapshots=true $MAVEN_ARGS
	mvn versions:commit $MAVEN_ARGS

	release_commit_new_snapshot
	# CI_NEEDS_PUSH was already set	by release_commit_and_tag()
}


# Establishes the Maven goal to use in stage_build(), based on is_deploy_mode()
#
function get_maven_goal
{
	# If true, notifies which kind of maven goal the build is going to use
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
