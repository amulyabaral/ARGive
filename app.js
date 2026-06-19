/* ARGive — prototype UI logic. No backend; all data from data.js. */

const $ = (s) => document.querySelector(s);
const homeEl = $("#home");
const detailEl = $("#detail");
const exploreEl = $("#explore");
const resultsWrap = $("#results-wrap");
const resultsEl = $("#results");
const countEl = $("#result-count");
const emptyEl = $("#empty");
const searchEl = $("#search");

let normalised = true;
let map = null;

/* ===================== aggregates ===================== */
const AGG = (() => {
  const genes = new Set(), classes = {}, countries = new Set();
  let hits = 0;
  for (const d of ARGIVE_DATA) {
    countries.add(d.country);
    for (const a of d.args) {
      hits++; genes.add(a.gene);
      (classes[a.drug_class] ||= new Set()).add(a.gene);
    }
  }
  return { samples: ARGIVE_DATA.length, hits, genes: genes.size, classes, countries: countries.size };
})();

// per-gene prevalence (how many samples carry it) + its drug class
const GENES = (() => {
  const m = new Map();
  for (const d of ARGIVE_DATA) for (const a of d.args) {
    const g = m.get(a.gene) || { gene: a.gene, drug_class: a.drug_class, samples: 0 };
    g.samples++; m.set(a.gene, g);
  }
  return [...m.values()];
})();

// muted palette, assigned to classes by descending gene count (stable order)
const PALETTE = ["#0f7b6c", "#2f6db0", "#7a55c0", "#b04a93", "#c1556a", "#c07a2c", "#3f8f57", "#5a6a78", "#a8902a", "#7e8a2c", "#b3635c"];
const CLASS_COLOR = (() => {
  const ordered = Object.entries(AGG.classes).sort((a, b) => b[1].size - a[1].size).map((e) => e[0]);
  const out = {};
  ordered.forEach((c, i) => (out[c] = PALETTE[i % PALETTE.length]));
  return out;
})();
const hexA = (hex, a) => hex + a; // append alpha hex pair

function buildGeneCloud() {
  // legend — clickable to filter a whole class
  const ordered = Object.entries(AGG.classes).sort((a, b) => b[1].size - a[1].size);
  $("#gene-legend").innerHTML = ordered.map(([c]) =>
    `<span class="leg" data-q="${c}"><i style="background:${CLASS_COLOR[c]}"></i>${c}</span>`).join("");

  // cloud — genes sized by prevalence, sorted most-common first
  const maxS = Math.max(...GENES.map((g) => g.samples));
  $("#gene-cloud").innerHTML = [...GENES]
    .sort((a, b) => b.samples - a.samples || a.gene.localeCompare(b.gene))
    .map((g) => {
      const t = maxS > 1 ? (g.samples - 1) / (maxS - 1) : 0; // 0..1
      const size = (13 + t * 13).toFixed(1);                 // 13–26px
      const col = CLASS_COLOR[g.drug_class];
      return `<span class="gtag" data-q="${g.gene}" title="${g.drug_class} · ${g.samples} sample${g.samples > 1 ? "s" : ""}"
        style="font-size:${size}px;color:${col};background:${hexA(col, "14")};border-color:${hexA(col, "33")}">${g.gene}</span>`;
    }).join("");
}

function fmtBig(n) {
  if (n >= 1e6) return (n / 1e6).toFixed(1).replace(/\.0$/, "") + "M";
  if (n >= 1e4) return (n / 1e3).toFixed(0) + "k";
  return n.toLocaleString("en-US");
}

/* ===================== home build ===================== */
function buildHome() {
  // stat strip — scale shown calmly, three figures only
  $("#stat-strip").innerHTML = [
    [fmtBig(AGG.samples), "metagenomes archived"],
    [fmtBig(AGG.hits), "ARG hits catalogued"],
    [fmtBig(AGG.countries), "countries"],
  ].map(([v, k]) => `<div class="stat"><div class="stat-val">${v}</div><div class="stat-key">${k}</div></div>`).join("");

  $("#map-note").textContent = `${AGG.samples} sampling sites · ${AGG.countries} countries`;

  buildGeneCloud();

  // recently archived — deterministic ingest deltas convey "always running"
  const deltas = ["8 min ago", "23 min ago", "1 h ago", "2 h ago", "5 h ago", "9 h ago", "14 h ago", "yesterday"];
  const recent = [...ARGIVE_DATA].sort((a, b) => b.date.localeCompare(a.date)).slice(0, 8);
  $("#recent").innerHTML = recent.map((d, i) => `
    <div class="recent-row" data-acc="${d.accession}">
      <span class="recent-acc">${d.accession}</span>
      <span class="recent-title">${d.title}</span>
      <span class="recent-time">${deltas[i] || "earlier"}</span>
    </div>`).join("");

  // citation
  $("#cite-box").innerHTML =
    `ARGive Consortium (2026). <i>ARGive: a continuously-updated archive of antimicrobial-resistance genes in public metagenomes.</i> Release v2026.06. <span class="doi">doi:10.xxxx/argive.2026.06</span>`;
}

/* ===================== map ===================== */
function buildMap() {
  if (map) { map.invalidateSize(); return; }
  map = L.map("map", { scrollWheelZoom: false, worldCopyJump: true, minZoom: 1 }).setView([22, 12], 1.6);
  L.tileLayer("https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png", {
    attribution: '© OpenStreetMap, © CARTO', subdomains: "abcd", maxZoom: 10,
  }).addTo(map);

  const maxHits = Math.max(...ARGIVE_DATA.map((d) => d.args.length));
  for (const d of ARGIVE_DATA) {
    const r = 6 + (d.args.length / maxHits) * 11;
    const m = L.circleMarker([d.lat, d.lon], {
      radius: r, color: "#0f7b6c", weight: 1.5, fillColor: "#0f7b6c", fillOpacity: 0.45,
    }).addTo(map);
    m.bindPopup(
      `<div class="map-popup"><b>${d.title}</b>` +
      `<span class="mp-meta">${d.biome} · ${d.country} · ${d.args.length} ARG hits</span>` +
      `<button data-acc="${d.accession}" class="popup-open">Open dataset →</button></div>`
    );
  }
  map.on("popupopen", (e) => {
    const btn = e.popup.getElement().querySelector(".popup-open");
    if (btn) btn.onclick = () => openDetail(btn.dataset.acc);
  });
}

/* ===================== search / results ===================== */
function matches(d, q) {
  if (!q) return true;
  const hay = [d.title, d.biome, d.country, d.accession, d.study, d.platform,
    ...d.args.map((a) => a.gene), ...d.args.map((a) => a.drug_class)].join(" ").toLowerCase();
  return q.toLowerCase().split(/\s+/).every((t) => hay.includes(t));
}

function runSearch(q) {
  q = q.trim();
  if (!q) { showExplore(); return; }
  exploreEl.hidden = true;
  resultsWrap.hidden = false;
  const list = ARGIVE_DATA.filter((d) => matches(d, q));
  countEl.textContent = `${list.length} result${list.length === 1 ? "" : "s"} for “${q}”`;
  emptyEl.hidden = list.length !== 0;
  resultsEl.innerHTML = list.map(cardHTML).join("");
}

function showExplore() {
  resultsWrap.hidden = true;
  exploreEl.hidden = false;
  if (map) setTimeout(() => map.invalidateSize(), 0);
}

function cardHTML(d) {
  const pills = d.args.slice(0, 4).map((a) => `<span class="gene-pill">${a.gene}</span>`).join("");
  const extra = d.args.length > 4 ? `<span style="color:var(--ink-faint)">+${d.args.length - 4} more</span>` : "";
  return `
    <article class="card" data-acc="${d.accession}">
      <div class="card-top"><h3 class="card-title">${d.title}</h3><span class="card-acc">${d.accession}</span></div>
      <div class="card-meta">
        <span class="tag biome">${d.biome}</span><span class="tag">${d.country}</span>
        <span class="tag">${fmtDate(d.date)}</span><span class="tag">${shortPlatform(d.platform)}</span>
      </div>
      <div class="card-args"><b>${d.args.length}</b> ARG hits · ${pills} ${extra}</div>
    </article>`;
}

/* ===================== detail ===================== */
function openDetail(acc) {
  const d = ARGIVE_DATA.find((x) => x.accession === acc);
  if (!d) return;
  normalised = true;
  detailEl.innerHTML = detailHTML(d);
  homeEl.hidden = true; detailEl.hidden = false;
  window.scrollTo(0, 0);
  wireDetail(d);
}
function closeDetail() { detailEl.hidden = true; homeEl.hidden = false; if (map) setTimeout(() => map.invalidateSize(), 0); }

function detailHTML(d) {
  return `
  <div class="detail-wrap">
    <button class="backlink" id="back">← Back to ARGive</button>
    <div class="detail-head">
      <h1>${d.title}</h1>
      <div class="detail-sub">
        <span class="tag biome">${d.biome}</span><span class="tag">${d.country}</span>
        <span class="tag">${d.lat.toFixed(2)}, ${d.lon.toFixed(2)}</span>
        <span class="tag">${fmtDate(d.date)}</span><span class="tag">${d.platform}</span>
        <span class="card-acc">${d.accession} · ${d.study}</span>
      </div>
      <div class="detail-actions">
        <button class="btn primary" id="dl-hits">↓ Download ARG hits + citation (TSV)</button>
        <button class="btn" id="dl-context">↓ Download context (JSON)</button>
      </div>
      <p class="note-line">Denominator: <b>${d.genome_equivalents.toFixed(1)}</b> genome equivalents (SingleM) · ${fmtBp(d.bp)} sequenced · archived in release v2026.06</p>
    </div>
    ${argPanel(d)} ${metaPanel(d)} ${contextPanel(d)}
  </div>`;
}

function argPanel(d) {
  return `
  <div class="panel">
    <div class="panel-head">
      <h2>Resistance genes · ${d.args.length} hits</h2>
      <div class="toggle" id="norm-toggle">
        <button data-norm="1" class="on">Copies / genome</button><button data-norm="0">Raw depth</button>
      </div>
    </div>
    <table class="arg-table">
      <thead><tr><th>Gene</th><th>Drug class</th><th class="num">% identity</th><th class="num" id="val-head">Copies / genome</th><th class="bar-cell"></th></tr></thead>
      <tbody id="arg-body">${argRows(d)}</tbody>
    </table>
  </div>`;
}
function argRows(d) {
  const key = normalised ? "copies_per_genome" : "depth";
  const max = Math.max(...d.args.map((a) => a[key]));
  return [...d.args].sort((a, b) => b[key] - a[key]).map((a) => {
    const v = a[key], w = max ? Math.round((v / max) * 100) : 0;
    return `<tr><td class="gene">${a.gene}</td><td>${a.drug_class}</td><td class="num">${a.identity.toFixed(1)}</td><td class="num">${v.toFixed(2)}</td><td class="bar-cell"><div class="bar" style="width:${w}%"></div></td></tr>`;
  }).join("");
}
function metaPanel(d) {
  const p = d.paper;
  const rows = p.extracted.map((e) => `
    <div class="meta-row"><div class="meta-key">${e.field}</div>
      <div><div class="meta-val">${e.value}</div>
      <div class="prov"><span class="conf ${e.confidence}">${e.confidence}</span> extracted from ${e.source}</div></div></div>`).join("");
  return `<div class="panel"><h2>Context extracted from the linked paper</h2><div class="meta-grid">${rows}</div>
    <p class="note-line">Source: <a class="paper-link" href="https://doi.org/${p.doi}" target="_blank" rel="noopener">${p.title}</a> — ${p.journal}, ${p.year}. Each field carries a model-assigned confidence and a page/section pointer; nothing is asserted without provenance.</p></div>`;
}
function contextPanel(d) {
  const c = d.context;
  const cards = [
    ctxCard(c.temp_mean_c, "°C", "Mean air temp (30 d)"),
    ctxCard(c.precip_mm_30d, "mm", "Precipitation (30 d)"),
    ctxCard(c.soil_moisture, "", "Soil moisture (m³/m³)"),
    ctxCard(c.population_density, "/km²", "Population density"),
    ctxCard(c.antibiotic_use_ddd, "DDD", "Antibiotic use index"),
  ].join("");
  return `<div class="panel"><h2>Environmental & socioeconomic context</h2><div class="ctx-grid">${cards}</div>
    <p class="note-line">Joined by sampling coordinate and date — weather/soil from ERA5 reanalysis, socioeconomic covariates from open population & antibiotic-use sources.</p></div>`;
}
function ctxCard(v, unit, label) {
  const body = v == null ? `<div class="ctx-na">— not applicable</div>` : `<div class="ctx-val">${v}<small>${unit ? " " + unit : ""}</small></div>`;
  return `<div class="ctx-card">${body}<div class="ctx-key">${label}</div></div>`;
}

function wireDetail(d) {
  $("#back").onclick = closeDetail;
  $("#norm-toggle").addEventListener("click", (e) => {
    const btn = e.target.closest("button[data-norm]"); if (!btn) return;
    normalised = btn.dataset.norm === "1";
    document.querySelectorAll("#norm-toggle button").forEach((b) => b.classList.toggle("on", b === btn));
    $("#val-head").textContent = normalised ? "Copies / genome" : "Raw depth";
    $("#arg-body").innerHTML = argRows(d);
  });
  $("#dl-hits").onclick = () => downloadHits(d);
  $("#dl-context").onclick = () => downloadContext(d);
}

/* ===================== downloads ===================== */
const CITE = "ARGive Consortium (2026). ARGive resistome archive, release v2026.06. doi:10.xxxx/argive.2026.06";
function downloadHits(d) {
  const head = `# Downloaded from ARGive (release v2026.06)\n# Source accession: ${d.accession} (${d.study})\n# Please cite: ${CITE}\n`;
  const cols = ["accession", "gene", "drug_class", "identity", "depth", "copies_per_genome"].join("\t");
  const rows = d.args.map((a) => [d.accession, a.gene, a.drug_class, a.identity, a.depth, a.copies_per_genome].join("\t"));
  saveFile(`${d.accession}_arg_hits.tsv`, head + [cols, ...rows].join("\n"), "text/tab-separated-values");
}
function downloadContext(d) {
  saveFile(`${d.accession}_context.json`, JSON.stringify({
    _citation: CITE, _release: "v2026.06",
    accession: d.accession, study: d.study, location: { lat: d.lat, lon: d.lon },
    date: d.date, genome_equivalents: d.genome_equivalents, context: d.context, paper: d.paper,
  }, null, 2), "application/json");
}
function saveFile(name, content, mime) {
  const blob = new Blob([content], { type: mime });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob); a.download = name; a.click(); URL.revokeObjectURL(a.href);
}

/* ===================== helpers ===================== */
function fmtDate(s) { const [y, m, dd] = s.split("-"); return new Date(y, m - 1, dd).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" }); }
function fmtBp(bp) { return bp >= 1e9 ? (bp / 1e9).toFixed(1) + " Gbp" : (bp / 1e6).toFixed(0) + " Mbp"; }
function shortPlatform(p) { if (/Nanopore/i.test(p)) return "Nanopore (long-read)"; if (/NovaSeq|HiSeq|Illumina/i.test(p)) return "Illumina"; return p; }

/* ===================== events ===================== */
searchEl.addEventListener("input", (e) => runSearch(e.target.value));
$("#quickchips").addEventListener("click", (e) => { const c = e.target.closest(".chip"); if (!c) return; searchEl.value = c.dataset.q; runSearch(c.dataset.q); });
function geneSearch(e) { const el = e.target.closest("[data-q]"); if (!el) return; searchEl.value = el.dataset.q; runSearch(el.dataset.q); window.scrollTo({ top: 0, behavior: "smooth" }); }
$("#gene-cloud").addEventListener("click", geneSearch);
$("#gene-legend").addEventListener("click", geneSearch);
$("#recent").addEventListener("click", (e) => { const r = e.target.closest(".recent-row"); if (r) openDetail(r.dataset.acc); });
resultsEl.addEventListener("click", (e) => { const c = e.target.closest(".card"); if (c) openDetail(c.dataset.acc); });
$("#clear-search").addEventListener("click", () => { searchEl.value = ""; showExplore(); });
$("#copy-cite").addEventListener("click", (e) => {
  navigator.clipboard?.writeText(CITE).then(() => { e.target.textContent = "Copied ✓"; setTimeout(() => (e.target.textContent = "Copy citation"), 1500); });
});

/* ===================== init ===================== */
buildHome();
buildMap();
