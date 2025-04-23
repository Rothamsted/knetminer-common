# Revision History

*This file was last reviewed on 2025-04-23.* **Please, keep this note updated.**

# 6.0.1-SNAPSHOT
* Next snapshot

# 6.0
* Migration to new artifactory.knetminer.com Maven repo.
* Surefire, deprecated systemProperties replaced by systemPropertyVariables.
* Commons RNG removed.


# 5.0
* Maven plug-ins upgraded.
* Many dependencies upgraded.
* More dependencies added: Reactor, Commons RNG.

## Continuos Integration Scripts
* Adding 'main' to the default list of branches that should be deployed.
* CI scripts, diagnostic messages added.
* CI scripts, distinction between `MAVEN_BUILD_ARGS` and `MAVEN_ARGS`.


# 4.0
* Migrated to Java 17. **WARNING: no backward compatibility guaranteed**.


# 3.1.1-SNAPSHOT
* Internal repo re-added for testing purposes.

## CI scripts:
* --no-transfer-progress removed from default options, since it hides important uploading messages


# 3.1
* build.sh extended to support multiple deploy branches
* Minor fixes in the archetype utility
* More plug-ins added to the common POM
* Dependency upgrades to the common POM
* Multiple branches for CI scripts
* Failure notification to Slack for CI script


# 3.0.1
* JSON-related dependencies added
* Various dependency upgrades 


# 2.0
* download-page added
* Eclipse directive to ignore plug-ins added (avoid irrelevant warnings in Eclipse)
* Java 11 migration and other dependency upgrades
* Migrated to github actions, generic CI scripts


## 1.0
* First release

