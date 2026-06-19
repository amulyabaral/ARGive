/*
 * SINGLEM — the denominator. `singlem microbial_fraction` (a.k.a. read_fraction)
 * estimates the number of genome equivalents in a metagenome from single-copy
 * marker genes. This is what makes ARGive numbers COMPARABLE across samples of
 * wildly different sequencing depth: copies-per-genome = depth / genome_equiv.
 *
 * Runs on trimmed reads, independent of assembly.
 *
 * params.singlem_metapackage: frozen metapackage path (recommended). If null,
 * the package bundled in the container is used.
 */
process SINGLEM {
    tag   "${meta.id}"
    label 'process_medium'
    container 'quay.io/biocontainers/singlem:1.0.0--pyhdfd78af_0'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("${meta.id}.singlem.tsv"), emit: fraction
    path 'versions.yml',                             emit: versions

    script:
    def pkg   = params.singlem_metapackage ? "--metapackage ${params.singlem_metapackage}" : ''
    def input = meta.single_end ? "-1 ${reads[0]}" : "-1 ${reads[0]} -2 ${reads[1]}"
    """
    set -euo pipefail
    export SINGLEM_METAPACKAGE_PATH=${params.singlem_metapackage ?: ''}
    singlem pipe ${input} ${pkg} --threads ${task.cpus} -p ${meta.id}.profile.tsv
    singlem microbial_fraction -p ${meta.id}.profile.tsv ${input} ${pkg} \\
        --output-tsv ${meta.id}.singlem.tsv

    cat <<-VERS > versions.yml
    "${task.process}":
        singlem: "${params.versions.singlem}"
    VERS
    """
}
