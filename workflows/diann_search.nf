
// modules
include { DIANN_SEARCH_LIB_FREE } from "../modules/diann"

workflow diann_search {
    
    take:
        ms_file_ch
        fasta

    emit:
        quant_files
        speclib
        precursor_report
        stdout
        stderr
        predicted_speclib
        versions
        citations

    main:

        diann_results = null
        diann_results = DIANN_SEARCH_LIB_FREE (
            ms_file_ch.collect(),
            fasta,
            params.diann_params
        )

        predicted_speclib = diann_results.predicted_speclib

        quant_files       = diann_results.quant_files
        speclib           = diann_results.speclib
        precursor_report     = diann_results.precursor_report
        stdout            = diann_results.stdout
        stderr            = diann_results.stderr
        versions          = DIANN_SEARCH_LIB_FREE.out.version_info
        citations         = DIANN_SEARCH_LIB_FREE.out.citation
}
