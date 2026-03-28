
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
        stdout
        stderr
        versions
        citations

    main:

        carafe_results = CARAFE(
            mzml_file_ch.collect(),
            fasta_file,
            peptide_results_file,
            carafe_params,
            output_format
        )

        speclib_tsv       = carafe_results.speclib_tsv
        stdout            = carafe_results.stdout
        stderr            = carafe_results.stderr
        versions          = CARAFE.out.version_info
        citations         = CARAFE.out.citation
}