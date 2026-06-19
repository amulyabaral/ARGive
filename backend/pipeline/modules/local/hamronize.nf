/*
 * HAMRONIZE — the heart of ARGive's "one ontology" pillar.
 *
 * Takes every tool's native report for a sample, normalizes each into the
 * hAMRonization spec with `hamronize <tool>`, then `hamronize summarize`s them
 * into ONE harmonized TSV. Because every row records its analysis_software_name,
 * the downstream build_record.py can compute per-gene concordance (how many
 * tools agreed) — the trust signal nothing else in the field surfaces at scale.
 *
 * The harmonized TSV is also the canonical researcher-facing archive artifact
 * (published per-release to Cloudflare R2 + Zenodo).
 *
 * Inputs are matched lists: tools[i] is the tool that produced reports[i].
 */
process HAMRONIZE {
    tag   "${meta.id}"
    label 'process_low'
    container 'quay.io/biocontainers/hamronization:1.1.4--pyhdfd78af_0'

    input:
    tuple val(meta), val(tools), path(reports)

    output:
    tuple val(meta), path("${meta.id}.hamronized.tsv"), emit: harmonized
    path 'versions.yml',                                emit: versions

    script:
    // version lookup per tool for hAMRonize provenance flags
    def swver = [amrfinderplus: params.versions.amrfinderplus, rgi: params.versions.rgi,
                 abricate: params.versions.abricate, resfinder: params.versions.resfinder]
    def dbver = [amrfinderplus: params.versions.amrfinder_db, rgi: params.versions.card,
                 abricate: params.versions.resfinder_db, resfinder: params.versions.resfinder_db]
    def calls = [tools, reports].transpose().collect { t, r ->
        "hamronize ${t} --input_file_name ${meta.id} " +
        "--analysis_software_version '${swver[t]}' " +
        "--reference_database_version '${dbver[t]}' " +
        "--format tsv ${r} > h_${t}.tsv"
    }.join('\n    ')
    """
    set -euo pipefail
    ${calls}
    hamronize summarize -o ${meta.id}.hamronized.tsv -t tsv h_*.tsv

    cat <<-VERS > versions.yml
    "${task.process}":
        hamronize: \$(hamronize --version 2>&1 | sed 's/.* //')
    VERS
    """
}
