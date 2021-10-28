# Knetminer Download Page scripts

These are utilities that builds a download page using the latest releases available in our 
[Maven Artifactory Manager](https://knetminer.com/artifactory/).  

It works like [this example](download-page-example.sh), the `make_doc` function receives a set of 
parameters about the the artifact you need to update in a template file, then it gets the latest 
version for the artifact and replaces the corresponging placeholders in the input template document.
The script can then be chained to process multiple artifacts/placeholders.  

Ondex has a [production example][10] of it.

[10]: https://github.com/Rothamsted/knetbuilder/blob/master/ondex-knet-builder/src/main/deploy/mk_download_page.sh
