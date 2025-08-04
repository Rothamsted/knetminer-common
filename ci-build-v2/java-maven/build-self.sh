#!/usr/bin/env bash
set -e

# Do not use it. This is the entry point for building from my own repository.
# It essentially uses java-maven/build.sh, but without downloading anything, since the 
# files that would normally be downloaded from myself are already here.
#

function install_and_import 
{
	. ./ci-build-v2/java-maven/_common.sh	
}

install_and_import
main
