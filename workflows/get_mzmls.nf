// modules
include { PANORAMA_GET_FILE as PANORAMA_GET_RAW_FILE } from "../modules/panorama"
include { MSCONVERT } from "../modules/msconvert"

PANORAMA_URL = 'https://panoramaweb.org'

workflow get_mzmls {
    take:
        spectra_file
        aws_secret_id

    emit:
       mzml_ch

    main:

        raw_ch = null
        if(spectra_file.startsWith(PANORAMA_URL)) {
            PANORAMA_GET_RAW_FILE(spectra_file, aws_secret_id)
            raw_ch = PANORAMA_GET_RAW_FILE.out.panorama_file
        } else {
            raw_ch = file(spectra_file, checkIfExists: true)
        }

        if(!(spectra_file.toLowerCase().endsWith("mzml"))) {
            mzml_ch = MSCONVERT(
                PANORAMA_GET_RAW_FILE.out.panorama_file,
                params.msconvert.do_demultiplex,
                params.msconvert.do_simasspectra
            )
        } else {
            mzml_ch = raw_ch        // use mzMLs directly
        }

}
