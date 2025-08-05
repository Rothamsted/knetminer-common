function main
{
	install_notification_failure
	common_setup
	validate_preconditions
	
	run_stage build_setup
	run_stage git_setup
	run_stage init_release  
	run_stage build
	run_stage deploy
	run_stage release
	run_stage remote_git_update
	run_stage custom_close
}



function stage_build_setup
{
	true
}


function stage_init_release
{
	# Your _custom implementation should start with this
	is_release_mode true || return 0
}

function stage_build
{
	true
}

function stage_deploy
{
	if ! is_deploy_mode; then
	  printf "\n\n\tThis is not a deployment build, deployment operations are skipped.\n"
	fi
	
	# Your custom deploy should call this and then do something if is_deploy_mode
}

function stage_release
{
	# Your _custom implementation should start with this	
	is_release_mode || return 0
	
	# And probably it will need this at the end, if it tagged the repo and/or changed version
	#export NEEDS_PUSH=true	
}

function stage_git_setup
{
	git config --global user.name "$GIT_USER"
	git config --global user.email "$GIT_USER_EMAIL"
	git config --global "url.https://$GIT_USER:$GIT_PASSWORD@github.com.insteadof" "https://github.com"
}


# If CI_NEEDS_PUSH is true, then pushes local commits back to the remote github repo.
function stage_remote_git_update
{	
	$CI_NEEDS_PUSH || return 0
	
	printf "== Pushing changes to github\n"
	
	# TODO: Is --force still neded? Requires testing, maybe it messes up with the assigned release tag
  git push --force --tags origin HEAD:"$CI_GIT_BRANCH"
}

function stage_custom_close
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
	if [[ -z "$CI_SLACK_API_NOTIFICATION_URL" ]]; then
	  printf "\n\nERROR: can't send error notification to empty Slack URL\n\n"
	  return 1
	fi
	
	printf "Notifying the error to Slack\n"
	
  run_url="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
  if [[ -z "$CI_FAIL_MESSAGE" ]]; then
    # Slack uses a reduced version of MD (https://api.slack.com/reference/surfaces/formatting)
    CI_FAIL_MESSAGE="*CI build failure for $GITHUB_REPOSITORY*"
    CI_FAIL_MESSAGE="$CI_FAIL_MESSAGE\n\nSorry, the build for this repo failed, see details <$run_url|here>.\n"
  fi

  curl -X POST -H 'Content-type: application/json' \
    --data "{ \"text\": \"$CI_FAIL_MESSAGE\" }" \
    "$CI_SLACK_API_NOTIFICATION_URL"
}

# Install notify_failure() by means of the 'trap' command.
#
# This also prepaers the environment for the handler to work
#
function install_notification_failure
{
	# Needed to send notifications via Slack, but normally it's there by default
	printf "== Installing additional Ubuntu packages\n" 
	sudo apt -y update
	sudo apt -y install curl
	
	printf "== Installing failure handler\n" 
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
}

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
		
		!with_log \
			|| printf "== Releasing '%s', new snapshot will be: '%s'\n" \
			   "${CI_NEW_RELEASE_VER}" "${CI_NEW_SNAPSHOT_VER}"
	fi
	
	$is_release
}


# Many cron-based CI triggers don't consider whether there have been changes or not since the last 
# build, so this function can be used to check how many commits there have been in the past 
# CI_SCHEDULE_PERIOD hours. The function will exit the build if that's the case.
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
function precondition_skip_commit_tag
{
	printf "== Checking skip commit tag\n"
	
	if is_release_mode || [[ ! `git log -1 --pretty=format:"%s"` =~ "$CI_SKIP_TAG" ]]; then
		return 0
	fi
	
	printf "\n$CI_SKIP_TAG prefix in the last commit message, not building upon this commit\n"
	exit
}

# The default calls precondition_scheduled_build and precondition_skip_commit_tag and 
function validate_preconditions
{
	precondition_scheduled_build
	precondition_skip_commit_tag
}


# TODO: comment me!
# 
function run_stage
{
  stage_name=$1
  
  stage_fun="stage_${stage_name}"
  
  declare -F "${stage_fun}_custom" >/dev/null && stage_fun="${stage_fun}_custom"
  
  printf "\n\n==== Stage: ${stage_fun}\n\n"
  ${stage_fun}
  printf "\n==== /end:Stage: ${stage_fun}\n\n"

}