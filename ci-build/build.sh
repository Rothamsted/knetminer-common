set -e

function notify_failure 
{
	CI_SUBJECT="{CI_SUBJECT-CI build failure for $GITHUB_REPOSITORY}"
	run_url="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
	CI_FAIL_MESSAGE="{CI_FAIL_MESSAGE-Sorry, build for this repo failed, see details at $run_url}"
	CI_MAIL_FROM="{CI_MAIL_FROM-$GIT_USER_EMAIL}"
	
	sendemail -f "$CI_MAIL_FROM" -t $CI_NOTIFIED_EMAILS \
	-m "$CI_FAIL_MESSAGE" \
	-u "$CI_SUBJECT" \
	-s "$CI_SMTP_SERVER" -xu "$CI_SMTP_USER" -xp "$CI_SMTP_PASSWORD" \
	-o tls=yes
}

# TODO: To be completed (including variables above)
# Needed to send notifications
#apt-get -y update
#apt-get -y sendemail
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


# TODO: document these two
export CI_SKIP_TAG='[ci skip]'
export MAVEN_ARGS='--no-transfer-progress --batch-mode'

if [[ `git log -1 --pretty=format:"%s"` =~ "$CI_SKIP_TAG" ]]; then
	echo -e "\n$CI_SKIP_TAG prefix, ignoring this commit\n"
	exit
fi

export NEEDS_PUSH=false # TODO: document variables

# PRs are checked out in detach mode, so they haven't any branch, so checking if this is != master
# filters them away too
export GIT_BRANCH=`git branch --show-current`
export DEPLOY_BRANCH=master # TODO: or a list?


# Manage releasing too, when these vars are defined
#
export IS_RELEASE=false
if [[ ! -z "${NEW_RELEASE_VER}" ]] && [[ ! -z "${NEW_SNAPSHOT_VER}" ]]; then
	if [[ "$GIT_BRANCH" != 'master' ]]; then
		echo -e "\n\nERROR: use releasing parameters with the main repo and the master branch only!\n"
		exit 1
	fi 
  echo -e "\n\n\tReleasing ${NEW_RELEASE_VER}, new snapshot will be: ${NEW_SNAPSHOT_VER}\n" 
  export IS_RELEASE=true
fi


# TODO: review documentation about handlers
[[ -e ./ci-build/build-begin.sh ]] && . ./ci-build/build-begin.sh


# These need to be configured by the CI
git config --global user.name "$GIT_USER"
git config --global user.email "$GIT_USER_EMAIL"
git config --global "url.https://$GIT_USER:$GIT_PASSWORD@github.com.insteadof" "https://github.com"

if $IS_RELEASE; then
  mvn versions:set -DnewVersion="${NEW_RELEASE_VER}" -DallowSnapshots=true $MAVEN_ARGS
  # Commit immediately, even if it fails, we will have a chance to give up
  mvn versions:commit $MAVEN_ARGS
fi

if [[ "$GIT_BRANCH" == "$DEPLOY_BRANCH" ]]; then 
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

if [[ "$GIT_BRANCH" != "$DEPLOY_BRANCH" ]]; then
  echo -e "\n\n\tNot in the main repo, and/or not in the master branch, build ends here. Bye.\n"
	exit
fi


# And now manage the release too
#
if $IS_RELEASE; then
	echo -e "\n\n\tCommitting ${NEW_RELEASE_VER} to github\n"
	git commit -a -m "Releasing ${NEW_RELEASE_VER}. ${CI_SKIP_TAG}"
	
  # TODO: --force was used in Travis, cause it seems to place a tag automatically
	git tag --force --annotate "${NEW_RELEASE_VER}" -m "Releasing ${NEW_RELEASE_VER}. ${CI_SKIP_TAG}"
	
	echo -e "\n\n\tSwitching codebase version to ${NEW_SNAPSHOT_VER}\n"
	mvn versions:set -DnewVersion="${NEW_SNAPSHOT_VER}" -DallowSnapshots=true $MAVEN_ARGS
	mvn versions:commit $MAVEN_ARGS
	
	git commit -a -m "Switching version to ${NEW_SNAPSHOT_VER}. ${CI_SKIP_TAG}"
	NEEDS_PUSH=true
fi


if $NEEDS_PUSH; then
	echo -e "\n\n\tPushing changes to github\n"
	
	# It seems that Travis auto-pushes tags
	# TODO: Still neded? Requires testing, maybe it messes up with the assigned release tag
  git push --force --tags origin HEAD:"$GIT_BRANCH"
fi

[[ -e ./ci-build/build-end.sh ]] && . ./ci-build/build-end.sh

echo -e "\n\nThe End.\n"
