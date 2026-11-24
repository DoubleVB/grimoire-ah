# Feuille de route Profitmancer

Source : `AUDIT.md` (base `9135b0e`, 23/11/2026). Effort : XS < 30 min, S < 2 h, M ½-1 j, L > 1 j.
Les références de lignes portent sur `grimoire-alchimiste.html` (page) et `scripts/fetch-ah.mjs` (CI).

## Quick wins (< 30 min)

- [ ] En-tête HTML : doctype, charset, viewport, `lang`, retirer la meta `claude:` — l. 1-2 — XS (AUDIT.md §3 P1-2)
- [ ] Redirection `grimoire-alchimiste.html` -> `profitmancer.html`, MAJ `index.html` — XS (§3 P1-3)
- [ ] Coût `null` si prix de composant manquant, corriger le tri — page l. 1219-1232, 1287 — XS (§3 P1-4)
- [ ] `ah.yml` : échouer si `git fetch data` échoue hors « branche absente » — l. 16-17 — XS (§2 P0-1)
- [ ] `readJson` : défaut uniquement sur `ENOENT` — fetch-ah l. 41 — XS (§2 P0-1)
- [ ] `AbortSignal.timeout(20000)` sur tous les `fetch` — page l. 2343-2723, fetch-ah l. 20-202 — XS (§3 P1-7)
- [ ] Sentinelle `-1` du tri par compétence — page l. 1287-1290 — XS (§4 P2-1)
- [ ] Badge « limited stock » du Flip : condition `r.sus` — page l. 2047 — XS (§4 P2-2)
- [ ] Supprimer `RULESET`/`AH_IDS` et le champ `cloudCfg` — ah.yml l. 27-28, page l. 963, 2634 — XS (§4 P2-4)
- [ ] Compteur « named » de `names.json` — fetch-ah l. 215 — XS (§4 P2-6)
- [ ] `.langsw` en `var(--on-accent)`, dédoublonner `.histhead` — l. 295, 82/87 — XS (§3 P1-11, §4 P2-9)
- [ ] Ajouter `LICENSE` + section contenus tiers — racine — XS (§3 P1-10)
- [ ] `esc()` sur `aria-label`/`title`, date de graphique via `LOC` — l. 1394, 2049-2134 — XS (§4 P2-16)
- [ ] `role="tooltip"` sur `.wtt` — l. 2827-2833 — XS (§3 P1-11)
- [ ] Retirer `_cutfix`, afficher la commission dans l'en-tête — l. 1135, 2325 — XS (§3 P1-5)
- [ ] Installeur : vérifier l'auteur dans le `.toc` avant suppression — `Install-Profitmancer.ps1` l. 54-57 — XS (§4 P2-15)
- [ ] Dédupliquer `api`/`apiNs` — fetch-ah l. 29-38, 148-156 — XS (§4 P2-5)

## P0 — perte de données / exécution de code

- [ ] P0-1 Historique cloud effaçable + force-push : `ls-remote --exit-code`, garde-fou -50 %, sauvegarde artefact — `ah.yml` l. 16-39, fetch-ah l. 41, 159, 222-245 — S (§2 P0-1)
- [ ] P0-2 Dossier de marché supprimé après une seule omission : `missingSince`, N runs — fetch-ah l. 72, 287 — S (§2 P0-2)
- [ ] P0-3 Installeur sans intégrité : sources dans `addon/` `updater/`, zip en Release taggée, SHA256 épinglé — `install.ps1` l. 7, 14, 18 — M (§2 P0-3)

## P1 — bugs visibles, sécurité, conformité

- [ ] P1-1 XSS : `esc()` unique, validation d'ids/icônes, `new Option`, CSP, secret Blizzard hors `localStorage` — page l. 2373-2778, 1548, 2672 — S (§3 P1-1)
- [ ] P1-2 En-tête HTML (voir quick wins) — XS
- [ ] P1-3 Renommage : redirection, ne pas changer `grim:` ni l'IndexedDB — XS (voir quick wins)
- [ ] P1-4 Coût partiel (voir quick wins) — XS
- [ ] P1-5 Commission HV par défaut 5 %/15 %, déduite du marché choisi — l. 1133, 1231 — S (§3 P1-5)
- [ ] P1-6 Updater : SHA256/signature de `ProfitmancerData.lua`, contrôle de structure — `Update-Profitmancer.ps1` l. 18-27 — S (§3 P1-6)
- [ ] P1-7 Timeouts (voir quick wins) — XS
- [ ] P1-8 Quota localStorage : `save()` renvoie un booléen, purge `hist` > 60 j, index par marché — l. 1080, 1138, 1480 — S (§3 P1-8)
- [ ] P1-9 Wowhead/Blizzard : valider les conditions, tooltips à la demande — l. 2798, fetch-ah l. 202 — décision puis M (§3 P1-9)
- [ ] P1-10 LICENSE (voir quick wins) — XS
- [ ] P1-11 Contraste et tooltips clavier/tactile/graphiques — l. 231, 232, 269, 295, 1407, 2827 — S (§3 P1-11)
- [ ] P1-12 Faction vendeurs déduite du marché, ajouter Blackwater — l. 2016, 736, 880 — S (§3 P1-12)

## P2 — dette et robustesse (regroupé par thème)

- [ ] Calculs/UX : P2-1 tri compétence, P2-2 badge Flip, P2-16 i18n/attributs — XS (§4)
- [ ] Données CI : P2-3 `sold24` biaisé (M), P2-6 schéma `names.json` `v:2` (S), P2-7 `data/markets.json` (S), P2-14 cron/diff/SHA d'actions (S) — fetch-ah, ah.yml (§4)
- [ ] Nettoyage : P2-4 variables mortes, P2-5 `api` unique, P2-13 code mort (stock, `LAUNCHER`, `VENDOR_APPROX`) — XS à S (§4)
- [ ] Front : P2-8 alléger la page (`TT` -> JSON à la demande) M, P2-9 CSS fusionné S, P2-12 rendu de la vue visible S (§4)
- [ ] Accessibilité : P2-10 rôles ARIA tr/onglets/pastilles — l. 1300, 582, 1260, 831 — S (§4)
- [ ] Qualité : P2-11 tests `node --test` + `ci.yml` (items.json == ITEMS, PSScriptAnalyzer) — M (§4)
- [ ] Installeur : P2-15 suppression ciblée — XS (§4)

## Ordre d'exécution recommandé

1. **Protéger les données** : P0-1 puis P0-2 (quick wins 4-5 inclus), plus timeouts P1-7 — AUDIT.md §2.
2. **Quick wins page** : en-tête, redirection, coût partiel, tri, badge, `LICENSE`, contrastes — AUDIT.md §6.
3. **Sécurité page** : P1-1 (XSS, CSP, secrets), puis P1-6 (updater) — AUDIT.md §3.
4. **Chaîne d'installation** : P0-3 (sources versionnées, Release, SHA256), P2-15, retrait de `GrimoireData.lua` — AUDIT.md §5.
5. **Produit et dette** : P1-5, P1-12, P1-8, P1-9, P1-11, puis tests (P2-11) avant les refontes P2-8, P2-9, P2-12.
