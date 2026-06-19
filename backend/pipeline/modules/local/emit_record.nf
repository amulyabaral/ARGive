/*
 * EMIT_RECORD — terminal step. Runs build_record.py (shipped on PATH from
 * pipeline/bin/) to merge the harmonized hits, KMA depth, SingleM denominator
 * and ENA metadata into ONE validated record.json, stamped with frozen tool
 * versions and the release tag. Publishes record.json + the canonical
 * harmonized TSV to the outdir; later stages sync these to R2/Zenodo.
 */
process EMIT_RECORD {
    tag   "${meta.id}"
    label 'process_low'
    container 'quay.io/biocontainers/python:3.10'
    publishDir "${params.outdir}/records", mode: params.publish_dir_mode

    input:
    tuple val(meta), path(hamronized), path(kma_res), path(singlem), path(meta_json)

    output:
    tuple val(meta), path("${meta.id}.record.json"), emit: record
    path "${meta.id}.hamronized.tsv",                emit: harmonized   // canonical archive artifact
    path 'versions.yml',                             emit: versions

    script:
    def versions_json = groovy.json.JsonOutput.toJson(params.versions)
    def rev = workflow.revision ?: workflow.commitId ?: 'dev'
    """
    set -euo pipefail
    echo '${versions_json}' > versions.json

    build_record.py \\
        --hamronized ${hamronized} \\
        --kma-res ${kma_res} \\
        --singlem ${singlem} \\
        --meta ${meta_json} \\
        --drug-map ${projectDir}/assets/drug_class_map.tsv \\
        --release ${params.release} \\
        --versions versions.json \\
        --pipeline-revision ${rev} \\
        --out ${meta.id}.record.json

    # keep the harmonized TSV next to the record as the researcher-facing artifact
    cp ${hamronized} ${meta.id}.hamronized.tsv

    cat <<-VERS > versions.yml
    "${task.process}":
        build_record: "argive ${params.release}"
    VERS
    """
}
