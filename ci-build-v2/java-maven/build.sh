#!/usr/bin/env bash
set -e

function install_and_import 
{
	# eg, export CI_URL_BASE="https://raw.githubusercontent.com/Rothamsted/knetminer-common/refs/heads/ci-build-v2/ci-build-v2"	
	if [[ ! -z "$CI_BUILDER_VERSION" ]]; then
		cat <<EOT
		
		
		CI_BUILDER_VERSION is not set, you must set this in your GHA workflow file.
		See the documentation for details.
		
EOT
	fi		
	

	#for download in ("$url_base/_common.sh" _common.sh) ("$url_base/java-maven/maven-settings.sh" java-maven/maven-settings.sh)
	# Relative to the git root
	for file_local_path in "_common.sh" "java-maven/_common.sh" "java-maven/maven-settings.sh"
	do
		[[ ! -e "$file_local_path" ]] || continue;
				
		url="$CI_URL_BASE/${file_local_path}"
		file_path="$(realpath "${file_local_path}")"		
		dir_path="$(dirname "${file_path}")"
		
		print "- Downloading '%s' to '%s'" "$url" "${file_path}"

		mkdir -p "${dir_path}"
		curl "$url" -o "${file_path}"
	done
	
	# Eventually, these should be here
	. ./ci-build-v2/java-maven/_common.sh	
}

install_and_import
main
