// Paste in the Chrome console on any https://www.wowhead.com/forever/ page (same origin), then run:
//   await whDownloadAll()
// Chrome must allow multiple downloads. Put the downloaded wh-*.json (+ zones.json) in one folder, then:
//   node scripts/build-recipes.mjs <folder>
// Do not commit the raw dumps (Wowhead content).
window.whGrab = async url => {
  const t = await (await fetch(url, { credentials: 'include' })).text();
  const li = t.indexOf('new Listview');
  const m = t.slice(li, li + 3000).match(/data: ?(\w+)\}\)/);
  if (!m) throw new Error('no listview ' + url);
  const i = t.indexOf('var ' + m[1] + ' = ');
  let s = t.indexOf('[', i), d = 0, q = null, e = s;
  for (; e < t.length; e++) {
    const c = t[e];
    if (q) { if (c === '\\') e++; else if (c === q) q = null; }
    else if (c === '"' || c === "'") q = c;
    else if (c === '[') d++;
    else if (c === ']') { d--; if (!d) break; }
  }
  return new Function('return ' + t.slice(s, e + 1))().map(x => {
    const o = { ...x };
    if (x.envChange && x.envChange.after) o.cd = x.envChange.after.cooldown || '';
    delete o.envChange;
    return o;
  });
};
window.whDownloadAll = async () => {
  // [profession, spells path, items path]; cooking and first-aid are secondary skills
  const list = [['alchemy'], ['blacksmithing'], ['enchanting'], ['engineering'], ['leatherworking'], ['mining'], ['tailoring'], ['cooking', 1], ['first-aid', 1]];
  for (const [p, sec] of list) {
    const spells = await whGrab(`/forever/spells/${sec ? 'secondary-skills' : 'professions'}/${p}`);
    let items = [];
    try { items = await whGrab(`/forever/items/recipes/${p}`); } catch (e) { /* mining has no recipe items */ }
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([JSON.stringify({ prof: p, spells, items })], { type: 'application/json' }));
    a.download = `${p}.json`;
    document.body.appendChild(a); a.click(); a.remove();
    await new Promise(r => setTimeout(r, 1500));
  }
  return 'done';
};
// zones.json: on /forever/zones, build {id: name} from g_listviews.zones.data for the zone ids used in the items' sourcemore.
