set -e
cd "`dirname "$0"`"

. ./download-page-utils.sh

# You can chain the computation of multiple URLs
# See make_doc for the parameters.
# 
cat "Download-example-template.md" \
| make_doc \
    maven-snapshots uk.ac.rothamsted.knetminer knetminer-common \
  	'' pom snapUrl \
| make_doc \
    maven-releases uk.ac.rothamsted.knetminer knetminer-common \
  	'' pom releaseUrl \
  	