
# Rough debugging/logging function. Several function below use this and actually print 
# diagnostics when IS_DEBUG is non-null
#

#IS_DEBUG=true
function debug
{
  [[ -z "$IS_DEBUG" ]] && return
  echo "$1" >&2	
}

# Checks that the templates came in as the first argument in the command line.
# See download-page-example.sh 
#
function get_template
{
	if [ "$1" == "--help" ]; then
	
	  cat <<EOT
	  
	  
	    ./$(dirname $0)
	    
	Outputs the download file, using the template to place the links to the latest versions. 
	
EOT
	
	  exit 1
	fi
}


# A simple client to the Nexus API to search info about a Maven artifact 
# This returns API JSON and might contain multiple results per query (eg, multiple versions),
# which are sorted by version number (Nexus applies a sensible order relation like 3.2.1 > 3.2) 
# 
# See the list of parameter below
#
function nexus_asset_search
{
	repo="$1"
	group="$2"
	artifact="$3"
	classifier="$4"
	ext="$5"
	version="$6" # This is the only one that is optional, last versions are fetched if omitted
	
	url="https://knetminer.com/artifactory"
	url="$url/service/rest/v1/search/assets?sort=version&direction=desc"
	
	url="$url&repository=$repo"
	url="$url&maven.groupId=$group"
	url="$url&maven.artifactId=$artifact"
	url="$url&maven.classifier=$classifier"
	url="$url&maven.extension=$ext"
	[[ -z "$version" ]] || url="$url&maven.baseVersion=$version"
	
  debug "--- URL: $url" 		

	curl -X GET "$url" -H "accept: application/json"
}

# Expects the Nexus search result coming from nexus_asset_search and extracts the first 'downloadUrl' field
# that is in that JSON, so the last version requested.
# 
# It has no parameters, since it processes its standard input and returns a result through the
# stdout.
#
function js_2_download_url
{
	egrep --max-count 1 '"downloadUrl" :' | sed -E s/'.*"downloadUrl" : "([^"]+)".*'/'\1'/
}

# Expects an .md template in the standard input and replaces placeholders for Maven module links, resolving
# them through the functions above. Returns the result through stdout, multiple invocations (one per module/placeholder)
# can be piped. See below the param details. See further below for usage examples. 
# 
function make_doc
{
  # The function parameters
  #  
	repo="$1" 				# The repository (usually maven-releases or maven-snapshots)
	group="$2" 				# The Maven group
	artifact="$3"			# The artifact
	classifier="$4"		# eg, 'packaged-distro', for cases where multiple final files are deployed. Can be ''
	ext="$5"					# eg, zip, jar, can be ''
  # eg, 'ondexSnapUrl', will replace '%ondexSnapUrl%' with the URL found by Nexus to download
  # Ondex (as long as you passed the right artifact coordinates).
  #  
  placeholder="%$6%" 
  version="$7" 			# Optional, as above

  # /End parameters

	debug "--- make_doc '$repo' '$group' '$artifact' '$classifier' '$ext' '$placeholder' '$version'"

	download_url=$(nexus_asset_search \
  	$repo $group $artifact "$classifier" "$ext" "$version" |js_2_download_url)

  debug "--- DOWNLOAD URL: '$download_url'"

  cat | sed -E s"|$placeholder|$download_url|g"
}
