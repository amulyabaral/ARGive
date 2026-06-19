/*
 * PUBLISH_RELEASE — collect every sample's record + harmonized TSV into one
 * citable release bundle (combined TSV, manifest.json, CITATION.cff, SHA256SUMS),
 * publish it to the archive (outdir, which can be a Cloudflare R2 s3:// path), and
 * optionally deposit to Zenodo to mint the release DOI.
 *
 * Runs ONCE per pipeline run, after all records are emitted (it consumes the
 * collected channels). Zenodo deposit is gated by params.publish_zenodo and
 * needs ZENODO_TOKEN in the environment.
 */
process PUBLISH_RELEASE {
    label 'process_low'
    container 'quay.io/biocontainers/python:3.10'
    publishDir "${params.outdir}/release", mode: params.publish_dir_mode

    input:
    path records      // all *.record.json
    path harmonized   // all *.hamronized.tsv

    output:
    path "bundle/**",            emit: bundle
    path "zenodo.json",          optional: true, emit: zenodo
    path 'versions.yml',         emit: versions

    script:
    def zen_args = params.zenodo_sandbox ? '--sandbox' : ''
    def zen_pub  = params.zenodo_publish ? '--publish' : ''
    """
    set -euo pipefail
    make_manifest.py \\
        --records ${records} \\
        --hamronized ${harmonized} \\
        --release ${params.release} \\
        --out-dir bundle

    if [ "${params.publish_zenodo}" = "true" ]; then
        zenodo_upload.py --bundle-dir bundle --release ${params.release} \\
            ${zen_args} ${zen_pub} --out zenodo.json
    fi

    cat <<-VERS > versions.yml
    "${task.process}":
        make_manifest: "argive ${params.release}"
    VERS
    """
}
