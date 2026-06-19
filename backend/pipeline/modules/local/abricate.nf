/*
 * ABRICATE — fast assembly-based screen against the ResFinder DB. Cheap, robust
 * fourth opinion that strengthens the concordance signal. Output TSV is consumed
 * by `hamronize abricate`.
 */
process ABRICATE {
    tag   "${meta.id}"
    label 'process_low'
    container 'quay.io/biocontainers/abricate:1.0.1--ha8f3691_2'

    input:
    tuple val(meta), path(contigs)

    output:
    tuple val(meta), val('abricate'), path("${meta.id}.abricate.tsv"), emit: report
    path 'versions.yml',                                               emit: versions

    script:
    """
    set -euo pipefail
    gzip -dc ${contigs} > contigs.fna
    abricate --db resfinder --threads ${task.cpus} contigs.fna > ${meta.id}.abricate.tsv

    cat <<-VERS > versions.yml
    "${task.process}":
        abricate: \$(abricate --version 2>&1 | sed 's/^abricate //')
    VERS
    """
}
