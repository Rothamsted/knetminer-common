# New Common ci-build

## Current workflow

An abstract view is:

* error handler
* environment setup
* check schedule
* git setup
* if install:
  * build and install
* else if deploy:
  * build and deploy
* if deploy:
  * deploy operations (eg, test server)
* if release:
  * release operations (eg, tagging, release server, distro download)
* if needs_push
  * git push

  
## New Architecture

* Have common flavour-independent lib
  * error_handler
  * schedule_check
  * the notion of stage with hooks, with `run_stage()`, `run_hook() # (if exists)`
  * ssh deployment?
  * git versioning/tagging

* Every flavour has its own directory and its own workflow

```bash
function run_hook
{
	fun=$1
	declare -F "$fun" >/dev/null && $fun || return 
}

function run_stage
{
  stage=$1

  run_hook ${stage}_before
  ${stage}_body
  run_hook ${stage}_after
}
```

* What next:
  * fix inclusions
  * fix REPO_DIR, it's computed from top-level
  * test simple Maven build
  
