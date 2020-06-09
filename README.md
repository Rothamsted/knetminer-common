# The knetminer Maven commons

This Maven project contains resources that are commonly used by the Knetminer team, either to 
manage Maven-based projects, or other utilities (eg, maintenance scripts).

In this README, we list the resources you find here.


## Index

  * [Common parent POM](#common-parent-pom)
  * [Deployment on our artifactory server](#deployment-on-our-artifactory-server)
  * [Using multiple deployment profiles](#using-multiple-deployment-profiles)
  * [Travis support files](#travis-support-files)
  * [Archetype for new projects](#archetype-for-new-projects)
  * [Other common files](#other-common-files)
  * [Usage examples](#usage-examples)

    
## Common parent POM

this is [here](pom.xml), just next to this hereby document. This can be used with either new or existing projects,
to put in place some common definitions that you need to deploy on our [artifactory service][10], or to harmonise the
third-party Maven dependencies we use for our projects.

[10]: https://knetminer.org/artifactory/


Your project can be linked to this common POM the usual way:


```xml
<project ...>
  <modelVersion>4.0.0</modelVersion
  
  <!-- The link to us -->
	<parent>
	  <groupId>uk.ac.rothamsted.knetminer</groupId>
	  <artifactId>knetminer-common</artifactId>
	  <version>SEE-THE-POM</version>
	</parent>  
  
  <groupId>YOUR-GROUP-ID</groupId>
  <artifactId>YOUR-ARTIFACT-ID</artifactId>
  <version>YOUR-VERSION<version>

  ...
  
	<repositories>
	  <repository>
	  	<!-- This is needed to let Maven find the parent POM -->
			<id>knetminer-repo</id>
			<name>Knetminer Unified Repository</name>
			<url>https://knetminer.org/artifactory/repository/maven-public</url>
			<snapshots><enabled>true</enabled></snapshots>
			<releases><enabled>true</enabled></releases>
	  </repository>
	</repositories>	
	
	...
</project>
```

This will link your project to our artifactory server, which manages, among other things, Ondex artifacts, Knetminer
artifacts and a cache from Maven central. You can add more proxied Maven repositories to it, if you've the right 
credentials (else, just ask the Knetminer team admins). This makes builds faster and avoids to list those repositories 
in every POM where you need them (just the knetminer-repo listed above is needed).

As usually, it also makes you available a number of dependencies, either about our own projects or third-parties, which
youn can refer without having to specifying a version to use. For instance this:

```xml
<dependency>
  <groupId>org.apache.logging.log4j</groupId>
  <artifactId>log4j-api</artifactId>
</dependency>
<dependency>
  <groupId>org.apache.logging.log4j</groupId>
  <artifactId>log4j-core</artifactId>
</dependency>
```  

will point at the version defined in our parent POM, in its `dependencyManagement` section.  

This has pros and cons. On the one hand, if you have multiple and interdependant projects, it's easier to keep  their 
common dependencies aligned. On the other hand, your builds might break more often, when we upgrade our POM, especially
if you're using a SNAPSHOT version of it.

**Note to maintainers**: if you have access to the hereby common POM, be careful with upgrading a managed dependency.
Possibly trigger Travis and Jenkins builds around manually and check they still succeed. If needed, increase the POM
version.

More elements are defined in the common POM for you, like the UTF-8 encoding, the default Java version, etc. 
More can be added, either by yourself, if you've admin rights, or upon request. Like dependencies, these are all defaults,
which can be overriden when needed.


## Deployment on our artifactory server

Once your project is linked to our common POM, it's easy to deploy it into our artifactory server.
This can be done by using our common Maven settings file (included [hereby][20], in the same projec 
where this README is):.

```bash
$ cd <where your POM and project is>
$ curl https://raw.githubusercontent.com/Rothamsted/knetminer-common/master/travis/maven-settings.xml \
  settings.xml
$ export KNET_REPO_USER=<your-user>
$ export KNET_REPO_PASSWORD=<your-password>
$ mvn clean deploy --settings settings.xml
```

As you can see, you need an account to write into our artifactory server. The OS variables used to define
them are the same defined in `maven-settings.xml`. Maven has alternatives to do so (eg, `.m2/settings.xml`), though the 
preferred way to deploy your project is via Travis automation (see the next section).

[20]: travis/maven-settings.xml


## Using multiple deployment profiles

It's a common practice to set different profiles in a project's POM, so that it's possible to deploy the project in 
different repositories. If that's your case (eg, you're working with a third-party fork), we provide Maven properties 
to do so. In addition to the steps above, (mention our POM in your `<parent>` section and add our artifactory server 
in `<repositories>`), you can define a profile like:
  
```xml
<profile>
	<id>knetminer-deploy</id>
	<distributionManagement>
	  <repository>
			<id>${knetminer.mvnrepo.rel.id}</id>
			<name>${knetminer.mvnrepo.rel.name}</name>
			<url>${knetminer.mvnrepo.rel.url}</url>
	  </repository>
	  <snapshotRepository>
			<id>${knetminer.mvnrepo.snapshots.id}</id>
			<name>${knetminer.mvnrepo.snapshots.name}</name>
			<url>${knetminer.mvnrepo.snapshots.url}</url>
	  </snapshotRepository>
	</distributionManagement>
</profile>

```

and then use `mvn deploy -Pknetminer-deploy` as usually. Alternatively, if your project is already using properties
in the `<distributionManagement>` section and overriding them with profiles, you can do:

```xml
<profile>
	<id>knetminer-deploy</id>

	<properties>
		<your.prop.rel.id>${knetminer.mvnrepo.rel.id}</your.prop.rel.id>
		<your.prop.rel.name>${knetminer.mvnrepo.rel.name}</your.prop.rel.name>		
		<your.prop.rel.url>${knetminer.mvnrepo.rel.url}</your.prop.rel.url>

		<your.prop.snapshots.id>${knetminer.mvnrepo.snapshots.id}</your.prop.snapshots.id>
		<your.prop.snapshots.name>${knetminer.mvnrepo.snapshots.name}</your.prop.snapshots.name>		
		<your.prop.snapshots.url>${knetminer.mvnrepo.snapshots.url}</your.prop.snapshots.url>
	</properties>
</properties>
```


## Travis support files
You don't need to deploy from you working PC, manually. We use CI systems nowadays, and
our preferred ones is Travis(1[30], 2[40]). You can reuse our [standard Travis file][50]. As you can see, this
does the very minimal, that is: 

	1. Defines common stuff like the Java version to use for the build
  1. Downloads the [settings file][20] discussed above
  1. Issues 'mvn deploy' using those settings
  1. Keeps Maven files into a cache, to ensure performance (and contribute to the environment...)

Once you have copied that file into your Maven project, these basics can customised as you need.
Note that this requires that you define the right credential variables (the ones used by `settings.xml`, see above)
in the [Travis settings for your project][60]. 
 

[30]: https://www.vogella.com/tutorials/TravisCi/article.html
[40]: https://docs.travis-ci.com/user/tutorial/
[50]: knetminer-archetype/src/main/resources/archetype-resources/.travis.yml
[60]: https://docs.travis-ci.com/user/environment-variables/#defining-variables-in-repository-settings


## Archetype for new projects

All of the above (link to common POM, Travis settings) is easy to setup when you're creating a new Maven project, thanks
to our [Maven Archetype Project](knetminer-archetype). In case you don't know them, [Maven archetypes][70] are templates
to make Maven projects. In our case, you can quickly create a new project with a POM that contains the elements described
above (inheritance from the common POM, basic Travis file) and more (eg, common files like `.gitignore`, see 
the next section).  

Details on how to use the archetype are available in its README.

[70]: https://maven.apache.org/archetype/maven-archetype-plugin/index.html


## Other common files

Most of Knetminer common files are into the [Maven Archetype Project](knetminer-archetype). If you already have an 
existing project, you can download files separately from that.  

In addition to the files mentioned in the other sections, other relevant ones are:  

  * [.gitignore](knetminer-archetype/.gitignore), which defines common files you don't want to version
  * More to come (TODO)


## Usage examples

For more details on how to use the material in this repository, have a look at real use cases:

  * [rdf2neo](https://github.com/Rothamsted/rdf2neo)
  * More to come (TODO)
 
