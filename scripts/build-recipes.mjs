// Build recipe acquisition details (REC_SRC) and craft cooldowns (CD_HOURS)
// from Wowhead Forever exports, then inject them into profitmancer.html.
// Usage: node scripts/build-recipes.mjs <wh-folder>
// <wh-folder> holds <profession>.json ({prof, spells, items}) and zones.json.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const PAGE = path.join(ROOT, "profitmancer.html");
const OUT = path.join(ROOT, "data", "recipe-sources.json");
const WH = process.argv[2];
if (!WH || !fs.existsSync(WH)) { console.error("usage: node scripts/build-recipes.mjs <wh-folder>"); process.exit(1); }

// Site profession code -> Wowhead file
const FILES = { alch: "alchemy", cook: "cooking", bs: "blacksmithing", lw: "leatherworking", tail: "tailoring", eng: "engineering", ench: "enchanting", mine: "mining", fa: "first-aid" };
// Original page defaults (kept when Wowhead gives no cooldown). Not re-read from the page on purpose.
const DEFAULT_CD = { 12360: 23, 251290: 47, 14342: 96, 15407: 96, 15846: 23, 17771: 24 };
const START = "// REC_SRC:start", END = "// REC_SRC:end";

// ---- read page constants (one JSON literal per line) ----
let html = fs.readFileSync(PAGE, "utf8");
function pageConst(name) {
  const m = html.match(new RegExp("^const " + name + "\\s*=\\s*([\\[{].*?)\\r?$", "m"));
  if (!m) throw new Error("page const not found: " + name);
  // drop the trailing ";" and any "// comment" after the literal
  let s = m[1]; const end = Math.max(s.lastIndexOf("};"), s.lastIndexOf("];"));
  if (end >= 0) s = s.slice(0, end + 1);
  try { return JSON.parse(s); } catch (e) { throw new Error("cannot parse page const " + name + ": " + e.message); }
}
const DATA = pageConst("DATA"), COOK = pageConst("COOK"), PROFX = pageConst("PROFX");
const RITEMS = pageConst("RITEMS"), FLIP_SRC = pageConst("FLIP_SRC"), FLIP_NPC = pageConst("FLIP_NPC");
const FLIP_BUY = pageConst("FLIP_BUY"), PZONES = pageConst("ZONES");
let RVEND = {}; try { RVEND = pageConst("RVEND"); } catch { /* optional */ }

// ---- read Wowhead exports ----
const ZONES = JSON.parse(fs.readFileSync(path.join(WH, "zones.json"), "utf8"));
// Reputation required by recipe items ({itemId: {faction?, rank}}), made by scripts/fetch-rep.mjs; optional
const REP = fs.existsSync(path.join(WH, "rep.json")) ? JSON.parse(fs.readFileSync(path.join(WH, "rep.json"), "utf8")) : {};
const WHD = {};
for (const [k, f] of Object.entries(FILES)) {
  const p = path.join(WH, f + ".json");
  if (!fs.existsSync(p)) throw new Error("missing " + p);
  WHD[k] = JSON.parse(fs.readFileSync(p, "utf8"));
}

// ---- helpers ----
const unresolvedZones = {}, unresolvedQuestCats = {};
function zoneName(id, ctx) {
  if (id == null) return undefined;
  const n = ZONES[id] || PZONES[id];
  if (n) return n;
  (unresolvedZones[id] = unresolvedZones[id] || new Set()).add(ctx);
  return undefined;
}
const norm = s => String(s || "").toLowerCase().replace(/[^a-z0-9]/g, "");
const PREFIX = /^(?:Recipe|Pattern|Plans|Schematic|Formula|Design|Manual|Guide|Blueprint|Technique)\s*:\s*/i;
function parseCd(s) {
  const m = /^([\d.]+)\s*(day|days|hr|hrs|hour|hours|min|mins|minute|minutes|sec|secs)\b/i.exec(String(s || "").trim());
  if (!m) return null;
  const v = parseFloat(m[1]), u = m[2].toLowerCase();
  const h = u.startsWith("day") ? v * 24 : u.startsWith("h") ? v : u.startsWith("min") ? v / 60 : v / 3600;
  return h >= 1 ? Math.round(h * 10) / 10 : Math.round(h * 1000) / 1000; // sub-hour keeps minute precision
}
const sig = r => (r || []).map(([i, q]) => i + "x" + q).sort().join(",");

// Vendors known by the page for a recipe item (FLIP_SRC / RVEND), as npc ids
function pageVendors(iid) {
  const ids = new Set();
  for (const [n] of FLIP_SRC[iid] || []) ids.add(String(n));
  for (const [n] of RVEND[iid] || []) ids.add(String(n));
  return ids;
}
function vendorCost(iid) {
  const r = RITEMS[iid];
  if (r && r[4] > 0) return r[4];
  if (FLIP_BUY[iid] > 0) return FLIP_BUY[iid];
  return undefined;
}
function vendorEntry(npcName, zone, iid) {
  const e = { t: "vendor", npc: npcName };
  if (zone) e.zone = zone;
  const c = vendorCost(iid); if (c != null) e.cost = c;
  return e;
}
// One Wowhead sourcemore entry -> REC_SRC entry, given the source type it belongs to
function fromMore(type, m, it) {
  const ctx = it.name;
  if (type === 4) {
    if (m.t === 5) {
      const e = { t: "quest", name: m.n };
      if (m.c > 0) { const z = zoneName(m.c, ctx); if (z) e.zone = z; }
      else if (m.c != null) (unresolvedQuestCats[m.c] = unresolvedQuestCats[m.c] || new Set()).add(ctx);
      return e;
    }
    const e = { t: "quest" }; const z = zoneName(m.z, ctx); if (z) e.zone = z; return e;
  }
  if (type === 5) {
    if (m.t === 1) return vendorEntry(m.n, zoneName(m.z, ctx), it.id);
    const e = { t: "vendor" }; const z = zoneName(m.z, ctx); if (z) e.zone = z;
    const c = vendorCost(it.id); if (c != null) e.cost = c; return e;
  }
  if (type === 2) {
    const e = { t: "drop" };
    if (m.n && (m.t === 1 || m.t === 2)) e.npc = m.n; // t2 = chest / object
    const z = zoneName(m.z, ctx); if (z) e.zone = z;
    if (m.bd) e.boss = true;
    return e;
  }
  return { t: "other" };
}
// All entries for one Wowhead recipe item; detail=false when some source has no detail
function itemSources(it) {
  const src = it.source || [], more = it.sourcemore || [];
  const out = []; let detail = true;
  const pv = pageVendors(it.id);
  const pageVendorEntries = () => [...pv].filter(n => FLIP_NPC[n]).map(n => vendorEntry(FLIP_NPC[n][0], zoneName(FLIP_NPC[n][1], it.name), it.id));
  if (more.length && more.length === src.length) {
    src.forEach((s, i) => {
      if (s === 5 && more[i].t !== 1 && pv.size) out.push(...pageVendorEntries());
      else out.push(fromMore(s, more[i], it));
    });
  } else {
    // Unpaired: assign each sourcemore entry to a plausible type, verified where possible
    const used = new Set();
    for (const m of more) {
      let type = null;
      if (m.t === 5 && src.includes(4)) type = 4;
      else if (m.t === 1 && src.includes(5) && pv.has(String(m.ti))) type = 5;
      else if ((m.bd || m.dd != null || m.t === 2) && src.includes(2)) type = 2;
      else if (src.filter(s => [2, 4, 5].includes(s)).length === 1) type = src.find(s => [2, 4, 5].includes(s));
      if (type == null) continue; // ambiguous: don't guess
      out.push(fromMore(type, m, it)); used.add(type);
    }
    for (const s of src) {
      if (used.has(s)) continue;
      if (s === 5 && pv.size) { out.push(...pageVendorEntries()); used.add(5); continue; }
      if (s === 5) { const e = { t: "vendor" }; const c = vendorCost(it.id); if (c != null) e.cost = c; out.push(e); detail = false; }
      else if (s === 2) { out.push({ t: "drop" }); if (!more.length) detail = false; }
      else if (s === 4) { out.push({ t: "quest" }); detail = false; }
      else out.push({ t: "other" });
      used.add(s);
    }
  }
  return { out, detail };
}
const dedupe = list => { const s = new Set(); return list.filter(e => { const k = JSON.stringify(e); return !s.has(k) && s.add(k); }); };

// ---- site recipes, keys computed exactly like mkRec ----
const seen = {};
const keyOf = prof => id => { const sk = prof + id; seen[sk] = (seen[sk] || 0) + 1; const base = prof === "alch" ? String(id) : prof === "cook" ? "c" + id : prof + id; return seen[sk] > 1 ? `${base}-${seen[sk]}` : base; };
const SITE = [];
const add = (prof, list) => { const k = keyOf(prof); for (const row of list) SITE.push({ prof, id: row[0], skill: row[3], r: row[5], key: k(row[0]) }); };
add("alch", DATA.rec); add("cook", COOK.rec);
for (const [p, l] of Object.entries(PROFX.rec)) add(p, l);

// ---- match + build ----
const REC_SRC = {}, CD_HOURS = {}, stats = {}, cdFromWh = {};
const usedSpell = new Set();
for (const prof of Object.keys(FILES)) {
  const d = WHD[prof];
  const byItem = {};
  for (const s of d.spells) if (s.creates && s.creates[0]) (byItem[s.creates[0]] = byItem[s.creates[0]] || []).push(s);
  const byName = {};
  for (const it of d.items) { const n = norm(it.name.replace(PREFIX, "")); (byName[n] = byName[n] || []).push(it); }
  for (const s of d.spells) { const h = parseCd(s.cd); if (h != null && s.creates && s.creates[0]) (cdFromWh[prof] = cdFromWh[prof] || {})[s.creates[0]] = h; }
  const st = stats[prof] = { site: 0, detail: 0, partial: 0, unknown: 0 };
  for (const rec of SITE.filter(x => x.prof === prof)) {
    st.site++;
    const cands = (byItem[rec.id] || []).filter(s => !usedSpell.has(prof + s.id));
    const all = byItem[rec.id] || [];
    const spell = cands.find(s => sig(s.reagents) === sig(rec.r)) || cands.find(s => s.learnedat === rec.skill) || cands[0]
      || all.find(s => sig(s.reagents) === sig(rec.r)) || all[0];
    if (!spell) { REC_SRC[rec.key] = [{ t: "unknown" }]; st.unknown++; continue; }
    usedSpell.add(prof + spell.id);
    const out = []; let detail = true;
    const ssrc = spell.source || [];
    if (ssrc.includes(6)) { const e = { t: "trainer" }; if (spell.trainingcost != null) e.cost = spell.trainingcost; out.push(e); }
    const needItem = ssrc.some(s => s !== 6) || !ssrc.length; // no spell source: the recipe item may still tell
    if (needItem) {
      const itemName = ((DATA.items[rec.id] || COOK.items[rec.id] || PROFX.items[rec.id] || [])[0]);
      const its = byName[norm(spell.name)] || (itemName && byName[norm(itemName)]) || [];
      if (its.length) for (const it of its) { const r = itemSources(it); for (const e of r.out) if (e.t === "vendor" && REP[it.id]) e.rep = REP[it.id]; out.push(...r.out); if (!r.detail) detail = false; }
      else { detail = false; for (const s of ssrc) if (s !== 6) out.push({ t: s === 5 ? "vendor" : s === 2 ? "drop" : s === 4 ? "quest" : "other" }); }
    }
    if (!out.length) { REC_SRC[rec.key] = [{ t: "unknown" }]; st.unknown++; continue; }
    REC_SRC[rec.key] = dedupe(out);
    if (detail) st.detail++; else st.partial++;
  }
}

// ---- cooldowns: Wowhead first, then original defaults ----
// mkRec flags r.cd via `id in CD_HOURS` without the profession, so an item also crafted
// by another profession (e.g. Gold Bar: transmute + smelting) goes to CD_BY_PROF only.
const defaultsKept = [], CD_BY_PROF = {}, collisions = [];
for (const [prof, l] of Object.entries(cdFromWh)) for (const [id, h] of Object.entries(l)) {
  (CD_BY_PROF[prof] = CD_BY_PROF[prof] || {})[id] = h;
  const other = SITE.find(x => x.prof !== prof && String(x.id) === id);
  if (other) collisions.push(prof + ":" + id + " (also " + other.key + ")"); else CD_HOURS[id] = h;
}
for (const [id, h] of Object.entries(DEFAULT_CD)) if (!(id in CD_HOURS)) { CD_HOURS[id] = h; defaultsKept.push(id); }

// ---- guards ----
const siteKeys = new Set(SITE.map(x => x.key));
if (siteKeys.size !== SITE.length) throw new Error("duplicate site keys");
if (Object.keys(REC_SRC).length !== siteKeys.size || ![...siteKeys].every(k => k in REC_SRC)) throw new Error("REC_SRC keys differ from site keys");

// ---- compact encoding: dictionary for repeated strings, expanded at page load ----
const dict = [], dIdx = new Map();
const di = s => { if (!dIdx.has(s)) { dIdx.set(s, dict.length); dict.push(s); } return dIdx.get(s); };
const T = { trainer: 0, vendor: 1, drop: 2, quest: 3, other: 4, unknown: 5 };
// entry -> [type, cost|0, npc|-1, zone|-1, flags] ; flags: 1=boss ; quest name stored in npc slot
const enc = {};
for (const [k, l] of Object.entries(REC_SRC)) enc[k] = l.map(e => {
  const a = [T[e.t], e.cost || 0, e.npc != null ? di(e.npc) : e.name != null ? di(e.name) : -1, e.zone != null ? di(e.zone) : -1, e.boss ? 1 : 0, e.rep ? di(e.rep.rank + "|" + (e.rep.faction || "")) : -1];
  const EMPTY = [null, 0, -1, -1, 0, -1];
  while (a.length > 1 && a[a.length - 1] === EMPTY[a.length - 1]) a.pop();
  return a;
});
const esc = s => JSON.stringify(s).replace(/<\//g, "<\\/");
const block = [
  START,
  "// Generated by scripts/build-recipes.mjs from Wowhead Forever data. Do not edit by hand.",
  "// REC_SRC[rec.key] = [{t:'trainer'|'vendor'|'drop'|'quest'|'other'|'unknown', cost?, npc?, zone?, name?, boss?, rep?:{rank, faction?}}]",
  `const REC_SRC=((d,m)=>{const T=["trainer","vendor","drop","quest","other","unknown"],o={};for(const k in m)o[k]=m[k].map(([t,c,n,z,f,r])=>{const e={t:T[t]};if(c)e.cost=c;if(n!=null&&n>=0)e[t===3?"name":"npc"]=d[n];if(z!=null&&z>=0)e.zone=d[z];if(f&1)e.boss=true;if(r!=null&&r>=0){const q=d[r].split("|");e.rep={rank:q[0]};if(q[1])e.rep.faction=q[1]}return e});return o})(${esc(dict)},${esc(enc)});`,
  "// Craft cooldowns in hours, keyed by created item id (transmutes without an entry default to 20 h)",
  `const CD_HOURS=${esc(CD_HOURS)};`,
  "// Same, per profession (includes items also crafted without cooldown by another profession)",
  `const CD_BY_PROF=${esc(CD_BY_PROF)};`,
  `const cdTxt=id=>{const h=CD_HOURS[id]||20;if(h<1)return Math.round(h*60)+" min";return h%24===0?h/24+" d":Math.round(h*10)/10+" h"};`,
  END,
].join("\n");

// ---- write JSON ----
fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, JSON.stringify({ REC_SRC, CD_HOURS, CD_BY_PROF }) + "\n");

// ---- inject (re-read the page right before writing) ----
html = fs.readFileSync(PAGE, "utf8");
const eol = html.includes("\r\n") ? "\r\n" : "\n";
const blk = block.split("\n").join(eol);
const si = html.indexOf(START), ei = html.indexOf(END);
if (si >= 0 && ei > si) {
  html = html.slice(0, si) + blk + html.slice(ei + END.length);
} else {
  // First run: replace the hand-written CD_HOURS + cdTxt lines
  const re = /^const CD_HOURS=\{[^\n]*\};\r?\n(const cdTxt=[^\n]*\r?\n)?/m;
  if (!re.test(html)) throw new Error("CD_HOURS line not found and no markers present");
  html = html.replace(re, m => blk + (m.endsWith("\r\n") ? "\r\n" : "\n"));
}
if ((html.match(/\bconst CD_HOURS\s*=/g) || []).length !== 1) throw new Error("CD_HOURS must be declared exactly once");
if ((html.match(/\bconst cdTxt\s*=/g) || []).length !== 1) throw new Error("cdTxt must be declared exactly once");
fs.writeFileSync(PAGE, html);

// ---- report ----
console.log("prof   site  detail  partial  unknown");
for (const [p, s] of Object.entries(stats)) console.log(p.padEnd(6), String(s.site).padStart(4), String(s.detail).padStart(7), String(s.partial).padStart(8), String(s.unknown).padStart(8));
console.log("block size:", (Buffer.byteLength(blk) / 1024).toFixed(1), "KB; dictionary:", dict.length, "strings");
console.log("cooldowns from Wowhead:", JSON.stringify(cdFromWh));
console.log("defaults kept (unconfirmed):", defaultsKept.join(", ") || "none");
console.log("kept out of CD_HOURS (shared item id):", collisions.join("; ") || "none");
const fmt = o => Object.entries(o).map(([k, v]) => k + " (" + [...v].slice(0, 3).join(" / ") + ")").join("; ") || "none";
console.log("unresolved zone ids:", fmt(unresolvedZones));
console.log("unresolved quest categories:", fmt(unresolvedQuestCats));
