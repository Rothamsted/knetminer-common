#!/usr/bin/env bash
set -e

function install_and_import 
{
	url_base="$1"
	printf "\n== Downloading from URL base '%s'\n\n" "$url_base"

	file_local_paths=("_common.sh" "java-maven/_common.sh" "java-maven/maven-settings.xml")

	# Relative to the <git root>/ci-build-v2
	for file_local_path in "${file_local_paths[@]}"
	do
		file_local_path="ci-build-v2/$file_local_path"
		[[ ! -e "$file_local_path" ]] || continue;
				
		url="$url_base/${file_local_path}"
		file_path="$(realpath "${file_local_path}")"		
		dir_path="$(dirname "${file_path}")"
		
		printf "= Downloading '%s' to '%s'" "$url" "${file_path}\n"

		mkdir -p "${dir_path}"
		curl --fail-with-body "$url" -o "${file_path}"
	done

	# Eventually, these should be here.
	. ./ci-build-v2/java-maven/_common.sh	

	# WARNING: the best way to override functions defined in these imported files is 
	# doing it in your own definition file and then importing it after the original ones, like
	# it's shown here.
	# This is not necessary if you only have stage_xxx_local() functions (or only your own new
	# functions).
	#
	# . ./ci-build-v2/java-maven/_common-local.sh
}

install_and_import "https://raw.githubusercontent.com/Rothamsted/knetminer-common/refs/heads/ci-build-v2"
main
