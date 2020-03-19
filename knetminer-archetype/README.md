# The Knetminer archetype

TODO: intro

```bash  	
mvn archetype:generate \
  -DgroupId=org.test.group \
  -DartifactId=test \
  -DarchetypeGroupId=uk.ac.rothamsted.knetminer \
  -DarchetypeArtifactId=knetminer-archetype \
  -DarchetypeVersion=<see pom.xml>
```

**YOU HAVE TO SETUP OUR REPOSITORY**
		
The `-DarchetypeRepository` don't work anymore with recent versions of the Maven archetype plugin,
So, in order for the command above to work, you've to first setup our repository:  
  
`https://knetminer.org/artifactory/repository/maven-public`  
    
in your Maven environment. Details [here][1].

[1]: https://maven.apache.org/archetype/maven-archetype-plugin/archetype-repository.html
