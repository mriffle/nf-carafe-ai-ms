def exec_java_command(mem) {
    def xmx = "-Xmx${mem.toGiga()-1}G"
    return "java -Djava.aws.headless=true ${xmx} -jar /usr/local/bin/encyclopedia.jar"
}


process ENCYCLOPEDIA_TSV_TO_DLIB {
    publishDir "${params.result_dir}/carafe", failOnError: true, mode: 'copy'
    label 'process_medium'
    label 'process_high_memory'
    container params.images.encyclopedia

    input:
        path fasta
        path tsv_file

    output:
        path("*.stderr"), emit: stderr
        path("*.stdout"), emit: stdout
        path("carafe_spectral_library.dlib"), emit: dlib
        path("encyclopedia_version.json"), emit: version_info
        val 'encyclopedia', emit: citation

    script:
    def container_image = task.container ?: 'none'
    """
    ENCY_VERSION=\$(${exec_java_command(task.memory)} --version 2>&1 | egrep -o '[0-9]+\\.[0-9]+(\\.[0-9]+)*(-[0-9]+)?' | head -1 || true)
    ENCY_VERSION=\${ENCY_VERSION:-unknown}

    ${exec_java_command(task.memory)} \\
        -numberOfThreadsUsed ${task.cpus} \\
        -convert \\
        -prositCSVToLibrary \\
        -o "carafe_spectral_library.dlib" \\
        -i "${tsv_file}" \\
        -f "${fasta}" \\
        > >(tee "encyclopedia-convert-tsv.stdout") 2> >(tee "encyclopedia-convert-tsv.stderr" >&2)

    cat <<VEOF > encyclopedia_version.json
{"program": "EncyclopeDIA", "version": "\$ENCY_VERSION", "container": "${container_image}"}
VEOF
    """

    stub:
    """
    touch stub.stderr stub.stdout
    touch "carafe_spectral_library.dlib"
    echo '{"program": "EncyclopeDIA", "version": "stub", "container": "stub"}' > encyclopedia_version.json
    """
}
