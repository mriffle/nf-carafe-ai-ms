def exec_java_command(mem) {
    def xmx = "-Xmx${mem.toGiga()-1}G"
    return "java -Djava.aws.headless=true ${xmx} -jar /opt/carafe/carafe-0.0.1/carafe-0.0.1.jar"
}

process CARAFE {
    publishDir "${params.result_dir}/carafe", failOnError: true, mode: 'copy'
    label 'process_high_constant'
    container params.images.carafe
    
    input:
        path fasta_file
        path peptide_results_file
        val carafe_params
    
    output:
        path("*.stderr"), emit: stderr
        path("*.stdout"), emit: stdout
        path("carafe_spectral_library.tsv"), emit: speclib_tsv
        path("carafe_version.txt"), emit: version

    script:
        """
        ${exec_java_command(task.memory)} \\
        -db "${fasta_file}" \\
        -i "${peptide_results_file}" \\
        -device cpu \\
        ${carafe_params} \\
        > >(tee "carafe.stdout") 2> >(tee "carafe.stderr" >&2)

        mv -v SkylineAI_spectral_library.tsv carafe_spectral_library.tsv

        grep "Version:" carafe.stdout | head -n 1 | awk '{print \$2}' | xargs printf "carafe_version=%s\n" > carafe_version.txt
        """

    stub:
        """
        touch carafe_spectral_library.tsv carafe_version.txt
        touch stub.stderr stub.stdout
        """
}

