# The knetminer Maven commons

This Maven project contains resources that are commonly used by the Knetminer team, either to 
manage Maven-based projects, or other utilities (eg, maintenance scripts).

In this README, we list the resources you find here.


## Index

* [Common parent POM](#common-parent-pom)
* [Deployment on our artifactory server](#deployment-on-our-artifactory-server)
* [Using multiple deployment profiles](#using-multiple-deployment-profiles)
* [Continuous integration support files](#continuous-integration-support-files)
* [Archetype for new projects](#archetype-for-new-projects)
* [Downloading Page scripts](#downloading-page-scripts)
* [Other common files](#other-common-files)
* [Usage examples](#usage-examples)

    
## Common parent POM

This is [here](pom.xml), just next to this hereby document. This can be used with either new or existing projects,
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
you can refer without having to specifying a version to use. For instance, this:

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
Possibly trigger CI builds manually (including internal Jenkins jobs) and check they still succeed. If needed, 
increase the POM version.

More elements are defined in the common POM for you, like the UTF-8 encoding, the default Java version, etc. 
More can be added, either by yourself, if you've admin rights, or upon request. Like dependencies, these are all defaults,
which can be overriden when needed.


## Deployment on our artifactory server

Once your project is linked to our common POM, it's easy to deploy it into our artifactory server.
This can be done by using our common Maven settings file (included [hereby][20], in the same project 
where this hereby README is):.

```bash
$ cd <where your POM and project is>
$ curl https://raw.githubusercontent.com/Rothamsted/knetminer-common/master/ci-build/maven-settings.xml \
  settings.xml
$ export KNET_REPO_USER=<your-user>
$ export KNET_REPO_PASSWORD=<your-password>
$ mvn clean deploy --settings settings.xml
```

As you can see, you need an account to write into our artifactory server. The OS variables used to define
them are the same defined in [`maven-settings.xml`][20]. Maven has alternatives to do so (eg, `.m2/settings.xml`), though the 
preferred way to deploy your project is via CI automation (see the next section).

[20]: ci-build/maven-settings.xml


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


## Continuous integration support files
You don't need to deploy from you working PC, manually. We use CI systems nowadays, and
our current one is [GitHub Actions][30]. You can reuse our [common GH Actions file][50]. As you can see, this
does the very minimal, that is: 

  1. Defines common stuff like the Java version to use for the build
  1. Downloads common files and scripts we use to build (from this hereby repository)
  1. Runs the downloaded `[ci-build/build.sh][170]`
  1. Keeps Maven files into a cache, to ensure performance (and contribute to the environment...)

[170]: ci-build/build.sh

This assumes that you define a number of authentication values, via [GitHub Actions secrets][60].

The `build.sh` script is designed to manage releases as well. You can run a build manually, from the GH Actions 
control panel. From there, set proper variables there about the new release version you want and the next Maven 
snapshot version you want the codebase to be updated with, and the script will issue a release, move the POM to 
the next snapshot, commit everything on GitHub.      

Again, you'll need to define your github credentials, in order to push new tags.

This version is designed to completely automate the download of our build files into your local
project copy, every time you build (from GH Actions). You might need some customisation, by either working
with a copy of the build file above, or by leveraging build script handlers (see next paragraph).  

Another function that `build.sh` has is checking if the build was triggered by a [periodically scheduled workflow][65]
or not. If that's the case, the script proceeds with an actual build only if there have been github commits since
the last build.    

Finally, note that we try to keep our CI scripts as independent as possible from the particular CI framework that
is being used.  
 
[30]: https://docs.github.com/en/free-pro-team@latest/actions/quickstart
[50]: knetminer-archetype/src/main/resources/archetype-resources/.github/workflows/build.yml
[60]: https://docs.github.com/en/free-pro-team@latest/actions/reference/encrypted-secrets
[65]: https://jasonet.co/posts/scheduled-actions/


### Reusing build files and customising the build

If you need a particular building flow, which different from our default only on a couple of details, you don't 
necessarily need to rewrite the logics of `build.sh` from scratch, or worse, duplicate and tweak it. 
In fact, such `build.sh` script is a scaffold for common actions and a Maven-based build is framed within such scaffold.   

This is obtained by checking if certain script handlers are present in the `ci-build` folder of your code base. Briefly,
this is the workflow of `build.sh`

* Check if we actually need a build at all (eg, if we are in a periodic build and there aren't recent git commits, or 
  the last commit has the '[ci skip]' tag in its message).
* Do some preparations and set variables like `GIT_BRANCH` or `IS_RELEASE`. This includes setting the Maven project to
  the version `NEW_RELEASE_VER`, if this is passed in as parameter.
* if the handler **`build-before.sh`** exists, it's run (using [bash sourcing][200], ie, the handler can set 
  variables for its parent of for the following handlers).
* if **`build-body.sh`** exists, it runs it (again, via sourcing), else runs a default `mvn <deploy|install>` command.
  * As mentioned above, if you're managing a release build, these scripts are called with the Maven project set to the release 
    version that you passed via the `NEW_RELEASE_VER` parameter. 
* same as above for **`build-after.sh`**.
* After the main build, if needed, `build.sh` finalises the releasing process, ie, commits/pushes the new version 
  to github, including adding a proper version tag, move the Maven project's version to the next snapshot version 
  (using the `NEW_SNAPSHOT_VER` parameter).  
* If the `NEEDS_PUSH` variable is set to 'true', pushes CI-commited changes to the git's cloned codebase.
* As a last step, after build, releasing and github updates, the script **`build-end.sh`** is invoked if it exists 
  (once more, via Bash sourcing). So, this is to do very final operations, like notifying other systems (eg, for 
  internal deployment).
 
See [the `build.sh` script][170] for details. Examples of such customisations are available for [Ondex][202] 
and [Knetminer][204].  

[200]: https://linuxize.com/post/bash-source-command
[202]: https://github.com/Rothamsted/knetbuilder/tree/master/ci-build
[204]: https://github.com/Rothamsted/knetminer/tree/master/ci-build


## Archetype for new projects

All of the above (link to common POM, GH Actions settings) is easy to setup when you're creating a new Maven project, 
thanks to our [Maven Archetype Project](knetminer-archetype). In case you don't know them, [Maven archetypes][70] are 
templates to make Maven projects. In our case, you can quickly create a new project with a POM that contains the 
elements described above (inheritance from the common POM, basic GH Actions file) and more (eg, common files 
like `.gitignore`, see the next section).  

Details on how to use Maven archetypes are available in its [README][80].

[70]: https://maven.apache.org/archetype/maven-archetype-plugin/index.html
[80]: knetminer-archetype/README.md


## Downloading Page scripts

These are scripts that we use with KnetMiner Maven-based projects, to build download pages about the
binary artifacts that are published on our Maven artifactory. See [here](download-page) for details.


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
