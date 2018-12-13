#!/usr/bin/env bash
#
# Build, Test and Publish all products of the FIBO ontology family.
#
# This script needs to be run inside the Docker container that is based on the ontology-publisher image.
#
# TODO: Make this script fibo independent, should support any "ontology family"
#
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)" || exit 1

if [ -f ${SCRIPT_DIR}/lib/_functions.sh ] ; then
  # shellcheck source=lib/_functions.sh
  source ${SCRIPT_DIR}/lib/_functions.sh || exit $?
else # This else section is to trick IntelliJ Idea to actually load _functions.sh during editing
  source lib/_functions.sh || exit $?
fi
if [ -f ${SCRIPT_DIR}/lib/_globals.sh ] ; then
  # shellcheck source=lib/_globals.sh
  source ${SCRIPT_DIR}/lib/_globals.sh || exit $?
else # This else section is to trick IntelliJ Idea to actually load _functions.sh during editing
  source lib/_globals.sh || exit $?
fi

if [ -f ${SCRIPT_DIR}/lib/build-cats.sh ] ; then
  # shellcheck source=lib/build-cats.sh
  source ${SCRIPT_DIR}/lib/build-cats.sh
else
  source lib/build-cats.sh # This line is only there to make the IntelliJ Bash plugin see build-cats.sh
fi
if [ -f ${SCRIPT_DIR}/lib/build-about.sh ] ; then
  # shellcheck source=lib/build-about.sh
  source ${SCRIPT_DIR}/lib/build-about.sh
else
  source lib/build-about.sh # This line is only there to make the IntelliJ Bash plugin see build-about.sh
fi
if [ -f ${SCRIPT_DIR}/lib/build-theallfile.sh ] ; then
  # shellcheck source=lib/build-theallfile.sh
  source ${SCRIPT_DIR}/lib/build-theallfile.sh
else
  source lib/build-theallfile.sh # This line is only there to make the IntelliJ Bash plugin see build-theallfile.sh
fi
if [ -f ${SCRIPT_DIR}/lib/build-widoco.sh ] ; then
  # shellcheck source=lib/build-widoco.sh
  source ${SCRIPT_DIR}/lib/build-widoco.sh
else
  source lib/build-widoco.sh # This line is only there to make the IntelliJ Bash plugin see build-widoco.sh
fi

#
# The "index" of fibo is a list of all the ontology files, in their
# directory structure.  This is an attempt to automatically produce
# this.
#
function ontologyBuildIndex () {

  require tag_root || return $?
  require tag_root_url || return $?
  require GIT_TAG_NAME || return $?

  logRule "Step: build tree.html files"

  (
  	cd ${tag_root:?} || return $?
  	while read directory ; do
  	  #log "Directory is ${directory}"
  	  (
  	    cd "${directory}" || return $?
  	    ${TREE} -P '*.rdf|*.html' -T "Directory Tree" -H "${tag_root_url:?}/${directory/.\//}" --noreport --charset=UTF8 -N | \
          ${SED} \
            -e 's/.VERSION { font-size: small;/.VERSION { display: none; font-size: small;/g' \
            -e 's/BODY {.*}/BODY { font-family : "Courier New"; font-size: 12pt ; line-height: 0.90}/g' \
            -e 's/ariel/"Courier New"/g' \
            -e 's/<hr>//g' \
            -e "s@>Directory Tree<@>FIBO Ontology file directory ${directory/.\//}<@g" \
            -e 's@h1>\n<p>@h1><p>This is the directory structure of FIBO; you can download individual files this way.  To load all of FIBO, please follow the instructions for particular tools at <a href="http://spec.edmcouncil.org/fibo">the main fibo download page</a>.<p/>@' \
            -e "s@<a href=\".*>${spec_root_url}/.*</a>@@" > tree.html
  	  )
  	done < <(${FIND} . -type d)
	)

	return $?
}

#
# Copy all publishable files from the fibo repo to the appropriate target directory (${tag_root})
# where they will be converted to publishable artifacts
#
function ontologyCopyRdfToTarget() {

  require source_family_root || return $?
  require tag_root || return $?

  local module
#  local upperModule

  logRule "Step: ontologyCopyRdfToTarget"

  log "Copying all artifacts that we publish straight from git into target directory"

  (
    rm -rf "${tag_root}"
    mkdir -p "${tag_root}"
    cd "${source_family_root}" || return $?
    while read -r file ; do
      if ontologyIsInTestDomain "${file}" ; then
        "${CP}" "${file}" --parents "${tag_root}/"
      fi
    done < <(
      find . \
        -name '*.rdf'  -o \
        -name '*.ttl'  -o \
        -name '*.md'   -o \
        -name '*.jpg'  -o \
        -name '*.png'  -o \
        -name '*.gif'  -o \
        -name '*.docx' -o \
        -name '*.pdf'  -o \
        -name '*.sq'
    )
  )

  #
  # Rename the lower case module directories as we have them in the fibo git repo to
  # upper case directory names as we serve them on spec.edmcouncil.org
  #
#  log "Rename all lower case module directories to upper case and remove unpublished directories:"
#  (
#    cd "${tag_root}" || return $?
#    while read -r module ; do
#      [ "${module}" == "./etc" ] && continue
##     [ "${module}" == "./ext" ] && continue
#      upperModule="${module^^}"
#      [ "${module}" == "${upperModule}" ] && continue
#      #
#      # Mv in two steps to avoid the error
#      # "cannot move X to a subdirectory of itself"
#      #
#      if ! mv -f "${module}" "${module}_upper" ; then
#        error "Cannot rename ${module} to ${module}_upper"
#        return 1
#      fi
#      if ! mv -f "${module}_upper" "${upperModule}" ; then
#        error "Cannot rename ${module}_upper to ${upperModule}"
#        return 1
#      fi
#    done < <(find . -maxdepth 1 -mindepth 1 -type d)
#    export modules=""
#    export module_directories=""
#    while read -r module ; do
#      [ "${module}" == "./etc" ] && continue
##     [ "${module}" == "./ext" ] && continue
#      export modules="${modules} ${module/.\//}"
#      export module_directories="${module_directories} $(readlink -f "${module}")"
#    done < <(find . -maxdepth 1 -mindepth 1 -type d)
#    logVar modules
#  )
  #
  # Clean up a few things that are too embarrassing to publish
  #
  #rm -vrf ${tag_root}/etc >/dev/null 2>&1
  rm -vrf ${tag_root}/etc/cm >/dev/null 2>&1
  rm -vrf ${tag_root}/etc/data >/dev/null 2>&1
  rm -vrf ${tag_root}/etc/image >/dev/null 2>&1
#  rm -vrf ${tag_root}/etc/imports >/dev/null 2>&1
  rm -vrf ${tag_root}/etc/infra >/dev/null 2>&1
  rm -vrf ${tag_root}/etc/odm >/dev/null 2>&1
  rm -vrf ${tag_root}/etc/operational >/dev/null 2>&1
#  rm -vrf ${tag_root}/etc/process >/dev/null 2>&1
  rm -vrf ${tag_root}/etc/source >/dev/null 2>&1
  rm -vrf ${tag_root}/etc/spec >/dev/null 2>&1
  rm -vrf ${tag_root}/etc/testing >/dev/null 2>&1
  rm -vrf ${tag_root}/etc/uml >/dev/null 2>&1
  rm -vrf ${tag_root}/**/archive >/dev/null 2>&1
  rm -vrf ${tag_root}/**/Bak >/dev/null 2>&1

  #${FIND} ${tag_root}

  return 0
}

function ontologySearchAndReplaceStuff() {

  logRule "Step: ontologySearchAndReplaceStuff"

  local -r sedfile=$(mktemp ${TMPDIR}/sed.XXXXXX)
  
  cat > "${sedfile}" << __HERE__
#
# First replace all http:// urls to https:// if that's not already done
#
s@http://spec.edmcouncil.org@${spec_root_url}@g
#
# Replace all IRIs in the form:
#
# - https://spec.edmcouncil.org/fibo/XXX/ with
# - https://spec.edmcouncil.org/fibo/ontology/XXX/
#
# This replacement should not really be necessary since we've changed all those non-/ontology/ IRIs
# in the git sources with their /ontology/-counterparts but the publisher should be able to support
# older versions of the sources as well so we leave this in here.
#
s@${spec_family_root_url}/\([A-Z]*\)/@${product_root_url}/\1/@g
#
# Dealing with special case /ext/.
#
s@${spec_family_root_url}/ext/@${product_root_url}/ext/@g
#
# Then replace some odd ones with a version number in it like:
#
# - https://spec.edmcouncil.org/fibo/ontology/BE/20150201/
#
# with
#
# - https://spec.edmcouncil.org/fibo/ontology/BE/
#
s@${product_root_url}/\([A-Z]*\)/[0-9]*/@${product_root_url}/\1/@g
#
# We only want the following types of IRIs to be versioned: owl:imports and owl:versionIRI.
#
# - <owl:imports rdf:resource="https://spec.edmcouncil.org/fibo/ontology/FND/InformationExt/InfoCore/"/> becomes:
# - <owl:imports rdf:resource="https://spec.edmcouncil.org/fibo/ontology/master/latest/FND/InformationExt/InfoCore/"/>
#
s@\(owl:imports rdf:resource="${product_root_url}/\)@\1${GIT_BRANCH}/${GIT_TAG_NAME}/@g
#
# And then the same for the owl:versionIRI.
#
s@\(owl:versionIRI rdf:resource="${product_root_url}/\)@\1${GIT_BRANCH}/${GIT_TAG_NAME}/@g
#
# Just to be sure that we don't see any 'ontology/ontology' IRIs:
#
s@/ontology/ontology/@/ontology/@g
#
__HERE__

  #cat "${sedfile}"

  (
    ${FIND} ${tag_root}/ -type f \( -name '*.rdf' -o -name '*.ttl' -o -name '*.md' \) -exec ${SED} -i -f ${sedfile} {} \;
  )

  rm -f "${sedfile}"

  #
  # We want to add in a rdfs:isDefinedBy link from every class back to the ontology.
  #
  if ((speedy)) ; then
	  log "speedy=true -> Leaving out isDefinedBy because it is slow"
	else
	  #${tag_root}/ -type f  -name '*.rdf' -not -name '*About*'  -print | \
	  #xargs -P $(nproc) -I fileName
	  ${FIND} ${tag_root}/ -type f  -name '*.rdf' -not -name '*About*'  -print | while read file ; do
	    addIsDefinedBy "${file}"
    done
  fi
 
  return 0
}

# 
# Add isDefinedBy triples to a single file
#
function addIsDefinedBy () {

  local file="$1"

  log "add isDefinedBy link to ${file/${WORKSPACE}/}"

  local sqfile ; sqfile="$(mktempWithExtension sq sparql)" || return $?

  cat > "${sqfile}" << __HERE__
#
# Generated by $0:addIsDefinedBy()
#
# This SPARQL statement adds isDefinedBy triples
#
PREFIX owl: <http://www.w3.org/2002/07/owl#> 
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> 
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#> 
PREFIX afn: <http://jena.apache.org/ARQ/function#>

CONSTRUCT {
  ?cl rdfs:isDefinedBy ?clns .
  ?pr rdfs:isDefinedBy ?prns .
}
WHERE {
  ?ont a owl:Ontology.
  FILTER (REGEX (STR (?ont), "spec.edmcouncil"))
  OPTIONAL {
    ?cl a owl:Class .
    FILTER (REGEX (STR (?cl), "spec.edmcouncil"))
    BIND (IRI(afn:namespace(?cl)) as ?clns)
    FILTER (?clns = ?ont)
  }
  OPTIONAL {
    ?pr  a ?x .
    FILTER (REGEX (STR (?pr), "spec.edmcouncil"))
    FILTER (?x IN (owl:AnnotationProperty,
       	   owl:AsymmetricProperty,
	   owl:DatatypeProperty,
	   owl:DeprecatedProperty,
	   owl:FunctionalProperty,
	   owl:InverseFunctionalProperty,
	   owl:IrreflexiveProperty,
	   owl:ObjectProperty,
	   owl:OntologyProperty,
	   owl:ReflexiveProperty,
	   owl:SymmetricProperty,
	   owl:TransitiveProperty,
	   rdf:Property,
	   rdfs:ContainerMembershipProperty
	   ))
    BIND (IRI(afn:namespace(?pr)) as ?prns)
    FILTER (?prns = ?ont)
  }
}
__HERE__

  #
  # Set the memory for ARQ
  #
  export JVM_ARGS=${JVM_ARGS:--Xmx4G}

  local outfile ; outfile="$(mktempWithExtension outfile rdf)" || return $?
  #
  # Some configurations of the serializer create XML that Jena ARQ doesn't like. This stabilizes them.
  #
  ${SCRIPT_DIR}/utils/convertRdfFile.sh rdf-xml "${file}" "rdf-xml"

  "${JENA_ARQ}" \
    --query="${sqfile}" \
    --data="${file}" \
    --results=RDF > "${outfile}"

  local outfile2 ; outfile2="$(mktempWithExtension outfile2 rdf)" || return $?

  "${JENA_ARQ}" \
    --query="${SCRIPT_DIR}/lib/echo.sparql" \
    --data="${file}" \
    --data="${outfile}" \
    --results=RDF > "${outfile2}"

  ${SCRIPT_DIR}/utils/convertRdfFile.sh rdf-xml "${outfile2}" "rdf-xml"

  mv -f "${outfile2}" "$1"
  rm "${outfile}"
  rm "${sqfile}"

  return 0
}

#
# For the .ttl files, find the ontology, and compute the version IRI from it.
# Put it in a cookie where TopBraid will find it.
#
function fixTopBraidBaseURICookie() {

  local ontologyFile="$1"
  local queryFile="$2"
  local baseURI
  local uri

  log "Annotating ${ontologyFile/${WORKSPACE}/}"

  log "CSV output of query is:"

  "${JENA_ARQ}" \
      --query="${queryFile}" \
      --data="${ontologyFile}" \
      --results=csv

  baseURI=$( \
    "${JENA_ARQ}" \
      --query="${queryFile}" \
      --data="${ontologyFile}" \
      --results=csv | \
      ${GREP} edmcouncil | \
      ${SED} "s@\(${product_root_url}/\)@\1${GIT_BRANCH}/${GIT_TAG_NAME}/@" | \
      ${SED} "s@${GIT_BRANCH}/${GIT_TAG_NAME}/${GIT_BRANCH}/${GIT_TAG_NAME}/@${GIT_BRANCH}/${GIT_TAG_NAME}/@" \
  )

  uri="# baseURI: ${baseURI}"

  ${SED} -i "1s;^;${uri}\n;" "${ontologyFile}"
}

#
# Add the '# baseURI' line to the top of all turtle files with the versioned ontology IRI
#

function ontologyAnnotateTopBraidBaseURL() {

  local queryFile="$(mktemp ${TMPDIR}/ontXXXXXX.sq)"

  log "Add versioned baseURI to all turtle files"

  #
  # Create a file with a SPARQL query that gets the OntologyIRIs in a given model/file.
  #
  cat > "${queryFile}" << __HERE__
SELECT ?o WHERE {
  ?o a <http://www.w3.org/2002/07/owl#Ontology> .
}
__HERE__

  cat "${queryFile}"

  #
  # Now iterate through all turtle files that we're going to publish
  # and call fixTopBraidBaseURICookie() for each.
  #
  ${FIND} ${tag_root}/ -type f -name "*.ttl" | while read file ; do
    fixTopBraidBaseURICookie "${file}" "${queryFile}"
  done
}


function ontologyConvertMarkdownToHtml() {

  logRule "Step: ontologyConvertMarkdownToHtml"

  if ((pandoc_available == 0)) ; then
    error "Could not convert Markdown files to HTML since pandoc is missing"
    return 0 # Ignoring this error though
  fi

  (
    cd "${tag_root}" || return $?

    for markdownFile in **/*.md ; do
      ontologyIsInTestDomain "${markdownFile}" || continue
      log "Convert ${markdownFile} to html"
      ${pandoc_bin} --quiet --standalone --from markdown --to html -o "${markdownFile/.md/.html}" "${markdownFile}"
    done
  )
  return $?
}

#
# TODO: Omar can you look at this? Do we still need this?
#
function storeVersionInStardog() {

  log "Commit to Stardog..."

  ${stardog_vcs} commit --add $(${FIND} ${tag_root} -name "*.rdf") -m "$GIT_COMMENT" -u obkhan -p stardogadmin ${GIT_BRANCH}
  SVERSION=$(${stardog_vcs} list --committer obkhan --limit 1 ${GIT_BRANCH} | ${SED} -n -e 's/^.*Version:   //p')
  ${stardog_vcs} tag --drop $JIRA_ISSUE ${GIT_BRANCH} || true
  ${stardog_vcs} tag --create $JIRA_ISSUE --version $SVERSION ${GIT_BRANCH}
}

#
# This function returns true if the given file name resides in the test/dev "domain" (a root directory)
#
# TODO: Make it always return true when running in non-dev mode
# TODO: Make the regex expression configurable
#
function ontologyIsInTestDomain() {

  local rdfFile="$1"

  [[ "${rdfFile}" =~ ^.*/*etc/.*$ ]] && return 0

  if [[ "${rdfFile}" =~ ^.*/*CAE/.*$ ]] ; then
#   logItem "Ontology file is in test domain" "${rdfFile}"
    return 0
  fi

# logItem "Ontology file is not in test domain" "${rdfFile}"

  return 1
}

#
# Now use the rdf-toolkit serializer to create copies of all .rdf files in all the supported RDF formats
#
# Using the Sesame serializer, here's the documentation:
#
# https://github.com/edmcouncil/rdf-toolkit/blob/master/docs/SesameRdfFormatter.md
#
function ontologyConvertRdfToAllFormats() {

  require tag_root || return $?

  logRule "Step: ontologyConvertRdfToAllFormats"

  pushd "${tag_root:?}" >/dev/null || return $?

  local -r maxParallelJobs=1
  local numberOfParallelJobs=0

  log "Running ${maxParallelJobs} converter jobs in parallel:"

  for rdfFile in **/*.rdf ; do
    ontologyIsInTestDomain "${rdfFile}" || continue
    for format in json-ld turtle ; do
      if ((maxParallelJobs == 1)) ; then
        ${SCRIPT_DIR}/utils/convertRdfFile.sh rdf-xml "${rdfFile}" "${format}" || return $?
      else
        ${SCRIPT_DIR}/utils/convertRdfFile.sh rdf-xml "${rdfFile}" "${format}" &
        ((numberOfParallelJobs++))
        if ((numberOfParallelJobs >= maxParallelJobs)) ; then
          wait
          numberOfParallelJobs=0
        fi
      fi
    done || return $?
  done || return $?
  rc=$?

#  ((maxParallelJobs > 1)) && wait

  popd >/dev/null || return $?

  log "End of ontologyConvertRdfToAllFormats"

  return $?
}

function vocabularyConvertTurtleToAllFormats() {

  pushd "${tag_root}" >/dev/null

  for ttlFile in **/*.ttl ; do
    for format in json-ld rdf-xml ; do
      ${SCRIPT_DIR}/utils/convertRdfFile.sh turtle "${ttlFile}" "${format}" || return $?
    done || return $?
  done || return $?

  popd >/dev/null

  return $?
}

#
# We need to put the output of this job in a directory next to all other branches and never delete any of the
# other formerly published branches.
#
function zipWholeTagDir() {

  require spec_root || return $?
  require tag_root || return $?

  local tarGzFile="${tag_root}.tar.gz"
  local tarGzContentsFile="${tag_root}.tar.gz.log"
  local zipttlFile="${tag_root}.ttl.zip"
  local ziprdfFile="${tag_root}.rdf.zip"
  local zipjsonFile="${tag_root}.jsonld.zip"

  (
    cd ${spec_root}
    ${TAR} -czf "${tarGzFile}" "${tag_root/${spec_root}/.}"
  )
  [ $? -ne 0 ] && return 1

  log "Created ${tarGzFile/${WORKSPACE}/},"
  log "saving contents list in ${tarGzContentsFile/${WORKSPACE}/}"
  ls -al "${tarGzFile}" > "${tarGzContentsFile}" 2>&1 || return $?

  return 0
}

#
# Copy the static files of the site
#
function copySiteFiles() {

  require spec_root || return $?

  (
    cd ${WORKSPACE}/static-site

    #Replace GIT BRANCH and TAG in the glossary index html
    #
    # DA>JG, I commented this out since this doesn't make sense it seems.
    #    There is no string "GIT_BRANCH" in index.html and even if there
    #    were I think it should always point to master/latest anyway (which it
    #    already does)
    #
    # JG>DA yes I understand but we better rethink this whole model, most files
    #    should reside in one of the versioned product directories, not in any
    #    of the /static directories. For the overall site pages, that span all
    #    versions we should have a special environment variable in the main
    #    Jenkinsfile (in the fibo repo) that holds the BRANCH/TAG value of the
    #    version of fibo-infra that should be used as the source of those
    #    files.
    #
    #log "Replacing GIT_BRANCH  $GIT_BRANCH"
    #${SED} -i "s/GIT_BRANCH/$GIT_BRANCH/g" "static/glossary/index.html"
    #
    #log "Replacing GIT_TAG_NAME  $GIT_TAG_NAME"
    #${SED} -i "s/GIT_TAG_NAME/$GIT_TAG_NAME/g" "static/glossary/index.html"

    ${CP} -r * "${spec_root}/"
  )
  #
  # JG>Why is this file not in the fibo repo itself?
  #
  ${CP} ${WORKSPACE}/LICENSE "${spec_root}"

  (
    cd "${spec_root}"
    chmod -R g+r,o+r .
  )

  return 0
}

function zipOntologyFiles () {

  require family_product_branch_tag || return $?
  require tag_root || return $?

  logRule "Step: zipOntologyFiles"

  local zipttlDevFile="${tag_root}/dev.ttl.zip"
  local ziprdfDevFile="${tag_root}/dev.rdf.zip"
  local zipjsonldDevFile="${tag_root}/dev.jsonld.zip"
  local zipttlProdFile="${tag_root}/prod.ttl.zip"
  local ziprdfProdFile="${tag_root}/prod.rdf.zip"
  local zipjsonldProdFile="${tag_root}/prod.jsonld.zip"
    
  (
    cd "${spec_root}"
    #
    # Make sure that everything is world readable before we zip it
    #
    chmod -R g+r,o+r .
    zip -r ${zipttlDevFile} "${family_product_branch_tag}" -x \*.rdf \*.zip  \*.jsonld \*AboutFIBOProd.ttl
    zip -r ${ziprdfDevFile} "${family_product_branch_tag}" -x \*.ttl \*.zip \*.jsonld \*AboutFIBOProd.rdf
    zip -r ${zipjsonldDevFile} "${family_product_branch_tag}" -x \*.ttl \*.zip \*.rdf \*AboutFIBOProd.jsonld

    ${GREP} -r 'utl-av[:;.]Release' "${family_product_branch_tag}" | ${GREP} -F ".ttl" | ${SED} 's/:.*$//' | xargs zip -r ${zipttlProdFile}
    ${FIND}  "${family_product_branch_tag}" -name '*About*.ttl' -print | ${GREP} -v "AboutFIBODev.ttl" |  xargs zip ${zipttlProdFile}
    ${FIND}  "${family_product_branch_tag}" -name '*catalog*.xml' -print | xargs zip ${zipttlProdFile}
    ${GREP} -r 'utl-av[:;.]Release' "${family_product_branch_tag}" | ${GREP} -F ".rdf" |   ${SED} 's/:.*$//' | xargs zip -r ${ziprdfProdFile}
    ${FIND}  "${family_product_branch_tag}" -name '*About*.rdf' -print | ${GREP} -v "AboutFIBODev.rdf" | xargs zip ${ziprdfProdFile}
    ${FIND}  "${family_product_branch_tag}" -name '*catalog*.xml' -print | xargs zip ${ziprdfProdFile}
    ${GREP} -r 'utl-av[:;.]Release' "${family_product_branch_tag}" | ${GREP} -F ".jsonld" |   ${SED} 's/:.*$//' | xargs zip -r ${zipjsonldProdFile}
    ${FIND}  "${family_product_branch_tag}" -name '*About*.jsonld' -print | ${GREP} -v "AboutFIBODev.jsonld" | xargs zip ${zipjsonldProdFile}
    ${FIND}  "${family_product_branch_tag}" -name '*catalog*.xml' -print | xargs zip ${zipjsonldProdFile}

  )

  log "Step: zipOntologyFiles finished"

  return 0
}

#
# Produce the artifacts of the ontology product
#
function publishProductOntology() {

  require spec_family_root || return $?

  setProduct ontology || return $?

  ontology_product_tag_root="${tag_root}"
  #
  # Show the ontology root directory but strip the WORKSPACE director from it to
  # save log space, it's ugly
  #
  log "Ontology Root: ${ontology_product_tag_root/${WORKSPACE}/}"

  ontologyCopyRdfToTarget || return $?
  ontologyBuildCatalogs  || return $?
  ontologyConvertMarkdownToHtml || return $?
  ontologyBuildIndex  || return $?
  ontologyCreateAboutFiles || return $?
  ontologySearchAndReplaceStuff || return $?
#  if ((speedy)) ; then
#    log "speedy=true -> Not doing some conversions because they are slow"
#  else
    ontologyConvertRdfToAllFormats || return $?
#  fi
# ontologyAnnotateTopBraidBaseURL || return $?
  ontologyCreateTheAllTtlFile || return $?
  #
  # JG>Who's using "ontology-zips.log"?
  #
  zipOntologyFiles > "${tag_root}/ontology-zips.log" || return $?

  if ((speedy)) ; then
    log "speedy=true -> Not doing quads because they are slow"
  else
    buildquads || return $?
  fi

  return 0
}

#
# Called by publishProductVocabulary(), sets the names of all modules in the global variable modules and their
# root directories in the global variable module_directories
#
# 1) Determine which modules will be included. They are kept on a property
#    called <http://www.edmcouncil.org/skosify#module> in skosify.ttl
#
# JG>Apache jena3 is also installed on the Jenkins server itself, so maybe
#    no need to have this in the fibs-infra repo.
#
function vocabularyGetModules() {

  require vocabulary_script_dir || return $?
  require ontology_product_tag_root || return $?

  #
  # Set the memory for ARQ
  #
  export JVM_ARGS=${JVM_ARGS:--Xmx4G}

  log "Query the skosify.ttl file for the list of modules (TODO: Should come from rdf-toolkit.ttl)"

  ${JENA_ARQ} \
    --results=CSV \
    --data="${vocabulary_script_dir}/skosify.ttl" \
    --query="${vocabulary_script_dir}/get-module.sparql" | ${GREP} -v list > \
    "${TMPDIR}/module"

  if [ ${PIPESTATUS[0]} -ne 0 ] ; then
    error "Could not get modules"
    return 1
  fi

  cat "${TMPDIR}/module"

  export modules="$(< "${TMPDIR}/module")"

  export module_directories="$(for module in ${modules} ; do echo -n "${ontology_product_tag_root}/${module} " ; done)"

  log "Found the following modules:"
  echo ${modules}

  log "Using the following directories:"
  echo ${module_directories}

  rm -f "${TMPDIR}/module"

  return 0
}

#
# 2) Compute the prefixes we'll need.
#
function vocabularyGetPrefixes() {

  require vocabulary_script_dir || return $?
  require ontology_product_tag_root || return $?
  require modules || return $?
  require module_directories || return $?

  log "Get prefixes"

  cat "${vocabulary_script_dir}/basic-prefixes.ttl" > "${TMPDIR}/prefixes.ttl"

  pushd "${ontology_product_tag_root}" >/dev/null
  ${GREP} -R --include "*.ttl" --no-filename "@prefix fibo-" >> "${TMPDIR}/prefixes.ttl"
  popd >/dev/null

  #
  # Sort and filter out duplicates
  #
  sort --unique --output="${TMPDIR}/prefixes.ttl" "${TMPDIR}/prefixes.ttl"

  log "Found the following namespaces and prefixes:"
  cat "${TMPDIR}/prefixes.ttl"

  return 0
}

#
# 3) Gather up all the RDF files in those modules.  Include skosify.ttl, since that has the rules
#
# Generates TMPDIR/temp0.ttl
#
function vocabularyGetOntologies() {

  require vocabulary_script_dir || return $?
  require module_directories || return $?

  logRule "Step: vocabularyGetOntologies"

  #
  # Set the memory for ARQ
  #
  export JVM_ARGS=${JVM_ARGS:--Xmx4G}

  log "Get Ontologies into merged file (temp0.ttl)"

  log "Files that go into dev:"

  ${FIND} "${ontology_product_tag_root}" -name "*.rdf" | ${SED} "s@^/output/@- @g"

  log "Files that go into prod:"

  ${GREP} -r 'utl-av[:;.]Release' "${ontology_product_tag_root}" | ${SED} 's/:.*$//;s/^${WORKSPACE}/- /' | ${GREP} -F ".rdf"

  #
  # Get ontologies for Dev
  #
  ${JENA_ARQ} \
    $(${FIND}  "${ontology_product_tag_root}" -name "*.rdf" | ${SED} "s/^/--data=/") \
    --data="${vocabulary_script_dir}/skosify.ttl" \
    --data="${vocabulary_script_dir}/datatypes.rdf" \
    --query="${vocabulary_script_dir}/skosecho.sparql" \
    --results=TTL > "${TMPDIR}/temp0.ttl"

  if [ ${PIPESTATUS[0]} -ne 0 ] ; then
    error "Could not get Dev ontologies"
    return 1
  fi

  #
  # Get ontologies for Prod
  #
  ${JENA_ARQ} \
    $(${GREP} -r 'utl-av[:;.]Release' "${ontology_product_tag_root}" | ${SED} 's/:.*$//;s/^/--data=/' | ${GREP} -F ".rdf") \
    --data="${vocabulary_script_dir}/skosify.ttl" \
    --data="${vocabulary_script_dir}/datatypes.rdf" \
    --query="${vocabulary_script_dir}/skosecho.sparql" \
    --results=TTL > "${TMPDIR}/temp0B.ttl"

  if [ ${PIPESTATUS[0]} -ne 0 ] ; then
    error "Could not get Prod ontologies"
    return 1
  fi

  log "Generated ${TMPDIR/${WORKSPACE}/}/temp0.ttl:"

  head -n200 "${TMPDIR}/temp0.ttl"

  log "Generated ${TMPDIR/${WORKSPACE}/}/temp0B.ttl:"

  head -n200 "${TMPDIR}/temp0B.ttl"

  return 0
}

#
# Run SPIN
#
# JG>WHat does this do?
#
# Generates TMPDIR/temp1.ttl
#
function vocabularyRunSpin() {

  log "STARTING SPIN"

  rm -f "${TMPDIR}/temp1.ttl" >/dev/null 2>&1
  rm -f "${TMPDIR}/temp1B.ttl" >/dev/null 2>&1

  "${SCRIPT_DIR}/utils/spinRunInferences.sh" "${TMPDIR}/temp0.ttl" "${TMPDIR}/temp1.ttl" || return $?
  "${SCRIPT_DIR}/utils/spinRunInferences.sh" "${TMPDIR}/temp0B.ttl" "${TMPDIR}/temp1B.ttl" || return $?

  log "Generated ${TMPDIR/${WORKSPACE}/}/temp1.ttl:"
  log "Generated ${TMPDIR/${WORKSPACE}/}/temp1B.ttl:"

  log "Printing first 50 lines of ${TMPDIR/${WORKSPACE}/}/temp1.ttl"
  head -n50 "${TMPDIR}/temp1.ttl"

  log "Printing first 50 lines of ${TMPDIR/${WORKSPACE}/}/temp1B.ttl"
  head -n50 "${TMPDIR}/temp1B.ttl"

  #The first three lines contain some WARN statements - removing it to complete the build.
  #JC > Need to check why this happens
  #log "Removing the first three lines from ${TMPDIR}/temp1.ttl"
  #${SED} -i.bak -e '1,3d' "${TMPDIR}/temp1.ttl"
  #log "Printing first 50 lines of ${TMPDIR}/temp1.ttl"
  #head -n50 "${TMPDIR}/temp1.ttl"

  #log "Removing the first three lines from ${TMPDIR}/temp1B.ttl"
  #${SED} -i.bak -e '1,3d' "${TMPDIR}/temp1B.ttl"
  #log "Printing first 50 lines of ${TMPDIR}/temp1B.ttl"
  #head -n50 "${TMPDIR}/temp1B.ttl"

  ### END Karthik changes

  return 0
}

#
# 4) Run the schemify rules.  This adds a ConceptScheme to the output.
#
function vocabularyRunSchemifyRules() {

  #
  # Set the memory for ARQ
  #
  export JVM_ARGS=${JVM_ARGS:--Xmx4G}

  log "Run the schemify rules"

  #
  # Dev
  #
  ${JENA_ARQ} \
    --data="${TMPDIR}/temp1.ttl" \
    --data="${vocabulary_script_dir}/schemify.ttl" \
    --query="${vocabulary_script_dir}/skosecho.sparql" \
    --results=TTL > "${TMPDIR}/temp2.ttl"

  if [ ${PIPESTATUS[0]} -ne 0 ] ; then
    error "Could not run the Dev schemify rules"
    return 1
  fi

  #
  # Prod
  #
  ${JENA_ARQ} \
    --data="${TMPDIR}/temp1B.ttl" \
    --data="${vocabulary_script_dir}/schemify.ttl" \
    --query="${vocabulary_script_dir}/skosecho.sparql" \
    --results=TTL > "${TMPDIR}/temp2B.ttl"

  if [ ${PIPESTATUS[0]} -ne 0 ] ; then
    error "Could not run the Prod schemify rules"
    return 1
  fi

  return 0
}

#
# Publish the product called "index"
#
function publishProductIndex() {

  setProduct ontology
  ontology_product_tag_root="${tag_root}"

  setProduct index || return $?
  index_product_tag_root="${tag_root}"

  export index_script_dir="${SCRIPT_DIR}/fibo-index"

  (
    cd "${index_product_tag_root}" || return $?

    cat > OntologyIndex.csv << __HERE__
Ontology,Maturity Level
__HERE__

   ${GREP} -r 'hasMaturityLevel' "${ontology_product_tag_root}" | \
        ${GREP} '\.rdf' | \
        ${SED} 's!"/>!!; s!^.*/!!; s/.rdf:.*resource=".*utl-av;/,/' |\
        ${SED} 's/,Release$/,Production/; s/,Provisional/,Development/; s/,Informative/,Development/' >> OntologyIndex.csv

   chmod a+x "${SCRIPT_DIR}/csv-to-xlsx.py"

   ${SCRIPT_DIR}/csv-to-xlsx.py  OntologyIndex.csv  OntologyIndex.xlsx "${index_script_dir}/csvconfig"
 )

 return $?
}

#
# Turns FIBO in to FIBO-V
#
# The translation proceeds with the following steps:
#
# 1) Start the output with the standard prefixes.  They are in a file called skosprefixes.
# 2) Determine which modules will be included. They are kept on a property called <http://www.edmcouncil.org/skosify#module> in skosify.ttl
# 3) Gather up all the RDF files in those modules
# 4) Run the shemify rules.  This adds a ConceptScheme to the output.
# 5) Merge the ConceptScheme triples with the SKOS triples
# 6) Convert upper cases.  We have different naming standards in FIBO-V than in FIBO.
# 7) Remove all temp files.
#
# The output is in .ttl form in a file called fibo-v.ttl
#
function publishProductVocabulary() {

  #
  # Set the memory for ARQ
  #
  export JVM_ARGS=${JVM_ARGS:--Xmx4G}

  require JENAROOT || return $?

  setProduct ontology
  ontology_product_tag_root="${tag_root}"

  setProduct vocabulary || return $?
  vocabulary_product_tag_root="${tag_root}"

  (
    cd "${SCRIPT_DIR}/vocabulary" || return $?
    vocabulary_script_dir="$(pwd)"

    publishProductVocabularyInner
  )
  local rc=$?

  log "Done with processing product vocabulary rc=${rc}"

  return ${rc}
}

function publishProductVocabularyInner() {

  #
  # 1) Start the output with the standard prefixes.  We compute these from the files.
  #
  log "# baseURI: ${product_root_url}" > ${TMPDIR}/fibo-v1.ttl
  #cat skosprefixes >> ${TMPDIR}/fibo-v1.ttl

  #vocabularyGetModules || return $?
  vocabularyGetPrefixes || return $?
  vocabularyGetOntologies || return $?
  vocabularyRunSpin || return $?
  vocabularyRunSchemifyRules || return $?

  log "second run of spin"
  "${SCRIPT_DIR}/utils/spinRunInferences.sh" "${TMPDIR}/temp2.ttl" "${TMPDIR}/tc.ttl" || return $?
  "${SCRIPT_DIR}/utils/spinRunInferences.sh" "${TMPDIR}/temp2B.ttl" "${TMPDIR}/tcB.ttl" || return $?

  #
  # Set the memory for ARQ
  #
  export JVM_ARGS=${JVM_ARGS:--Xmx4G}

  log "ENDING SPIN"
  #
  # 5) Merge the ConceptScheme triples with the SKOS triples
  #
  ${JENA_ARQ}  \
    --data="${TMPDIR}/tc.ttl" \
    --data="${TMPDIR}/temp1.ttl" \
    --query="${SCRIPT_DIR}/lib/echo.sparql" \
    --results=TTL > "${TMPDIR}/fibo-uc.ttl"

  ${JENA_ARQ}  \
    --data="${TMPDIR}/tcB.ttl" \
    --data="${TMPDIR}/temp1B.ttl" \
    --query="${SCRIPT_DIR}/lib/echo.sparql" \
    --results=TTL > "${TMPDIR}/fibo-ucB.ttl"

  #
  # 6) Convert upper cases.  We have different naming standards in FIBO-V than in FIBO.
  #
  ${SED} "s/uc(\([^)]*\))/\U\1/g" "${TMPDIR}/fibo-uc.ttl" >> ${TMPDIR}/fibo-v1.ttl
  ${SED} "s/uc(\([^)]*\))/\U\1/g" "${TMPDIR}/fibo-ucB.ttl" >> ${TMPDIR}/fibo-v1B.ttl

  ${JENA_ARQ}  \
    --data="${TMPDIR}/fibo-v1.ttl" \
    --query="${SCRIPT_DIR}/lib/echo.sparql" \
    --results=TTL > "${TMPDIR}/fibo-vD.ttl"
  ${JENA_ARQ}  \
    --data="${TMPDIR}/fibo-v1B.ttl" \
    --query="${SCRIPT_DIR}/lib/echo.sparql" \
    --results=TTL > "${TMPDIR}/fibo-vP.ttl"

  #
  # Adjust namespaces
  #
  ${JENA_RIOT} "${TMPDIR}/fibo-vD.ttl" > "${TMPDIR}/fibo-vD.nt"
  ${JENA_RIOT} "${TMPDIR}/fibo-vP.ttl" > "${TMPDIR}/fibo-vP.nt"

  cat > "${TMPDIR}/vochelp.ttl" <<EOF
  <https://spec.edmcouncil.org/fibo/vocabulary#hasDomain> 
  rdf:type owl:AnnotationProperty ;
  rdfs:label "has domain" ;
  rdfs:range xsd:string ;
  rdfs:subPropertyOf dct:subject .
  <https://spec.edmcouncil.org/fibo/vocabulary#hasSubDomain>
  rdf:type owl:AnnotationProperty ;
  rdfs:label "has subdomain" ;
  rdfs:range xsd:string ;
  rdfs:subPropertyOf dct:subject .
EOF

  cat \
    "${TMPDIR}/prefixes.ttl" \
    "${TMPDIR}/vochelp.ttl" \
    "${TMPDIR}/fibo-vD.nt" | \
  ${JENA_RIOT} \
    --syntax=turtle \
    --output=turtle > \
    "${tag_root}/fibo-vD.ttl"

  cat \
    "${TMPDIR}/prefixes.ttl" \
    "${TMPDIR}/vochelp.ttl" \
    "${TMPDIR}/fibo-vP.nt" | \
  ${JENA_RIOT} \
    --syntax=turtle \
    --output=turtle > \
    "${tag_root}/fibo-vP.ttl"

  #
  # JG>Dean I didn't find any hygiene*.sparql files anywhere
  #
#  log "Running tests"
#  ${FIND} ${vocabulary_script_dir}/testing -name 'hygiene*.sparql' -print
#  ${FIND} ${vocabulary_script_dir}/testing -name 'hygiene*.sparql' \
#    -exec ${JENA_ARQ} --data="${tag_root}/fibo-v.ttl" --query={} \;

  vocabularyConvertTurtleToAllFormats || return $?

  (cd "${tag_root}"; rm -f **.zip)

  #
  # gzip --best --stdout "${tag_root}/fibo-vD.ttl" > "${tag_root}/fibo-vD.ttl.gz"
  #
  (cd "${tag_root}" ; zip fibo-vD.ttl.zip fibo-vD.ttl)
  #
  # gzip --best --stdout "${tag_root}/fibo-vD.rdf" > "${tag_root}/fibo-vD.rdf.gz"
  #
  (cd "${tag_root}" ; zip  fibo-vD.rdf.zip fibo-vD.rdf)
  #
  # gzip --best --stdout "${tag_root}/fibo-vD.jsonld" > "${tag_root}/fibo-vD.jsonld.gz"
  #
  (cd "${tag_root}" ; zip  fibo-vD.jsonld.zip fibo-vD.jsonld)
  #
  # gzip --best --stdout "${tag_root}/fibo-vB.ttl" > "${tag_root}/fibo-vP.ttl.gz"
  #
  (cd "${tag_root}" ; zip  fibo-vP.ttl.zip fibo-vP.ttl)
  #
  # gzip --best --stdout "${tag_root}/fibo-vB.rdf" > "${tag_root}/fibo-vP.rdf.gz"
  #
  (cd "${tag_root}" ; zip  fibo-vP.rdf.zip fibo-vP.rdf)
  #
  # gzip --best --stdout "${tag_root}/fibo-vB.jsonld" > "${tag_root}/fibo-vP.jsonld.gz"
  #
  (cd "${tag_root}" ; zip  fibo-vP.jsonld.zip fibo-vP.jsonld)

  log "Finished publishing the Vocabulary Product"

  return 0
}

#
# Produce all artifacts for the glossary product
#
function publishProductGlossary() {

  setProduct ontology || return $?
  export ontology_product_tag_root="${tag_root}"

  setProduct glossary || return $?
  export glossary_product_tag_root="${tag_root}"
  export glossary_product_tag_root_url="${tag_root_url}"

  publishProductGlossaryContent || return $?
  publishProductGlossaryReactApp || return $?

  return 0
}

#
# Produce all artifacts for the glossary product
#
function publishProductGlossaryReactApp() {

  return 0

  local rc

  logRule "Publishing the glossary product React App"

  require glossary_product_tag_root || return $?
  require glossary_product_tag_root_url || return $?

  (
    #
    # Go to the /app directory to build the code of the React App (which is currently
    # just for the glossary but might soon be extended to cover the other products as well,
    # which why the /app directory is not called /app-glossary or so)
    #
    cd "${SCRIPT_DIR}/../../app" || return $?

    cat package.json | jq ".homepage = \"${glossary_product_tag_root_url}\"" > package2.json

    cp package2.json package.json
    rm package2.json
    #
    # HACK: copy the generated glossary*.jsonld files to the data directory as JSON so that it gets
    # included in the app.
    # (This is a terrible hack)
    #
    # We rename them to .json since React can then load them via "import".
    #
    if ((debug)) ; then
      log "debug=true so only copying glossary-test.json into $(pwd)/data"
      (
      cp "${glossary_product_tag_root}/glossary-test.jsonld"  src/data/glossary-test.json
      cp "${glossary_product_tag_root}/glossary-test.jsonld"  src/data/glossary-prod.json
      cp "${glossary_product_tag_root}/glossary-test.jsonld"  src/data/glossary-dev.json
      )
    else
      log "debug=false so copying both glossary-prod.json as well as glossary-dev.json"
      cp "${glossary_product_tag_root}/glossary-prod.jsonld"  src/data/glossary-prod.json
      cp "${glossary_product_tag_root}/glossary-dev.jsonld"   src/data/glossary-dev.json
      cp "${glossary_product_tag_root}/glossary-test.jsonld"  src/data/glossary-test.json
    fi

    npm install || return $?

    npm run build || return $?

    ${CP} -vR publisher/* "${glossary_product_tag_root}/" > "${WORKSPACE}/glossary-build-directory.log" 2>&1
  )
  rc=$?

  if ((rc != 0)) ; then
    error "Could not build the react app"
    return ${rc}
  fi

  log "Successfully built the React App for the Glossary Product"

  return 0
}

function publishProductGlossaryRemoveWarnings() {

  local fixFile="$1"
  local glossaryVersion="$2"
  local glossaryName="glossary-${glossaryVersion}"

  verbose "Remove warnings from ${glossaryName}.ttl, save as ${glossaryName}-fixed.ttl"
  ${SED} '/^@prefix/,$!d' "${glossary_product_tag_root}/${glossaryName}.ttl" > "${glossary_product_tag_root}/${glossaryName}-fixed.ttl"
  verbose "Run ${glossaryName}-fixed.ttl through fix-sparql construct and save as ${glossaryName}.ttl"
  ${JENA_ARQ} --data="${glossary_product_tag_root}/${glossaryName}-fixed.ttl" --query="${fixFile}" > "${glossary_product_tag_root}/${glossaryName}.ttl"
  verbose "Remove ${glossaryName}-fixed.ttl"
  rm "${glossary_product_tag_root}/${glossaryName}-fixed.ttl"

  return 0
}

#
# Produce all artifacts for the glossary product
#
function publishProductGlossaryContent() {

  logRule "Publishing the content files of the glossary product"

  require ontology_product_tag_root || return $?
  require glossary_product_tag_root || return $?

  export glossary_script_dir="${SCRIPT_DIR}/glossary"

  #
  # Set the memory for ARQ
  #
  export JVM_ARGS=${JVM_ARGS:--Xmx4G}

  #
  # Get ontologies for Dev
  #
  if ((debug == 0)) ; then
    verbose "Get all dev ontologies convert to one N-Triples file (${TMPDIR/${WORKSPACE}/}/glossary-dev.nt)"
    ${JENA_ARQ} \
      $(${FIND} "${ontology_product_tag_root}" -name "*.rdf" | ${SED} "s/^/--data=/") \
      --data=${glossary_script_dir}/owlnames.ttl \
      --query="${SCRIPT_DIR}/lib/echo.sparql" \
      --results=Turtle > "${TMPDIR}/glossary-dev.ttl"

    if [ ${PIPESTATUS[0]} -ne 0 ] ; then
      error "Could not get Dev ontologies"
      return 1
    fi
    #
    # Fast conversion of the N-Triples file to Turtle
    #
    #${SERDI} -b -f -i ntriples -o turtle "${TMPDIR}/glossary-dev.nt" > "${TMPDIR}/glossary-dev.ttl"
  fi

  #
  # Get ontologies for Prod
  #
  if ((debug == 0)) ; then
    verbose "Get all prod ontologies convert to one N-Triples file (${TMPDIR/${WORKSPACE}/}/glossary-prod.nt)"
    ${JENA_ARQ} \
      $(${GREP} -r 'utl-av[:;.]Release' "${ontology_product_tag_root}" | ${SED} 's/:.*$//;s/^/--data=/' | ${GREP} -F ".rdf") \
      --data=${glossary_script_dir}/owlnames.ttl \
      --query="${SCRIPT_DIR}/lib/echo.sparql" \
      --results=Turtle > "${TMPDIR}/glossary-prod.ttl"

    if [ ${PIPESTATUS[0]} -ne 0 ] ; then
      error "Could not get Prod ontologies"
      return 1
    fi
    #
    # Fast conversion of the N-Triples file to Turtle
    #
    #${SERDI} -b -f -i ntriples -o turtle "${TMPDIR}/glossary-prod.nt" > "${TMPDIR}/glossary-prod.ttl"
  fi

  #
  # Just do "Corporations.rdf" for test purposes
  #
  verbose "Get the Corporations.rdf ontology (for test purposes) and generate ${TMPDIR}/glossary-test.ttl"
  ${JENA_ARQ} \
    $(${FIND}  "${ontology_product_tag_root}" -name "Corporations.rdf" | ${SED} "s/^/--data=/") \
    --data=${glossary_script_dir}/owlnames.ttl \
    --query="${SCRIPT_DIR}/lib/echo.sparql" \
    --results=Turtle > "${TMPDIR}/glossary-test.ttl"
  rc=$?

  if ((rc > 0)) ; then
    error "Could not get Prod ontologies"
    return 1
  fi
  if [ ! -f "${TMPDIR}/glossary-test.ttl" ] ; then
    error "Did not generate ${TMPDIR}/glossary-test.ttl"
    return 1
  fi
  #
  # Fast conversion of the N-Triples file to Turtle
  #
  #${SERDI} -b -f -i ntriples -o turtle "${TMPDIR}/glossary-test.nt" > "${TMPDIR}/glossary-test.ttl"

  if ((debug)) ; then
    log "debug=true so only generating the test version of the glossary"
    "${SCRIPT_DIR}/utils/spinRunInferences.sh" "${TMPDIR}/glossary-test.ttl" "${glossary_product_tag_root}/glossary-test.ttl" || return $?
  else
    log "debug=false so now we're generating the full prod and dev versions"
    "${SCRIPT_DIR}/utils/spinRunInferences.sh" "${TMPDIR}/glossary-prod.ttl" "${glossary_product_tag_root}/glossary-prod.ttl" &
    "${SCRIPT_DIR}/utils/spinRunInferences.sh" "${TMPDIR}/glossary-dev.ttl" "${glossary_product_tag_root}/glossary-dev.ttl" &
    log "and on top of that also the test glossary"
    "${SCRIPT_DIR}/utils/spinRunInferences.sh" "${TMPDIR}/glossary-test.ttl" "${glossary_product_tag_root}/glossary-test.ttl" &
    log "Waiting for the above SPIN commands to finish"
    wait
    log "SPIN commands have finished"
  fi

  #
  # The spin inferences can create too many explanations.  This removes redundant ones.
  #
  local fixFile="$(createTempFile "fix" "sq")"
  cat > "${fixFile}" << __HERE__
PREFIX owlnames: <http://spec.edmcouncil.org/owlnames#>

CONSTRUCT {
  ?s ?p ?o
}
WHERE {
  ?s ?p ?o .
  FILTER (
    (?p != owlnames:mdDefinition) || (
      NOT EXISTS {
        ?s  owlnames:mdDefinition ?o2 .
        FILTER (REGEX (?o2, CONCAT ("^", ?o, ".")))
		  }
		)
  )
}
__HERE__

  #
  # Spin can put warnings at the start of a file.  I don't know why. Get rid of them.
  # I figured this out, and I think I got rid of it, but this still won't hurt.
  #
  if ((debug)) ; then
    publishProductGlossaryRemoveWarnings "${fixFile}" test || return $?
  else
    publishProductGlossaryRemoveWarnings "${fixFile}" prod || return $?
    publishProductGlossaryRemoveWarnings "${fixFile}" dev || return $?
    publishProductGlossaryRemoveWarnings "${fixFile}" test || return $?
  fi

  cat > "${TMPDIR}/nolabel.sq" << __HERE__
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

CONSTRUCT {
  ?s ?p ?o
}
WHERE {
  ?s ?p ?o .
  FILTER (ISIRI (?s) || (?p != rdfs:label))
}
__HERE__

  if ((debug)) ; then
    ${JENA_ARQ} --data="${glossary_product_tag_root}/glossary-test.ttl" --query="${TMPDIR}/nolabel.sq" > "${TMPDIR}/glossary-test-nolabel.ttl"
  else
    ${JENA_ARQ} --data="${glossary_product_tag_root}/glossary-prod.ttl" --query="${TMPDIR}/nolabel.sq" > "${TMPDIR}/glossary-prod-nolabel.ttl"
    ${JENA_ARQ} --data="${glossary_product_tag_root}/glossary-dev.ttl"  --query="${TMPDIR}/nolabel.sq" > "${TMPDIR}/glossary-dev-nolabel.ttl"
    ${JENA_ARQ} --data="${glossary_product_tag_root}/glossary-test.ttl" --query="${TMPDIR}/nolabel.sq" > "${TMPDIR}/glossary-test-nolabel.ttl"
  fi

  log "Using RDF toolkit to convert Turtle to JSON-LD"

  if ((debug)) ; then
    log "Convert ${TMPDIR/${WORKSPACE}/}/glossary-test-nolabel.ttl to ${glossary_product_tag_root/${WORKSPACE}/}/glossary-test.jsonld"
    (
    set -x
    java \
      -Xmx4G \
      -Xms4G \
      -Dfile.encoding=UTF-8 \
      -jar "${RDFTOOLKIT_JAR}" \
      --source "${TMPDIR}/glossary-test-nolabel.ttl" \
      --source-format turtle \
      --target "${glossary_product_tag_root}/glossary-test.jsonld" \
      --target-format json-ld \
      --infer-base-iri \
      --use-dtd-subset -ibn \
      > "${WORKSPACE}/rdf-toolkit-glossary-test.log" 2>&1
    )
  else
    log "Convert ${TMPDIR/${WORKSPACE}/}/glossary-prod-nolabel.ttl to ${glossary_product_tag_root/${WORKSPACE}/}/glossary-prod.jsonld"
    java \
      -Xmx4G \
      -Xms4G \
      -Dfile.encoding=UTF-8 \
      -jar "${RDFTOOLKIT_JAR}" \
      --source "${TMPDIR}/glossary-prod-nolabel.ttl" \
      --source-format turtle \
      --target "${glossary_product_tag_root}/glossary-prod.jsonld" \
      --target-format json-ld \
      --infer-base-iri \
      --use-dtd-subset -ibn \
      > "${WORKSPACE}/rdf-toolkit-glossary-prod.log" 2>&1
    log "Convert ${TMPDIR/${WORKSPACE}/}/glossary-dev-nolabel.ttl to ${glossary_product_tag_root/${WORKSPACE}/}/glossary-dev.jsonld"
    java \
      -Xmx4G \
      -Xms4G \
      -Dfile.encoding=UTF-8 \
      -jar "${RDFTOOLKIT_JAR}" \
      --source "${TMPDIR}/glossary-dev-nolabel.ttl" \
      --source-format turtle \
      --target "${glossary_product_tag_root}/glossary-dev.jsonld" \
      --target-format json-ld \
      --infer-base-iri \
      --use-dtd-subset -ibn \
      > "${WORKSPACE}/rdf-toolkit-glossary-dev.log" 2>&1
    log "Convert ${TMPDIR/${WORKSPACE}/}/glossary-test-nolabel.ttl to ${glossary_product_tag_root/${WORKSPACE}/}/glossary-test.jsonld"
    java \
      -Xmx4G \
      -Xms4G \
      -Dfile.encoding=UTF-8 \
      -jar "${RDFTOOLKIT_JAR}" \
      --source "${TMPDIR}/glossary-test-nolabel.ttl" \
      --source-format turtle \
      --target "${glossary_product_tag_root}/glossary-test.jsonld" \
      --target-format json-ld \
      --infer-base-iri \
      --use-dtd-subset -ibn \
      > "${WORKSPACE}/rdf-toolkit-glossary-test.log" 2>&1
  fi

  if ((debug)) ; then
    glossaryMakeExcel "${TMPDIR}/glossary-test-nolabel.ttl" "${glossary_product_tag_root}/glossary-test"
  else
    glossaryMakeExcel "${TMPDIR}/glossary-dev-nolabel.ttl"  "${glossary_product_tag_root}/glossary-dev"
    glossaryMakeExcel "${TMPDIR}/glossary-prod-nolabel.ttl" "${glossary_product_tag_root}/glossary-prod"
    glossaryMakeExcel "${TMPDIR}/glossary-test-nolabel.ttl" "${glossary_product_tag_root}/glossary-test"
  fi

  #
  # JG>Since I didn't figure out yet how to make webpack load .jsonld files as if they
  #    were normal .json files I need to have some symlinks here from .json to .jsonld
  #    so that these json-ld files can be downloaded with either extension. This is
  #    a temporary measure. We might actually want to generate real plain vanilla JSON
  #    files with a simplified structure allowing others to include the glossary more
  #    easily into their own apps.
  #
  (
    cd "${glossary_product_tag_root}"
    if ((debug)) ; then
      rm -f glossary-test.json
      ln -s "glossary-test.jsonld" "glossary-test.json"
    else
      rm -f glossary-prod.json
      rm -f glossary-dev.json
      ln -s "glossary-dev.jsonld" "glossary-dev.json"
      ln -s "glossary-prod.jsonld" "glossary-prod.json"
      rm -f glossary-test.json
      ln -s "glossary-test.jsonld" "glossary-test.json"
    fi
  )

  return 0
}

#
# What does "glossaryMakeExcel" stand for?
#
function glossaryMakeExcel () {

  local dataTurtle="$1"
  local glossaryBaseName="$2"

  log "Creating Excel file from ${glossaryBaseName/${WORKSPACE}/}.csv"

  #
  # Set the memory for ARQ
  #
  export JVM_ARGS="${JVM_ARGS:--Xmx4G}"

  cat > "${TMPDIR}/makeCcsv.sparql" <<EOF
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX owlnames: <http://spec.edmcouncil.org/owlnames#> 
PREFIX xsd:  <http://www.w3.org/2001/XMLSchema#> 
PREFIX owl:   <http://www.w3.org/2002/07/owl#> 
PREFIX rdf:   <http://www.w3.org/1999/02/22-rdf-syntax-ns#> 
PREFIX av: <https://spec.edmcouncil.org/fibo/ontology/FND/Utilities/AnnotationVocabulary/>

SELECT ?Term ?Type (GROUP_CONCAT (?syn; separator=",") AS ?Synonyms) ?Definition ?GeneratedDefinition  ?example ?explanatoryNote ?ReleaseStatus
WHERE {
  ?c a owlnames:Class  ; av:hasMaturityLevel ?level .
  BIND (IF ((?level=av:Release), "Production", "Development") AS ?ReleaseStatus)
  FILTER (REGEX (xsd:string (?c), "edmcouncil"))
  ?c  owlnames:definition ?Definition ;
  owlnames:label ?Term .

  BIND ("Class" as ?Type)

  OPTIONAL {?c owlnames:synonym ?syn}
  OPTIONAL {?c owlnames:example ?example}
  OPTIONAL {?c owlnames:explanatoryNote ?explanatoryNote}

  OPTIONAL {?c  owlnames:mdDefinition ?GeneratedDefinition}
}
GROUP BY ?c ?Term ?Type ?Definition ?GeneratedDefinition ?example ?explanatoryNote ?ReleaseStatus
ORDER BY ?Term
EOF

  ${JENA_ARQ} --data="${dataTurtle}" --query="${TMPDIR}/makeCcsv.sparql" --results=TSV > "${glossaryBaseName}.tsv"

  cat > "${TMPDIR}/makePcsv.sparql" <<EOF
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX owlnames: <http://spec.edmcouncil.org/owlnames#> 
PREFIX xsd:  <http://www.w3.org/2001/XMLSchema#> 
PREFIX owl:   <http://www.w3.org/2002/07/owl#> 
PREFIX rdf:   <http://www.w3.org/1999/02/22-rdf-syntax-ns#> 
PREFIX av: <https://spec.edmcouncil.org/fibo/ontology/FND/Utilities/AnnotationVocabulary/>

SELECT ?Term ?Type (GROUP_CONCAT (?syn; separator=",") AS ?Synonyms) ?Definition ?GeneratedDefinition  ?example ?explanatoryNote ?ReleaseStatus
WHERE {
  ?c a owlnames:Property ; av:hasMaturityLevel ?level .
  BIND (IF ((?level=av:Release), "Production", "Development") AS ?ReleaseStatus)
  FILTER (REGEX (xsd:string (?c), "edmcouncil"))

  OPTIONAL {?c  owlnames:definition ?Definition}

  ?c owlnames:label ?Term .

  BIND ("Property" as ?Type)

  OPTIONAL {?c owlnames:synonym ?syn}
  OPTIONAL {?c owlnames:example ?example}
  OPTIONAL {?c owlnames:explanatoryNote ?explanatoryNote}
  OPTIONAL {?c owlnames:mdDefinition ?GeneratedDefinition}
}
GROUP BY ?c ?Term ?Type ?Definition ?GeneratedDefinition ?example ?explanatoryNote ?ReleaseStatus
ORDER BY ?Term
EOF

  ${JENA_ARQ} --data="${dataTurtle}" --query="${TMPDIR}/makePcsv.sparql" --results=TSV | tail -n +2 >> "${glossaryBaseName}.tsv"

  ${SED} -i 's/"@../"/g; s/\t\t\t/\t""\t""\t/; s/\t\t/\t""\t/g; s/\t$/\t""/' "${glossaryBaseName}.tsv"

  ${SED} 's/"\t"/","/g' "${glossaryBaseName}.tsv" > "${glossaryBaseName}.csv"
  ${SED} -i '1s/\t[?]/,/g;1s/^[?]//' "${glossaryBaseName}.csv"
  
  #chmod a+x "${SCRIPT_DIR}/csv-to-xlsx.py"
  ${PYTHON3} ${SCRIPT_DIR}/csv-to-xlsx.py  "${glossaryBaseName}.csv" "${glossaryBaseName}.xlsx" "${glossary_script_dir}/csvconfig"

  return 0
}

#
# this is the new data dictionary. It is independent of any glossary work. 
#
function publishProductDataDictionary() {

  logRule "Publishing the datadictionary product"

  setProduct ontology || return $?
  export ontology_product_tag_root="${tag_root}"

  setProduct datadictionary || return $?
  export datadictionary_product_tag_root="${tag_root}"

  (
    cd ${ontology_product_tag_root}
    ls
  )

  export datadictionary_script_dir="${SCRIPT_DIR}/datadictionary"

  #
  # Set the memory for ARQ
  #
  export JVM_ARGS=${JVM_ARGS:--Xmx4G}

  #
  # Get ontologies for Prod
  #
  ${JENA_ARQ} \
    $(${GREP} -r 'utl-av[:;.]Release' "${ontology_product_tag_root}" | ${SED} 's/:.*$//;s/^/--data=/' | ${GREP} -F ".rdf") \
    --data="${datadictionary_script_dir}/AllProd.ttl" \
    --query="${datadictionary_script_dir}/echo.sq" \
    --results=TTL > "${TMPDIR}/temp0B.ttl"

  log "here is the start of the combined file"
  wc    "${TMPDIR}/temp0B.ttl"

  ${JENA_ARQ} \
    --data="${TMPDIR}/temp0B.ttl" \
    --query="${datadictionary_script_dir}/pseudorange.sq" \
    > "${TMPDIR}/pr.ttl"

  wc "${TMPDIR}/pr.ttl"

  cat > "${TMPDIR}/con1.sq" <<EOF
PREFIX av: <https://spec.edmcouncil.org/fibo/ontology/FND/Utilities/AnnotationVocabulary/>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> 

SELECT DISTINCT ?c
WHERE {?x av:forCM true . 
?x rdfs:subClassOf* ?c  .
FILTER (ISIRI (?c))
}
EOF

  ${JENA_ARQ} \
    --data="${TMPDIR}/temp0B.ttl" \
    --query="${TMPDIR}/con1.sq" \
    --results=TSV > "${TMPDIR}/CONCEPTS"

  log "Here are the concepts"
  cat "${TMPDIR}/CONCEPTS"

  cat > "${TMPDIR}/ss.sq" << EOF
PREFIX afn: <http://jena.apache.org/ARQ/function#>
PREFIX owl: <http://www.w3.org/2002/07/owl#>
prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> 
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> 
prefix skos: <http://www.w3.org/2004/02/skos/core#> 
prefix edm: <http://www.edmcouncil.org/temp#>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX av: <https://spec.edmcouncil.org/fibo/ontology/FND/Utilities/AnnotationVocabulary/>

SELECT ?class ?table ?definition ?field ?description ?type ?maturity ?r1
WHERE {
  ?class a owl:Class .
  FILTER (ISIRI (?class))
  LET (?ont := IRI (REPLACE (xsd:string (?class), "/[^/]*$", "/")))
  ?ont av:hasMaturityLevel  ?smaturity .
  BIND (IF ((?smaturity = av:Release), "Production", "Development") AS ?maturity)
  FIlTER (REGEX (xsd:string (?class), "edmcouncil"))
  ?class rdfs:subClassOf* ?base1 .
  ?b1 edm:pseudodomain ?base1; a edm:PR ; edm:p ?p ; edm:pseudorange ?r1  .
  ?p av:forDD "true"^^xsd:boolean .
  FILTER NOT EXISTS {
    ?class rdfs:subClassOf* ?base2 .
# FILTER (?base2 != ?base1)
    ?b2 a edm:PR ; edm:p ?p ; edm:pseudorange ?r2 ; edm:pseudodomain ?base2 .
	  ?r2 rdfs:subClassOf+ ?r1
	}

  ?p rdfs:label ?field .
  OPTIONAL {?p  skos:definition ?dx}
  BIND (COALESCE (?dx, "(none)") AS ?description )
  ?r1 rdfs:label ?type .
  ?class rdfs:label ?table
  OPTIONAL {?class skos:definition  ?dy }
  BIND ( COALESCE (?dy, "(none)") AS ?definition )
} 
EOF

  #
  # Turns out, putting this into a text file and grepping over it ran faster than putting it into a triple store.
  #
  ${JENA_ARQ} \
    --data="${TMPDIR}/temp0B.ttl" \
    --data="${TMPDIR}/pr.ttl" \
    --query="${TMPDIR}/ss.sq" \
    --results=TSV | ${SED} 's/"@../"/g' > "${TMPDIR}/ssx.txt"

  log "Here are the first few lines"
  head  "${TMPDIR}/ssx.txt"
  #
  # remove duplicate lines
  #
  sort -u "${TMPDIR}/ssx.txt" > "${TMPDIR}/ss.txt"
  #
  # Start with empty output
  #
  log "" > "${TMPDIR}/output.tsv"
  #
  # The CONCEPTS are stop-classes; we don't show those.  So we treat them as DONE at the start of the processing.
  #
  ${CP} "${TMPDIR}/CONCEPTS" "${TMPDIR}/DONE"
  #
  # Find the list of things to include.  This is too costly to include all classes.
  #
  cat > "${TMPDIR}/dumps.sq" <<EOF
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>

SELECT DISTINCT ?c
WHERE {
  ?x <https://spec.edmcouncil.org/fibo/ontology/FND/Utilities/AnnotationVocabulary/dumpable> true .
  ## Swap these two to include all subclasses of marked classes
  ?c rdfs:subClassOf* ?x .
  #BIND (?x AS ?c)
  ?c rdfs:label ?lx
  BIND (UCASE (?lx) AS ?l)
} ORDER BY ?l
EOF

  ${JENA_ARQ}  --data="${TMPDIR}/temp0B.ttl"  --query="${TMPDIR}/dumps.sq"  --results=TSV > "${TMPDIR}/dumps"

  ${CP} "${TMPDIR}/dumps" "${TMPDIR}/pr.ttl"    "${TMPDIR}/temp0B.ttl"  ${datadictionary_product_tag_root}

  log "here are the dumps"
  cat "${TMPDIR}/dumps"
  log "that was the dumps"

  echo Writing into "${datadictionary_product_tag_root}/index.html"

  log "${datadictionary_script_dir/${WORKSPACE}/}/index.template contains"
  cat "${datadictionary_script_dir}/index.template"

  ${SED}  '/-- index of dictionaries goes here/,$d' \
  "${datadictionary_script_dir}/index.template" > "${datadictionary_product_tag_root}/index.html"

  cat >> "${datadictionary_product_tag_root}/index.html" <<EOF
<table>
EOF

  tail -n +2 "${TMPDIR}/dumps" | while read class ; do
    dumpdd $class
  done

  cat >> "${datadictionary_product_tag_root}/index.html" <<EOF
</table>
EOF

  ${SED} \
    '1,/-- index of dictionaries goes here/d' \
    "${datadictionary_script_dir}/index.template" >> "${datadictionary_product_tag_root}/index.html"

  return 0
}

#
# Helper Function for datadictionary
#
function localdd () {

  if ${GREP} -q "$1" "${TMPDIR}/DONE" ; then
    log "I've seen it before!"
    return 0
  fi

  echo "$1" >>  "${TMPDIR}/DONE"

  ${GREP}  "^$1" "${TMPDIR}/ss.txt" | \
  ${SED} "s/^[^\t]*\t//; s/\t[^\t]*$//; 2,\$s/^[^\t]*\t[^\t]*\t/\t\"\"\t/" >> "${TMPDIR}/output.tsv"

  log "Finished tsv sed for $1"

  #tdbquery --loc=TEMP  --query=temp2.sq --results=TSV   > next
  ${GREP} "^$1" "${TMPDIR}/ss.txt" | ${SED} 's/^.*\t//'  |  while read uri ; do
    localdd "$(echo "${uri}" | ${SED} 's/\r//')"
  done

  return 0
}


#
# Helper Function for datadictionary
#
function dumpdd () {

  log "Creating Data Dictionary for $1"

  # Extract the filename from the local part of the class IRI
  local t=${1##*/}
  local fname=${t%>*}

  cat >> "${datadictionary_product_tag_root}/index.html" << EOF
<tr><td>${fname}</td><td><a href="${fname}.xlsx">excel</a></td><td><a href="${fname}.csv">CSV</a></td></tr>
EOF

  # Reset the output to blank
  echo "" > "${TMPDIR}/output.tsv"

  #Reset the "seen" list to be the stopclasses
  ${CP} "${TMPDIR}/CONCEPTS"  "${TMPDIR}/DONE"

  localdd $1

  cat > "${datadictionary_product_tag_root}/${fname}.csv" <<EOF
Table,Definition,Field,Field Definition,Type,Maturity
EOF

  ${SED} 's/"\t"/","/g; s/^\t"/,"/' "${TMPDIR}/output.tsv" >> "${datadictionary_product_tag_root}/${fname}.csv"

  chmod a+x "${SCRIPT_DIR}/csv-to-xlsx.py"
  ${SCRIPT_DIR}/csv-to-xlsx.py  "${datadictionary_product_tag_root}/${fname}.csv" "${datadictionary_product_tag_root}/${fname}.xlsx"  "${datadictionary_script_dir}/csvconfig"

  return 0
}

#
# Stuff for building nquads files
#
function quadify () {

  local tmpont="$(mktemp ${TMPDIR}/ontology.XXXXXX.sq)"

  #
  # Set the memory for ARQ
  #
  export JVM_ARGS=${JVM_ARGS:--Xmx4G}

  cat >"${tmpont}" << __HERE__
SELECT ?o WHERE {?o a <http://www.w3.org/2002/07/owl#Ontology> }
__HERE__
    
  ${JENA_RIOT} "$1" | \
    ${SED} "s@[.]\$@ <$(${JENA_ARQ} --results=csv --data=$1 --query=${tmpont} | ${GREP} -v '^o' | tr -d '\n\r')> .@"
  local rc=$?

  rm "${tmpont}"

  return ${rc}
}

function buildquads () {

  local ProdQuadsFile="${tag_root}/prod.fibo.nq"
  local DevQuadsFile="${tag_root}/dev.fibo.nq"

  log "starting buildquads"

  (
    cd ${spec_root}

	  ${FIND} . -name '*.rdf' -print | while read file; do quadify "$file"; done > "${DevQuadsFile}"

	  ${GREP} -r 'utl-av[:;.]Release' "${family_product_branch_tag}" | \
	    ${GREP} -F ".rdf" | \
	    ${SED} 's/:.*$//' | \
	    while read file ; do quadify $file ; done > ${ProdQuadsFile}

	  zip ${ProdQuadsFile}.zip ${ProdQuadsFile}
	  zip ${DevQuadsFile}.zip ${DevQuadsFile}
  )

  log "finished buildquads"

  return 0
}

function main() {

  initRootProcess
  initOSBasedTools || return $?
  initWorkspaceVars || return $?
  initRepoBasedTools || return $?
  initGitVars || return $?
  initJiraVars || return $?

  if [ "$1" == "init" ] ; then
    return 0
  fi

  #
  # If we specified any parameters (other than "init") then
  # assume that these are the product names we need to run
  #
  if [ $# -gt 0 ] ; then
    products="$*"
  else
    #
    # Since we'e running the whole show from one call to this script,
    # ensure that publishing it all is the last step. Otherwise do not
    # forget to call this one last.
    #
    products="${products} publish"
  fi

  for product in ${products} ; do
    if [[ "${product}" != "publish" && ! "${product}" =~ ^--* ]] ; then
      logRule "Publish ${family}-product \"${product}\""
    fi
    case ${product} in
      ontology)
        publishProductOntology || return $?
        ;;
      widoco)
        publishProductWidoco || return $?
        ;;
      index)
	      publishProductIndex || return $?
	      ;;
      vocabulary)
        publishProductVocabulary || return $?
        ;;
      glossary)
        publishProductGlossary || return $?
        ;;
      datadictionary)
        publishProductDataDictionary || return $?
        ;;
      publish)
        #
        # "publish" is not really a product but an action that should come after
        # all the products have been run
        #
        logRule "Final publish stage"
        zipWholeTagDir || return $?
        copySiteFiles || return $?
        ;;
      --*)
        continue
        ;;
      *)
        error "Unknown product ${product}"
        return 1
        ;;
    esac
    #
    # Always switch off tracing in case some product-script forgot
    #
    set +x
    #
    # Make clear in the log that a given product is done
    #
    if [ "${product}" != "publish" ] ; then
      log "Finished publication of ${family}-product \"${product}\""
    fi
  done

  log "We're all done"

  return 0
}

main $@
exit $?
