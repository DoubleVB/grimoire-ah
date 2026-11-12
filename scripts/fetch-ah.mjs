// Grimoire — hourly WoW Forever auction house scan (runs on GitHub Actions, Node 20+, no dependencies)
// Writes data/latest.json (current prices for every item) and data/snaps.json (history of the Grimoire's items).
import { readFile, writeFile } from "node:fs/promises";

const env = process.env;
const REGION = env.REGION || "eu";
const NAMESPACE = env.NAMESPACE || "dynamic-forever-eu";
const RULESET = env.RULESET || "1";
const AH_IDS = (env.AH_IDS || "").split(/[,\s]+/).filter(Boolean);
const KEEP_DAYS = +(env.KEEP_DAYS || 14);
if (!env.BLIZZARD_CLIENT_ID || !env.BLIZZARD_CLIENT_SECRET) throw new Error("Missing BLIZZARD_CLIENT_ID / BLIZZARD_CLIENT_SECRET secrets.");
if (!AH_IDS.length) throw new Error("Missing the AH_IDS variable (auction house id(s), e.g. 113).");

async function token() {
  const r = await fetch("https://oauth.battle.net/token", {
    method: "POST",
    headers: { Authorization: "Basic " + Buffer.from(env.BLIZZARD_CLIENT_ID + ":" + env.BLIZZARD_CLIENT_SECRET).toString("base64"), "Content-Type": "application/x-www-form-urlencoded" },
    body: "grant_type=client_credentials",
  });
  if (!r.ok) throw new Error("Blizzard authentication refused: " + r.status);
  return (await r.json()).access_token;
}

let lastMod = 0;
async function api(tok, path) {
  const r = await fetch(`https://${REGION}.api.blizzard.com${path}?namespace=${encodeURIComponent(NAMESPACE)}&locale=en_US`, { headers: { Authorization: "Bearer " + tok } });
  if (r.status === 404) return null;
  if (!r.ok) throw new Error(`API ${r.status} at ${path}`);
  const lm = Date.parse(r.headers.get("last-modified") || ""); if (lm) lastMod = Math.max(lastMod, lm);
  return r.json();
}

async function auctionsOf(tok, id) {
  for (const base of [`/data/wow/ruleset/${RULESET}/auctions/${id}`, `/data/wow/connected-realm/${RULESET}/auctions/${id}`]) {
    const h = await api(tok, base);
    if (!h) continue;
    let all = Array.isArray(h.auctions) ? [...h.auctions] : [];
    if (Array.isArray(h.commodities)) all = all.concat(h.commodities);
    else { const c = await api(tok, base + "/commodities"); if (c && Array.isArray(c.auctions)) all = all.concat(c.auctions); }
    if (all.length) return all;
  }
  return [];
}

const readJson = async (f, d) => { try { return JSON.parse(await readFile(f, "utf8")); } catch { return d; } };

const tok = await token();
let auctions = [];
for (const id of AH_IDS) auctions = auctions.concat(await auctionsOf(tok, id));
if (!auctions.length) throw new Error("The auction house answered with no auctions: check RULESET and AH_IDS.");
const t = lastMod || Date.now();

const snapsFile = await readJson("data/snaps.json", { v: 1, snaps: [] });
const last = snapsFile.snaps[snapsFile.snaps.length - 1];
if (last && Math.abs(last.t - t) < 60000) { console.log("No new data from Blizzard since " + new Date(t).toISOString()); process.exit(0); }

// Same maths as the Grimoire: lowest price, "market" = average of the cheapest 15%, quantity listed
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

const tracked = new Set((await readJson("data/items.json", [])).map(String));
const items = {}; for (const id in prices) if (tracked.has(id)) items[id] = [prices[id][2], prices[id][0]];
snapsFile.snaps.push({ t, items });
snapsFile.snaps = snapsFile.snaps.filter(s => s.t >= t - KEEP_DAYS * 86400000).sort((a, b) => a.t - b.t);

await writeFile("data/latest.json", JSON.stringify({ v: 1, t, count: auctions.length, ah: AH_IDS, prices }));
await writeFile("data/snaps.json", JSON.stringify(snapsFile));
console.log(`Saved ${auctions.length} auctions (${Object.keys(items).length} Grimoire items), Blizzard data from ${new Date(t).toISOString()}. History: ${snapsFile.snaps.length} scans.`);
