#!/usr/bin/env bash

# This is downloaded and executed by your project's build.sh.
# As a bootstrap script, it loads whatever is necessary from this repository

set -e

# Flavour-specific installers, they all use install()
# 

function install_java_maven
{
	url_base="$1"
	install "java-maven" "$url_base" "_common.sh" "java-maven/_common.sh" "java-maven/maven-settings.xml"
}


function install
{
	# Syntax: install_and_import <flavour> <url-base> <file> <file> ...
	#
	# flavour is a supported flavour name, eg, java-maven, python-poetry. This corresponds to 
	# one of the subdirectories in ci-build-v2/
	# 
	# url-base is the github URL base for the raw files in this repository, which can include a branch or a release
	# eg, https://raw.githubusercontent.com/Rothamsted/knetminer-common/refs/heads/ci-build-v2
  # 
	# files are relative to the ci-build-v2/ dir in this repository, eg, java-maven/_common.sh
	#

	flavour="$1"

	url_base="$2"
	printf "\n== Downloading from URL base '%s'\n\n" "$url_base"

	file_local_paths=("${@:3}")

	# Relative to the <git root>/ci-build-v2
	for file_local_path in "${file_local_paths[@]}"
	do
		file_local_path="ci-build-v2/$file_local_path"
		[[ ! -e "$file_local_path" ]] || continue;
				
		url="$url_base/${file_local_path}"
		file_path="$(realpath "${file_local_path}")"		
		dir_path="$(dirname "${file_path}")"
		
		printf "= Downloading '%s' to '%s'\n" "$url" "${file_path}"

		mkdir -p "${dir_path}"
		curl --fail-with-body "$url" -o "${file_path}"
	done

	# Eventually, these should be here.
	. "./ci-build-v2/${flavour}/_common.sh"
}

url_base="$1"
flavour="$2"

# Replace '-' with '_', so we can allow flavours with the same name as the subdirectories
# (Bash doesn't like '-')
flavour="${flavour//-/_}"

install_$flavour "$url_base" $flavour
