#!/usr/bin/env nextflow
/*
 * ===========================================================================
 *  ARGive — reprocessing pipeline
 *  Harmonized, normalized, concordance-scored resistome from public metagenomes
 * ===========================================================================
 *  Run examples:
 *    nextflow run main.nf -profile test,apptainer
 *    nextflow run main.nf -profile slurm,apptainer  --input samplesheet.csv --outdir results -resume
 *    nextflow run main.nf -profile awsbatch          --input samplesheet.csv --outdir s3://argive/v2026.06 -resume
 */
nextflow.enable.dsl = 2

include { ARGIVE }          from './workflows/argive.nf'
include { PUBLISH_RELEASE } from './modules/local/publish_release.nf'

// ---------------------------------------------------------------------------
// param validation (fail fast, before any compute is scheduled)
// ---------------------------------------------------------------------------
def validate() {
    if (!params.input) {
        exit 1, "ERROR: --input samplesheet.csv is required (see assets/samplesheet.schema.json)"
    }
    def f = file(params.input)
    if (!f.exists()) exit 1, "ERROR: samplesheet not found: ${params.input}"
}

def banner() {
    log.info """\
    ============================================================
     ARGive reprocess  ·  release ${params.release}
    ------------------------------------------------------------
     input        : ${params.input}
     outdir       : ${params.outdir}
     skip_assembly: ${params.skip_assembly}
     min_identity : ${params.min_identity}
     profiles     : ${workflow.profile}
    ============================================================
    """.stripIndent()
}

// ---------------------------------------------------------------------------
// samplesheet -> channel of tuple(meta, has_local, fastq_1, fastq_2)
// ---------------------------------------------------------------------------
def parse_samplesheet() {
    Channel.fromPath(params.input)
        .splitCsv(header: true)
        .map { row ->
            if (!row.accession?.trim())
                exit 1, "ERROR: samplesheet row missing 'accession': ${row}"
            def has_local = (row.fastq_1?.trim()) ? true : false
            def single_end
            if (row.single_end?.toString()?.trim()) {
                single_end = row.single_end.toString().toLowerCase() in ['true', '1', 'yes']
            } else {
                single_end = has_local ? !(row.fastq_2?.trim()) : false
            }
            def meta = [
                id        : row.accession.trim(),
                accession : row.accession.trim(),
                study     : row.study?.trim() ?: null,
                platform  : row.platform?.trim() ?: null,
                single_end: single_end,
            ]
            tuple(meta, has_local, row.fastq_1?.trim() ?: null, row.fastq_2?.trim() ?: null)
        }
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------
workflow {
    validate()
    banner()

    ch_samples = parse_samplesheet()
    ARGIVE( ch_samples )

    // assemble a citable release bundle (combined TSV + manifest + CITATION + sums),
    // publish to outdir (R2-capable) and optionally deposit to Zenodo for a DOI
    if (params.publish_release) {
        PUBLISH_RELEASE(
            ARGIVE.out.record.map { meta, f -> f }.collect(),
            ARGIVE.out.harmonized.collect(),
        )
    }

    // dump all collected tool/db versions for reproducibility
    ARGIVE.out.versions
        .unique()
        .collectFile(name: 'software_versions.yml', storeDir: "${params.tracedir}", sort: true)

    // per-run completion summary -> logging.config handles the rest
    workflow.onComplete = {
        log.info "ARGive run ${workflow.runName} complete: success=${workflow.success}, duration=${workflow.duration}"
    }
}
