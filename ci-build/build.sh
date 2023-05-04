set -e

# Notify build failures using a Slack webhook
# Realised with https://www.howtogeek.com/devops/how-to-send-a-message-to-slack-from-a-bash-script
#
function notify_failure
{
  run_url="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
  if [[ -z "$CI_FAIL_MESSAGE" ]]; then
    # Slack uses a reduced version of MD (https://api.slack.com/reference/surfaces/formatting)
    CI_FAIL_MESSAGE="*CI build failure for $GITHUB_REPOSITORY*"
    CI_FAIL_MESSAGE="$CI_FAIL_MESSAGE\n\nSorry, the build for this repo failed, see details <$run_url|here>.\n"
  fi

	if [[ -z "$CI_SLACK_API_NOTIFICATION_URL" ]]; then
	  printf "\n\nERROR: can't send error notification to empty Slack URL\n\n"
	  exit 1
	fi

  curl -X POST -H 'Content-type: application/json' \
    --data "{ \"text\": \"$CI_FAIL_MESSAGE\" }" \
    "$CI_SLACK_API_NOTIFICATION_URL"
}

# Needed to send notifications, but normally it's there by default
# apt-get -y update
# apt-get -y curl

# TODO: re-enable when development is complete enough
# trap notify_failure ERR


if [[ "$CI_TRIGGERING_EVENT" == 'schedule' ]]; then
	
	# Many cron-based CI triggers don't consider if there have been changes or not, so we rely on 
	# git commits to check that. This isn't perfect (eg, last build could have failed due to network problems,
	# not necessarily the code itself), but good enough in most cases. 
	#
	nchanges=1
	[[ -z "$CI_SCHEDULE_PERIOD" ]] \
	  && echo -e "\n\nWARNING: No CI_SCHEDULE_PERIOD defined, I'll build unconditionally as per schedule\n" \
	  || nchanges=$(git log --since "$CI_SCHEDULE_PERIOD hours ago" --format=oneline | wc -l)

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
export MYDIR="`pwd`"

# github already supports this, when a commit message has a tag like this, it doesn't invoke
# any action at all. However, these scripts are generic and hence we want to manage this 
# here too. Morover, we use this tag to skip our own commits.
# 
export SKIP_TAG='[ci skip]'


# PRs are checked out in detach mode, so they haven't any branch, so checking if this is != master
# filters them away too
export GIT_BRANCH=`git branch --show-current`

# If the current branch is one of these, then we have to do deploy operations, else
# we only do rebuilds. This distinguishes between eg, release branches and experimental branches or 
# pull requests.
# 
export DEPLOY_BRANCHES='master' # A list of branches, separated by spaces

export NEEDS_PUSH=false # TODO: document variables


[[ " $DEPLOY_BRANCHES " =~ " $GIT_BRANCH " ]] && export IS_DEPLOY=true || IS_DEPLOY=false

# If the corresponding vars are set, manage releasing with a variant of the build procedure
#
[[ ! -z "${CI_NEW_RELEASE_VER}" ]] && [[ ! -z "${CI_NEW_SNAPSHOT_VER}" ]] \
  && export IS_RELEASE=true || exprt IS_RELEASE=false



# build-local:
#   Runs mainly local build tasks, including compiling, unit testing. Possibly, this also 
#   does remote things, if they're integrated with the paricular task (eg, 'maven deploy')
#
function build_local_base_begin
{	
	if $IS_RELEASE; then
	  if ! $IS_DEPLOY; then
			printf "\n\nERROR: Can't do a release for a non-deploy branch, check DEPLOY_BRANCHES or the running branch\n"
			exit 1
		fi
		echo -e "\n\n\tReleasing ${NEW_RELEASE_VER}, new snapshot will be: ${NEW_SNAPSHOT_VER}\n" 
	fi
	
	# When we're skipping the last commit, ignore the release thing too
	if ! $IS_RELEASE && [[ `git log -1 --pretty=format:"%s"` =~ "$CI_SKIP_TAG" ]]; then
		echo -e "\n$CI_SKIP_TAG prefix, ignoring this commit\n"
		exit
	fi

	set_git_credentials	
}


# deploy-distro:
#   Deploys the distribution files, if not already done during build-local, updates SCM (ie, 
#   push to github).
#

function deploy_distro
{
	deploy_distro_begin

	if ! $IS_DEPLOY; then
	  echo -e "\n\n\tThis is not a deployment build, all ends here. Bye.\n"
		exit
	fi

	deploy_distro_body

	# Manage the release aspects that deal with updating git
	#
	if $IS_RELEASE; then
		echo -e "\n\n\tCommitting ${NEW_RELEASE_VER} to github\n"
		# --allow-empty is needed cause previous steps might have their own commits, with their
		# own messages
		git commit -a --allow-empty -m "Releasing ${NEW_RELEASE_VER}. ${CI_SKIP_TAG}"
		
	  # TODO: --force was used in Travis, cause it seems to place a tag automatically
		git tag --force --annotate "${NEW_RELEASE_VER}" -m "Releasing ${NEW_RELEASE_VER}. ${CI_SKIP_TAG}"
				
		git commit -a -m "Switching version to ${NEW_SNAPSHOT_VER}. ${CI_SKIP_TAG}"
		# You shouldn't reset it in the follow, since we actually need it
		export NEEDS_PUSH=true
	fi
		
	deploy_distro_end 
}



# deploy-resources:
#   Deploys further resources, eg, Docker images, test servers.
#
function deploy_resources_begin {}
function deploy_resources_body {}
function deploy_resources_end {}

function deploy_resources
{
	deploy_resources_begin
	deploy_resources_body
	deploy_resources_end
}


# integration-tests:
#   Runs tests that needs deployed resources like test servers.
#
function integration_tests_begin {}
function integration_tests_body {}
function integration_tests_end {}

# finalize: 
#   Further operatinons and updates, which finalises a successful build, eg, tags and pushes
#   via git, tag a Docker image.
#
function finalize_begin {}
function finalize_body {}
function finalize_end {}

# close:
#   Final operations, eg, disposal of temp files, closing temp test servers.
#   This is always invoked, even in case of failure, so the implementation should decide
#   whether an operation here depends on a successful/failed build, or it's unconditional.
#
function close_begin {}
function close_body {}
function close_end {}



function do_if_exists
{
	fun=$1
	declare -F "$fun" >/dev/null && $fun || return 
}

function do_stage
{
  stage=$1

  do_if_exists ${stage}_begin
  do_if_exists ${stage}_flavor_begin
  do_if_exists ${stage}_base_begin
  ${stage}_body
  do_if_exists ${stage}_base_end
  do_if_exists ${stage}_flavor_end  
  do_if_exists ${stage}_end
}



 
printf "\n\n  ---- Building for the %s flavor ----\n\n" $CI_BUILD_FLAVOR 

flavor_hooks_path="$MYDIR/${CI_BUILD_FLAVOR}-hooks.sh"

if [[ ! -e "$flavor_hooks_path" ]]; then
  printf "\n  ERROR: no flavour hooks \"%s\" found, check the CI downloads work\n\n" "$flavor_hooks_path"
  exit 1 
fi

# Redefines the base hooks above, based on the specific flavour. This file can contain
# hook functions that override the base implementations above.
# 
. "$flavor_hooks_path"

local_hooks_path="$MYDIR/${CI_BUILD_FLAVOR}-hooks-local.sh"

if [[ -e "$local_hooks_path" ]]; then
	printf "\n  No local hooks \"%s\" found, using defaults for %s\n\n" "$local_hooks_path" $CI_BUILD_FLAVOR
else
  # Else, loads them
  . "$local_hooks_path"
fi 


for stage in build_local deploy distro
do
  do_stage $stage
done


# ----- Support helpers
function set_git_credentials
{
	# TODO: review where vars and secrets should come from (github or gist)
	git config --global user.name "$CI_GIT_USER"
	git config --global user.email "$CI_GIT_USER_EMAIL"
	git config --global "url.https://$CI_GIT_USER:$CI_GIT_PASSWORD@github.com.insteadof" "https://github.com"
}









export MAVEN_ARGS='--no-transfer-progress --batch-mode'

# PRs are checked out in detach mode, so they haven't any branch, so checking if this is != master
# filters them away too
export GIT_BRANCH=`git branch --show-current`

# If the current branch is one of these, then we have to do deploy operations, else
# we only do rebuilds. This distinguishes between eg, release branches and experimental branches or 
# pull requests.
# 
export DEPLOY_BRANCHES='master' # A list of branches, separated by spaces

# TODO: review documentation about handlers
# This can change the variables above, or pre-set some of the variables used below
[[ -e ./ci-build/build-begin.sh ]] && . ./ci-build/build-begin.sh


[[ " $DEPLOY_BRANCHES " =~ " $GIT_BRANCH " ]] && export IS_DEPLOY=true || IS_DEPLOY=false


# Manage releasing too, when these vars are defined
#
[[ ! -z "${NEW_RELEASE_VER}" ]] && [[ ! -z "${NEW_SNAPSHOT_VER}" ]] \
  && IS_RELEASE=true || IS_RELEASE=false

if $IS_RELEASE; then
  if ! $IS_DEPLOY; then
		echo -e "\n\nERROR: Can't do a release for a non-deploy branch, check DEPLOY_BRANCHES or the running branch\n"
		exit 1
	fi
	echo -e "\n\n\tReleasing ${NEW_RELEASE_VER}, new snapshot will be: ${NEW_SNAPSHOT_VER}\n" 
fi 


if ! $IS_RELEASE && [[ `git log -1 --pretty=format:"%s"` =~ "$CI_SKIP_TAG" ]]; then
	echo -e "\n$CI_SKIP_TAG prefix, ignoring this commit\n"
	exit
fi

export NEEDS_PUSH=false # TODO: document variables


# These need to be configured by the CI
git config --global user.name "$GIT_USER"
git config --global user.email "$GIT_USER_EMAIL"
git config --global "url.https://$GIT_USER:$GIT_PASSWORD@github.com.insteadof" "https://github.com"

if $IS_RELEASE; then
  mvn versions:set -DnewVersion="${NEW_RELEASE_VER}" -DallowSnapshots=true $MAVEN_ARGS
  # Commit immediately, even if it fails, we will have a chance to give up
  mvn versions:commit $MAVEN_ARGS
fi

if $IS_DEPLOY; then 
	echo -e "\n\n\tMaven Deployment\n"
	export MAVEN_GOAL='deploy'
else
	echo -e "\n\n\tNot in the main repo, and/or not in the master branch, building only, without deployment\n"
	export MAVEN_GOAL='install'
fi

[[ -e ./ci-build/build-before.sh ]] && . ./ci-build/build-before.sh

if [[ -e ./ci-build/build-body.sh ]]; then
  . ./ci-build/build-body.sh
else
  mvn $MAVEN_GOAL --settings ci-build/maven-settings.xml $MAVEN_ARGS
fi
 
[[ -e ./ci-build/build-after.sh ]] && . ./ci-build/build-after.sh

if ! $IS_DEPLOY; then
  echo -e "\n\n\tThis is not a deployment build, all ends here. Bye.\n"
	exit
fi


# And now manage the release too
#
if $IS_RELEASE; then
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
fi


if $NEEDS_PUSH; then
	echo -e "\n\n\tPushing changes to github\n"
	
	# It seems that Travis auto-pushes tags
	# TODO: Still neded? Requires testing, maybe it messes up with the assigned release tag
  git push --force --tags origin HEAD:"$GIT_BRANCH"
fi

[[ -e ./ci-build/build-end.sh ]] && . ./ci-build/build-end.sh

echo -e "\n\nThe End.\n"
