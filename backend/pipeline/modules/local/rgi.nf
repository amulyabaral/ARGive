/*
 * RGI — Resistance Gene Identifier, calling against CARD. Assembly-based
 * (contig mode). Its great value to ARGive is the ARO accession it assigns to
 * every hit — the canonical ontology ID we carry through to the record.
 * Output `.txt` is consumed by `hamronize rgi`.
 *
 * params.card_json: a specific CARD card.json to `rgi load` (frozen per release).
 * If null, the DB bundled/loaded in the container image is used.
 */
process RGI {
    tag   "${meta.id}"
    label 'process_medium'
    container 'quay.io/biocontainers/rgi:6.0.3--pyha8f3691_1'

    input:
    tuple val(meta), path(contigs)

    output:
    tuple val(meta), val('rgi'), path("${meta.id}.rgi.txt"), emit: report
    path 'versions.yml',                                     emit: versions

    script:
    def load = params.card_json ? "rgi load --card_json ${params.card_json} --local" : ''
    def localflag = params.card_json ? '--local' : ''
    """
    set -euo pipefail
    gzip -dc ${contigs} > contigs.fna
    ${load}
    rgi main -i contigs.fna -o ${meta.id}.rgi \\
        -t contig -a BLAST -n ${task.cpus} ${localflag} --clean
    # rgi writes ${meta.id}.rgi.txt and .json; keep the txt for hAMRonize

    cat <<-VERS > versions.yml
    "${task.process}":
        rgi: \$(rgi main --version 2>&1 | tail -1)
        card: "${params.versions.card}"
    VERS
    """
}
