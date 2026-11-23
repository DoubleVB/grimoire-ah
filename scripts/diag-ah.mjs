// Profitmancer: one-off diagnostic — prices of common items in every WoW Forever auction house, to tell which house is which server type.
// Run by hand from Actions → "Diagnose AH" → Run workflow. Reads only; publishes nothing.
const env = process.env;
const REGION = env.REGION || "eu", NAMESPACE = env.NAMESPACE || "dynamic-forever-eu";
const r0 = await fetch("https://oauth.battle.net/token", { method: "POST", headers: { Authorization: "Basic " + Buffer.from(env.BLIZZARD_CLIENT_ID + ":" + env.BLIZZARD_CLIENT_SECRET).toString("base64"), "Content-Type": "application/x-www-form-urlencoded" }, body: "grant_type=client_credentials" });
const tok = (await r0.json()).access_token;
const ITEMS = new Set("2515,8069,10513,8067,3033,2516,8068,2512,2519,11285,10512,4306,3371,18042,14047,11284,3465,3030,15997,6359,3464,2589,1081,12365,18945,4592,3685,2678,2835,4304,6358,4603,7912,8170,10620,12359,13465,13545,2592,4338,13422,247786,3860,2318,6289,13423,5075,11630,6362,2841,2319,2840,2770,3858,6308,4593,2836,274964,3358,2450,4234,3859,13758,11083,3530,8365,6371,2772,2581,2320,6450,13755,9399,6887,765,6303,2447,4289,4536,2934,2692,2321,4357,12207,3818,730,8167,2449,5527,3356,17056,4625,4387,3575,11018,3531,2838,248825,13928,13463,8831,10940,4470,5504,6657,2771,769,6361,248815,3576,13760,13932,279981,2453,10286,8483,6290,3820,785,3713,13757,3385,159,2996,8932,3470,7286,4594,3357,15420,5140,13933,6451,13754,249428,251291,5116,783,6291,4404,21153,4377,5503,5634,8153,17057,10938,12037,17058,6947,4339,13889,2605,13466,2842,3241,2928,254432,3827,2452,6889,13467,4233,7972,3821,16204,5633,3726,3173,3731,7676,13464,7965,11185,774,3478,15992,12208,5472,13927,6370,5997,7072,4371,8165,11370,2775,250947,8839,2677,279967,729,8169,8364,6522,21071,12404,11137,2880,8925,2687,21217,7974,4358,3928,8846,5095,3172,13759,4375,6533,2672,7966,249410,2304,11184,3486,279968,3355,3404,4461,2997,3819,3369,8150,5165,4291,10558,4364,2683,5530,13888,9259,4231,12205,4278,2679,4479,8151,12644,4611,5525,249426,14048,16971,279960,13935,8838,8173,4337".split(",").map(Number));
for (const id of [110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 123, 124, 125]) {
  const r = await fetch(`https://${REGION}.api.blizzard.com/data/wow/ruleset/1/auctions/${id}?namespace=${NAMESPACE}&locale=en_US`, { headers: { Authorization: "Bearer " + tok } });
  const j = r.ok ? await r.json() : {};
  const out = {};
  for (const a of j.auctions || []) {
    const it = a.item && a.item.id; if (!ITEMS.has(it)) continue;
    const q = a.quantity || 1, u = a.unit_price ?? (a.buyout != null ? a.buyout / q : null); if (u == null) continue;
    const o = out[it] = out[it] || [Infinity, 0]; o[0] = Math.min(o[0], Math.round(u)); o[1] += q;
  }
  console.log("DIAG2 " + id + " " + r.headers.get("last-modified") + " " + JSON.stringify(out));
}
