process WRITE_VERSIONS {
    publishDir "${params.result_dir}", failOnError: true, mode: 'copy'
    container params.images.ubuntu

    input:
        val workflow_metadata
        val version_entries

    output:
        path("versions.txt"), emit: versions_file

    script:
    def metadata_text = workflow_metadata.collect { entry ->
        "${entry[0]}: ${entry[1]}"
    }.join('\n')

    def version_text = version_entries
        .unique { it.program }
        .sort { it.program }
        .collect { entry ->
            "${entry.program}\n  Version: ${entry.version}\n  Container image: ${entry.container}"
        }.join('\n\n')

    """
    cat > versions.txt << 'ENDOFVERSIONS'
${metadata_text}

Programs and versions used in this workflow run:

${version_text}
ENDOFVERSIONS
    """

    stub:
    """
    touch versions.txt
    """
}
