# ARGive backend

> The compute and data layer behind **ARGive — the living archive of the world's resistome**.

The frontend (`/index.html`, `/app.js`, `/data.js`) currently runs on hand-written demo
data. This backend produces the *real* thing: every public shotgun metagenome we ingest is
re-processed through one frozen, versioned, multi-tool pipeline so that every ARG hit in the
archive is **comparable, concordance-scored, normalized, contextualized, and citable**.

Nothing in this backend runs on a workstation. It is built to run on an **HPC cluster
(SLURM scheduler, Apptainer/Singularity containers)** — see [`pipeline/`](pipeline/).

---

## Why ARGive is different

Public resistome data is technically open but scientifically incomparable: every study uses
its own AMR tool, its own ontology, its own units, and leaves the "why" trapped in a PDF.
ARGive collapses that into a single substrate:

| Pillar | What it means | Where it lives |
|---|---|---|
| **One reprocessing** | Every sample re-run through *the same* frozen pipeline | `pipeline/` |
| **Multi-pipeline concordance** | A gene is scored by *how many tools* called it (1–4) | `hamronize` + `build_record.py` |
| **One ontology** | All hits harmonized to canonical IDs (NCBI RefGene / CARD ARO) | `hAMRonize` + `assets/drug_class_map.tsv` |
| **One denominator** | Copies per genome via SingleM genome-equivalents | `singlem` + `normalize_copies.py` |
| **Full provenance** | DB versions, tool versions, release tag frozen per record | `build_record.py` → `_provenance` |
| **Context** | LLM-extracted paper metadata + environmental join (later phases) | `metadata/`, `enrich/` |

---

## Repository layout

```
backend/
  pipeline/                 # Nextflow DSL2 reprocessing pipeline (THIS PHASE)
    main.nf                 # entry workflow
    nextflow.config         # params + profile selection
    conf/
      base.config           # per-process cpu/mem/time labels
      slurm.config          # SLURM executor profile (HPC)
      apptainer.config      # Apptainer/Singularity container profile
      test.config           # tiny smoke-test profile
    workflows/argive.nf     # the ARGive subworkflow (channel wiring)
    modules/local/*.nf      # one process per tool
    bin/                    # helper scripts shipped to every task (on PATH)
      build_record.py       # merge harmonized hits + depth + denominator -> record JSON
      normalize_copies.py   # depth + genome-equivalents -> copies/genome
    assets/
      drug_class_map.tsv    # controlled drug-class vocabulary
      record.schema.json    # JSON Schema for a per-sample ARGive record
      samplesheet.schema.json
  ingest/                   # ENA/SRA accession discovery (later phase)
  metadata/                 # LLM paper-context extraction (later phase)
  enrich/                   # environmental/socioeconomic join (later phase)
  api/                      # FastAPI + Postgres serving the frontend (later phase)
```

---

## The record contract (pipeline → frontend)

The pipeline's terminal output is **one JSON record per sample**, validated against
[`pipeline/assets/record.schema.json`](pipeline/assets/record.schema.json). It is a superset
of the object shape the frontend already consumes in `data.js` (`accession`, `study`,
`title`, `biome`, `country`, `lat`, `lon`, `date`, `platform`, `bp`, `genome_equivalents`,
`args[]` with `gene`/`drug_class`/`identity`/`depth`/`copies_per_genome`).

ARGive adds, per ARG hit:

- `tools` — list of pipelines that called this gene (e.g. `["amrfinderplus","rgi","resfinder"]`)
- `concordance` — `len(tools)`, the trust signal surfaced in the UI
- `aro` / `reference_accession` — canonical ontology IDs
- `coverage` / `reference_length` — for read-mapped quantification

…and per record a `_provenance` block freezing every tool + database version and the release
tag, so any number can be reproduced exactly.

---

## Pinned versions (release `v2026.06`)

Versions are pinned in `pipeline/nextflow.config` (`params.versions`) and stamped into every
record's `_provenance`. Bumping any of these = a new release tag, never a silent overwrite.

| Component | Pinned | Role |
|---|---|---|
| AMRFinderPlus + DB | `4.0.x` / `2026-xx` | assembly-based calling, NCBI RefGene ontology |
| RGI + CARD | `6.0.x` / CARD `4.0.0` | assembly-based calling, ARO ontology |
| ResFinder + DB (KMA) | `4.x` | **read-based** calling → depth for quantification |
| abricate (+ db) | `1.0.x` | fast assembly-based concordance check |
| hAMRonize | `1.1.x` | harmonization to a common report |
| SingleM | `1.0.x` | genome-equivalents denominator |
| fastp | `0.24.x` | QC/trim |
| MEGAHIT | `1.2.x` | assembly |

> Exact patch versions + container digests are resolved on first build and committed to
> `pipeline/conf/containers.config`. See that file for the source of truth once generated.

---

## Quickstart (on the cluster, not here)

```bash
# from a login node with Nextflow + Apptainer available
module load Nextflow Apptainer        # or NRIS/Sigma2 equivalents
cd backend/pipeline

# smoke test on a tiny bundled sample (single node)
nextflow run main.nf -profile test,apptainer

# real run on SLURM
nextflow run main.nf \
  -profile slurm,apptainer \
  --input  /path/to/samplesheet.csv \
  --outdir /cluster/work/argive/v2026.06 \
  -resume
```

`samplesheet.csv` columns are documented in
[`pipeline/assets/samplesheet.schema.json`](pipeline/assets/samplesheet.schema.json). Minimum:
just an `accession` (reads are fetched from ENA); optionally point at local `fastq_1`/`fastq_2`.
