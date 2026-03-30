// modules
include { PANORAMA_GET_FILE as PANORAMA_GET_SPECTRA_FILE } from "../modules/panorama"
include { PANORAMA_GET_FILE as PANORAMA_GET_SPECTRA_DIR_FILE } from "../modules/panorama"
include { PANORAMA_GET_RAW_FILE_LIST } from "../modules/panorama"
include { MSCONVERT } from "../modules/msconvert"
include { UNZIP_BRUKER_DATA } from "../modules/bruker"

PANORAMA_URL = 'https://panoramaweb.org'

workflow get_mzmls {
    take:
        aws_secret_id

    emit:
       mzml_ch
       versions
       citations

    main:

        spectra_ch = null
        needs_msconvert = false
        needs_unzip = false
        citations = Channel.empty()
        versions = Channel.empty()

        if(params.spectra_dir) {

            if(is_panorama_url(params.spectra_dir)) {
                // Panorama directory: list files, filter by glob, download each
                // Bruker .d directories cannot be downloaded from Panorama, only .d.zip files
                def glob_lower = params.spectra_dir_glob.toLowerCase()
                if(glob_lower.endsWith('.d') && !glob_lower.endsWith('.d.zip')) {
                    error "Bruker .d directories cannot be downloaded from PanoramaWeb. Use a glob pattern matching .d.zip files instead."
                }

                PANORAMA_GET_RAW_FILE_LIST(params.spectra_dir, params.spectra_dir_glob, aws_secret_id)
                download_urls_ch = PANORAMA_GET_RAW_FILE_LIST.out.download_file_list
                    .splitText()
                    .map { it.trim() }
                    .filter { it }

                PANORAMA_GET_SPECTRA_DIR_FILE(download_urls_ch, aws_secret_id)
                spectra_ch = PANORAMA_GET_SPECTRA_DIR_FILE.out.panorama_file

                citations = citations.mix(PANORAMA_GET_RAW_FILE_LIST.out.citation)
                    .mix(PANORAMA_GET_SPECTRA_DIR_FILE.out.citation)
                versions = versions.mix(PANORAMA_GET_RAW_FILE_LIST.out.version_info)
                    .mix(PANORAMA_GET_SPECTRA_DIR_FILE.out.version_info)

                needs_msconvert = glob_lower.endsWith('.raw')
                needs_unzip = glob_lower.endsWith('.d.zip')
            } else {
                // Local directory: glob for files and validate
                def matched_files = file("${params.spectra_dir}/${params.spectra_dir_glob}", type: 'any')
                if(matched_files instanceof Path) matched_files = [matched_files]
                if(!matched_files) matched_files = []

                if(matched_files.isEmpty()) {
                    error "No files matching '${params.spectra_dir_glob}' found in '${params.spectra_dir}'"
                }

                def exts = matched_files.collect { f ->
                    def name = f.name.toLowerCase()
                    if (name.endsWith('.d.zip')) return 'd.zip'
                    return f.extension.toLowerCase()
                }.unique()

                if(exts.size() != 1 || !(exts[0] in ['raw', 'mzml', 'd', 'd.zip'])) {
                    error "All files matching '${params.spectra_dir_glob}' in '${params.spectra_dir}' must be .raw, .mzML, .d, or .d.zip files of the same type. Found extensions: ${exts.join(', ')}"
                }

                needs_msconvert = exts[0] == 'raw'
                needs_unzip = exts[0] == 'd.zip'
                spectra_ch = Channel.fromList(matched_files)
            }

        } else {

            // spectra_file: single file
            if(is_panorama_url(params.spectra_file)) {
                def spectra_lower = params.spectra_file.toLowerCase()
                if(spectra_lower.endsWith('.d') && !spectra_lower.endsWith('.d.zip')) {
                    error "Bruker .d directories cannot be downloaded from PanoramaWeb. Use .d.zip files instead."
                }
                PANORAMA_GET_SPECTRA_FILE(params.spectra_file, aws_secret_id)
                spectra_ch = PANORAMA_GET_SPECTRA_FILE.out.panorama_file
                citations = citations.mix(PANORAMA_GET_SPECTRA_FILE.out.citation)
                versions = versions.mix(PANORAMA_GET_SPECTRA_FILE.out.version_info)
            } else {
                spectra_ch = Channel.of(file(params.spectra_file, checkIfExists: true))
            }

            def spectra_name = params.spectra_file.toLowerCase()
            needs_msconvert = spectra_name.endsWith('.raw')
            needs_unzip = spectra_name.endsWith('.d.zip')
        }

        if(needs_msconvert) {
            MSCONVERT(
                spectra_ch,
                params.msconvert.do_demultiplex,
                params.msconvert.do_simasspectra
            )
            mzml_ch = MSCONVERT.out.mzml_file
            citations = citations.mix(Channel.of('msconvert'))
            versions = versions.mix(MSCONVERT.out.version_info)
        } else if(needs_unzip) {
            mzml_ch = UNZIP_BRUKER_DATA(spectra_ch)
        } else {
            mzml_ch = spectra_ch
        }
}

// returns true if the url is a PanoramaWeb URL (public or private)
def is_panorama_url(url) {
    return url.startsWith(PANORAMA_URL)
}

// returns true if the url requires authentication (non-public Panorama folders)
def panorama_auth_required_for_url(url) {
    return url.startsWith(PANORAMA_URL) && !url.contains("/_webdav/Panorama%20Public/")
}
