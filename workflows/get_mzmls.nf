// modules
include { PANORAMA_GET_FILE as PANORAMA_GET_SPECTRA_FILE } from "../modules/panorama"
include { PANORAMA_GET_FILE as PANORAMA_GET_SPECTRA_DIR_FILE } from "../modules/panorama"
include { PANORAMA_GET_RAW_FILE_LIST } from "../modules/panorama"
include { MSCONVERT } from "../modules/msconvert"

PANORAMA_URL = 'https://panoramaweb.org'

workflow get_mzmls {
    take:
        aws_secret_id

    emit:
       mzml_ch

    main:

        spectra_ch = null
        needs_msconvert = false

        if(params.spectra_dir) {

            if(is_panorama_url(params.spectra_dir)) {
                // Panorama directory: list files, filter by glob, download each
                PANORAMA_GET_RAW_FILE_LIST(params.spectra_dir, params.spectra_dir_glob, aws_secret_id)
                download_urls_ch = PANORAMA_GET_RAW_FILE_LIST.out.download_file_list
                    .splitText()
                    .map { it.trim() }
                    .filter { it }

                PANORAMA_GET_SPECTRA_DIR_FILE(download_urls_ch, aws_secret_id)
                spectra_ch = PANORAMA_GET_SPECTRA_DIR_FILE.out.panorama_file

                needs_msconvert = !params.spectra_dir_glob.toLowerCase().endsWith('mzml')
            } else {
                // Local directory: glob for files and validate
                def matched_files = file("${params.spectra_dir}/${params.spectra_dir_glob}")
                if(matched_files instanceof Path) matched_files = [matched_files]
                if(!matched_files) matched_files = []

                if(matched_files.isEmpty()) {
                    error "No files matching '${params.spectra_dir_glob}' found in '${params.spectra_dir}'"
                }

                def exts = matched_files.collect { it.extension.toLowerCase() }.unique()
                if(exts.size() != 1 || !(exts[0] in ['raw', 'mzml'])) {
                    error "All files matching '${params.spectra_dir_glob}' in '${params.spectra_dir}' must be .raw or .mzML files of the same type. Found extensions: ${exts.join(', ')}"
                }

                needs_msconvert = exts[0] == 'raw'
                spectra_ch = Channel.fromList(matched_files)
            }

        } else {

            // spectra_file: single file
            if(is_panorama_url(params.spectra_file)) {
                PANORAMA_GET_SPECTRA_FILE(params.spectra_file, aws_secret_id)
                spectra_ch = PANORAMA_GET_SPECTRA_FILE.out.panorama_file
            } else {
                spectra_ch = Channel.of(file(params.spectra_file, checkIfExists: true))
            }

            needs_msconvert = !params.spectra_file.toLowerCase().endsWith('mzml')
        }

        if(needs_msconvert) {
            mzml_ch = MSCONVERT(
                spectra_ch,
                params.msconvert.do_demultiplex,
                params.msconvert.do_simasspectra
            )
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
