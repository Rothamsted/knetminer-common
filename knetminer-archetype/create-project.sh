#
# This file is generated by the POM from the copy at /src/main/resources/create-project.sh
# So, modify that copy only!
# 
# TODO: doesn't work after a release.
#
groupId="$1"
artifactId="$2"
version="$3"

if [[ "$#" < 3 ]]; then
	cat <<EOT


Creates a new Knetminer project from our archetype.  
	
	$(basename $0) <groupId> <artifactId> <version> 

EOT
	exit 1
fi

# First, download the archetype
mvn dependency:get \
  -Dartifact=uk.ac.rothamsted.knetminer:knetminer-archetype:3.0.2-SNAPSHOT\
  -DremoteRepositories=https://knetminer.org/artifactory/repository/maven-public
     
# So that now we can use it from the local repo
#
mvn archetype:generate \
	-DgroupId=$groupId -DartifactId=$artifactId -Dversion=$version \
	-DarchetypeGroupId=uk.ac.rothamsted.knetminer \
	-DarchetypeArtifactId=knetminer-archetype \
	-DarchetypeVersion=3.0.2-SNAPSHOT \
	-DinteractiveMode=false 
