
// modules
include { DIANN_SEARCH_LIB_FREE } from "../modules/diann"

workflow diann_search {
    
    take:
        ms_file_ch
        fasta

    emit:
        precursor_report
        stdout
        stderr
        versions
        citations

    main:

        diann_results = null
        diann_results = DIANN_SEARCH_LIB_FREE (
            ms_file_ch.collect(),
            fasta,
            params.diann_params
        )

        precursor_report  = diann_results.precursor_report
        stdout            = diann_results.stdout
        stderr            = diann_results.stderr
        versions          = DIANN_SEARCH_LIB_FREE.out.version_info
        citations         = DIANN_SEARCH_LIB_FREE.out.citation
}
