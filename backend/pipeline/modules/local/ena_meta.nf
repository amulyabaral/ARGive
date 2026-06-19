/*
 * ENA_META — fetch run/sample metadata from ENA and emit meta.json: the
 * accession-derived fields the frontend shows (study, platform, base_count,
 * country, collection_date, lat/lon, title). Runs regardless of whether reads
 * were fetched or supplied locally.
 *
 * Rich context (paper-extracted fields, environmental join) is added by the
 * separate metadata/ and enrich/ services in later phases — this only covers
 * what ENA itself exposes.
 */
process ENA_META {
    tag   "${meta.id}"
    label 'process_low'
    container 'quay.io/biocontainers/python:3.10'

    input:
    val meta

    output:
    tuple val(meta), path("${meta.id}.meta.json"), emit: meta_json
    path 'versions.yml',                           emit: versions

    script:
    """
    set -euo pipefail
    python3 - <<'PY'
import json, urllib.request, urllib.parse
acc = "${meta.accession}"
fields = ",".join([
    "run_accession","study_accession","instrument_platform","instrument_model",
    "base_count","read_count","sample_accession","country","location",
    "lat","lon","collection_date","scientific_name","sample_title","study_title",
])
url = "https://www.ebi.ac.uk/ena/portal/api/filereport?" + urllib.parse.urlencode(
    {"accession": acc, "result": "read_run", "fields": fields, "format": "tsv"})
rec = {}
try:
    with urllib.request.urlopen(url, timeout=120) as r:
        lines = r.read().decode().splitlines()
    if len(lines) >= 2:
        hdr = lines[0].split("\\t")
        val = lines[1].split("\\t")
        rec = dict(zip(hdr, val))
except Exception as e:
    import sys; sys.stderr.write("WARN: ENA meta fetch failed for %s: %s\\n" % (acc, e))

def num(x):
    try: return float(x)
    except: return None

# parse "lat,lon" out of a combined `location` like '56.17 N 9.55 E' if needed
lat = num(rec.get("lat")); lon = num(rec.get("lon"))

meta = {
    "accession": acc,
    "study": rec.get("study_accession") or "${meta.study ?: ''}",
    "title": rec.get("sample_title") or rec.get("study_title") or acc,
    "country": (rec.get("country") or "").split(":")[0] or None,
    "lat": lat, "lon": lon,
    "date": rec.get("collection_date") or None,
    "platform": rec.get("instrument_model") or rec.get("instrument_platform") or "${meta.platform ?: ''}",
    "bp": int(rec["base_count"]) if rec.get("base_count","").isdigit() else None,
    "biome": None,            # assigned by enrich/ in a later phase
    "scientific_name": rec.get("scientific_name") or None,
}
json.dump(meta, open("${meta.id}.meta.json","w"), indent=2)
PY

    cat <<-VERS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //')
        ena-source: "ebi.ac.uk/ena filereport API"
    VERS
    """
}
