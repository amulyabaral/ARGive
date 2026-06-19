#!/usr/bin/env python3
"""
zenodo_upload.py — deposit a release bundle to Zenodo and (optionally) publish it
to mint a DOI. This is what turns the placeholder `doi:10.xxxx/argive...` in the
frontend into a real, citable identifier per release.

Auth: export ZENODO_TOKEN=<personal access token>  (scope: deposit:write, deposit:actions)
Use --sandbox while testing (https://sandbox.zenodo.org) to avoid minting real DOIs.

Flow: create deposition -> upload each file to its bucket -> set metadata ->
optionally publish. Prints the (draft) DOI and deposition URL as JSON to stdout.

Stdlib only (urllib). Files are streamed with PUT to the deposition bucket.
"""
import argparse
import json
import os
import sys
import urllib.request


def _req(method, url, token, data=None, headers=None, raw=False):
    h = {"Authorization": f"Bearer {token}"}
    if headers:
        h.update(headers)
    body = data
    if data is not None and not raw:
        body = json.dumps(data).encode()
        h["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=body, method=method, headers=h)
    with urllib.request.urlopen(req, timeout=300) as r:
        payload = r.read()
    return json.loads(payload) if payload and not raw else payload


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--bundle-dir", required=True, help="dir produced by make_manifest.py")
    ap.add_argument("--release", required=True)
    ap.add_argument("--sandbox", action="store_true")
    ap.add_argument("--publish", action="store_true", help="publish (mint DOI). Omit for a reviewable draft.")
    ap.add_argument("--out", default="-", help="write deposition info JSON here")
    a = ap.parse_args()

    token = os.environ.get("ZENODO_TOKEN")
    if not token:
        sys.exit("ERROR: ZENODO_TOKEN not set")
    base = "https://sandbox.zenodo.org" if a.sandbox else "https://zenodo.org"

    # 1. create deposition
    dep = _req("POST", f"{base}/api/deposit/depositions", token, data={})
    dep_id = dep["id"]
    bucket = dep["links"]["bucket"]

    # 2. upload every file in the bundle to the deposition bucket
    for name in sorted(os.listdir(a.bundle_dir)):
        path = os.path.join(a.bundle_dir, name)
        if not os.path.isfile(path):
            continue
        with open(path, "rb") as fh:
            _req("PUT", f"{bucket}/{name}", token, data=fh.read(), raw=True,
                 headers={"Content-Type": "application/octet-stream"})
        sys.stderr.write(f"uploaded {name}\n")

    # 3. metadata
    meta = {"metadata": {
        "title": f"ARGive resistome archive — release {a.release}",
        "upload_type": "dataset",
        "description": ("Harmonized, concordance-scored, copies-per-genome-normalized "
                        "antimicrobial-resistance gene archive from public metagenomes. "
                        f"Release {a.release}. See manifest.json and CITATION.cff."),
        "creators": [{"name": "ARGive Consortium"}],
        "version": a.release,
        "keywords": ["antimicrobial resistance", "resistome", "metagenomics", "hAMRonize"],
        "access_right": "open",
        "license": "cc-by-4.0",
    }}
    _req("PUT", f"{base}/api/deposit/depositions/{dep_id}", token, data=meta)

    doi = dep.get("metadata", {}).get("prereserve_doi", {}).get("doi")
    if a.publish:
        pub = _req("POST", f"{base}/api/deposit/depositions/{dep_id}/actions/publish", token, data={})
        doi = pub.get("doi", doi)

    info = {"deposition_id": dep_id, "doi": doi, "published": bool(a.publish),
            "url": f"{base}/deposit/{dep_id}", "sandbox": a.sandbox}
    out = sys.stdout if a.out == "-" else open(a.out, "w")
    json.dump(info, out, indent=2)
    sys.stderr.write(f"\nZenodo deposition {dep_id} doi={doi} published={a.publish}\n")


if __name__ == "__main__":
    main()
