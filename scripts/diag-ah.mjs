// Profitmancer: one-off diagnostic — how WoW Forever splits auction houses between server types (rulesets) and factions.
// Run by hand from Actions → "Diagnose AH" → Run workflow. Reads only; publishes nothing.
const env = process.env;
const REGION = env.REGION || "eu", NAMESPACE = env.NAMESPACE || "dynamic-forever-eu";
const r0 = await fetch("https://oauth.battle.net/token", { method: "POST", headers: { Authorization: "Basic " + Buffer.from(env.BLIZZARD_CLIENT_ID + ":" + env.BLIZZARD_CLIENT_SECRET).toString("base64"), "Content-Type": "application/x-www-form-urlencoded" }, body: "grant_type=client_credentials" });
const tok = (await r0.json()).access_token;
async function api(path, ns = NAMESPACE) {
  const r = await fetch(`https://${REGION}.api.blizzard.com${path}${path.includes("?") ? "&" : "?"}namespace=${encodeURIComponent(ns)}&locale=en_US`, { headers: { Authorization: "Bearer " + tok } });
  return { status: r.status, lm: r.headers.get("last-modified"), body: r.ok ? await r.json() : await r.text().catch(() => "") };
}
const short = o => JSON.stringify(o, (k, v) => k === "_links" || k === "key" ? undefined : v).slice(0, 1500);
const log = (...a) => console.log("DIAG", ...a);

const idx = await api("/data/wow/ruleset/index");
log("ruleset index", idx.status, short(idx.body));
const rulesets = ((idx.body && (idx.body.rulesets || Object.values(idx.body).find(Array.isArray))) || []).map(r => r.id);
if (!rulesets.length) rulesets.push(1, 2, 3, 15);

const ids = new Set();
for (const rs of rulesets) {
  const d = await api(`/data/wow/ruleset/${rs}`); log(`ruleset ${rs} detail`, d.status, short(d.body));
  const a = await api(`/data/wow/ruleset/${rs}/auctions/`); log(`ruleset ${rs} auctions index`, a.status, short(a.body));
  for (const h of (a.body && a.body.auctions) || []) ids.add(h.id);
}
for (const p of ["/data/wow/realm/index", "/data/wow/connected-realm/index", "/data/wow/auctions/index"]) { const x = await api(p); log(p, x.status, short(x.body)); }

// Fingerprint of every (ruleset, auction house): same fingerprint under two rulesets = the ruleset number is ignored
const rows = [];
for (const id of [...ids].sort((a, b) => a - b)) {
  for (const rs of rulesets) {
    const h = await api(`/data/wow/ruleset/${rs}/auctions/${id}`);
    const list = h.body && Array.isArray(h.body.auctions) ? h.body.auctions : [];
    let sum = 0, mn = Infinity, mx = 0; for (const x of list) { sum = (sum + x.id) % 1e9; mn = Math.min(mn, x.id); mx = Math.max(mx, x.id); }
    const extra = h.body && typeof h.body === "object" ? Object.keys(h.body).filter(k => !["auctions", "_links", "commodities"].includes(k)).map(k => k + "=" + JSON.stringify(h.body[k]).slice(0, 120)).join(" ") : "";
    rows.push({ id, rs, status: h.status, n: list.length, fp: list.length ? `${mn}-${mx}-${sum}` : "", lm: h.lm, extra });
    log(`AH ${id} ruleset ${rs}: status ${h.status}, ${list.length} auctions, fp ${rows.at(-1).fp}, ${h.lm} ${extra}`);
  }
}
log("SUMMARY");
for (const id of [...ids].sort((a, b) => a - b)) {
  const r = rows.filter(x => x.id === id);
  log(`AH ${id}: ${r.map(x => `rs${x.rs}=${x.n}`).join(" ")} → ${new Set(r.map(x => x.fp)).size === 1 ? "SAME data for every ruleset" : "DIFFERENT data per ruleset"}`);
}
