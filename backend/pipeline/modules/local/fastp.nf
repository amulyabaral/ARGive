/*
 * FASTP — adapter/quality trimming + QC for short reads. Emits cleaned reads,
 * a JSON report (parsed downstream for post-QC base count -> record.bp), and
 * captures the version. Handles single- and paired-end via meta.single_end.
 *
 * Long reads (meta.platform == OXFORD_NANOPORE) bypass fastp upstream; this
 * process is for Illumina-style short reads only.
 */
process FASTP {
    tag   "${meta.id}"
    label 'process_medium'
    container 'quay.io/biocontainers/fastp:0.24.0--heae3180_1'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("${meta.id}.trim*.fastq.gz"), emit: reads
    tuple val(meta), path("${meta.id}.fastp.json"),     emit: json
    path  'versions.yml',                               emit: versions

    script:
    def sub = params.max_reads ? "--reads_to_process ${params.max_reads}" : ''
    if (meta.single_end)
        """
        set -euo pipefail
        fastp -i ${reads[0]} -o ${meta.id}.trim.fastq.gz \\
            --thread ${task.cpus} ${sub} \\
            --json ${meta.id}.fastp.json --html ${meta.id}.fastp.html \\
            --qualified_quality_phred 20 --length_required 50 --detect_adapter_for_pe

        cat <<-VERS > versions.yml
        "${task.process}":
            fastp: \$(fastp --version 2>&1 | sed 's/^fastp //')
        VERS
        """
    else
        """
        set -euo pipefail
        fastp -i ${reads[0]} -I ${reads[1]} \\
            -o ${meta.id}.trim_1.fastq.gz -O ${meta.id}.trim_2.fastq.gz \\
            --thread ${task.cpus} ${sub} \\
            --json ${meta.id}.fastp.json --html ${meta.id}.fastp.html \\
            --qualified_quality_phred 20 --length_required 50 --detect_adapter_for_pe

        cat <<-VERS > versions.yml
        "${task.process}":
            fastp: \$(fastp --version 2>&1 | sed 's/^fastp //')
        VERS
        """
}
