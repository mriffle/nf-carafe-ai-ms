process MSCONVERT {
    storeDir "${params.mzml_cache_directory}/${workflow.commitId}/${params.msconvert.do_demultiplex}/${params.msconvert.do_simasspectra}"
    label 'process_medium'
    label 'process_high_memory'
    label 'error_retry'
    container params.images.proteowizard

    tag "${raw_file.baseName}"

    input:
        path raw_file
        val do_demultiplex
        val do_simasspectra

    output:
        path("${raw_file.baseName}.mzML"), emit: mzml_file
        path("${raw_file.baseName}_msconvert_version.json"), emit: version_info

    script:

    demultiplex_param = do_demultiplex ? '--filter "demultiplex optimization=overlap_only"' : ''
    simasspectra = do_simasspectra ? '--simAsSpectra' : ''

    def container_image = task.container ?: 'none'

    """
    wine msconvert \
        ${raw_file} \
        -v \
        --zlib \
        --mzML \
        --ignoreUnknownInstrumentError \
        --filter "peakPicking true 1-" \
        --64 ${simasspectra} ${demultiplex_param}

    # Extract version from msconvert help output
    wine msconvert --help > msconvert_help.txt 2>&1 || true
    MSCONVERT_VERSION=\$(tr -d '\\r' < msconvert_help.txt | grep -E 'ProteoWizard release:|Build date:' | sed 's/^[[:space:]]*//' | awk '{printf sep \$0; sep="; "}' || true)
    MSCONVERT_VERSION=\${MSCONVERT_VERSION:-unknown}
    cat <<VEOF > ${raw_file.baseName}_msconvert_version.json
{"program": "msconvert", "version": "\$MSCONVERT_VERSION", "container": "${container_image}"}
VEOF
    """

    stub:
    """
    touch ${raw_file.baseName}.mzML
    echo '{"program": "msconvert", "version": "stub", "container": "stub"}' > ${raw_file.baseName}_msconvert_version.json
    """
}
