
// modules
include { CARAFE } from "../modules/carafe"

workflow carafe {
    
    take:
        mzml_file_ch
        fasta_file
        peptide_results_file
        carafe_params
        output_format

    emit:
        speclib_tsv
        carafe_version
        stdout
        stderr

    main:

        carafe_results = CARAFE(
            mzml_file_ch,
            fasta_file,
            peptide_results_file,
            carafe_params,
            output_format
        )

        carafe_version    = carafe_results.version
        speclib_tsv       = carafe_results.speclib_tsv
        stdout            = carafe_results.stdout
        stderr            = carafe_results.stderr
}