# The Continuous Integration Commons

This project offers common scripts to build projects based on various programming languages, including operations like compiling, testing, deploying on registries (Maven repositories, PyPI), working in release mode.

We use these scripts for KnetMiner projects, but they are generic and can be useful for your codebase as well.

[_common.sh](./_common.sh) is the core file. It contains the `main()` function which define a CI/CD common workflow, in the form of steps run by the `run_stage()` function.

`run_stage()` allows for customising/extending what a stage does for your project. For instance, if you want to customise the `build` stage, you can define a function named ``stage_build_local()` in your project/repository, and then `run_stage()` will call it instead of the default `stage_build()` implementation. This also permits a limited form of inheritance, since the `_local()` function can still call the original `stage_build()` when needed.

Stages have default implementations that vary with flavour of commons scripts you use, eg, if your project uses the [java-maven/_common.sh](java-maven/_common.sh) script, then its ``stage_build()` function will call Maven.

