#!/usr/bin/env python3
"""
normalize_copies.py — the one-line scientific core, exposed as a reusable
utility and importable function.

    copies_per_genome = gene_depth / genome_equivalents

where genome_equivalents is the community-summed coverage of single-copy marker
genes (SingleM). build_record.py uses the same formula; this standalone CLI is
for ad-hoc normalization of a KMA .res against a genome-equivalents value.
"""
import argparse
import csv
import sys


def copies_per_genome(depth, genome_equivalents):
    """Return depth normalized to copies per genome, or None if undefined."""
    if depth is None or not genome_equivalents:
        return None
    return depth / genome_equivalents


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("res", help="KMA .res file with a Depth column")
    ap.add_argument("--genome-equivalents", type=float, required=True)
    ap.add_argument("--out", default="-")
    a = ap.parse_args()

    out = sys.stdout if a.out == "-" else open(a.out, "w")
    w = csv.writer(out, delimiter="\t")
    w.writerow(["template", "depth", "copies_per_genome"])
    with open(a.res) as fh:
        for r in csv.DictReader(fh, delimiter="\t"):
            tmpl = r.get("#Template") or r.get("Template")
            try:
                depth = float(r.get("Depth", "nan"))
            except (TypeError, ValueError):
                continue
            cpg = copies_per_genome(depth, a.genome_equivalents)
            w.writerow([tmpl, depth, "" if cpg is None else round(cpg, 4)])


if __name__ == "__main__":
    main()
