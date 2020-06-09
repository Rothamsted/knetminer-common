# The Knetminer archetype

This is a [Maven Archetype project][10], which helps to define new Knetminer-related projects that
contains common elements and pointers to our resources. See the [main README](../README.md) for details.  

When you generate a new Maven project with this artifact, you have a starting skeleton, which links to our
common POM (see the link above) and inherits copies of common files like the ones needed for Travis deployment
(again, see the link above).

[10]: https://maven.apache.org/archetype/maven-archetype-plugin/index.html
 
You can easily generate a new project (ie, Maven module) from a Bash-compatible shell,
by typing something like:


```bash  	
curl -L https://tinyurl.com/knetminer-archetype-sh | sh -s uk.ac.rothamsted.knetminer sample-jar 1.0-SNAPSHOT
```

where, of course, the three parameters are the new artifact's coordinates.

The new project is a simple jar project. The common elements it contains include:

  * A [POM file][20] that inherits from our [common POM](../README), defining common third party dependencies 
  (eg, log4j2) and coordinates to download/deploy with our [team artifactory](https://knetminer.org/artifactory)
  * A [simple Travis file][30], which downloads our [common Maven settings](../settings.xml) and deploys your new 
  project on our artifactory
  * A convenience [.gitignore file][40]

**WARNING**: The default `.gitignore` files ignores `travis/*`, since our scripts download this from our repo and,
by default, it is not meant to be duplicated in derived projects.  
  

**To Windows users**: while we haven't tried it yet, we're confident that you can reproduce what the command above does
manually. That is, download this hereby archetype project as a dependency in your local Maven, 
then launch the Archetype plugins. This is simply what the [above script](create-project.sh) does.

[20]: src/main/resources/archetype-resources/pom.xml
[30]: src/main/resources/archetype-resources/.travis.yml
[40]: src/main/resources/archetype-resources/.gitignore
