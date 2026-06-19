/*
 * RESFINDER (read-based, KMA) — the QUANTITATIVE backbone of ARGive.
 *
 * Unlike the assembly-based callers, this maps trimmed reads directly against
 * the ResFinder DB with KMA, which yields a per-gene DEPTH (the fixture in
 * data/sample_kma_output.res). Depth ÷ SingleM genome-equivalents = the
 * copies-per-genome the frontend shows. It ALSO contributes to concordance.
 *
 * Two outputs:
 *   report -> ResFinder_results_tab.txt   (consumed by `hamronize resfinder`)
 *   res    -> concatenated KMA *.res       (consumed by build_record.py for depth)
 *   align  -> ${id}.kma_align.tar.gz       (KMA .aln consensus + .frag.gz read-to-gene
 *            fragment mapping — the per-read evidence behind every detection;
 *            published to the archive so a call can always be audited/re-derived)
 */
process RESFINDER {
    tag   "${meta.id}"
    label 'process_medium'
    container 'quay.io/biocontainers/resfinder:4.5.0--pyhdfd78af_0'
    publishDir "${params.outdir}/alignments", mode: params.publish_dir_mode, pattern: '*.kma_align.tar.gz'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), val('resfinder'), path("${meta.id}.resfinder.tab"), emit: report
    tuple val(meta), path("${meta.id}.kma.res"),                         emit: res
    tuple val(meta), path("${meta.id}.kma_align.tar.gz"),                emit: align
    path 'versions.yml',                                                 emit: versions

    script:
    def db_arg = params.resfinder_db ? "-db_res ${params.resfinder_db}" : ''
    def ifq    = meta.single_end ? "-ifq ${reads[0]}" : "-ifq ${reads[0]} ${reads[1]}"
    """
    set -euo pipefail
    # -k passes our kma binary; --kma_args forces full alignment output:
    #   -a  : print all template alignments    -matrix : per-position consensus matrix
    # (.aln and .frag.gz are produced by KMA; -matrix adds .mat.gz)
    run_resfinder.py ${ifq} -o rf_out -acq ${db_arg} \\
        --min_cov 0.6 --threshold 0.8 -k \$(command -v kma) \\
        --kma_args "-a -matrix" || \\
    run_resfinder.py ${ifq} -o rf_out -acq ${db_arg} \\
        --min_cov 0.6 --threshold 0.8 -k \$(command -v kma)

    # standardized tab summary for harmonization
    cp rf_out/ResFinder_results_tab.txt ${meta.id}.resfinder.tab

    # KMA .res files carry Depth; concatenate (keep a single header) for build_record.py
    first=1
    : > ${meta.id}.kma.res
    for f in \$(find rf_out -name '*.res'); do
        if [ \$first -eq 1 ]; then cat "\$f" >> ${meta.id}.kma.res; first=0;
        else tail -n +2 "\$f" >> ${meta.id}.kma.res; fi
    done

    # bundle the alignment evidence (.aln consensus, .frag.gz read mapping, .mat.gz matrix)
    align_files=\$(find rf_out \\( -name '*.aln' -o -name '*.frag.gz' -o -name '*.mat.gz' -o -name '*.res' \\) -printf '%P\\n' || true)
    if [ -n "\$align_files" ]; then
        tar -czf ${meta.id}.kma_align.tar.gz -C rf_out \$align_files
    else
        # never produce an empty/absent output; emit a documented placeholder
        echo "no KMA alignment files produced for ${meta.id}" > NO_ALIGNMENTS.txt
        tar -czf ${meta.id}.kma_align.tar.gz NO_ALIGNMENTS.txt
    fi

    cat <<-VERS > versions.yml
    "${task.process}":
        resfinder: "${params.versions.resfinder}"
        resfinder_db: "${params.versions.resfinder_db}"
    VERS
    """
}
