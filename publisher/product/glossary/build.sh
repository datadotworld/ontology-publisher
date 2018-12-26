#!/usr/bin/env bash
#
# Generate the glossary "product" from the source ontologies
#

#
# Looks silly but fools IntelliJ to see the functions in the included files
#
false && source ../../lib/_functions.sh

#
# Produce all artifacts for the glossary product
#
function publishProductGlossary() {

  setProduct ontology || return $?
  export ontology_product_tag_root="${tag_root:?}"

  setProduct glossary || return $?
  export glossary_product_tag_root="${tag_root:?}"
  export glossary_product_tag_root_url="${tag_root_url:?}"

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

  local numberOfProductionLevelOntologyFiles=0

  export glossary_script_dir="${SCRIPT_DIR:?}/glossary"

  if [ ! -d "${glossary_script_dir}" ] ; then
    error "Could not find ${glossary_script_dir}"
    return 1
  fi

  #
  # Set the memory for ARQ
  #
  JVM_ARGS="--add-opens java.base/java.lang=ALL-UNNAMED"
  JVM_ARGS="${JVM_ARGS} -Dxxx=arq"
  JVM_ARGS="${JVM_ARGS} -Xms2g"
  JVM_ARGS="${JVM_ARGS} -Xmx9g"
  JVM_ARGS="${JVM_ARGS} -Dfile.encoding=UTF-8"
  JVM_ARGS="${JVM_ARGS} -Djava.io.tmpdir=\"${TMPDIR}\""
  export JVM_ARGS
  logVar JVM_ARGS

  #
  # Get ontologies for Dev
  #
# if ((debug == 0)) ; then
    verbose "Get all dev ontologies convert to one Turtle file ($(logFileName ${TMPDIR}/glossary-dev.ttl))"
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
# fi

  #
  # Get ontologies for Prod
  #
# if ((debug == 0)) ; then
    verbose "Get all prod ontologies convert to one Turtle file ($(logFileName ${TMPDIR}/glossary-prod.ttl))"

    log "All production level ontology files:"
    while read prodOntologyFile ; do
      log "- ${prodOntologyFile}"
      numberOfProductionLevelOntologyFiles=$((numberOfProductionLevelOntologyFiles + 1))
    done < <(${GREP} -r 'utl-av[:;.]Release' "${ontology_product_tag_root}")

    if ((numberOfProductionLevelOntologyFiles == 0)) ; then
      warning "There are no production level ontology files"
    else
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
# fi

  #
  # Just do "Corporations.rdf" for test purposes
  #
  verbose "Get the Corporations.rdf ontology (for test purposes) and generate ($(logFileName ${TMPDIR}/glossary-test.ttl))"
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

#  if ((debug)) ; then
#    log "debug=true so only generating the test version of the glossary"
#    "${SCRIPT_DIR}/utils/spinRunInferences.sh" "${TMPDIR}/glossary-test.ttl" "${glossary_product_tag_root}/glossary-test.ttl" || return $?
#  else
    log "debug=false so now we're generating the full prod and dev versions"

    if ((numberOfProductionLevelOntologyFiles > 0)) ; then
      "${SCRIPT_DIR}/utils/spinRunInferences.sh" "${TMPDIR}/glossary-prod.ttl" "${glossary_product_tag_root}/glossary-prod.ttl" &
    fi
    "${SCRIPT_DIR}/utils/spinRunInferences.sh" "${TMPDIR}/glossary-dev.ttl" "${glossary_product_tag_root}/glossary-dev.ttl" &
    log "and on top of that also the test glossary"
    "${SCRIPT_DIR}/utils/spinRunInferences.sh" "${TMPDIR}/glossary-test.ttl" "${glossary_product_tag_root}/glossary-test.ttl" &
    log "Waiting for the above SPIN commands to finish"
    wait
    log "SPIN commands have finished"
#  fi

  #
  # The spin inferences can create too many explanations.  This removes redundant ones.
  #
  local -r fixFile="$(createTempFile "fix" "sq")"
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
#  if ((debug)) ; then
#    publishProductGlossaryRemoveWarnings "${fixFile}" test || return $?
#  else
    if ((numberOfProductionLevelOntologyFiles > 0)) ; then
      publishProductGlossaryRemoveWarnings "${fixFile}" prod || return $?
    fi
    publishProductGlossaryRemoveWarnings "${fixFile}" dev || return $?
    publishProductGlossaryRemoveWarnings "${fixFile}" test || return $?
#  fi

  cat > "${TMPDIR}/nolabel.sq" << __HERE__
#
# JG>Dean, what's going on here? Removing all the rdfs:labels? Why?
#
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

CONSTRUCT {
  ?s ?p ?o
}
WHERE {
  ?s ?p ?o .
  FILTER (ISIRI (?s) || (?p != rdfs:label))
}
__HERE__

# if ((debug)) ; then
#   ${JENA_ARQ} --data="${glossary_product_tag_root}/glossary-test.ttl" --query="${TMPDIR}/nolabel.sq" > "${TMPDIR}/glossary-test-nolabel.ttl"
# else
    if ((numberOfProductionLevelOntologyFiles > 0)) ; then
      ${JENA_ARQ} --data="${glossary_product_tag_root}/glossary-prod.ttl" --query="${TMPDIR}/nolabel.sq" > "${TMPDIR}/glossary-prod-nolabel.ttl"
    fi
    ${JENA_ARQ} --data="${glossary_product_tag_root}/glossary-dev.ttl"  --query="${TMPDIR}/nolabel.sq" > "${TMPDIR}/glossary-dev-nolabel.ttl"
    ${JENA_ARQ} --data="${glossary_product_tag_root}/glossary-test.ttl" --query="${TMPDIR}/nolabel.sq" > "${TMPDIR}/glossary-test-nolabel.ttl"
#  fi

  log "Using RDF toolkit to convert Turtle to JSON-LD"

#  if ((debug)) ; then
#    log "Convert ${TMPDIR/${WORKSPACE}/}/glossary-test-nolabel.ttl to ${glossary_product_tag_root/${WORKSPACE}/}/glossary-test.jsonld"
#    (
#    set -x
#    java \
#      -Xmx4G \
#      -Xms4G \
#      -Dfile.encoding=UTF-8 \
#      -jar "${RDFTOOLKIT_JAR}" \
#      --source "${TMPDIR}/glossary-test-nolabel.ttl" \
#      --source-format turtle \
#      --target "${glossary_product_tag_root}/glossary-test.jsonld" \
#      --target-format json-ld \
#      --infer-base-iri \
#      --use-dtd-subset -ibn \
#      > "${glossary_product_tag_root}/rdf-toolkit-glossary-test.log" 2>&1
#    )
#  else
    if ((numberOfProductionLevelOntologyFiles > 0)) ; then
      log "Convert ${TMPDIR/${WORKSPACE}/}/glossary-prod-nolabel.ttl to ${glossary_product_tag_root/${WORKSPACE}/}/glossary-prod.jsonld"
      java \
        --add-opens java.base/java.lang=ALL-UNNAMED \
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
        > "${glossary_product_tag_root}/rdf-toolkit-glossary-prod.log" 2>&1
    fi
    log "Convert ${TMPDIR/${WORKSPACE}/}/glossary-dev-nolabel.ttl to ${glossary_product_tag_root/${WORKSPACE}/}/glossary-dev.jsonld"
    java \
      --add-opens java.base/java.lang=ALL-UNNAMED \
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
      > "${glossary_product_tag_root}/rdf-toolkit-glossary-dev.log" 2>&1
    log "Convert ${TMPDIR/${WORKSPACE}/}/glossary-test-nolabel.ttl to ${glossary_product_tag_root/${WORKSPACE}/}/glossary-test.jsonld"
    java \
      --add-opens java.base/java.lang=ALL-UNNAMED \
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
      > "${glossary_product_tag_root}/rdf-toolkit-glossary-test.log" 2>&1
#  fi

# if ((debug)) ; then
#   glossaryMakeExcel "${TMPDIR}/glossary-test-nolabel.ttl" "${glossary_product_tag_root}/glossary-test"
# else
    if ((numberOfProductionLevelOntologyFiles > 0)) ; then
      glossaryMakeExcel "${TMPDIR}/glossary-prod-nolabel.ttl" "${glossary_product_tag_root}/glossary-prod"
    fi
    glossaryMakeExcel "${TMPDIR}/glossary-dev-nolabel.ttl"  "${glossary_product_tag_root}/glossary-dev"
    glossaryMakeExcel "${TMPDIR}/glossary-test-nolabel.ttl" "${glossary_product_tag_root}/glossary-test"
#  fi

  #
  # JG>Since I didn't figure out yet how to make webpack load .jsonld files as if they
  #    were normal .json files I need to have some symlinks here from .json to .jsonld
  #    so that these json-ld files can be downloaded with either extension. This is
  #    a temporary measure. We might actually want to generate real plain vanilla JSON
  #    files with a simplified structure allowing others to include the glossary more
  #    easily into their own apps.
  #
  (
    cd "${glossary_product_tag_root}" || return $?
    if ((debug)) ; then
      rm -f glossary-test.json
      ln -s "glossary-test.jsonld" "glossary-test.json"
    else
      rm -f glossary-prod.json
      rm -f glossary-dev.json
      ln -s "glossary-dev.jsonld" "glossary-dev.json"
      if ((numberOfProductionLevelOntologyFiles > 0)) ; then
        ln -s "glossary-prod.jsonld" "glossary-prod.json"
      fi
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

  cat > "${TMPDIR}/makeCcsv.sparql" << __HERE__
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX owlnames: <http://spec.edmcouncil.org/owlnames#>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX owl: <http://www.w3.org/2002/07/owl#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
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
__HERE__

  ${JENA_ARQ} --data="${dataTurtle}" --query="${TMPDIR}/makeCcsv.sparql" --results=TSV > "${glossaryBaseName}.tsv"

  cat > "${TMPDIR}/makePcsv.sparql" << __HERE__
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX owlnames: <http://spec.edmcouncil.org/owlnames#>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX owl: <http://www.w3.org/2002/07/owl#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
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
__HERE__

  ${JENA_ARQ} --data="${dataTurtle}" --query="${TMPDIR}/makePcsv.sparql" --results=TSV | tail -n +2 >> "${glossaryBaseName}.tsv"

  ${SED} -i 's/"@../"/g; s/\t\t\t/\t""\t""\t/; s/\t\t/\t""\t/g; s/\t$/\t""/' "${glossaryBaseName}.tsv"

  ${SED} 's/"\t"/","/g' "${glossaryBaseName}.tsv" > "${glossaryBaseName}.csv"
  ${SED} -i '1s/\t[?]/,/g;1s/^[?]//' "${glossaryBaseName}.csv"

  ${PYTHON3} ${SCRIPT_DIR}/lib/csv-to-xlsx.py \
    "${glossaryBaseName}.csv" \
    "${glossaryBaseName}.xlsx" \
    "${glossary_script_dir}/csvconfig"

  return 0
}
