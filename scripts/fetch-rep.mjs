// Reads the reputation requirement of recipe items from Wowhead Forever item tooltips.
// Usage: node scripts/fetch-rep.mjs <folder with wh json> [delayMs=1000]
// Writes <folder>/rep.json: { itemId: {faction?, rank} }. Resumable; stops at the first 403/429.
import fs from 'node:fs';
import path from 'node:path';

const dir = process.argv[2];
const delay = +(process.argv[3] || 1000);
if (!dir) { console.error('usage: node scripts/fetch-rep.mjs <folder> [delayMs]'); process.exit(1); }

const out = path.join(dir, 'rep.json');
const rep = fs.existsSync(out) ? JSON.parse(fs.readFileSync(out, 'utf8')) : {};
const ids = new Set();
for (const f of fs.readdirSync(dir)) {
  if (!f.endsWith('.json') || f === 'zones.json' || f === 'rep.json') continue;
  for (const it of JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8')).items || []) {
    if ((it.source || []).includes(5)) ids.add(it.id); // vendor recipes only
  }
}

const RANK = '(Friendly|Honored|Revered|Exalted)';
function parse(text) {
  let m = text.match(new RegExp(`Requires ([A-Z][^.<]{2,50}?) - ${RANK}`));
  if (m && !/^(Blacksmithing|Alchemy|Enchanting|Engineering|Leatherworking|Tailoring|Cooking|First Aid|Mining)/.test(m[1])) return { faction: m[1].split("Requires ").pop().trim(), rank: m[2] }; // drop a leading specialization requirement
  m = text.match(new RegExp(`Requires ${RANK} with this faction`));
  if (m) return { rank: m[1] };
  m = text.match(new RegExp(`Become ${RANK} with ([A-Z][^.<]{2,50}?)(?: to|\\.|$)`));
  if (m) return { faction: m[2].trim(), rank: m[1] };
  return null;
}

let n = 0;
for (const id of ids) {
  if (id in rep) continue;
  const r = await fetch(`https://nether.wowhead.com/forever/tooltip/item/${id}`, { headers: { 'User-Agent': 'Mozilla/5.0' } });
  if (r.status === 403 || r.status === 429) { console.error('blocked', r.status, 'at', id); break; }
  if (!r.ok) { rep[id] = null; continue; }
  const j = await r.json();
  const text = (j.tooltip || '').replace(/<[^>]+>/g, ' ').replace(/&nbsp;/g, ' ').replace(/\s+/g, ' ');
  rep[id] = parse(text);
  if (++n % 25 === 0) fs.writeFileSync(out, JSON.stringify(rep));
  await new Promise(res => setTimeout(res, delay));
}
fs.writeFileSync(out, JSON.stringify(rep));
console.log('items', ids.size, 'done', Object.keys(rep).length, 'with rep', Object.values(rep).filter(Boolean).length);
