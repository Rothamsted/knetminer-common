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

**To Windows users**: while we haven't tried it yet, we're confident that you can reproduce what the command above does
manually. That is, download this hereby archetype project as a dependency in your local Maven, 
then launch the Archetype plugins. This is simply what the [above script](create-project.sh) does.
