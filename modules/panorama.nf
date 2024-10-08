// Modules/process for interacting with PanoramaWeb

def exec_java_command(mem) {
    def xmx = "-Xmx${mem.toGiga()-1}G"
    return "java -Djava.aws.headless=true ${xmx} -jar /usr/local/bin/PanoramaClient.jar"
}

String escapeRegex(String str) {
    return str.replaceAll(/([.\^$+?{}\[\]\\|()])/) { match, group -> '\\' + group }
}

String setupPanoramaAPIKeySecret(secret_id, executor_type) {

    if(executor_type != 'awsbatch') {
        return ''
    } else {
        SECRET_NAME = 'PANORAMA_API_KEY'
        REGION = params.aws.region
        
        return """
            echo "Getting Panorama API key from AWS secrets manager..."
            SECRET_JSON=\$(${params.aws.batch.cliPath} secretsmanager get-secret-value --secret-id ${secret_id} --region ${REGION} --query 'SecretString' --output text)
            PANORAMA_API_KEY=\$(echo \$SECRET_JSON | sed -n 's/.*"${SECRET_NAME}":"\\([^"]*\\)".*/\\1/p')
        """
    }
}

/**
 * Get the Panorama project webdav URL for the given Panorama webdav directory
 *
 * @param webdavDirectory The full URL to the WebDav directory on the Panorama server.
 * @return The modified URL pointing to the project's main view page.
 * @throws IllegalArgumentException if the input URL does not contain the required segments.
 */
String getPanoramaProjectURLForWebDavDirectory(String webdavDirectory) {
    def uri = new URI(webdavDirectory)

    def pathSegments = uri.path.split('/')
    pathSegments = pathSegments.findAll { it && it != '_webdav' }

    int cutIndex = pathSegments.indexOf('@files')
    if (cutIndex != -1) {
        pathSegments = pathSegments.take(cutIndex)
    }

    def basePath = pathSegments.collect { URLEncoder.encode(it, "UTF-8") }.join('/')
    def encodedProjectView = URLEncoder.encode('project-begin.view', 'UTF-8')
    def newUrl = "${uri.scheme}://${uri.host}/${basePath}/${encodedProjectView}"

    return newUrl
}

process PANORAMA_GET_RAW_FILE_LIST {
    cache false
    label 'process_low_constant'
    label 'error_retry'
    container params.images.panorama_client
    publishDir "${params.result_dir}/panorama", failOnError: true, mode: 'copy'
    secret 'PANORAMA_API_KEY'

    input:
        each web_dav_url
        val file_glob
        val aws_secret_id

    output:
        tuple val(web_dav_url), path("*.download"), emit: raw_file_placeholders
        path("*.stdout"), emit: stdout
        path("*.stderr"), emit: stderr

    script:
    // convert glob to regex that we can use to grep lines from a file of filenames
    String regex = '^' + escapeRegex(file_glob).replaceAll("\\*", ".*") + '$'

    """
    ${setupPanoramaAPIKeySecret(aws_secret_id, task.executor)}

    echo "Running file list from Panorama..."
        ${exec_java_command(task.memory)} \
        -l \
        -e raw \
        -w "${web_dav_url}" \
        -k \$PANORAMA_API_KEY \
        -o panorama_files.txt \
        > >(tee "panorama-get-files.stdout") 2> >(tee "panorama-get-files.stderr" >&2) && \
        grep -P '${regex}' panorama_files.txt | xargs -I % sh -c 'touch %.download'

    echo "Done!" # Needed for proper exit
    """
}

process PANORAMA_GET_FILE {
    label 'process_low_constant'
    label 'error_retry'
    container params.images.panorama_client
    publishDir "${params.result_dir}/panorama", failOnError: true, mode: 'copy', pattern: "*.stdout"
    publishDir "${params.result_dir}/panorama", failOnError: true, mode: 'copy', pattern: "*.stderr"
    secret 'PANORAMA_API_KEY'

    input:
        val web_dav_dir_url
        val aws_secret_id

    output:
        path("${file(web_dav_dir_url).name}"), emit: panorama_file
        path("*.stdout"), emit: stdout
        path("*.stderr"), emit: stderr

    script:
        file_name = file(web_dav_dir_url).name
        """
        ${setupPanoramaAPIKeySecret(aws_secret_id, task.executor)}

        echo "Downloading ${file_name} from Panorama..."
            ${exec_java_command(task.memory)} \
            -d \
            -w "${web_dav_dir_url}" \
            -k \$PANORAMA_API_KEY \
            > >(tee "panorama-get-${file_name}.stdout") 2> >(tee "panorama-get-${file_name}.stderr" >&2)
        echo "Done!" # Needed for proper exit
        """

    stub:
    """
    touch "${file(web_dav_dir_url).name}"
    touch stub.stderr stub.stdout
    """
}

process PANORAMA_GET_RAW_FILE {
    label 'process_low_constant'
    label 'error_retry'
    maxForks 4
    container params.images.panorama_client
    storeDir "${params.panorama_cache_directory}"
    secret 'PANORAMA_API_KEY'

    input:
        tuple val(web_dav_dir_url), path(download_file_placeholder)
        val aws_secret_id

    output:
        path("${download_file_placeholder.baseName}"), emit: panorama_file
        path("*.stdout"), emit: stdout
        path("*.stderr"), emit: stderr

    script:
        raw_file_name = download_file_placeholder.baseName

        """
        ${setupPanoramaAPIKeySecret(aws_secret_id, task.executor)}

        echo "Downloading ${raw_file_name} from Panorama..."
            ${exec_java_command(task.memory)} \
            -d \
            -w "${web_dav_dir_url}${raw_file_name}" \
            -k \$PANORAMA_API_KEY \
            > >(tee "panorama-get-${raw_file_name}.stdout") 2> >(tee "panorama-get-${raw_file_name}.stderr" >&2)
        echo "Done!" # Needed for proper exit
        """

    stub:
    """
    touch "${download_file_placeholder.baseName}"
    touch stub.stderr stub.stdout
    """
}
