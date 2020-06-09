
# This is only used by the default travis in the archetype-built projects. The main project
# ignores it. 
#
cd `dirname "$0"`

# Travis has to both define TRAVIS_DIR_URL and download me.
#
for file in maven-settings.xml travis.sh 
do
	wget "$TRAVIS_DIR_URL/$file" -O "$file"
done
