# Running ARGive on AWS Batch (+ Cloudflare R2)

ARGive's compute is cloud-native: every task is an AWS Batch job running the
*same* pinned OCI container the module declares. Durable outputs land in
Cloudflare R2 (S3 API, zero egress). This is the first-class deployment.

```
   Nextflow head ──submits──▶ AWS Batch ──runs containers on──▶ EC2 Spot (compute env)
        │                                                          │
        └── work + outputs ◀──────── S3 API ───────────▶ Cloudflare R2 bucket
```

## One-time AWS setup

You need three things: a **compute environment**, a **job queue**, and the
**IAM roles** Batch uses. The Nextflow-recommended path:

1. **Networking** — a VPC with a subnet that has outbound internet (NAT or public)
   so jobs can reach ENA and pull containers.
2. **IAM roles**
   - `AWSBatchServiceRole` (Batch service role)
   - an **instance role** with `AmazonEC2ContainerServiceforEC2Role` + S3 access
     (scoped to your buckets; for R2, creds are passed as env, see below)
   - a **job role** if tasks need AWS APIs (not required for R2).
3. **Compute environment** — MANAGED, Spot, allowed instance types `optimal`
   (or `c`/`m`/`r` families), min vCPUs 0, max vCPUs e.g. 256. Spot is safe here:
   tasks are idempotent and Nextflow retries (`base.config` retries 137/140).
4. **Job queue** — bound to that compute environment. Its name is your `--aws_queue`.
5. **AMI / scratch** — use an ECS-optimized AMI with a large `/scratch` (assemblies
   are big and transient). The `awsbatch.config` mounts `/scratch` and points the
   AWS CLI at `/usr/local/bin/aws`.

> Fastest route: `nextflow` + the **AWS Batch Terraform/CloudFormation** from the
> nf-core community, or Seqera Platform's "Batch Forge" which provisions all of the
> above for you. Either is fine; the pipeline doesn't care how the queue was made.

## R2 credentials (passed to the head job's environment)

```bash
export AWS_ACCESS_KEY_ID=<r2 access key id>
export AWS_SECRET_ACCESS_KEY=<r2 secret access key>
export ARGIVE_R2_ENDPOINT=https://<account_id>.r2.cloudflarestorage.com
```

R2 is the `--outdir` (records, alignments, release bundle). The Batch **work dir**
can be a normal S3 bucket (`-w s3://...`) or R2 too — either works via the S3 API.

## Launch

```bash
nextflow run main.nf \
  -profile awsbatch,r2 \
  --input    samplesheet.csv \
  --outdir   s3://argive-archive/v2026.06 \
  -w         s3://argive-work/scratch \
  --aws_queue  argive-queue \
  --aws_region eu-north-1 \
  --release    v2026.06 \
  -resume
```

`-resume` is reliable thanks to `cache = 'lenient'` (see `conf/logging.config`):
re-runs skip every task whose inputs are unchanged, even though object-store
staging rewrites timestamps. Fetch-new-data = append rows to the samplesheet and
`-resume`; redo-one-tool = bump that tool's version (new release) and `-resume`.

## Cost intuition (order-of-magnitude)

Because we store **derived results only**, storage is trivially cheap (R2: ~$0.015/GB-mo,
the whole archive is single-digit GB, downloads are free egress). The cost is *compute*:

| Item | Rough cost driver |
|---|---|
| Per metagenome | ~1–4 vCPU-hours (assembly dominates); Spot ~$0.01–0.04/vCPU-hr → a few cents to ~$0.15/sample |
| 10,000 samples | dominated by MEGAHIT memory/time; budget by reserving `bigmem` only when needed |
| Egress | **$0** on R2 for public downloads — the reason R2 was chosen |

Knobs to control spend: `--skip_assembly` (reads-only quant, far cheaper),
`--max_reads` (subsample huge runs), Spot compute env, and `queueSize` to cap
concurrency.

## Monitoring

- `results/pipeline_info/` → `trace.txt`, `report.html`, `timeline.html`, `dag.html`.
- Set `--weblog_url <endpoint>` to stream live task events (or use Seqera Platform
  on top of the same Batch queue for a launch/resume/logs UI).
- Failed tasks keep their `.command.sh`/`.command.err` in the work dir (`cleanup=false`)
  so any failure is reproducible: `cd <workdir/hash> && bash .command.run`.
