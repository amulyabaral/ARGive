/*
 * AMRFINDERPLUS — assembly-based AMR calling against the NCBI RefGene/AMR DB.
 * Contributes its hits to the harmonized concordance set. Nucleotide mode on
 * MEGAHIT contigs. Output TSV is consumed by `hamronize amrfinderplus`.
 *
 * params.amrfinder_db: path to a specific DB version (recommended, frozen per
 * release). If null, the DB bundled in the container image is used.
 */
process AMRFINDERPLUS {
    tag   "${meta.id}"
    label 'process_medium'
    container 'quay.io/biocontainers/ncbi-amrfinderplus:4.0.3--hf69ffd2_0'

    input:
    tuple val(meta), path(contigs)

    output:
    tuple val(meta), val('amrfinderplus'), path("${meta.id}.amrfinderplus.tsv"), emit: report
    path 'versions.yml',                                                         emit: versions

    script:
    def db_arg = params.amrfinder_db ? "--database ${params.amrfinder_db}" : ''
    """
    set -euo pipefail
    gzip -dc ${contigs} > contigs.fna
    amrfinder -n contigs.fna --plus ${db_arg} \\
        --threads ${task.cpus} --name ${meta.id} \\
        -o ${meta.id}.amrfinderplus.tsv

    cat <<-VERS > versions.yml
    "${task.process}":
        amrfinderplus: \$(amrfinder --version)
        amrfinder_db: "${params.versions.amrfinder_db}"
    VERS
    """
}
