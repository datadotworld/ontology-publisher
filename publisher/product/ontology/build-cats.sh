#!/usr/bin/env bash
#
# Stuff for building catalog files for products like Protegé and Jena (which is needed for SPIN 2.0)
#

#
# Looks silly but fools IntelliJ to see the functions in the included files
#
false && source ../../lib/_functions.sh

function ontologyBuildProtegeCatalog () {

  local -r directory="$1"
  local -r fibo_rel="$2"

  (
    cd "${directory}" || return $?    # Build the catalog in this directory
    verbose "Building Protegé catalog in $(logFileName "${directory}")"

    cat > catalog-v001.xml << __HERE__
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!-- Automatically built by the EDMC infrastructure -->
<catalog prefer="public" xmlns="urn:oasis:names:tc:entity:xmlns:xml:catalog">
__HERE__

    #
    # Find all the rdf files in fibo, and create catalog lines for them based on their location.
    #
    # TODO: Remove hardwired references to fibo and edmcouncil
    #
    find ${fibo_rel} -name '*.rdf' | \
      ${GREP} -v etc | \
      ${SED} 's@^.*$@  <uri id="User Entered Import Resolution" uri="&" name="https://spec.edmcouncil.org/fibo/&"/>@;s@.rdf"/>@/"/>@' | \
      ${SED} "s@fibo/${fibo_rel}/\([a-zA-Z]*/\)@fibo/${product}/${GIT_BRANCH}/${GIT_TAG_NAME}/\U\1\E@" | \
      ${SED} "s@fibo//*@fibo/@g" >> catalog-v001.xml

    cat >> catalog-v001.xml <<< '</catalog>'
  )
}

#
# Generate the Protegé catalog files.
# See also ontologyBuildJenaCatalogs.
#
function ontologyBuildProtegeCatalogs () {

  require tag_root || return $?

  #
  # Run build1catalog in each subdirectory except ext, etc and .git
  #
  find ${tag_root} \
    -maxdepth 1 \
    -mindepth 1 \
    -type d \( \
      -regex "\(.*/ext\)\|\(.*/etc\)\|\(.*/.git\)$" -prune  -o -print \
    \) | while read file ; do
      ontologyIsInTestDomain "${file}" || continue
      ontologyBuildProtegeCatalog "$file" ".." &
    done

  #
  # Run build1catalog in the main directory
  #
  ontologyBuildProtegeCatalog "${tag_root}" "." &

  wait

  return $?
}

#
# Called during the generation of the ontology product.
#
function ontologyBuildJenaCatalogs() {

  require tag_root || return $?

  cat > "${tag_root}/location-mapping.n3" << __HERE__
@prefix lm: <http://jena.hpl.hp.com/2004/08/location-mapping#> .

[] lm:mapping
  #
  # The lm:prefix/lm:altPrefix construct below does not work because it doesn't replace the last / in the given url
  # with ".rdf" so it cannot actually find the corresponding local file.
  #
  #[
  #  lm:prefix "${tag_root_url}" ;
  #  lm:altPrefix "file://${tag_root}"
  #],
  [
    lm:name "http://www.w3.org/2002/07/owl" ;
    lm:altName "file:///publisher/lib/ontologies/w3c/owl.rdf"
  ],
  [
    lm:name "http://www.w3.org/2000/01/rdf-schema" ;
    lm:altName "file:///publisher/lib/ontologies/w3c/rdf-schema.rdf"
  ],
  [
    lm:name "http://www.w3.org/2004/02/skos/core" ;
    lm:altName "file:///publisher/lib/ontologies/w3c/skos.rdf"
  ],
  [
    lm:name "http://spinrdf.org/spin" ;
    lm:altName "file:///publisher/lib/ontologies/topbraid/spin.rdf"
  ],
  [
    lm:name "http://spinrdf.org/sp" ;
    lm:altName "file:///publisher/lib/ontologies/topbraid/sp.rdf"
  ],
  [
    lm:name "http://spinrdf.org/spl" ;
    lm:altName "file:///publisher/lib/ontologies/topbraid/spl.rdf"
  ],
  [
    lm:name "http://spinrdf.org/spr" ;
    lm:altName "file:///publisher/lib/ontologies/topbraid/spr.rdf"
  ],
  [
    lm:name "http://spinrdf.org/spra" ;
    lm:altName "file:///publisher/lib/ontologies/topbraid/spra.rdf"
  ],
  [
    lm:name "http://uispin.org/ui" ;
    lm:altName "file:///publisher/lib/ontologies/topbraid/uispin.rdf"
  ],
  [
    lm:name "http://www.topbraid.org/2007/05/composite.owl" ;
    lm:altName "file:///publisher/lib/ontologies/topbraid/composite.rdf"
  ],
  [
    lm:name "http://topbraid.org/sparqlmotion" ;
    lm:altName "file:///publisher/lib/ontologies/topbraid/sparqlmotion.rdf"
  ],
  [
    lm:name "http://topbraid.org/sparqlmotionlib" ;
    lm:altName "file:///publisher/lib/ontologies/topbraid/sparqlmotionlib.rdf"
  ],
  [
    lm:name "http://topbraid.org/email" ;
    lm:altName "file:///publisher/lib/ontologies/topbraid/email.rdf"
  ],
  [
    lm:name "http://www.omg.org/techprocess/ab/SpecificationMetadata/" ;
    lm:altName "file:///publisher/lib/ontologies/omg/SpecificationMetadata.rdf"
  ],
  [
    lm:name "https://spec.edmcouncil.org/fibo/ontology/FND/Utilities/AnnotationVocabulary/" ;
    lm:altName "file:///publisher/lib/ontologies/edmcouncil/AnnotationVocabulary.rdf"
  ],
__HERE__

  (
    cd / || return $?
    #
    # Now read all our own ontologies
    #
    while read ontologyRdfFile ; do

      ontologyVersionIRI="https://${spec_host}/${ontologyRdfFile/.rdf//}"
      ontologyVersionIRI="${ontologyVersionIRI/${spec_host}?*output/${spec_host}}"

      ontologyIRI="${ontologyVersionIRI/\/${GIT_BRANCH}\/${GIT_TAG_NAME}}"

      cat >> "${tag_root}/location-mapping.n3" << __HERE__
  [
    lm:name "${ontologyIRI}/" ;
    lm:altName "file://${ontologyRdfFile}"
  ],
  [
    lm:name "${ontologyVersionIRI}/" ;
    lm:altName "file://${ontologyRdfFile}"
  ],
__HERE__
    done < <(find ${tag_root} -path '*/etc*' -prune -o -name '*About*' -prune -o -name 'ont-policy.rdf' -prune -o -name '*.rdf' -print)
  )
  #
  # Remove the last comma
  #
  truncate -s-2 "${tag_root}/location-mapping.n3"

  cat >> "${tag_root}/location-mapping.n3" <<< "."

  if ((verbose)) ; then
    log "Generated Jena Location Mapping file:"
    cat "${tag_root}/location-mapping.n3" | pipelog
  fi

  cat > "${tag_root}/ont-policy.rdf" << __HERE__
<?xml version='1.0'?>

<!DOCTYPE rdf:RDF [
    <!--

    NOTE that we're using the old namespace here for jena, hpl.hp.com, not apache.org.
    See this line:

    https://github.com/apache/jena/blob/69571e7ebc3bfde6ec3bc4e96d136428d7f7378e/
    jena-core/src/main/java/org/apache/jena/vocabulary/OntDocManagerVocab.java#L39

    -->
    <!ENTITY jena    'http://jena.hpl.hp.com/schemas/'>
    <!ENTITY rdf     'http://www.w3.org/1999/02/22-rdf-syntax-ns#'>
    <!ENTITY rdfs    'http://www.w3.org/2000/01/rdf-schema#'>
    <!ENTITY xsd     'http://www.w3.org/2001/XMLSchema#'>
    <!ENTITY base    '&jena;2003/03/ont-manager'>
    <!ENTITY ont     '&base;#'>
]>

<rdf:RDF
  xmlns:rdf ="&rdf;"
  xmlns:rdfs="&rdfs;"
  xmlns     ="&ont;"
  xml:base  ="&base;"
>
  <DocumentManagerPolicy>
    <!-- policy for controlling the document manager's behaviour -->
    <!--
      Switching the processImports value from false to true will cause tools like SPIN
      to import everything where many ontologies will be downloaded from the web.
      If the "\-\-network none" option is given when starting the container (check docker-run.sh)
      then all these external HTTP GET requests will fail, but nevertheless its important to
      understand the impact of the value below.
    -->
    <processImports rdf:datatype="&xsd;boolean">false</processImports>
    <cacheModels rdf:datatype="&xsd;boolean">true</cacheModels>
  </DocumentManagerPolicy>

  <OntologySpec>
      <!-- local version of the OWL language ontology (in OWL) -->
      <publicURI rdf:resource="http://www.w3.org/2002/07/owl" />
      <altURL    rdf:resource="file:///publisher/lib/ontologies/w3c/owl.owl" />
      <language  rdf:resource="http://www.w3.org/2002/07/owl" />
      <prefix    rdf:datatype="&xsd;string">owl</prefix>
  </OntologySpec>

  <OntologySpec>
      <!-- local version of the RDFS vocabulary -->
      <publicURI rdf:resource="http://www.w3.org/2000/01/rdf-schema" />
      <altURL    rdf:resource="file:///publisher/lib/ontologies/w3c/rdf-schema.rdf" />
      <language  rdf:resource="http://www.w3.org/2000/01/rdf-schema" />
      <prefix    rdf:datatype="&xsd;string">rdfs</prefix>
  </OntologySpec>

  <OntologySpec>
      <!-- local version of the spin vocabulary -->
      <publicURI rdf:resource="http://spinrdf.org/spin" />
      <altURL    rdf:resource="file:///publisher/lib/ontologies/topbraid/spin.rdf" />
  </OntologySpec>

  <OntologySpec>
      <!-- local version of the spin vocabulary -->
      <publicURI rdf:resource="http://www.topbraid.org/2007/05/composite.owl" />
      <altURL    rdf:resource="file:///publisher/lib/ontologies/topbraid/composite.rdf" />
  </OntologySpec>
__HERE__

  (
    cd / || return $?
    while read ontologyRdfFile ; do
      logVar spec_host 	
      logVar ontologyRdfFile
      ontologyVersionIRI="https://${spec_host}/${ontologyRdfFile/.rdf//}"
      logVar ontologyVersionIRI
      ontologyVersionIRI="${ontologyVersionIRI/${spec_host}?*output/${spec_host}}"
      logVar ontologyVersionIRI

      ontologyIRI="${ontologyVersionIRI/\/${GIT_BRANCH}\/${GIT_TAG_NAME}}"
      logVar ontologyIRI

      cat >> "${tag_root}/ont-policy.rdf" << __HERE__

  <OntologySpec>
      <publicURI rdf:resource="${ontologyIRI}/" />
      <altURL    rdf:resource="file://${ontologyRdfFile}" />
      <language  rdf:resource="http://www.w3.org/2000/01/rdf-schema" />
  </OntologySpec>

  <OntologySpec>
      <publicURI rdf:resource="${ontologyVersionIRI}/" />
      <altURL    rdf:resource="file://${ontologyRdfFile}" />
      <language  rdf:resource="http://www.w3.org/2000/01/rdf-schema" />
  </OntologySpec>
__HERE__
    done < <(getDevOntologies)
  )

  cat >> "${tag_root}/ont-policy.rdf" << __HERE__
</rdf:RDF>

__HERE__

  if ((verbose)) ; then
    log "Generated Jena Ontology Policy file:"
    cat "${tag_root}/ont-policy.rdf" | pipelog
  fi

  return $?
}

function ontologyBuildCatalogs() {

  logRule "Step: ontologyBuildCatalogs"

  find ${OUTPUT} -name 'ont-policy.rdf' -o -name 'location-mapping.n3' -delete

  ontologyBuildJenaCatalogs && ontologyBuildProtegeCatalogs
}
