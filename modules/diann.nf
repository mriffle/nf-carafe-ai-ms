process DIANN_SEARCH_LIB_FREE {
    publishDir "${params.result_dir}/diann", failOnError: true, mode: 'copy'
    label 'process_high_constant'
    container params.images.diann
    
    input:
        path ms_files
        path fasta_file
        val diann_params
    
    output:
        path("*.stderr"), emit: stderr
        path("*.stdout"), emit: stdout
        path("report.tsv.speclib"), emit: speclib
        path("${output_report_name}.{parquet,tsv}"), emit: precursor_report
        path("*.quant"), emit: quant_files
        path("lib.predicted.speclib"), emit: predicted_speclib
        path("diann_version.json"), emit: version_info
        val 'diann', emit: citation

    script:

        /* 
         * dia-nn will produce different results if the order of the input files is different
         * sort the files to ensure they are in the same order in every run
         */
        output_report_name = 'report'

        sorted_ms_files = ms_files.toList().sort { a, b -> a.toString() <=> b.toString() }

        ms_file_args = "--f '${sorted_ms_files.join('\' --f \'')}'"

        /*
         * Parse version from container image tag (e.g., "quay.io/protio/diann:1.8.1" -> "1.8.1")
         * Include --export-quant for version >= 2.0.0, or by default if version cannot be parsed
         */
        def imageTag = params.images.diann.tokenize(':').last()
        def versionParts = imageTag.tokenize('.')
        def major = versionParts[0]?.isInteger() ? versionParts[0].toInteger() : null
        def exportQuantParam = (major == null || major >= 2) ? "--export-quant" : ""

        def container_image = task.container ?: 'none'

        """
        diann ${ms_file_args} \
            --threads ${task.cpus} \
            --fasta "${fasta_file}" \
            --fasta-search \
            --predictor \
            ${diann_params} \
            > >(tee "diann.stdout") 2> >(tee "diann.stderr" >&2)

        # DiaNN does weird things with output file names depending on the version
        # Instead of specifying them as options to DiaNN we will rename the default output files manually
        if [[ -f report.tsv ]] ; then
            mv -nv report.tsv ${output_report_name}.tsv
        elif [[ -f report.parquet ]] ; then
            mv -nv report.parquet ${output_report_name}.parquet
        else
            echo "Missing DiaNN precursor report and/or speclib!" >&2
            exit 1
        fi

        DIANN_VERSION=\$(head -n 1 diann.stdout | egrep -o '[0-9]+\\.[0-9]+\\.[0-9]+' || true)
        DIANN_VERSION=\${DIANN_VERSION:-unknown}
        cat <<VEOF > diann_version.json
{"program": "DIA-NN", "version": "\$DIANN_VERSION", "container": "${container_image}"}
VEOF
        """

    stub:
        output_report_name = 'report'

        """
        touch lib.predicted.speclib report.tsv.speclib report.tsv stub.quant
        touch stub.stderr stub.stdout
        echo '{"program": "DIA-NN", "version": "stub", "container": "stub"}' > diann_version.json
        """
}
