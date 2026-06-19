/*
 * MEGAHIT — metagenome assembly. Contigs feed the assembly-based callers
 * (AMRFinderPlus, RGI, abricate) so their hits can be harmonized and, later,
 * linked to mobile genetic elements. Read-based quantification (ResFinder/KMA)
 * runs in parallel on the trimmed reads and does NOT depend on this.
 *
 * Skipped when params.skip_assembly is set (reads-only quantification mode).
 */
process MEGAHIT {
    tag   "${meta.id}"
    label 'process_high'
    container 'quay.io/biocontainers/megahit:1.2.9--h5b5514e_3'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("${meta.id}.contigs.fa.gz"), emit: contigs
    path  'versions.yml',                              emit: versions

    script:
    def input = meta.single_end ? "-r ${reads[0]}" : "-1 ${reads[0]} -2 ${reads[1]}"
    """
    set -euo pipefail
    megahit ${input} -t ${task.cpus} -m ${task.memory.toBytes()} \\
        --min-contig-len 500 -o megahit_out --out-prefix ${meta.id}

    gzip -c megahit_out/${meta.id}.contigs.fa > ${meta.id}.contigs.fa.gz

    cat <<-VERS > versions.yml
    "${task.process}":
        megahit: \$(megahit --version 2>&1 | sed 's/^MEGAHIT v//')
    VERS
    """
}
