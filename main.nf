#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// Sub workflows
include { get_input_files } from "./workflows/get_input_files"
include { diann_search } from "./workflows/diann_search"
include { carafe } from "./workflows/carafe"
include { get_mzmls } from "./workflows/get_mzmls"

// modules
include { GET_AWS_USER_ID } from "./modules/aws"
include { BUILD_AWS_SECRETS } from "./modules/aws"
include { ENCYCLOPEDIA_TSV_TO_DLIB } from "./modules/encyclopedia"
include { WRITE_CITATIONS } from "./modules/citations"
include { WRITE_VERSIONS } from "./modules/versions"

// useful functions and variables
include { param_to_list } from "./workflows/get_input_files"

// nf-schema parameter validation
include { validateParameters } from 'plugin/nf-schema'

// String to test for Panoramaness
PANORAMA_URL = 'https://panoramaweb.org'

//
// The main workflow
//
workflow {

    log.info file("${projectDir}/conf/startup.txt").text

    // Validate parameters against the schema (nextflow_schema.json)
    validateParameters()

    // Custom validation: spectra_file and spectra_dir are mutually exclusive
    if(!params.spectra_file && !params.spectra_dir) {
        error "Either `spectra_file` or `spectra_dir` must be specified."
    }

    if(params.spectra_file && params.spectra_dir) {
        error "`spectra_file` and `spectra_dir` cannot both be specified."
    }

    // if accessing panoramaweb and running on aws, set up an aws secret
    if(workflow.profile == 'aws' && is_panorama_used()) {
        GET_AWS_USER_ID()
        BUILD_AWS_SECRETS(GET_AWS_USER_ID.out)
        aws_secret_id = BUILD_AWS_SECRETS.out.aws_secret_id
    } else {
        aws_secret_id = Channel.of('none').collect()    // ensure this is a value channel
    }

    get_input_files(aws_secret_id)   // get input files
    get_mzmls(aws_secret_id)  // get mzmls

    // set up some convenience variables
    carafe_fasta_file = get_input_files.out.carafe_fasta_file
    diann_fasta_file = get_input_files.out.diann_fasta_file
    mzml_file_ch = get_mzmls.out.mzml_ch

    // collect citations and versions from subworkflows
    all_citations = get_input_files.out.citations
        .mix(get_mzmls.out.citations)
    all_versions = get_input_files.out.versions
        .mix(get_mzmls.out.versions)

    if(!params.peptide_results_file) {
        diann_search(
            mzml_file_ch,
            params.diann_fasta_file ? diann_fasta_file : carafe_fasta_file
        )
        peptide_report_file = diann_search.out.precursor_report
        all_citations = all_citations.mix(diann_search.out.citations)
        all_versions = all_versions.mix(diann_search.out.versions)
    } else {
        peptide_report_file = get_input_files.out.peptide_report
    }

    carafe(
        mzml_file_ch,
        carafe_fasta_file,
        peptide_report_file,
        params.cli_options,
        params.include_phosphorylation,
        params.include_oxidized_methionine,
        params.max_mod_option,
        params.output_format
    )

    if(params.output_format == 'encyclopedia') {
        ENCYCLOPEDIA_TSV_TO_DLIB(
            carafe_fasta_file,
            carafe.out.speclib_tsv
        )
        all_citations = all_citations.mix(ENCYCLOPEDIA_TSV_TO_DLIB.out.citation)
        all_versions = all_versions.mix(ENCYCLOPEDIA_TSV_TO_DLIB.out.version_info)
    }

    all_citations = all_citations.mix(carafe.out.citations)
    WRITE_CITATIONS(all_citations.unique().collect())

    all_versions = all_versions.mix(carafe.out.versions)
    all_version_data = all_versions.map { file ->
        new LinkedHashMap(new groovy.json.JsonSlurper().parseText(file.text))
    }

    workflow_metadata = Channel.of(
        ["Nextflow run at", workflow.start.toString()],
        ["Nextflow version", nextflow.version.toString()],
        ["Workflow git address", (workflow.repository ?: '').toString()],
        ["Workflow git revision (branch)", (workflow.revision ?: '').toString()],
        ["Workflow git commit hash", (workflow.commitId ?: '').toString()],
        ["Run session ID", workflow.sessionId.toString()],
        ["Command line", workflow.commandLine.toString()]
    ).collect(flat: false)

    WRITE_VERSIONS(workflow_metadata, all_version_data.collect())

}

// return true if any entry in the list created from the param is a panoramaweb URL
def any_entry_is_panorama(param) {
    values = param_to_list(param)
    return values.any { it.startsWith(PANORAMA_URL) }
}

// return true if panoramaweb will be accessed by this Nextflow run
def is_panorama_used() {
    return (params.diann_fasta_file     && panorama_auth_required_for_url(params.diann_fasta_file)) ||
           (params.carafe_fasta_file    && panorama_auth_required_for_url(params.carafe_fasta_file)) ||
           (params.peptide_results_file && panorama_auth_required_for_url(params.peptide_results_file)) ||
           (params.spectra_file         && panorama_auth_required_for_url(params.spectra_file)) ||
           (params.spectra_dir          && panorama_auth_required_for_url(params.spectra_dir))
}

def panorama_auth_required_for_url(url) {
    return url.startsWith(PANORAMA_URL) && !url.contains("/_webdav/Panorama%20Public/")
}

//
// Used for email notifications
//
def email() {
    // Create the email text:
    def (subject, msg) = EmailTemplate.email(workflow, params)
    // Send the email:
    if (params.email) {
        sendMail(
            to: "$params.email",
            subject: subject,
            body: msg
        )
    }
}

//
// This is a dummy workflow for testing
//
workflow dummy {
    println "This is a workflow that doesn't do anything."
}

// Email notifications:
workflow.onComplete {
    try {
        email()
    } catch (Exception e) {
        println "Warning: Error sending completion email."
    }
}
