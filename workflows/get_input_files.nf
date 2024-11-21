// modules
include { PANORAMA_GET_FILE as PANORAMA_GET_DIANN_FASTA } from "../modules/panorama"
include { PANORAMA_GET_FILE as PANORAMA_GET_CARAFE_FASTA } from "../modules/panorama"
include { PANORAMA_GET_FILE as PANORAMA_GET_PEPTIDE_REPORT } from "../modules/panorama"

PANORAMA_URL = 'https://panoramaweb.org'

/**
* Process a parameter variable which is specified as either a single value or List.
* If param_variable has multiple lines, each line with text is returned as an
* element in a List.
*
* @param param_variable A parameter variable which can either be a single value or List.
* @return param_variable as a List with 1 or more values.
*/
def param_to_list(param_variable) {
    if(param_variable instanceof List) {
        return param_variable
    }
    if(param_variable instanceof String) {
        // Split string by new line, remove whitespace, and skip empty lines
        return param_variable.split('\n').collect{ it.trim() }.findAll{ it }
    }
    return [param_variable]
}

workflow get_input_files {

   take:
        aws_secret_id

   emit:
       diann_fasta_file
       carafe_fasta_file
       peptide_report

    main:

        // get files from Panorama as necessary
        if(params.diann_fasta_file) {
            if(panorama_auth_required_for_url(params.diann_fasta_file)) {
                PANORAMA_GET_DIANN_FASTA(params.diann_fasta_file, aws_secret_id)
                diann_fasta_file = PANORAMA_GET_DIANN_FASTA.out.panorama_file
            } else {
                diann_fasta_file = file(params.diann_fasta_file, checkIfExists: true)
            }
        } else {
            diann_fasta_file = null
        }

        if(params.carafe_fasta_file) {
            if(panorama_auth_required_for_url(params.carafe_fasta_file)) {
                PANORAMA_GET_CARAFE_FASTA(params.carafe_fasta_file, aws_secret_id)
                carafe_fasta_file = PANORAMA_GET_CARAFE_FASTA.out.panorama_file
            } else {
                carafe_fasta_file = file(params.carafe_fasta_file, checkIfExists: true)
            }
        } else {
            carafe_fasta_file = null
        }

        if(params.peptide_results_file) {
            if(panorama_auth_required_for_url(params.peptide_results_file)) {
                PANORAMA_GET_PEPTIDE_REPORT(params.peptide_results_file, aws_secret_id)
                peptide_report = PANORAMA_GET_PEPTIDE_REPORT.out.panorama_file
            } else {
                peptide_report = file(params.peptide_results_file, checkIfExists: true)
            }
        } else {
            peptide_report = null
        }
}

def panorama_auth_required_for_url(url) {
    return url.startsWith(PANORAMA_URL) && !url.contains("/_webdav/Panorama%20Public/")
}
