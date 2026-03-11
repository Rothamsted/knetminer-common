
set -eE -o pipefail

# The Common Workflow
# 
# See README.md for an overview of this project.
#
function main
{
	install_notification_failure
	common_setup
	validate_preconditions
	
	# As mentioned in README.md, a workflow is mainly a sequence of stages. Each 
	# stage is run through the run_stage wrapper, so that you can override stages with
	# _local implementations.
	#
	# For example, build_setup() is a function, which can be possibly overridden/extended
	# by defining a stage_build_setup_local() function.
	#
	# In the hereby file, most stages are empty placholders, their actual non-local 
	# implementations are provided in $flavour/_common.sh files, and depend on a
	# flavour language and build system (eg, java-maven, python-poetry, etc).
	#
	run_stage build_setup
	run_stage git_setup
	run_stage init_release  
	run_stage build
	run_stage deploy
	run_stage release
	run_stage remote_git_update
	run_stage create_github_release
	run_stage close
}

## Default stages

# Note that you can't have an empty function body in bash, so we use 'true' instead.
# Also note that, since we usually have set -e at the top of a concrete CI script, a
# stage must always return 0 unless it actually needs to signal an error.
# For instance, this is not going to work as last command in a stage and when is_debug 
# is false, because in that case, you won't have a 0 return code:
# 
# $is_debug && print "Debug message"
#

# Additional build-specific setup.
# This should be dedicated to flavour-specific setup, and project-specifc setup in the hook 
# stage_build_setup_local(). For instance, in the java-maven  flavour, this is used to install Maven.
# If some setup applies to all kind of builds, then it should be in common_setup()
#
function stage_build_setup
{
	true
}


function stage_init_release
{
	# Your _local implementation should start with this
	is_release_mode true || return 0
	check_release_in_revision_history
	
	# And continue with what you need to do to prepare a release from the current
	# git branch.
}

# Checks that the revision history contains the new release and the snapshot versions
function check_release_in_revision_history
{
	printf "== Checking release versions are in the revision history file\n"
	for ver in "${CI_NEW_RELEASE_VER}" "${CI_NEW_SNAPSHOT_VER}"; do
		! fgrep -q "$ver" "$CI_REV_HISTORY_PATH" || continue
		printf "\n\nERROR: version '%s' not found in the revision history file '%s', looks like you need to update it, so I'll stop here\n\n" \
			"$ver" "$CI_REV_HISTORY_PATH"
		exit 1
	done
}

function stage_build
{
	true
}

# Used for deployment operations, such as uploading distro files to a registry or deploying an app on 
# a test server. This might depend on is_release_mode, eg, to decide what the target server is, or 
# to deploy only upon release.
#
# Note that if an operation is ony executed upon releasing (eg, building a distro tarball, publishing
# on a registry), then it should not be here, but in stage_release.
# 
function stage_deploy
{
	if ! is_deploy_mode; then
	  printf "\n\n\tThis is not a deployment build, deployment operations are skipped.\n"
	fi
	
	# Your custom deploy should call this and then do something if is_deploy_mode
}

# When the build is in release mode (see is_release_mode()), this stage should do the
# operations needed to produce a release. For instance, it might tag the git repo, it might
# use the 'gh release' command, it might trigger a script in a production server.
#
# This should use `git_commit_release()`, `git_tag_release()`, `git_commit_new_snapshot()` 
# to mark releasing-related changes in the current repo.
#
function stage_release
{
	# Likely, your own flavour will be like this:
	
	# Your _local implementation should start with this	
	is_release_mode || return 0
	
	# DO release-related changes (change version, test, prepare binaries, etc)	
	# release_commit_and_tag # commit them and tag with new version tag (sets CI_NEEDS_PUSH)
	
	# DO more changes to prepare the next snapshot/dev version	
	# release_commit_new_snapshot # And commit these too (sets CI_NEEDS_PUSH)
}


# Updates the git log with a release marking commit and creates a release tag.
# It also sets CI_NEEDS_PUSH to true, so you don't need to do it in other stages.
#
# Scripts like this are based on the environment variable CI_NEW_RELEASE_VER, which
# is usually a GHA parameter, set upon manual execution of a build workflow, which usually
# has the CI_NEW_SNAPSHOT_VER parameter too, to allow switching to the next snapshot version
# (in release_commit_new_snapshot()).
#
function release_commit_and_tag
{
	printf "== Committing/tagging ${CI_NEW_RELEASE_VER} to git\n"
	
	# --allow-empty is needed cause previous steps might have their own commits, with their
	# own messages
	git commit -a --allow-empty -m "release: commit changes for release ${CI_NEW_RELEASE_VER}. ${CI_SKIP_TAG}"
	
  # TODO: --force was used in Travis, cause it seems to place a tag automatically
	git tag --force --annotate "${CI_NEW_RELEASE_VER}" -m "release: add release tag ${CI_NEW_RELEASE_VER}. ${CI_SKIP_TAG}"

	export CI_NEEDS_PUSH=true	
}


# This is to be called after having switched the codebase to a new snapshot version
# While snapshot versions aren't used in all languages, the concept is a snapshot is 
# the current working version, which hasn't a release yet. For instance, in a Python/PIP
# project, you might want to switch to 1.0.1 or 1.0.1-dev after releasing 1.0.0.
# 
# This is based on the environment variable CI_NEW_SNAPSHOT_VER, which is usually a GHA
# parameter, set upon manual execution of a build workflow, together with CI_NEW_RELEASE_VER.
#
function release_commit_new_snapshot
{
	printf "== Committing ${CI_NEW_SNAPSHOT_VER} to git\n"
	
	git commit -a --allow-empty -m "Switching version to ${CI_NEW_SNAPSHOT_VER}. ${CI_SKIP_TAG}"
	export CI_NEEDS_PUSH=true
}


# Configures the running git with variables that usually come from github actions secrets.
# 
function stage_git_setup
{
	printf "== Setting git account and credentials\n"
	git config --global user.name "$GIT_USER"
	git config --global user.email "$GIT_USER_EMAIL"
	git config --global "url.https://$GIT_USER:$GIT_PASSWORD@github.com.insteadof" "https://github.com"
}


# If CI_NEEDS_PUSH is true, then pushes local commits back to the remote github repo.
#
# This is run at the end of a build workflow, after stages like 'release', to push local changes
# that one or more stages produced back to the remote git repo.
# 
function stage_remote_git_update
{	
	$CI_NEEDS_PUSH || return 0
	
	printf "== Pushing changes to github\n"
	
	# TODO: Is --force still neded? Requires testing, maybe it messes up with the assigned release tag
  git push --force --tags origin HEAD:"$CI_GIT_BRANCH"
}


function stage_create_github_release
{
	is_release_mode || return 0
	
	printf "== Creating release ${CI_NEW_RELEASE_VER} on GitHub\n"

	! ${CI_IS_LATEST_RELEASE:-true} || latest_flag='--latest'
	! ${CI_IS_PRE_RELEASE:-false} || pre_release_flag='--prerelease'
	
	release_notes="All details in the [revision history]($GITHUB_SERVER_URL/$GITHUB_REPOSITORY/blob/master/$CI_REV_HISTORY_PATH)."
	gh release create "${CI_NEW_RELEASE_VER}" $latest_flag $pre_release_flag \
		--notes "$release_notes"
}


# Run at the very end of a build workflow, allows for final operations, such as cleanups, 
# Triggering server updates, notifications.
# This default does nothing.
#
function stage_close
{
	true
}



# Notify build failures using a Slack webhook.
# Use install_notification_failure() to setup this
# 
# Realised with https://www.howtogeek.com/devops/how-to-send-a-message-to-slack-from-a-bash-script
#
function notify_failure
{
	# TODO: catch the initial error status and return it
	
	if [[ -z "$CI_SLACK_API_NOTIFICATION_URL" ]]; then
	  printf "\n\nWARNING: can't send error notification to empty Slack URL\n\n"
	  return 1
	fi
	
	printf "Notifying the error to Slack\n"
	
  run_url="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
  if [[ -z "$CI_FAIL_MESSAGE" ]]; then
    # Slack uses a reduced version of MD (https://api.slack.com/reference/surfaces/formatting)
    CI_FAIL_MESSAGE="*CI build failure for $GITHUB_REPOSITORY*"
    CI_FAIL_MESSAGE="$CI_FAIL_MESSAGE\n\nSorry, the build for this repo failed, see details <$run_url|here>.\n"
  fi

  curl --fail-with-body -X POST -H 'Content-type: application/json' \
       --data "{ \"text\": \"$CI_FAIL_MESSAGE\" }" \
       "$CI_SLACK_API_NOTIFICATION_URL"

	return 1
}

# Install notify_failure() by means of the 'trap' command.
#
# This also prepares the environment for the handler to work
#
function install_notification_failure
{
	# Needed to send notifications via Slack, but normally it's there by default
	printf "== Installing additional Ubuntu packages\n" 
	sudo apt -y update
	sudo apt -y install curl
	
	printf "== Installing failure handler\n"
	set -eE -o pipefail # Be very sure this is caught from any possible point
	trap notify_failure ERR	
}


# Setup various things that are common to all kind of builds
#
function common_setup
{
	printf "== Common setup\n"
	mypath="$(realpath "${BASH_SOURCE[0]}")"
	mydir="$(dirname "$mypath")"	
	
	cd "$mydir"
	cd ..
	export PROJECT_HOME="$(pwd)"	

	# Used in TODO:	
	export CI_SKIP_TAG='[ci skip]'
	# export CI_SKIP_TAG='[DISABLED]' # Used for debugging

	# We support the act tool, which requires some tricks
	if [[ $CI_IS_ACT_TOOL == 'true' ]]; then
		if [[ -z "$ACT_GIT_PASSWORD" ]]; then
			cat <<EOT
  
WARNING: CI_IS_ACT_TOOL is set and ACT_GIT_PASSWORD is empty.
  
You CAN'T get GIT_PASSWORD from:
  
  GIT_PASSWORD: \${{github.GITHUB_TOKEN}}

you can add this to the above definition in the env section of your Action workflow:

  ACT_GIT_PASSWORD: ${{secrets.GITHUB_PAT}}

and define GITHUB_PAT in the secrets file you pass to the act tool.

Continuing without a git password.

EOT
  
		fi 
		GIT_PASSWORD="$ACT_GIT_PASSWORD"
	fi
	
	# PRs are checked out in detach mode, so they haven't any branch, so checking if this is != master
	# filters them away too
	export CI_GIT_BRANCH=$(git branch --show-current)
	
	# If the current branch is one of these, then we have to do deploy operations, else
	# we only do rebuilds. This distinguishes between eg, release branches and experimental branches or 
	# pull requests.
	# 
	[[ ! -z "$CI_DEPLOY_BRANCHES" ]] \
		|| export CI_DEPLOY_BRANCHES='master main ci-build-v2' # A list of branches, separated by spaces
	
	# This is used in stages like remote_git_update(), if some previous stage set it to true, 
	# then it's known that we need to push local changes back to the remote git repo.
	export CI_NEEDS_PUSH=false

	export CI_REV_HISTORY_PATH="revision-history.md"
} # common_setup ()


# Tells if the CI build should work in deploy mode or not
# 
# Usually, deployment means rebuilding the project locally and updating something remotely
# (eg a binary repo, a test server).
# 
# The default implementation of this function just checks " $DEPLOY_BRANCHES " =~ " $CI_GIT_BRANCH "
# 
function is_deploy_mode
{
	[[ " $CI_DEPLOY_BRANCHES " =~ " $CI_GIT_BRANCH " ]] 
}


# Checks if we're in release mode or not.
#
# Releasing usually means actions like tagging the github repo and deploying on a production server.
#
# The default implementation checks the variables CI_NEW_RELEASE_VER and CI_NEW_SNAPSHOT_VER, which
# are supposed to be github action variables and are usually manually set when triggering a new release.
# 
# We also check is_deploy_mode() and raise an error if we're in release mode but we're not in deployment
# mode, since this is normally inconsistent.
# 
function is_release_mode
{
	with_log="${1:-false}"

	[[ ! -z "${CI_NEW_RELEASE_VER}" ]] && [[ ! -z "${CI_NEW_SNAPSHOT_VER}" ]] \
  	&& is_release=true || is_release=false

	if $is_release; then
	  if ! $(is_deploy_mode); then
			printf "\n\nERROR: Can't do a release for a non-deploy branch, check DEPLOY_BRANCHES or the running branch\n"
			exit 1
		fi
		
		! $with_log \
			|| printf "== Releasing '%s', new snapshot will be: '%s'\n" \
			   "${CI_NEW_RELEASE_VER}" "${CI_NEW_SNAPSHOT_VER}"
	fi
	
	$is_release
}


# Manages GHA builds based on scheduled events. It checks if there have been changes
# since the last build, and if not, it gives up the current build.
# 
# Many cron-based CI triggers don't consider whether there have been changes or not since the last 
# build, so this function can be used to check how many commits there have been in the past 
# CI_SCHEDULE_PERIOD hours. This function will exit the build if that's the case.
#  
# The approach isn't perfect (eg, last build could have failed due to network problems,
# not necessarily the code itself), but good enough in most cases. 
#
function precondition_scheduled_build
{
	printf "== Checking scheduled event settings\n"
	
	[[ "$CI_TRIGGERING_EVENT" == 'schedule' ]] || return 0 
		
	nchanges=1
	[[ -z "$CI_SCHEDULE_PERIOD" ]] \
	  && printf "\n\nWARNING: No CI_SCHEDULE_PERIOD defined, I'll build unconditionally as per schedule\n" \
	  || nchanges=$(git log --since "$CI_SCHEDULE_PERIOD hours ago" --format=oneline | wc -l)

	if [[ $(($nchanges)) -gt 0  ]]; then
		printf "\nProceeding with periodic build\n\n"
		return 0
	fi
		
	cat <<EOT
	
	This is a cron-triggered build and the code didn't change since the latest build, so we're not rebuilding.
	This is based on github logs (--since '$CI_SCHEDULE_PERIOD hours ago'). Please, launch a new build manually 
	if I didn't get it right.
		
EOT
		exit
}
# precondition_scheduled_build ()


# If !is_release_mode() and the last commit message contains CI_SKIP_TAG, then it exits the build
# 
# We check this just in case, nowadays github supports [ci skip] and when a commit has this 
# snippet, no build is triggered at all.
#
function precondition_skip_commit_tag
{
	printf "== Checking skip commit tag\n"
	
	if is_release_mode || [[ ! `git log -1 --pretty=format:"%s"` =~ "$CI_SKIP_TAG" ]]; then
		return 0
	fi
	
	printf "\n$CI_SKIP_TAG prefix in the last commit message, not building upon this commit\n"
	exit
}

# Does all the build pre-condition validations. The default calls precondition_scheduled_build() 
# and precondition_skip_commit_tag().
#
function validate_preconditions
{
	precondition_scheduled_build
	precondition_skip_commit_tag
}


# As said above, this run a stage named like name=$1, by calling stage_$name_local(), 
# if it exists, stage_${name}() otherwise. As explained stage_${name}() is usually
# implemented by a particular flavour of this commons scripts project.
# 
function run_stage
{
  stage_name=$1
  
  stage_fun="stage_${stage_name}"
  
  declare -F "${stage_fun}_local" >/dev/null && stage_fun="${stage_fun}_local"
  
  printf "\n\n==== Stage: ${stage_fun}\n\n"
  ${stage_fun}
  printf "\n==== /end Stage: ${stage_fun}\n\n"

}