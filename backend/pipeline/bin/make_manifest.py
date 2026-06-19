#!/usr/bin/env python3
"""
make_manifest.py — assemble a citable release bundle from all per-sample outputs.

Produces, for a release (e.g. v2026.06):
  * argive_<release>.hamronized.tsv  — ALL samples' harmonized hits in one TSV
        (the canonical researcher-facing artifact; opens in Excel/pandas/R-arrow)
  * manifest.json                    — release metadata + per-sample summary
  * CITATION.cff                     — machine-readable citation (cite the archive)
  * SHA256SUMS                       — integrity for every file in the bundle

This bundle is what gets synced to Cloudflare R2 and deposited to Zenodo (DOI).
Stdlib only.
"""
import argparse
import csv
import glob
import hashlib
import json
import os


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def combine_hamronized(tsvs, out_path):
    """Concatenate per-sample hAMRonize TSVs, keeping ONE header."""
    wrote_header = False
    n_rows = 0
    with open(out_path, "w", newline="") as out:
        for tsv in sorted(tsvs):
            with open(tsv) as fh:
                for i, line in enumerate(fh):
                    if i == 0:
                        if not wrote_header:
                            out.write(line)
                            wrote_header = True
                        continue
                    out.write(line)
                    n_rows += 1
    return n_rows


def summarize_record(path):
    rec = json.load(open(path))
    args = rec.get("args", [])
    concordant = sum(1 for a in args if (a.get("concordance") or 0) >= 2)
    return {
        "accession": rec.get("accession"),
        "study": rec.get("study"),
        "country": rec.get("country"),
        "genome_equivalents": rec.get("genome_equivalents"),
        "n_genes": len(args),
        "n_concordant": concordant,
    }, rec.get("_provenance", {})


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--records", nargs="+", required=True, help="record.json files (or globs)")
    ap.add_argument("--hamronized", nargs="+", required=True, help="per-sample hamronized TSVs (or globs)")
    ap.add_argument("--release", required=True)
    ap.add_argument("--out-dir", required=True)
    a = ap.parse_args()

    os.makedirs(a.out_dir, exist_ok=True)
    records = sorted({p for g in a.records for p in glob.glob(g)} or set(a.records))
    tsvs = sorted({p for g in a.hamronized for p in glob.glob(g)} or set(a.hamronized))

    combined = os.path.join(a.out_dir, f"argive_{a.release}.hamronized.tsv")
    n_rows = combine_hamronized(tsvs, combined)

    samples, provenance = [], {}
    for r in records:
        s, prov = summarize_record(r)
        samples.append(s)
        if prov:
            provenance = prov  # frozen + identical across a release

    manifest = {
        "release": a.release,
        "n_samples": len(samples),
        "n_hits": n_rows,
        "tool_versions": provenance.get("tool_versions", {}),
        "pipeline_revision": provenance.get("pipeline_revision"),
        "artifacts": {
            "combined_hamronized_tsv": os.path.basename(combined),
            "per_sample_records": "records/",
            "alignments": "alignments/",
        },
        "samples": samples,
    }
    with open(os.path.join(a.out_dir, "manifest.json"), "w") as fh:
        json.dump(manifest, fh, indent=2)

    # machine-readable citation — makes "cite the archive, not just the data" real
    cff = f"""cff-version: 1.2.0
title: "ARGive: a continuously-updated, harmonized archive of antimicrobial-resistance genes in public metagenomes"
message: "If you use ARGive data, please cite this release."
type: dataset
authors:
  - name: "ARGive Consortium"
version: "{a.release}"
abstract: >-
  {len(samples)} public metagenomes reprocessed through one frozen multi-tool pipeline,
  harmonized with hAMRonize, normalized to copies-per-genome via SingleM genome-equivalents,
  and concordance-scored across AMRFinderPlus, RGI/CARD, ResFinder and abricate.
keywords:
  - antimicrobial resistance
  - resistome
  - metagenomics
  - hAMRonize
"""
    with open(os.path.join(a.out_dir, "CITATION.cff"), "w") as fh:
        fh.write(cff)

    # checksums for everything in the bundle
    sums_path = os.path.join(a.out_dir, "SHA256SUMS")
    with open(sums_path, "w") as fh:
        for name in sorted(os.listdir(a.out_dir)):
            p = os.path.join(a.out_dir, name)
            if os.path.isfile(p) and name != "SHA256SUMS":
                fh.write(f"{sha256(p)}  {name}\n")

    print(f"make_manifest: release {a.release} -> {len(samples)} samples, {n_rows} hits")


if __name__ == "__main__":
    main()
