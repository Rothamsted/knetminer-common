# TODO: install.sh
# TODO: _common.sh

# TODO: comment me!
# 
function init_release
{
	$is_release && return || true
	 
  mvn versions:set -DnewVersion="${NEW_RELEASE_VER}" -DallowSnapshots=true $MAVEN_ARGS
  # Commit immediately, even if it fails, we will have a chance to give up
  mvn versions:commit $MAVEN_ARGS
}

function maven_main_build
{
	
}