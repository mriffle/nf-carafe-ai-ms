process UNZIP_BRUKER_DATA {
    label 'process_low'
    container params.images.ubuntu

    input:
        path zip_file

    output:
        path("${zip_file.baseName}"), emit: bruker_raw_dir

    script:
    """
    unzip "${zip_file}"
    """

    stub:
    """
    mkdir "${zip_file.baseName}"
    """
}
