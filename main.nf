#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// Sub workflows
include { get_input_files } from "./workflows/get_input_files"
include { diann_search } from "./workflows/diann_search"
include { carafe } from "./workflows/carafe"
include { get_mzmls } from "./workflows/get_mzmls"
include { save_run_details } from "./workflows/save_run_details"

// modules
include { GET_AWS_USER_ID } from "./modules/aws"
include { BUILD_AWS_SECRETS } from "./modules/aws"
include { ENCYCLOPEDIA_TSV_TO_DLIB } from "./modules/encyclopedia"

// useful functions and variables
include { param_to_list } from "./workflows/get_input_files"

// String to test for Panoramaness
PANORAMA_URL = 'https://panoramaweb.org'

//
// The main workflow
//
workflow {

    if(!params.spectra_file) {
        error "`spectra_file` is a required parameter."
    }

    if(!params.carafe_fasta_file) {
        error "`carafe_fasta_file` is a required parameter."
    }

    if(params.output_format != 'diann' && params.output_format != 'encyclopedia') {
        error "`output_format` must be one of 'diann' or 'encyclopedia'"
    }

    // version file channles
    diann_version = null
    carafe_version = null
    proteowizard_version = null // TODO: populate this

    // if accessing panoramaweb and running on aws, set up an aws secret
    if(workflow.profile == 'aws' && is_panorama_used()) {
        GET_AWS_USER_ID()
        BUILD_AWS_SECRETS(GET_AWS_USER_ID.out)
        aws_secret_id = BUILD_AWS_SECRETS.out.aws_secret_id
    } else {
        aws_secret_id = Channel.of('none').collect()    // ensure this is a value channel
    }

    get_input_files(aws_secret_id)   // get input files
    get_mzmls(params.spectra_file, aws_secret_id)  // get mzmls

    // set up some convenience variables
    carafe_fasta_file = get_input_files.out.carafe_fasta_file
    diann_fasta_file = get_input_files.out.diann_fasta_file
    mzml_file_ch = get_mzmls.out.mzml_ch

    if(!params.peptide_results_file) {
        diann_search(
            mzml_file_ch,
            params.diann_fasta_file ? diann_fasta_file : carafe_fasta_file
        )
        diann_version = diann_search.out.diann_version
        peptide_report_file = diann_search.out.precursor_tsv
    } else {
        diann_version = Channel.empty()
        peptide_report_file = get_input_files.out.peptide_report
    }

    carafe(
        mzml_file_ch,
        carafe_fasta_file,
        peptide_report_file,
        params.carafe_cli_options ? params.carafe_cli_options : '',
        params.output_format
    )

    if(params.output_format == 'encyclopedia') {
        ENCYCLOPEDIA_TSV_TO_DLIB(
            carafe_fasta_file,
            carafe.out.speclib_tsv
        )
    }

    carafe_version = carafe.out.carafe_version
    version_files = carafe_version.concat(diann_version).splitText()

    // input_files = diann_fasta_file.map{ it -> ['DIA-NN FASTA file', it.name] }    
    // if(!params.peptide_results_file) {
    //     input_files = input_files.concat( wide_mzml_ch.map{ it -> ['Spectra file', it.baseName] })   
    // }
    // if(params.carafe_fasta_file) {
    //     input_files = input_files.concat(carafe_fasta_file.map{ it -> ['Carafe FASTA file', it.name] })
    // }
    input_files = Channel.empty()
    //save_run_details(input_files.collect(), version_files.collect())
    //run_details_file = save_run_details.out.run_details

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
           (params.spectra_file         && panorama_auth_required_for_url(params.spectra_file))
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
