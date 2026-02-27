#!/usr/bin/env bash

# The common stage implementations for projects based on Python and Poetry.
# 

set -e

# A flavour starts with importing the core functions
. ./ci-build-v2/_common.sh


function stage_build_setup
{	
	# PyP uses this name as change log file, so we change the general default
	export CI_RELEASE_NOTES="All details in the [revision history]($GITHUB_SERVER_URL/$GITHUB_REPOSITORY/blob/master/CHANGELOG.md)."
}


function stage_init_release
{
	is_release_mode true || return 0
	 
	printf "== Setting new release '%s' in pyproject.toml\n" "${CI_NEW_RELEASE_VER}"
	poetry version "${CI_NEW_RELEASE_VER}"
}


function stage_build
{
	printf "= Poetry lock/sync\n"
	poetry lock
	poetry sync

	printf "= Tests\n"
	poetry run pytest
}

function stage_release
{
	# Likely, your own flavour will be like this:
	
	# Your _local implementation should start with this	
	is_release_mode || return 0

	printf "== Poetry build\n"
	poetry build

	printf "== Poetry publish\n"
	poetry publish --username "${CI_PYPI_USERNAME}" --password "${CI_PYPI_PASSWORD}"

	# Mark what we have just done with the release tag
	release_commit_and_tag
	
	# And commit it
	release_commit_new_snapshot
}
