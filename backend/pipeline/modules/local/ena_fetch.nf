/*
 * ENA_FETCH — resolve a run accession to FASTQ via the ENA filereport API and
 * download it. Skipped upstream when the samplesheet already supplies local FASTQ.
 *
 * Robustness: the ENA portal is occasionally flaky, so this is retried (see
 * conf/base.config withName:ENA_FETCH) and verifies MD5s when ENA reports them.
 */
process ENA_FETCH {
    tag   "${meta.id}"
    label 'process_low'
    container 'quay.io/biocontainers/gnu-wget:1.18--h36e9172_9'

    input:
    val meta

    output:
    tuple val(meta), path("${meta.id}*.fastq.gz"), emit: reads
    path  'versions.yml',                          emit: versions

    script:
    def acc = meta.accession
    """
    set -euo pipefail
    url="https://www.ebi.ac.uk/ena/portal/api/filereport?accession=${acc}&result=read_run&fields=fastq_ftp,fastq_md5&format=tsv"
    wget -q -O report.tsv "\$url"
    ftps=\$(awk 'NR==2{print \$1}' report.tsv)
    md5s=\$(awk 'NR==2{print \$2}' report.tsv)
    if [ -z "\$ftps" ]; then echo "ERROR: ENA returned no FASTQ for ${acc}" >&2; exit 1; fi
    i=1
    IFS=';' read -ra paths <<< "\$ftps"
    IFS=';' read -ra sums  <<< "\$md5s"
    for p in "\${paths[@]}"; do
        out="${meta.id}_\${i}.fastq.gz"
        wget -q -O "\$out" "https://\$p"
        want="\${sums[\$((i-1))]:-}"
        if [ -n "\$want" ]; then
            got=\$(md5sum "\$out" | awk '{print \$1}')
            [ "\$got" = "\$want" ] || { echo "ERROR: md5 mismatch \$out" >&2; exit 1; }
        fi
        i=\$((i+1))
    done
    cat <<-VERS > versions.yml
    "${task.process}":
        ena-source: "ebi.ac.uk/ena filereport API"
        wget: \$(wget --version | head -1 | sed 's/^GNU Wget //; s/ .*//')
    VERS
    """
}
