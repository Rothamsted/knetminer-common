#!/usr/bin/env bash
set -e

function install_and_import 
{
	ci_url_base="$1"

	# Relative to the git root
	for file_local_path in "_common.sh" "java-maven/_common.sh" "java-maven/maven-settings.sh"
	do
		[[ ! -e "$file_local_path" ]] || continue;
				
		url="$ci_url_base/${file_local_path}"
		file_path="$(realpath "${file_local_path}")"		
		dir_path="$(dirname "${file_path}")"
		
		print "- Downloading '%s' to '%s'" "$url" "${file_path}"

		mkdir -p "${dir_path}"
		curl "$url" -o "${file_path}"
	done
	
	# Eventually, these should be here
	. ./ci-build-v2/java-maven/_common.sh	
}

install_and_import "https://raw.githubusercontent.com/Rothamsted/knetminer-common/refs/heads/ci-build-v2/ci-build-v2"
main
