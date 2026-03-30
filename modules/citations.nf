process WRITE_CITATIONS {
    publishDir "${params.result_dir}", failOnError: true, mode: 'copy'
    container params.images.ubuntu

    input:
        val citation_keys

    output:
        path("citations.txt"), emit: citations_file

    script:
    def citation_text = citation_keys.unique().sort().collect { key ->
        def entry = params.citations[key]
        "${entry.name}\n${entry.ref}"
    }.join('\n\n')

    """
    cat > citations.txt << 'ENDOFCITATIONS'
Programs used in this workflow run and their citations:

${citation_text}
ENDOFCITATIONS
    """

    stub:
    """
    touch citations.txt
    """
}
