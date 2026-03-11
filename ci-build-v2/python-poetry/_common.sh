#!/usr/bin/env bash

# The common stage implementations for projects based on Python and Poetry.
# 

set -eE -o pipefail

# A flavour starts with importing the core functions
. ./ci-build-v2/_common.sh


function stage_build_setup
{	
	# PyP uses this name as change log file, so we change the general default
	export CI_REV_HISTORY_PATH="CHANGELOG.md"
	# This makes it log-friendly and suitable for unattended runs
	export CI_POETRY_DEFAULT_ARGS="--no-interaction --no-ansi"
}


function stage_init_release
{
	is_release_mode true || return 0
	check_release_in_revision_history
	 
	printf "== Setting new release '%s' in pyproject.toml\n" "${CI_NEW_RELEASE_VER}"
	poetry version "${CI_NEW_RELEASE_VER}"
}


function stage_build
{
	printf "== Poetry lock/sync\n"
	poetry $CI_POETRY_DEFAULT_ARGS lock
	poetry $CI_POETRY_DEFAULT_ARGS sync

	printf "== Tests\n"
	poetry run $CI_POETRY_DEFAULT_ARGS -- pytest
}

# See the generic version in ../_common.sh for details on how this stage should work.
#
function stage_release
{
	is_release_mode || return 0

	printf "== Poetry build\n"
	poetry $CI_POETRY_DEFAULT_ARGS build

	printf "== Publishing on PyPI\n"
	# This relies on POETRY_PYPI_TOKEN_PYPI defined in the secrets, user/password is now prohibited by PyPI,
	# and for good reasons.
	poetry $CI_POETRY_DEFAULT_ARGS publish

	printf "== Moving the project to the next version\n"
	poetry  $CI_POETRY_DEFAULT_ARGS version ${CI_NEW_SNAPSHOT_VER}

	# Mark what we have just done with the release tag
	release_commit_and_tag
	
	# And commit it
	release_commit_new_snapshot
}
