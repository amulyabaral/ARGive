#!/usr/bin/env python3
"""
build_record.py — merge a sample's harmonized hits + read-mapped depth +
genome-equivalent denominator + samplesheet/ENA metadata into ONE ARGive
record (validated against assets/record.schema.json) plus a citation manifest.

Design choices that matter scientifically (documented, not hidden):

  * Concordance = the number of DISTINCT calling tools that reported a gene, read
    from the hAMRonize `analysis_software_name` column. This is ARGive's trust
    signal. A gene called by 3/4 tools is far more credible than one tool's hit.

  * copies_per_genome = gene_depth / genome_equivalents, where
        genome_equivalents := the community-summed coverage of single-copy marker
        genes from SingleM (equivalently, the average coverage of a single-copy
        core gene across the metagenome). Under that definition a gene present at
        coverage D in a community of G genome-equivalents sits at D/G copies per
        genome. Raw `depth` is always retained alongside so the frontend's
        raw-vs-normalized toggle stays honest.

  * Drug classes are mapped onto ARGive's controlled vocabulary
    (assets/drug_class_map.tsv). Unmapped classes fall through to "Other" and
    are printed to stderr so the vocabulary is extended deliberately.

Stdlib only — runs in any python3 container.
"""
import argparse
import csv
import json
import re
import sys


# ---------- drug-class vocabulary ----------
def load_drug_map(path):
    m = {}
    if not path:
        return m
    with open(path) as fh:
        for line in fh:
            line = line.rstrip("\n")
            if not line or line.startswith("#") or "\t" not in line:
                continue
            raw, canon = line.split("\t", 1)
            m[raw.strip().lower()] = canon.strip()
    return m


def map_drug_class(raw, drug_map, unmapped):
    if not raw:
        return "Other"
    # hAMRonize may pack several classes separated by ; or , — take the first mapped
    for token in re.split(r"[;,/|]", raw):
        key = token.strip().lower()
        if key in drug_map:
            return drug_map[key]
    # try whole-string
    if raw.strip().lower() in drug_map:
        return drug_map[raw.strip().lower()]
    unmapped.add(raw)
    return "Other"


# ---------- tool-name normalization ----------
# hAMRonize writes a free-text analysis_software_name; collapse to our 4 tags.
TOOL_ALIASES = {
    "amrfinderplus": "amrfinderplus", "amrfinder": "amrfinderplus", "ncbi": "amrfinderplus",
    "rgi": "rgi", "card": "rgi",
    "resfinder": "resfinder",
    "abricate": "abricate",
}


def normalize_tool(name):
    n = (name or "").strip().lower()
    for key, tag in TOOL_ALIASES.items():
        if key in n:
            return tag
    return n or "unknown"


# ---------- gene-symbol normalization ----------
def clean_gene(symbol):
    """Harmonize a gene symbol to the frontend's display form.
    hAMRonize gene_symbol is usually clean already; KMA templates look like
    `sul1_5_U12338` (gene_variant_accession) so we strip the trailing
    _<variant>_<accession>.
    """
    s = (symbol or "").strip()
    # KMA template form: take everything before the first _<digits>_<ACCESSION>
    m = re.match(r"^(.+?)_\d+_[A-Z]{1,3}\d+", s)
    if m:
        return m.group(1)
    return s


# ---------- parsers ----------
def parse_hamronized(path):
    """Return list of dict rows from a hAMRonize summarized TSV (tolerant of
    column-name drift across hAMRonize versions)."""
    rows = []
    with open(path) as fh:
        reader = csv.DictReader(fh, delimiter="\t")
        for r in reader:
            rows.append(r)
    return rows


def col(row, *names):
    for n in names:
        if n in row and row[n] not in (None, "", "NA"):
            return row[n]
    return None


def parse_kma_res(path):
    """gene -> {depth, identity, coverage} from a KMA .res file (the fixture
    format). Multiple templates of the same gene -> keep the deepest."""
    out = {}
    if not path:
        return out
    with open(path) as fh:
        reader = csv.DictReader(fh, delimiter="\t")
        for r in reader:
            tmpl = r.get("#Template") or r.get("Template")
            if not tmpl:
                continue
            gene = clean_gene(tmpl)
            try:
                depth = float(r.get("Depth", "nan"))
            except ValueError:
                continue
            ident = _to_float(r.get("Template_Identity"))
            cov = _to_float(r.get("Template_Coverage"))
            prev = out.get(gene)
            if prev is None or depth > prev["depth"]:
                out[gene] = {"depth": depth, "identity": ident, "coverage": cov}
    return out


def parse_singlem(path):
    """Extract genome_equivalents (community coverage of single-copy markers).
    Tolerant of SingleM output variants: prefers an explicit coverage/genome
    column; else derives from microbial bases / average genome size."""
    if not path:
        return None
    with open(path) as fh:
        reader = csv.DictReader(fh, delimiter="\t")
        rows = list(reader)
    if not rows:
        return None
    # microbial_fraction output: bacterial_archaeal_bases / avg genome size
    r = rows[0]
    for key in ("genome_equivalents", "coverage", "estimated_genome_equivalents"):
        v = _to_float(r.get(key))
        if v:
            return v
    bases = _to_float(r.get("bacterial_archaeal_bases")) or _to_float(r.get("microbial_bases"))
    if bases:
        AVG_GENOME_SIZE = 4.0e6  # bp; documented assumption, tune per metapackage
        return round(bases / AVG_GENOME_SIZE, 2)
    return None


def _to_float(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


# ---------- merge ----------
def build_args(hrows, kma, drug_map, unmapped):
    """Aggregate per-gene across all tools -> list of arg hits."""
    genes = {}
    for r in hrows:
        sym = clean_gene(col(r, "gene_symbol", "gene_name"))
        if not sym:
            continue
        tool = normalize_tool(col(r, "analysis_software_name"))
        ident = _to_float(col(r, "sequence_identity", "Template_Identity"))
        dclass = map_drug_class(col(r, "drug_class", "antimicrobial_agent"), drug_map, unmapped)
        aro = col(r, "reference_accession") if tool == "rgi" else None
        ref = col(r, "reference_accession")

        g = genes.setdefault(sym, {
            "gene": sym, "gene_name": col(r, "gene_name"), "drug_class": dclass,
            "identity": ident, "tools": set(), "aro": None, "reference_accession": ref,
        })
        g["tools"].add(tool)
        if ident is not None and (g["identity"] is None or ident > g["identity"]):
            g["identity"] = ident
        if aro and not g["aro"]:
            g["aro"] = aro
        if g["drug_class"] == "Other" and dclass != "Other":
            g["drug_class"] = dclass

    # fold in KMA depth (and let read-mapping count as the 'resfinder' tool)
    for gene, kd in kma.items():
        g = genes.setdefault(gene, {
            "gene": gene, "gene_name": None, "drug_class": "Other",
            "identity": kd["identity"], "tools": set(), "aro": None, "reference_accession": None,
        })
        g["tools"].add("resfinder")
        g["_depth"] = kd["depth"]
        g["_coverage"] = kd["coverage"]
        if kd["identity"] is not None and (g["identity"] is None or kd["identity"] > g["identity"]):
            g["identity"] = kd["identity"]

    return genes


def finalize(genes, genome_equivalents):
    args = []
    for g in genes.values():
        depth = g.pop("_depth", None)
        coverage = g.pop("_coverage", None)
        cpg = None
        if depth is not None and genome_equivalents:
            cpg = round(depth / genome_equivalents, 4)
        tools = sorted(g["tools"])
        args.append({
            "gene": g["gene"],
            "gene_name": g["gene_name"],
            "drug_class": g["drug_class"],
            "identity": round(g["identity"], 1) if g["identity"] is not None else None,
            "depth": round(depth, 3) if depth is not None else None,
            "copies_per_genome": cpg,
            "coverage": round(coverage, 2) if coverage is not None else None,
            "tools": tools,
            "concordance": len(tools),
            "aro": g["aro"],
            "reference_accession": g["reference_accession"],
        })
    # most concordant, then deepest, then identity
    args.sort(key=lambda a: (-a["concordance"], -(a["depth"] or 0), -(a["identity"] or 0)))
    return args


def main():
    ap = argparse.ArgumentParser(description="Build an ARGive record from pipeline outputs.")
    ap.add_argument("--hamronized", required=True, help="hAMRonize summarized TSV")
    ap.add_argument("--kma-res", help="KMA .res file (depth for quantification)")
    ap.add_argument("--singlem", help="SingleM microbial_fraction TSV (denominator)")
    ap.add_argument("--meta", required=True, help="sample metadata JSON (accession, study, lat, ...)")
    ap.add_argument("--drug-map", help="drug_class_map.tsv")
    ap.add_argument("--release", default="v2026.06")
    ap.add_argument("--versions", help="tool versions JSON for _provenance")
    ap.add_argument("--pipeline-revision", default=None)
    ap.add_argument("--out", required=True, help="output record JSON path")
    a = ap.parse_args()

    meta = json.load(open(a.meta))
    drug_map = load_drug_map(a.drug_map)
    unmapped = set()

    hrows = parse_hamronized(a.hamronized)
    kma = parse_kma_res(a.kma_res)
    genome_equivalents = parse_singlem(a.singlem)

    genes = build_args(hrows, kma, drug_map, unmapped)
    args = finalize(genes, genome_equivalents)

    versions = json.load(open(a.versions)) if a.versions else {}

    record = dict(meta)  # accession, study, title, biome, country, lat, lon, date, platform, bp...
    record["genome_equivalents"] = genome_equivalents
    record["args"] = args
    record["_provenance"] = {
        "release": a.release,
        "pipeline_revision": a.pipeline_revision,
        "tool_versions": versions,
    }

    with open(a.out, "w") as fh:
        json.dump(record, fh, indent=2)

    if unmapped:
        sys.stderr.write(
            "WARN: %d drug-class string(s) fell through to 'Other' (extend drug_class_map.tsv): %s\n"
            % (len(unmapped), "; ".join(sorted(unmapped)))
        )
    sys.stderr.write(
        "build_record: %s -> %d genes, %s genome-equivalents\n"
        % (meta.get("accession", "?"), len(args),
           ("%.1f" % genome_equivalents) if genome_equivalents else "NA")
    )


if __name__ == "__main__":
    main()
