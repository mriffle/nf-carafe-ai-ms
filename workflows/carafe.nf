
// modules
include { CARAFE } from "../modules/carafe"

workflow carafe {
    
    take:
        fasta_file
        peptide_results_file
        carafe_params

    emit:
        speclib_tsv
        carafe_version
        stdout
        stderr

    main:

        carafe_results = CARAFE(
            fasta_file,
            peptide_results_file,
            carafe_params
        )

        carafe_version    = carafe_results.version
        speclib_tsv       = carafe_results.speclib_tsv
        stdout            = carafe_results.stdout
        stderr            = carafe_results.stderr
}