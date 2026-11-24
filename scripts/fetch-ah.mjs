// Profitmancer — hourly WoW Forever auction house scan (runs on GitHub Actions, Node 20+, no dependencies)
// Scans EVERY Forever market (each server type × faction) so anyone can use the data without a Blizzard key.
// Writes, per market, in data/ah/<server type>-<faction>/ (e.g. pvp-horde, pve-alliance, rppvp-blackwater):
//   latest.json, catalog.json   current prices for every item
//   snaps.json, qty24.json      history (sales estimates)
//   ProfitmancerData.lua        the same prices, ready for the in-game Profitmancer addon
// plus, per faction, data/ah/<faction>-auction-house/ProfitmancerData.lua with every server type in one file,
// data/index.json (the list of markets) and, for very old copies of the website, data/latest.json + data/snaps.json.
import { readFile, writeFile, mkdir, readdir, rm } from "node:fs/promises";

const env = process.env;
const REGION = env.REGION || "eu";
const NAMESPACE = env.NAMESPACE || "dynamic-forever-eu";
const KEEP_DAYS = +(env.KEEP_DAYS || 7);
// the market also published at the root (data/latest.json, data/snaps.json) for very old copies of the website
const MAIN_KEY = env.MAIN_KEY || "pvp-horde";
if (!env.BLIZZARD_CLIENT_ID || !env.BLIZZARD_CLIENT_SECRET) throw new Error("Missing BLIZZARD_CLIENT_ID / BLIZZARD_CLIENT_SECRET secrets.");

// Every request has a deadline (the whole body included: the auction lists weigh tens of MB)
const API_TIMEOUT = +(env.API_TIMEOUT_MS || 150000), ITEM_TIMEOUT = 30000;
async function token() {
  const r = await fetch("https://oauth.battle.net/token", {
    method: "POST",
    headers: { Authorization: "Basic " + Buffer.from(env.BLIZZARD_CLIENT_ID + ":" + env.BLIZZARD_CLIENT_SECRET).toString("base64"), "Content-Type": "application/x-www-form-urlencoded" },
    body: "grant_type=client_credentials",
    signal: AbortSignal.timeout(30000),
  });
  if (!r.ok) throw new Error("Blizzard authentication refused: " + r.status);
  return (await r.json()).access_token;
}

// Blizzard API. Dynamic namespace (auction houses) in en_US, with the Last-Modified date kept in `state`;
// static namespaces (items) with no locale, so names come with every language (EN + FR).
async function api(tok, path, { ns = NAMESPACE, locale = "en_US", state = null, timeout = API_TIMEOUT } = {}) {
  const url = `https://${REGION}.api.blizzard.com${path}?namespace=${encodeURIComponent(ns)}` + (locale ? "&locale=" + locale : "");
  for (let attempt = 0; ; attempt++) {
    const wait = () => new Promise(res => setTimeout(res, 2000 * (attempt + 1)));
    let r;
    try {
      r = await fetch(url, { headers: { Authorization: "Bearer " + tok }, signal: AbortSignal.timeout(timeout) });
      if (r.status === 404) return null;
      if ((r.status === 429 || r.status >= 500) && attempt < 3) { await wait(); continue; }
      if (!r.ok) throw new Error(`API ${r.status} at ${path}`);
      const body = await r.json();
      const lm = Date.parse(r.headers.get("last-modified") || ""); if (lm && state) state.lastMod = Math.max(state.lastMod || 0, lm);
      return body;
    } catch (e) {
      // time out or network error ("fetch failed"): retried like a 5xx
      if ((e.name === "TimeoutError" || e.name === "AbortError" || e instanceof TypeError) && attempt < 2) { await wait(); continue; }
      throw e.name === "TimeoutError" ? new Error(`API timeout at ${path}`) : e;
    }
  }
}
const locName = n => typeof n === "string" ? n : (n && (n.en_US || n.en_GB || Object.values(n)[0])) || "";
const slug = s => String(s).toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") || "ah";
// Missing file -> default value. Unreadable / corrupt file -> error: never restart a history from zero in silence.
const readJson = async (f, d) => {
  let txt;
  try { txt = await readFile(f, "utf8"); } catch (e) { if (e.code === "ENOENT") return d; throw e; }
  try { return JSON.parse(txt); } catch (e) { throw new Error(`${f} is corrupt (${e.message})`); }
};

// ——— Which auction house is which market ———
// On WoW Forever the ruleset number in the URL changes nothing: every ruleset lists the same 15 auction houses,
// one per server type and faction. Checked by hand (one character per server type, Nov 2026):
const MARKETS = [
  { rs: "PvP", name: "PvP", fr: "JcJ", ids: { alliance: 110, horde: 113, blackwater: 116 } },
  { rs: "PvE", name: "Normal", fr: "Normal", ids: { alliance: 111, horde: 114, blackwater: 117 } },
  { rs: "HC", name: "Hardcore", fr: "Hardcore", ids: { alliance: 112, horde: 115, blackwater: 118 } },
  { rs: "RP", name: "RP", fr: "RP", ids: { alliance: 119, horde: 120, blackwater: 121 } },
  { rs: "RPPvP", name: "RP-PvP", fr: "RP-JcJ", ids: { alliance: 123, horde: 124, blackwater: 125 } },
];
const FACTIONS = { alliance: "Alliance", horde: "Horde", blackwater: "Blackwater" };
const FACTION_FR = { alliance: "Alliance", horde: "Horde", blackwater: "Eaux-Noires" };
// Before Nov 2026 the scan merged the 5 server types of a faction: those keys still get one file per faction
// (holding every server type) so updaters installed back then keep working, and the addon picks the right type.
const LEGACY = { alliance: "alliance-auction-house", horde: "horde-auction-house", blackwater: "blackwater-auction-house" };

// ——— Discover every auction house: the list Blizzard gives, then one market per (server type, faction) ———
async function discover(tok) {
  let rulesets = [];
  try { const j = await api(tok, "/data/wow/ruleset/index"); rulesets = (j && (j.rulesets || Object.values(j).find(Array.isArray)) || []).map(r => r.id); } catch (e) { console.log("Ruleset index refused: " + e.message); }
  if (!rulesets.length) rulesets = [1];
  const seen = new Map();
  for (const rs of rulesets) {
    try { const j = await api(tok, `/data/wow/ruleset/${rs}/auctions/`); for (const a of (j && j.auctions) || []) if (!seen.has(a.id)) seen.set(a.id, { rs, name: locName(a.name) }); }
    catch (e) { console.log(`Ruleset ${rs}: ${e.message}`); }
  }
  const groups = [];
  for (const m of MARKETS) for (const f in m.ids) {
    const id = m.ids[f], s = seen.get(id);
    if (seen.size && !s) continue; // gone from Blizzard's list
    groups.push({ key: slug(m.rs + "-" + f), rs: m.rs, faction: f, ruleset: (s && s.rs) || rulesets[0], rulesets: [m.name], name: `${FACTIONS[f]} · ${m.name}`, label: `${FACTIONS[f]} · ${m.name}`, labelFr: `${FACTION_FR[f]} · ${m.fr}`, ids: [String(id)] });
  }
  // an auction house Blizzard adds later: scanned on its own until it is named above
  for (const [id, s] of seen) if (!MARKETS.some(m => Object.values(m.ids).includes(id))) {
    groups.push({ key: "ah-" + id, rs: "", faction: "", ruleset: s.rs, rulesets: [], name: `${s.name} #${id}`, label: `${s.name} #${id}`, labelFr: `${s.name} n°${id}`, ids: [String(id)] });
  }
  return groups;
}

async function auctionsOf(tok, rs, id, state) {
  for (const base of [`/data/wow/ruleset/${rs}/auctions/${id}`, `/data/wow/connected-realm/${rs}/auctions/${id}`]) {
    const h = await api(tok, base, { state });
    if (!h) continue;
    let all = Array.isArray(h.auctions) ? [...h.auctions] : [];
    if (Array.isArray(h.commodities)) all = all.concat(h.commodities);
    else { const c = await api(tok, base + "/commodities", { state }); if (c && Array.isArray(c.auctions)) all = all.concat(c.auctions); }
    if (all.length) return all;
  }
  return [];
}

// Same maths as Profitmancer: lowest price, "market" (EMV) = average of the cheapest 15%, quantity listed
function priceTable(auctions) {
  const by = {};
  for (const a of auctions) {
    const id = a.item && a.item.id, q = a.quantity || 1;
    const total = a.buyout ?? (a.unit_price != null ? a.unit_price * q : null);
    if (!id || !total) continue;
    (by[id] = by[id] || []).push([total / q, q]);
  }
  const prices = {};
  for (const id in by) {
    const l = by[id].sort((x, y) => x[0] - y[0]); const tot = l.reduce((s, x) => s + x[1], 0); const lim = Math.max(1, tot * 0.15);
    let n = 0, sum = 0; for (const [p, q] of l) { const take = Math.min(q, lim - n); sum += p * take; n += take; if (n >= lim) break; }
    prices[id] = [Math.round(l[0][0]), Math.round(sum / n), tot];
  }
  return prices;
}

// Units sold over the last 24 h: drops in the listed quantity between scans (extrapolated to 24 h; needs 6 h of scans)
// A scan listing far fewer items than usual (partial answer from Blizzard) is left out: otherwise every item it misses
// would count its whole stock as sold. The threshold is half the median item count of the window (per buffer).
function sold24(snaps, t) {
  const win = snaps.filter(s => s.t >= t - 86400000);
  const sizes = win.map(s => Object.keys(s.items).length).sort((a, b) => a - b);
  const med = sizes.length ? sizes[sizes.length >> 1] : 0;
  const pts = win.filter(s => Object.keys(s.items).length >= med / 2);
  const out = {}; if (pts.length < 2) return out;
  const span = (pts[pts.length - 1].t - pts[0].t) / 86400000; if (span < 0.25) return out;
  const k = span < 1 ? 1 / span : 1;
  const ids = new Set(); pts.forEach(p => Object.keys(p.items).forEach(id => ids.add(id)));
  for (const id of ids) {
    let sold = 0, prev = null;
    for (const p of pts) { const q = p.items[id] ? p.items[id][0] || 0 : 0; if (prev != null && prev > q) sold += prev - q; prev = q; }
    out[id] = Math.round(sold * k);
  }
  return out;
}

const esc = s => String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\r/g, "\\r").replace(/\n/g, "\\n");
// rows from a catalog ({id: [EMV, lowest, quantity, sold 24 h]})
const luaRows = cat => Object.keys(cat).sort((a, b) => a - b).map(id => { const [mk, mn, q, sd] = cat[id]; return `[${id}]={${mk},${mn},${q},${sd ?? -1}}`; }).join(",\n");
const HEAD = "-- {EMV, lowest buyout, quantity listed, sold in the last 24 h (-1 = not enough history)} in copper\n";
function luaFile(g, t, cat, name = "ProfitmancerData") {
  return `-- Profitmancer price data · ${String(g.label).replace(/[\r\n]+/g, " ")} · generated ${new Date(t).toISOString()}\n` + HEAD +
    `${name}={v=1,t=${Math.floor(t / 1000)},key="${esc(g.key)}",ah="${esc(g.label)}",rs="${esc(g.rs)}",p={\n` + luaRows(cat) + `\n}}\n`;
}
// One file per faction holding every server type: "p" is the PvP market (what addons older than 1.3.7 read),
// "alt" the other server types; the addon switches to the one of the character's server type.
function luaFaction(key, list, name = "ProfitmancerData") {
  const [main, ...rest] = list;
  const alt = rest.map(m => `${m.rs}={t=${Math.floor(m.t / 1000)},ah="${esc(m.label)}",p={\n${luaRows(m.items)}\n}}`).join(",\n");
  return `-- Profitmancer price data · ${FACTIONS[main.faction]}, every server type · generated ${new Date(main.t).toISOString()}\n` + HEAD +
    `${name}={v=2,t=${Math.floor(main.t / 1000)},key="${esc(key)}",ah="${esc(main.label)}",rs="${esc(main.rs)}",p={\n${luaRows(main.items)}\n},alt={\n${alt}\n}}\n`;
}

// ——— Names (EN + FR), quality, category and icon of every item seen at the AH, for the site's catalog ———
// Fetched once per item from the static item API and kept in data/names.json; a few thousand per run until complete.
const NAMES_PER_RUN = +(env.NAMES_PER_RUN || 2500);
const QUALITY = { POOR: 0, COMMON: 1, UNCOMMON: 2, RARE: 3, EPIC: 4, LEGENDARY: 5, ARTIFACT: 6, HEIRLOOM: 7 };
// static namespace, every language (no locale)
const apiNs = (tok, path, ns) => api(tok, path, { ns, locale: null, timeout: ITEM_TIMEOUT });
const loc = (n, l) => typeof n === "string" ? n : (n && (n[l] || n.en_US)) || "";
async function itemMeta(tok, houses) {
  const names = await readJson("data/names.json", { v: 1, ns: null, items: {}, classes: {} });
  const ids = new Set();
  for (const h of houses) { const l = await readJson(`data/ah/${h.key}/catalog.json`, null); if (l) Object.keys(l.items).forEach(id => ids.add(id)); }
  // New items first, then the ones the Forever database didn't know (0), retried once in the other Classic databases (-1 = not at Blizzard, then Wowhead; -2 = nowhere)
  const todo = [...[...ids].filter(id => !(id in names.items)).sort((a, b) => a - b), ...[...ids].filter(id => names.items[id] === 0)].slice(0, NAMES_PER_RUN);
  // Icons are Blizzard image files: remember the address they live at (same folder for every icon)
  if (!names.iconBase && names.ns) {
    try { const m = await apiNs(tok, "/data/wow/media/item/2589", names.ns); const a = m && (m.assets || []).find(x => x.key === "icon"); if (a) { names.iconBase = String(a.value).replace(/[^/]+$/, ""); await writeFile("data/names.json", JSON.stringify(names)); } } catch {}
  }
  if (!todo.length && !Object.values(names.items).includes(-1)) { console.log(`Item names: complete (${Object.keys(names.items).length}).`); return; }
  if (!names.ns) {
    for (const ns of [NAMESPACE.replace(/^dynamic-/, "static-"), "static-classic1x-" + REGION, "static-classic-" + REGION]) {
      try { if (await apiNs(tok, "/data/wow/item/2589", ns)) { names.ns = ns; break; } } catch (e) { console.log(`Namespace ${ns}: ${e.message}`); }
    }
    if (!names.ns) throw new Error("no static namespace answers for item 2589");
    console.log("Item names: static namespace " + names.ns);
  }
  const deadline = Date.now() + 8 * 60000; let done = 0, i = 0;
  async function worker() {
    while (i < todo.length && Date.now() < deadline) {
      const id = todo[i++];
      try {
        let ns = names.ns, it = names.items[id] === 0 ? null : await apiNs(tok, `/data/wow/item/${id}`, ns);
        if (!it) for (const alt of ["static-classic1x-" + REGION, "static-classic-" + REGION].filter(x => x !== names.ns)) { it = await apiNs(tok, `/data/wow/item/${id}`, alt); if (it) { ns = alt; break; } }
        if (!it) { names.items[id] = -1; continue; }
        let icon = "";
        try { const m = await apiNs(tok, `/data/wow/media/item/${id}`, ns); const a = m && (m.assets || []).find(x => x.key === "icon"); if (a) { icon = String(a.value).split("/").pop().replace(/\.jpg$/, ""); if (ns === names.ns) names.iconBase = names.iconBase || String(a.value).replace(/[^/]+$/, ""); else icon = String(a.value); } } catch {}
        const c = it.item_class || {}, sc = it.item_subclass || {};
        if (c.id != null) names.classes[c.id] = [loc(c.name, "en_US"), loc(c.name, "fr_FR")];
        if (c.id != null && sc.id != null) names.classes[c.id + "-" + sc.id] = [loc(sc.name, "en_US"), loc(sc.name, "fr_FR")];
        names.items[id] = [loc(it.name, "en_US"), loc(it.name, "fr_FR"), QUALITY[it.quality && it.quality.type] ?? 1, c.id ?? -1, sc.id ?? -1, it.level || 0, it.required_level || 0, icon];
        done++;
      } catch (e) { /* retried next run */ }
    }
  }
  await Promise.all(Array.from({ length: 10 }, worker));
  // Items Blizzard's databases don't know: Wowhead's public tooltips (name EN/FR, quality, icon, category, levels)
  const miss = Object.keys(names.items).filter(id => names.items[id] === -1 && ids.has(id)).slice(0, NAMES_PER_RUN);
  let wh = 0, j = 0;
  async function whWorker() {
    while (j < miss.length && Date.now() < deadline + 4 * 60000) {
      const id = miss[j++];
      try {
        const [en, fr] = await Promise.all(["", "?locale=2"].map(q => fetch(`https://nether.wowhead.com/forever/tooltip/item/${id}${q}`, { signal: AbortSignal.timeout(20000) }).then(r => r.ok ? r.json() : null)));
        if (!en || !en.name) { names.items[id] = -2; continue; }
        const tip = String(en.tooltip || ""), sc = tip.match(/scstart(\d+):(\d+)/);
        const req = tip.match(/Requires Level (\d+)/), il = tip.match(/Item Level (\d+)/);
        names.items[id] = [en.name, (fr && fr.name) || en.name, en.quality ?? 1, sc ? +sc[1] : -1, sc ? +sc[2] : -1, il ? +il[1] : 0, req ? +req[1] : 0, en.icon || ""];
        wh++;
      } catch { /* retried next run */ }
    }
  }
  if (miss.length) await Promise.all(Array.from({ length: 6 }, whWorker));
  if (wh) console.log(`Item names: +${wh} from Wowhead.`);
  await writeFile("data/names.json", JSON.stringify(names));
  const v = Object.values(names.items);
  console.log(`Item names: +${done} this run, ${v.filter(Array.isArray).length} named, ${v.filter(x => x === 0).length} to retry, ${v.filter(x => x === -1).length} for Wowhead, ${v.filter(x => x === -2).length} unknown, ${[...ids].filter(id => !(id in names.items)).length} not tried yet.`);
}

const tok = await token();
const groups = await discover(tok);
console.log(`Found ${groups.length} auction house(s): ${groups.map(g => g.label + " [" + g.ids.join(",") + "]").join(" | ")}`);
const tracked = new Set((await readJson("data/items.json", [])).map(String));
const oldIndex = await readJson("data/index.json", { houses: [] });
const index = [];
let failures = 0;
const entry = (g, t, count, scans) => ({ key: g.key, rs: g.rs, faction: g.faction, ruleset: g.ruleset, rulesets: g.rulesets, name: g.name, label: g.label, labelFr: g.labelFr, ah: g.ids, t, count, scans });
// Market not scanned this run: keep its previous index entry (or rebuild one from its files), so its folder and
// the files the updaters download are kept instead of being deleted at the end of the run.
async function keepPrevious(g) {
  const prev = oldIndex.houses.find(h => h.key === g.key);
  if (prev) { const { missingSince, ...p } = prev; index.push(p); return; }
  try {
    const c = await readJson(`data/ah/${g.key}/catalog.json`, null), s = await readJson(`data/ah/${g.key}/snaps.json`, null);
    if (c && c.t) index.push(entry(g, c.t, 0, s && Array.isArray(s.snaps) ? s.snaps.length : 0));
  } catch (e) { console.log(`::warning::${g.label}: previous files unreadable (${e.message})`); }
}
const readable = f => readFile(f, "utf8").then(x => { if (!x) return false; JSON.parse(x); return true; }, () => false).catch(() => false);

for (const g of groups) {
  const dir = `data/ah/${g.key}`;
  try {
    const state = { lastMod: 0 };
    let auctions = [];
    for (const id of g.ids) auctions = auctions.concat(await auctionsOf(tok, g.ruleset, id, state));
    if (!auctions.length) { console.log(`${g.label}: no auctions`); await keepPrevious(g); continue; }
    const t = state.lastMod || Date.now();
    await mkdir(dir, { recursive: true });
    const snapsFile = await readJson(`${dir}/snaps.json`, null) || { v: 1, snaps: [] };
    const last = snapsFile.snaps[snapsFile.snaps.length - 1];
    // a missing, empty or corrupt price file is rewritten even when Blizzard has nothing new
    const fresh = !(await readFile(`${dir}/ProfitmancerData.lua`, "utf8").catch(() => "")) || !(await readable(`${dir}/catalog.json`));
    const prev = oldIndex.houses.find(h => h.key === g.key);
    if (last && Math.abs(last.t - t) < 60000 && !fresh && prev) { console.log(`${g.label}: no new data since ${new Date(t).toISOString()}`); const { missingSince, ...p } = prev; index.push(p); continue; }
    const prices = priceTable(auctions);
    const items = {}; for (const id in prices) if (tracked.has(id)) items[id] = [prices[id][2], prices[id][0]];
    if (!(last && Math.abs(last.t - t) < 60000)) snapsFile.snaps.push({ t, items });
    snapsFile.snaps = snapsFile.snaps.filter(s => s.t >= t - KEEP_DAYS * 86400000).sort((a, b) => a.t - b.t);
    // Quantities of EVERY item over the last 26 h, so 24 h sales exist for the whole catalog (not only Profitmancer's items)
    const qbuf = await readJson(`${dir}/qty24.json`, { v: 1, snaps: [] });
    if (!qbuf.snaps.some(x => Math.abs(x.t - t) < 60000)) { const q = {}; for (const id in prices) q[id] = [prices[id][2]]; qbuf.snaps.push({ t, items: q }); }
    qbuf.snaps = qbuf.snaps.filter(x => x.t >= t - 26 * 3600000).sort((a, b) => a.t - b.t);
    const sold = Object.assign(sold24(snapsFile.snaps, t), sold24(qbuf.snaps, t));
    const catalog = {}; for (const id in prices) { const [mn, mk, q] = prices[id]; catalog[id] = [mk, mn, q, sold[id] ?? -1]; }
    await writeFile(`${dir}/qty24.json`, JSON.stringify(qbuf));
    await writeFile(`${dir}/catalog.json`, JSON.stringify({ v: 1, t, key: g.key, label: g.label, items: catalog }));
    const latest = { v: 1, t, key: g.key, label: g.label, count: auctions.length, ah: g.ids, prices };
    await writeFile(`${dir}/latest.json`, JSON.stringify(latest));
    await writeFile(`${dir}/snaps.json`, JSON.stringify(snapsFile));
    await writeFile(`${dir}/ProfitmancerData.lua`, luaFile(g, t, catalog));
    if (g.key === MAIN_KEY) {
      await writeFile("data/latest.json", JSON.stringify(latest));
      await writeFile("data/snaps.json", JSON.stringify(snapsFile));
    }
    index.push(entry(g, t, auctions.length, snapsFile.snaps.length));
    console.log(`${g.label}: ${auctions.length} auctions, ${Object.keys(items).length} Profitmancer items, data from ${new Date(t).toISOString()}, ${snapsFile.snaps.length} scans.`);
  } catch (e) {
    failures++; console.log(`::error::${g.label}: FAILED ${e.message}`);
    await keepPrevious(g);
  }
}
if (!index.length) throw new Error("No auction house could be scanned: check the Blizzard secrets.");
// A market Blizzard did not list this time (one refused call, a temporary omission...) keeps its entry and files
// for KEEP_DAYS days (marked "missingSince") before being dropped, instead of losing its history at once.
for (const h of oldIndex.houses) {
  if (index.some(x => x.key === h.key) || groups.some(g => g.key === h.key)) continue;
  const since = h.missingSince || Date.now();
  if (Date.now() - since < KEEP_DAYS * 86400000) { index.push({ ...h, missingSince: since }); console.log(`::warning::${h.label}: not listed by Blizzard since ${new Date(since).toISOString()}, previous data kept.`); }
  else console.log(`::warning::${h.label}: not listed by Blizzard for ${KEEP_DAYS} days, removed.`);
}
try { await itemMeta(tok, index); } catch (e) { console.log("::warning::Item names: " + e.message); }
// One file per faction with every server type (see luaFaction), at the keys updaters installed before Nov 2026 use
const factions = [];
for (const f in LEGACY) {
  try {
    const list = [];
    for (const m of MARKETS) {
      const h = index.find(x => x.rs === m.rs && x.faction === f); if (!h) continue;
      const c = await readJson(`data/ah/${h.key}/catalog.json`, null); if (!c) continue;
      list.push({ rs: m.rs, faction: f, label: h.label, t: c.t, items: c.items });
    }
    if (!list.length) continue;
    const dir = `data/ah/${LEGACY[f]}`;
    // keep only the two price files there (the old merged history is meaningless now)
    await rm(dir, { recursive: true, force: true }); await mkdir(dir, { recursive: true });
    await writeFile(`${dir}/ProfitmancerData.lua`, luaFaction(LEGACY[f], list));
    // DEPRECATED: compat anciens addons (nom d'origine), à retirer quand plus utilisé
    await writeFile(`${dir}/GrimoireData.lua`, luaFaction(LEGACY[f], list, "GrimoireData")); // addon's former name
    factions.push({ key: LEGACY[f], faction: f, label: FACTIONS[f], labelFr: FACTION_FR[f], rs: list.map(m => m.rs) });
  } catch (e) {
    // keep last run's faction file (and its index entry) rather than publishing nothing
    failures++; console.log(`::error::${FACTIONS[f]} (every server type): FAILED ${e.message}`);
    const old = (oldIndex.factions || []).find(x => x.key === LEGACY[f]); if (old) factions.push(old);
  }
}
// Remove the folders of auction houses that are no longer scanned
for (const d of await readdir("data/ah").catch(() => [])) if (!index.some(h => h.key === d) && !factions.some(h => h.key === d)) await rm(`data/ah/${d}`, { recursive: true, force: true });
await writeFile("data/index.json", JSON.stringify({ v: 2, t: Date.now(), houses: index, factions }, null, 1));
console.log(`Done: ${index.length} auction house(s) published, ${failures} failure(s).`);
