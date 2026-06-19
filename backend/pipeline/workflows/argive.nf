/*
 * ARGIVE subworkflow — the channel wiring.
 *
 *   reads ─┬─ FASTP ──┬─ MEGAHIT ─┬─ AMRFINDERPLUS ┐
 *          │          │           ├─ RGI           ├─ HAMRONIZE ─┐
 *          │          │           └─ ABRICATE      ┘             │
 *          │          ├─ RESFINDER (KMA, reads) ───────┐         ├─ EMIT_RECORD ─> record.json
 *          │          └─ SINGLEM (denominator) ────────┴─────────┘            + hamronized.tsv
 *   meta ──── ENA_META ──────────────────────────────────────────┘
 */

include { ENA_FETCH     } from '../modules/local/ena_fetch.nf'
include { ENA_META      } from '../modules/local/ena_meta.nf'
include { FASTP         } from '../modules/local/fastp.nf'
include { MEGAHIT       } from '../modules/local/megahit.nf'
include { AMRFINDERPLUS } from '../modules/local/amrfinderplus.nf'
include { RGI           } from '../modules/local/rgi.nf'
include { ABRICATE      } from '../modules/local/abricate.nf'
include { RESFINDER     } from '../modules/local/resfinder.nf'
include { HAMRONIZE     } from '../modules/local/hamronize.nf'
include { SINGLEM       } from '../modules/local/singlem.nf'
include { EMIT_RECORD   } from '../modules/local/emit_record.nf'

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

    // --- read-based quantification + denominator (no assembly needed) ---
    RESFINDER( ch_trimmed )
    SINGLEM( ch_trimmed )
    ch_versions = ch_versions.mix(RESFINDER.out.versions, SINGLEM.out.versions)

    // --- assembly-based callers (skippable) ---
    ch_asm_reports = Channel.empty()
    if (!params.skip_assembly) {
        MEGAHIT( ch_trimmed )
        AMRFINDERPLUS( MEGAHIT.out.contigs )
        RGI( MEGAHIT.out.contigs )
        ABRICATE( MEGAHIT.out.contigs )
        ch_versions = ch_versions.mix(MEGAHIT.out.versions, AMRFINDERPLUS.out.versions,
                                      RGI.out.versions, ABRICATE.out.versions)
        ch_asm_reports = AMRFINDERPLUS.out.report
            .mix(RGI.out.report, ABRICATE.out.report)
    }

    // --- harmonize all reports per sample ---
    ch_reports = ch_asm_reports
        .mix(RESFINDER.out.report)                       // tuple(meta, tag, report)
        .map { meta, tag, rep -> tuple(meta.id, meta, tag, rep) }
        .groupTuple()
        .map { id, metas, tags, reps -> tuple(metas[0], tags, reps) }
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
    record   = EMIT_RECORD.out.record
    versions = ch_versions
}
