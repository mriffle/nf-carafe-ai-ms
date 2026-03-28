process WRITE_VERSIONS {
    publishDir "${params.result_dir}", failOnError: true, mode: 'copy'
    container params.images.ubuntu

    input:
        val version_entries

    output:
        path("versions.txt"), emit: versions_file

    script:
    def version_text = version_entries
        .unique { it.program }
        .sort { it.program }
        .collect { entry ->
            "${entry.program}\n  Version: ${entry.version}\n  Container image: ${entry.container}"
        }.join('\n\n')

    """
    cat > versions.txt << 'ENDOFVERSIONS'
Programs and versions used in this workflow run:

${version_text}
ENDOFVERSIONS
    """

    stub:
    """
    touch versions.txt
    """
}
