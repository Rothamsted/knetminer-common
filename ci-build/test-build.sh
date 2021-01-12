# Do not use, it's to test the build.sh manually
#
set -e

#export NEW_RELEASE_VER='2.0RC1'
#export NEW_SNAPSHOT_VER='2.0.1-SNAPSHOT'

export GIT_USER=marco-brandizi
export GIT_USER_EMAIL=marco.brandizi@rothamsted.ac.uk
[[ -z "$GIT_PASSWORD" ]] && { echo GIT_PASSWORD is empty; exit 1; }

[[ -z "$KNET_REPO_USER" ]] && { echo KNET_REPO_USER is empty; exit 1; }
[[ -z "$KNET_REPO_PASSWORD" ]] && { echo KNET_REPO_PASSWORD is empty; exit 1; }


start_dir=`pwd`
cd `dirname "$BASH_SOURCE"`
cd ..

ci-build/build.sh
cd "$start_dir"
