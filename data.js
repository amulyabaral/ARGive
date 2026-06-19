/*
 * ARGive — sample catalogue (PROTOTYPE DATA)
 * --------------------------------------------------------------------------
 * Every record below is hand-written demo data for the UI prototype.
 * Nothing here was pulled from a live archive. The shape mirrors what the
 * real backend would produce per sample:
 *   - accession + study metadata (from ENA/SRA)
 *   - paper-extracted fields, each with a provenance + confidence flag
 *   - ARG hits parsed from a KMA/ResFinder run
 *   - a SingleM genome-equivalent denominator → copies per genome
 *   - environmental + socioeconomic context joined by coordinate + date
 *
 * Confidence values are illustrative of the provenance design, not real.
 */

const ARGIVE_DATA = [
  {
    accession: "ERR4796012",
    study: "PRJEB39047",
    title: "Agricultural topsoil resistome along a manure-amendment gradient, Jutland",
    biome: "Soil — agricultural",
    country: "Denmark",
    lat: 56.17,
    lon: 9.55,
    date: "2021-05-18",
    platform: "Illumina NovaSeq 6000",
    bp: 14_200_000_000,
    genome_equivalents: 318.4, // from SingleM microbial_fraction
    paper: {
      title: "Manure amendment reshapes the soil resistome in temperate cropland",
      journal: "Environmental Microbiome",
      year: 2022,
      doi: "10.1186/s40793-022-00417-1",
      extracted: [
        { field: "Antibiotic exposure", value: "Pig manure applied 3 weeks before sampling", confidence: "high", source: "Methods, p.4" },
        { field: "Host / matrix", value: "Bulk soil, 0–20 cm", confidence: "high", source: "Methods, p.3" },
        { field: "Land use", value: "Cereal cropland, conventional", confidence: "medium", source: "Abstract" },
        { field: "Sampling design", value: "Paired amended vs. control plots, n=12", confidence: "medium", source: "Figure 1 caption" },
      ],
    },
    context: {
      temp_mean_c: 13.8,
      precip_mm_30d: 41.2,
      soil_moisture: 0.31,
      population_density: 66,
      antibiotic_use_ddd: 9.4, // animal DDD/PCU, illustrative
    },
    args: [
      { gene: "sul1", drug_class: "Sulfonamide", identity: 98.9, depth: 4.21 },
      { gene: "tet(Q)", drug_class: "Tetracycline", identity: 96.4, depth: 1.88 },
      { gene: "aph(3'')-Ib", drug_class: "Aminoglycoside", identity: 99.5, depth: 2.07 },
      { gene: "aph(6)-Id", drug_class: "Aminoglycoside", identity: 97.9, depth: 1.42 },
      { gene: "qacEdelta1", drug_class: "Disinfectant", identity: 100.0, depth: 3.04 },
      { gene: "tet(M)", drug_class: "Tetracycline", identity: 88.9, depth: 0.74 },
    ],
  },
  {
    accession: "ERR5582441",
    study: "PRJEB43219",
    title: "Pristine forest soil baseline resistome, Finnish Lapland",
    biome: "Soil — forest",
    country: "Finland",
    lat: 67.37,
    lon: 26.63,
    date: "2020-07-02",
    platform: "Illumina HiSeq 4000",
    bp: 9_800_000_000,
    genome_equivalents: 204.1,
    paper: {
      title: "A near-pristine boreal soil resistome dominated by intrinsic genes",
      journal: "FEMS Microbiology Ecology",
      year: 2021,
      doi: "10.1093/femsec/fiab088",
      extracted: [
        { field: "Antibiotic exposure", value: "None reported; no agriculture within 20 km", confidence: "medium", source: "Study site, p.2" },
        { field: "Host / matrix", value: "Podzol O-horizon", confidence: "high", source: "Methods, p.3" },
        { field: "Land use", value: "Protected boreal forest", confidence: "high", source: "Abstract" },
      ],
    },
    context: {
      temp_mean_c: 4.1,
      precip_mm_30d: 58.7,
      soil_moisture: 0.44,
      population_density: 2,
      antibiotic_use_ddd: 1.1,
    },
    args: [
      { gene: "vanZ", drug_class: "Glycopeptide", identity: 84.2, depth: 0.41 },
      { gene: "tet(M)", drug_class: "Tetracycline", identity: 86.1, depth: 0.33 },
      { gene: "macB", drug_class: "Macrolide", identity: 90.7, depth: 0.58 },
    ],
  },
  {
    accession: "SRR15233907",
    study: "PRJNA742019",
    title: "Wastewater treatment plant influent resistome, São Paulo",
    biome: "Wastewater — influent",
    country: "Brazil",
    lat: -23.55,
    lon: -46.63,
    date: "2021-03-11",
    platform: "Illumina NovaSeq 6000",
    bp: 22_500_000_000,
    genome_equivalents: 512.7,
    paper: {
      title: "Urban wastewater as a sentinel for clinically relevant resistance in Brazil",
      journal: "Water Research",
      year: 2022,
      doi: "10.1016/j.watres.2022.118512",
      extracted: [
        { field: "Antibiotic exposure", value: "High community use; carbapenem residues detected", confidence: "high", source: "Results, p.6" },
        { field: "Host / matrix", value: "Raw sewage influent, 24h composite", confidence: "high", source: "Methods, p.2" },
        { field: "Population served", value: "~1.8 million", confidence: "medium", source: "Site description" },
      ],
    },
    context: {
      temp_mean_c: 22.9,
      precip_mm_30d: 184.0,
      soil_moisture: null,
      population_density: 7398,
      antibiotic_use_ddd: 19.8,
    },
    args: [
      { gene: "blaKPC-2", drug_class: "Beta-lactam", identity: 99.8, depth: 6.12 },
      { gene: "sul1", drug_class: "Sulfonamide", identity: 99.4, depth: 11.40 },
      { gene: "sul2", drug_class: "Sulfonamide", identity: 98.7, depth: 7.85 },
      { gene: "tet(A)", drug_class: "Tetracycline", identity: 99.1, depth: 9.33 },
      { gene: "aac(6')-Ib-cr", drug_class: "Aminoglycoside", identity: 99.0, depth: 4.71 },
      { gene: "qnrB", drug_class: "Fluoroquinolone", identity: 97.6, depth: 2.04 },
      { gene: "ermB", drug_class: "Macrolide", identity: 98.2, depth: 5.18 },
      { gene: "blaCTX-M-15", drug_class: "Beta-lactam", identity: 99.6, depth: 8.22 },
    ],
  },
  {
    accession: "SRR18002214",
    study: "PRJNA801144",
    title: "Rice paddy sediment resistome, Mekong Delta",
    biome: "Sediment — paddy",
    country: "Vietnam",
    lat: 10.03,
    lon: 105.78,
    date: "2021-09-24",
    platform: "Illumina NovaSeq 6000",
    bp: 17_900_000_000,
    genome_equivalents: 401.2,
    paper: {
      title: "Aquaculture-adjacent paddy sediments accumulate quinolone resistance",
      journal: "Science of the Total Environment",
      year: 2023,
      doi: "10.1016/j.scitotenv.2023.161204",
      extracted: [
        { field: "Antibiotic exposure", value: "Adjacent shrimp aquaculture; fluoroquinolone use", confidence: "high", source: "Introduction, p.2" },
        { field: "Host / matrix", value: "Flooded paddy sediment, 0–10 cm", confidence: "high", source: "Methods, p.3" },
        { field: "Land use", value: "Integrated rice–shrimp", confidence: "medium", source: "Abstract" },
      ],
    },
    context: {
      temp_mean_c: 27.4,
      precip_mm_30d: 233.5,
      soil_moisture: 0.61,
      population_density: 425,
      antibiotic_use_ddd: 24.1,
    },
    args: [
      { gene: "qnrS", drug_class: "Fluoroquinolone", identity: 99.2, depth: 5.44 },
      { gene: "sul2", drug_class: "Sulfonamide", identity: 98.9, depth: 6.71 },
      { gene: "floR", drug_class: "Phenicol", identity: 97.8, depth: 3.22 },
      { gene: "tet(A)", drug_class: "Tetracycline", identity: 98.4, depth: 4.90 },
      { gene: "oqxB", drug_class: "Fluoroquinolone", identity: 96.1, depth: 1.77 },
    ],
  },
  {
    accession: "ERR6781120",
    study: "PRJEB46891",
    title: "Alpine glacier-foreland soil resistome, Swiss Alps",
    biome: "Soil — alpine",
    country: "Switzerland",
    lat: 46.42,
    lon: 8.05,
    date: "2020-08-19",
    platform: "Illumina HiSeq 4000",
    bp: 8_100_000_000,
    genome_equivalents: 176.9,
    paper: {
      title: "Resistome of recently deglaciated alpine soils",
      journal: "Frontiers in Microbiology",
      year: 2021,
      doi: "10.3389/fmicb.2021.713012",
      extracted: [
        { field: "Antibiotic exposure", value: "None; high-altitude foreland", confidence: "medium", source: "Site, p.2" },
        { field: "Host / matrix", value: "Glacier foreland mineral soil", confidence: "high", source: "Methods, p.3" },
        { field: "Soil age", value: "10–150 years since retreat", confidence: "medium", source: "Figure 2" },
      ],
    },
    context: {
      temp_mean_c: 1.9,
      precip_mm_30d: 96.4,
      soil_moisture: 0.28,
      population_density: 27,
      antibiotic_use_ddd: 6.2,
    },
    args: [
      { gene: "macB", drug_class: "Macrolide", identity: 89.4, depth: 0.62 },
      { gene: "vanZ", drug_class: "Glycopeptide", identity: 82.0, depth: 0.29 },
      { gene: "bcrA", drug_class: "Bacitracin", identity: 91.1, depth: 0.71 },
    ],
  },
  {
    accession: "SRR16554302",
    study: "PRJNA764455",
    title: "Periurban vegetable-farm soil resistome, peri-Nairobi",
    biome: "Soil — agricultural",
    country: "Kenya",
    lat: -1.29,
    lon: 36.82,
    date: "2021-11-07",
    platform: "Illumina NovaSeq 6000",
    bp: 13_400_000_000,
    genome_equivalents: 296.5,
    paper: {
      title: "Irrigation with treated wastewater drives ARG load in periurban farms",
      journal: "Environment International",
      year: 2023,
      doi: "10.1016/j.envint.2023.107788",
      extracted: [
        { field: "Antibiotic exposure", value: "Treated-wastewater irrigation; sulfonamide residues", confidence: "high", source: "Results, p.5" },
        { field: "Host / matrix", value: "Vegetable plot topsoil", confidence: "high", source: "Methods, p.3" },
        { field: "Land use", value: "Smallholder horticulture", confidence: "high", source: "Abstract" },
      ],
    },
    context: {
      temp_mean_c: 19.6,
      precip_mm_30d: 78.3,
      soil_moisture: 0.34,
      population_density: 4850,
      antibiotic_use_ddd: 14.7,
    },
    args: [
      { gene: "sul1", drug_class: "Sulfonamide", identity: 99.1, depth: 8.02 },
      { gene: "sul2", drug_class: "Sulfonamide", identity: 98.5, depth: 5.66 },
      { gene: "dfrA1", drug_class: "Trimethoprim", identity: 97.9, depth: 3.41 },
      { gene: "tet(A)", drug_class: "Tetracycline", identity: 98.0, depth: 4.12 },
      { gene: "blaTEM-1", drug_class: "Beta-lactam", identity: 99.3, depth: 2.88 },
      { gene: "ermB", drug_class: "Macrolide", identity: 97.4, depth: 1.95 },
    ],
  },
  {
    accession: "ERR7240988",
    study: "PRJEB48710",
    title: "Coastal estuary sediment resistome, Oslofjord",
    biome: "Sediment — estuary",
    country: "Norway",
    lat: 59.41,
    lon: 10.48,
    date: "2021-06-15",
    platform: "Oxford Nanopore PromethION",
    bp: 6_700_000_000,
    genome_equivalents: 142.3,
    paper: {
      title: "Long-read sediment metagenomics resolves ARG-mobile element linkage in a Nordic fjord",
      journal: "Microbiome",
      year: 2023,
      doi: "10.1186/s40168-023-01502-4",
      extracted: [
        { field: "Antibiotic exposure", value: "Low; upstream municipal outfall 6 km", confidence: "medium", source: "Site, p.2" },
        { field: "Host / matrix", value: "Subtidal estuarine sediment", confidence: "high", source: "Methods, p.3" },
        { field: "Read type", value: "Long-read (Nanopore), ARG–plasmid linkage resolved", confidence: "high", source: "Results, p.7" },
      ],
    },
    context: {
      temp_mean_c: 11.2,
      precip_mm_30d: 52.9,
      soil_moisture: null,
      population_density: 118,
      antibiotic_use_ddd: 7.0,
    },
    args: [
      { gene: "sul1", drug_class: "Sulfonamide", identity: 97.2, depth: 1.84 },
      { gene: "tet(M)", drug_class: "Tetracycline", identity: 95.0, depth: 1.22 },
      { gene: "qacEdelta1", drug_class: "Disinfectant", identity: 98.8, depth: 2.10 },
    ],
  },
  {
    accession: "SRR19887731",
    study: "PRJNA853310",
    title: "Feedlot-adjacent soil resistome, Great Plains",
    biome: "Soil — agricultural",
    country: "United States",
    lat: 40.81,
    lon: -101.72,
    date: "2022-04-28",
    platform: "Illumina NovaSeq 6000",
    bp: 19_300_000_000,
    genome_equivalents: 433.8,
    paper: {
      title: "Macrolide and tetracycline accumulation in soils downwind of cattle feedlots",
      journal: "Applied and Environmental Microbiology",
      year: 2023,
      doi: "10.1128/aem.00455-23",
      extracted: [
        { field: "Antibiotic exposure", value: "Feedlot runoff; tylosin and chlortetracycline use", confidence: "high", source: "Introduction, p.2" },
        { field: "Host / matrix", value: "Surface soil, 0–15 cm", confidence: "high", source: "Methods, p.3" },
        { field: "Distance to feedlot", value: "200–800 m, downwind transect", confidence: "medium", source: "Figure 1" },
      ],
    },
    context: {
      temp_mean_c: 9.7,
      precip_mm_30d: 47.1,
      soil_moisture: 0.22,
      population_density: 3,
      antibiotic_use_ddd: 21.5,
    },
    args: [
      { gene: "tet(M)", drug_class: "Tetracycline", identity: 98.6, depth: 7.44 },
      { gene: "tet(W)", drug_class: "Tetracycline", identity: 97.9, depth: 5.10 },
      { gene: "ermB", drug_class: "Macrolide", identity: 98.8, depth: 6.33 },
      { gene: "ermF", drug_class: "Macrolide", identity: 97.1, depth: 3.27 },
      { gene: "sul1", drug_class: "Sulfonamide", identity: 98.0, depth: 2.41 },
      { gene: "aph(3')-IIIa", drug_class: "Aminoglycoside", identity: 96.8, depth: 1.58 },
    ],
  },
];

// Derived field: ARG copies per genome = depth / genome_equivalents-scaling.
// In the real pipeline this is hit depth normalised by the SingleM
// genome-equivalent denominator. Here we expose a simple, transparent
// computation so the raw-vs-normalised toggle is honest demo maths.
ARGIVE_DATA.forEach((d) => {
  d.args.forEach((a) => {
    // copies per genome ≈ (hit depth) / (mean genome coverage proxy)
    // genome coverage proxy scales with genome_equivalents/100 for the demo
    const genomeCovProxy = d.genome_equivalents / 100;
    a.copies_per_genome = +(a.depth / genomeCovProxy).toFixed(3);
  });
});

if (typeof module !== "undefined") module.exports = ARGIVE_DATA;
