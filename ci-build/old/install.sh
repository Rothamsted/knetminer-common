
# This is used by the default ci-build.sh script in the archetype-built projects. The main project
# ignores it. 
#
cd `dirname "$0"`

# The CI config has to both define CI_DIR_URL and download me.
#
for file in maven-settings.xml build.sh
do
	[[ -e "$file" ]] || wget "$CI_DIR_URL/$file" -O "$file"
done
