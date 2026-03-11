# The Continuous Integration Commons (CI-Commons)

This project offers common scripts to build projects based on various programming languages, including operations like compiling, testing, deploying on registries (Maven repositories, PyPI), working in release mode.

We use these scripts for KnetMiner projects, but they are generic and can be useful for your codebase as well.

[_common.sh](./_common.sh) is the core file. It contains the `main()` function which define a CI/CD common workflow, in the form of steps run by the `run_stage()` function.

`run_stage()` allows for customising/extending what a stage does for your project. For instance, if you want to customise the `build` stage, you can define a function named ``stage_build_local()` in your project/repository, and then `run_stage()` will call it instead of the default `stage_build()` implementation. This also permits a limited form of inheritance, since the `_local()` function can still call the original `stage_build()` when needed.

Stages have default implementations that vary with flavour of commons scripts you use, eg, if your project uses the [java-maven/_common.sh](java-maven/_common.sh) script, then its ``stage_build()` function will call Maven.

## A Little Tutorial

In the follow, we'll show how to use the CI-Commons to add CI builds to your Python/GitHub project.

### Start from your GitHub repository

Suppose this is at ` https://github.com/YourOrg/your-poetry-prj.git` and that it's 
based on [Poetry](TODO) and [PyTest](TODO).

Then, do this:

```bash
cd <your git clone root>
# Start up files and customisations
mkdir -p ci-build-v2/python-poetry

ci_release=<[LAST]RELEASE TAG ON OUR SIDE>
ci_base=https://raw.githubusercontent.com/Rothamsted/knetminer-common/refs/heads/$ci_release/ci-build-v2/

# A Common template that does all the bootstrapping
curl $ci_base/ci-build-v2/build.sh.template -o ci-build-v2/python-poetry/build.sh

# The usual stuff you need for GitHub Actions
mkdir .github
curl $ci_base/ci-build-v2/python-poetry/standard-build.yml -o .github/standard-build.yml
```

### Customise the templates

* Review the downloaded `ci-build-v2/python-poetry/build.sh`. In particular, adjust `ci_build_url_base` as above, so that your build script points to our repository correctly.

* Review the downloaded `.github/standard-build.yml`
  * This defines a minimal workflow that starts the actual build from your `ci-build-v2/python-poetry/build.sh`. One of the most important things it contains are the `env` section, which cranes your 
	GH secrets into your Bash environment.

### Test it

You can test your new build with the [act](TODO) tool. Setup a secrets file for it as needed (remember to keep it protected and **don't push it to github**).

This can be done before pushing the changes above to GitHub. Once act runs your new build based on our CI scripts, you can push your changes and GitHub will start building automatically at every push.

**Note**: once the automation is in place, you can skip a build against a particular commit, by adding '[ci skip]' at the end of the commit message. This is [a GHA feature](TODO)

### How it works and how to customise/extend your build

The CI Commons is arranged as a 3-layer script system:

* In the [generic _common.sh](_common.sh) a main() function is defined, which is the one called to start a CI build. This calls some common boilerplate functions, then a series of 'stage' functions, eg, `build()`, `deploy()`, `release()`

* The generic versions of these function do very common things, or are just empty. For instance, `stage_build_setup()` just authenticates the runner on github, `stage_build_setup()` just contains `true` (since bash functions can't be empty).

* The actual meat is in the flavour-specific `_common.sh` script, for instance [`python-poetry/_common.sh`](python-poetry/_common.sh). This imports (Via [Bash source](TODO)) the generic `_common.sh` and then overrides and extends the generic stage functions, as needed for a particular build flavour. For example, the `stage_build()` defined for the Python/Poetry flavour updates Poetry-related project files and then runs pytest via `poetry run`. The `stage_release()` function for the same flavour uses Poetry to publish the current project on PyPI (thanks to the upper common stuff, this happens only after tests pass).

* The idea behind having flavours is that a set of common tasks can be adapted to the specific language and a build tool for that language. At the moment, we have defined the already-mentioned Python+Poetry flavour and the [Java+Maven flavour](java-maven/).

The default commands in the `build.sh` script you downloaded is the third layer: it imports the flavour-specific `_common.sh` (which, as seen above, imports/overrides the generic commons), then it overrides/extends the generic or flavour-specific stage functions and eventually runs `main()`. The latter will pick-up the latest definition of stage functions. 

Since Bash isn't an object-oriented language, nor does it have an easy way to store references to redefined functions, your project/repository specific extensions should be based on functions named like `stage_${stage_name}_local()`. For instance, this example skips the PyPI publishing that is available in the default Python+Poetry flavour:

```bash
function stage_release_local
{
	is_release_mode || return 0

	# At least for now, we override the default by removing PyPI publishing, since, for the time being,
	# we link this project through its github URL.

	printf "== TODO: Skipping build+PyPI publishing for now, fix it when necessary\n"
	poetry $CI_POETRY_DEFAULT_ARGS build

	printf "== Moving the project to the next version\n"
	poetry  $CI_POETRY_DEFAULT_ARGS version ${CI_NEW_SNAPSHOT_VER}

	# Mark what we have just done with the release tag
	release_commit_and_tag
	
	# And commit it
	release_commit_new_snapshot
}
```

In this other example (from the [jutils repo](https://github.com/marco-brandizi/jutils)) about the Java+Maven flavour, we run our Javadoc script after having called the common `build` stage: 

```Bash
function stage_build_local
{
	# First does the common stuff for this flavour stage
	stage_build
	
	# Javadocs only for the main trunk
	#
	[[ "$CI_GIT_BRANCH" == 'master' ]] || return 0

  # You can place whatever you want in your local ./ci-build-v2/ directory, the CI scripts are 
	# run on your own runner, and their starting directory is the root of your own repository 
	# (if the workflow clones it through the checkout action)
	# 
	bash ./ci-build-v2/java-maven/mk-javadocs.sh
	
	printf "== Committing Javadocs\n"
	git add docs/apidocs
  git commit -a -m "docs: update CI-generated javadoc files $CI_SKIP_TAG"

  export CI_NEEDS_PUSH=true # Instructs the git update stage that we have stuff to push
}
```

This also shows why yor local extension should have the `_local` postfix in its name: each stage has an id and must have the `stage_$id ()` function defined, and optionally, the `$stage_id_local ()`. If the latter exists, the `main()` function invokes it in place of `stage_$id ()`, but the original function is still around, so you can reuse it in your local version when needed (as shown here).

The previous example about Python shows that you can completely override the original stage function, though, in that case, probably you'll still want to look at the original code and replicate part of it. Functions like `release_commit_and_tag()` are defined in the generic `_common.sh` to ease this approach.

## Tricks and tips

### Conventions

When you customise a build, have a look at existing conventions. For instance:

* Almost all environment variables that are managed by CI-Commons and are meant to drive the build, stage behaviours, deployment credentials, etc, are prefixed with `CI_`, eg, `CI_NEW_RELEASE_VER`, `CI_REV_HISTORY_PATH`

* A stage begins and ends with messages like: 
  ```bash
  printf "\n\n==== Stage: ${stage_fun}\n\n"
  ${stage_fun}
  printf "\n==== /end Stage: ${stage_fun}\n\n"
	```
	While messages within the stage have only "==" and no beginning new lines

* flags have the 'true' or 'false' values (or aren't set) and their name is like `is_xxx` or `IS_XXX`

* As per Bash conventions, variables that are exported to external scripts or comes from the outside have uppercase names, the others are lowercase.

### Slack notifications

The `main()` function uses the [Bash trap mechanism](TODO) bind any build failure to the function `notify_failure()`. This checks if `CI_SLACK_API_NOTIFICATION_URL` is available (usually from GHA secrets) and possibly uses it to notify Slack of the problem. This can be useful for your Slack team and is based on [Slack web hooks](https://www.howtogeek.com/devops/how-to-send-a-message-to-slack-from-a-bash-script).

TODO: support for other notification mechanisms (eg, email, Jira).

