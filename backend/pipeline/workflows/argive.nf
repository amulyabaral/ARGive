/*
 * ARGIVE subworkflow — the channel wiring.
 *
 * CURRENT MVP: ResFinder/KMA only (read-based).
 *
 *   meta ── ENA_META ──────────────────────────────────────────────┐
 *   reads ─ FASTP ──┬─ RESFINDER (KMA, reads) ─┬─ HAMRONIZE ─┐      │
 *                   │                          │  (resfinder) │      ├─ EMIT_RECORD ─> record.json
 *                   └─ SINGLEM (denominator) ──┴──────────────┴──────┘            + hamronized.tsv
 *
 * The assembly-based concordance callers (MEGAHIT + AMRFINDERPLUS + RGI +
 * ABRICATE) are intentionally NOT wired right now — their modules remain in
 * modules/local/ and can be re-enabled by restoring the block marked
 * "CONCORDANCE (disabled)" below. With one tool, every gene's concordance == 1.
 */

include { ENA_FETCH   } from '../modules/local/ena_fetch.nf'
include { ENA_META    } from '../modules/local/ena_meta.nf'
include { FASTP       } from '../modules/local/fastp.nf'
include { RESFINDER   } from '../modules/local/resfinder.nf'
include { HAMRONIZE   } from '../modules/local/hamronize.nf'
include { SINGLEM     } from '../modules/local/singlem.nf'
include { EMIT_RECORD } from '../modules/local/emit_record.nf'

workflow ARGIVE {
    take:
    ch_samples   // tuple(meta, has_local, fastq_1, fastq_2)

    main:
    ch_versions = Channel.empty()

    // --- metadata for every sample (independent of reads source) ---
    ENA_META( ch_samples.map { meta, l, f1, f2 -> meta } )
    ch_versions = ch_versions.mix(ENA_META.out.versions)

    // --- reads: local vs fetched ---
    ch_branch = ch_samples.branch { meta, local, f1, f2 ->
        local: local
        fetch: !local
    }
    ch_local = ch_branch.local.map { meta, local, f1, f2 ->
        def files = f2 ? [file(f1), file(f2)] : [file(f1)]
        tuple(meta, files)
    }
    ENA_FETCH( ch_branch.fetch.map { meta, local, f1, f2 -> meta } )
    ch_versions = ch_versions.mix(ENA_FETCH.out.versions)

    ch_reads = ch_local.mix(ENA_FETCH.out.reads)

    // --- QC: fastp for short reads; long reads pass through untrimmed (TODO: nanofilt) ---
    ch_rb = ch_reads.branch { meta, r ->
        long_read:  (meta.platform ?: '').toUpperCase().contains('NANOPORE')
        short_read: true
    }
    FASTP( ch_rb.short_read )
    ch_versions = ch_versions.mix(FASTP.out.versions)
    ch_trimmed = FASTP.out.reads.mix(ch_rb.long_read)

    // --- read-based detection (depth) + denominator ---
    RESFINDER( ch_trimmed )
    SINGLEM( ch_trimmed )
    ch_versions = ch_versions.mix(RESFINDER.out.versions, SINGLEM.out.versions)

    // ===== CONCORDANCE (disabled) ===========================================
    // To re-enable multi-tool concordance, include MEGAHIT/AMRFINDERPLUS/RGI/
    // ABRICATE again, run them on MEGAHIT contigs, and mix their *.report into
    // ch_reports below alongside RESFINDER.out.report.
    // ========================================================================

    // --- harmonize (ResFinder only -> standardized terminology + canonical TSV) ---
    ch_reports = RESFINDER.out.report                 // tuple(meta, 'resfinder', report)
        .map { meta, tag, rep -> tuple(meta, [tag], [rep]) }
    HAMRONIZE( ch_reports )
    ch_versions = ch_versions.mix(HAMRONIZE.out.versions)

    // --- join everything by sample and emit the record ---
    ch_emit = HAMRONIZE.out.harmonized.map { m, f -> [m.id, m, f] }
        .join( RESFINDER.out.res.map     { m, f -> [m.id, f] } )
        .join( SINGLEM.out.fraction.map  { m, f -> [m.id, f] } )
        .join( ENA_META.out.meta_json.map{ m, f -> [m.id, f] } )
        .map { id, m, h, res, sm, mj -> tuple(m, h, res, sm, mj) }
    EMIT_RECORD( ch_emit )
    ch_versions = ch_versions.mix(EMIT_RECORD.out.versions)

    emit:
    record     = EMIT_RECORD.out.record
    harmonized = EMIT_RECORD.out.harmonized
    alignments = RESFINDER.out.align        // KMA alignment evidence per sample
    versions   = ch_versions
}
