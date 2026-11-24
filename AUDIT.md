# Audit Profitmancer (grimoire-ah)

- **Date** : 23/11/2026.
- **Base auditée** : commit `9135b0e` (HEAD).
- **Méthode** : lecture seule. Aucun script du dépôt ni du zip n'a été exécuté. Seules des sondes Node `vm` ont été lancées sur les données embarquées de la page.

> **Références de lignes.** Elles renvoient à `HEAD:grimoire-alchimiste.html`, extrait avec `git show`. Ce fichier est en cours de renommage en `profitmancer.html`, donc les numéros peuvent varier légèrement dans le working tree. Les autres références renvoient à `HEAD:scripts/fetch-ah.mjs`, `HEAD:.github/workflows/ah.yml`, `HEAD:install.ps1` et aux fichiers de `Profitmancer-WoW-Forever.zip` (SHA256 `CE258385EEE768222CAD3E53783A66A9EB9CE0FBC64C781E6DCF23CFC265C690`). Le contenu de ce zip a été lu comme donnée, sans être exécuté.

**Priorités**

| Niveau | Définition |
|---|---|
| **P0** | Perte de données ou exécution de code chez les utilisateurs |
| **P1** | Bug visible, sécurité ou conformité à traiter rapidement |
| **P2** | Dette, robustesse, confort |

Effort : **XS** < 30 min · **S** < 2 h · **M** ½ à 1 j · **L** > 1 j.

---

## 1. Verdict sur les pistes pré-identifiées

| Piste | Verdict | Référence |
|---|---|---|
| XSS via innerHTML des tooltips (noms d'objets venant d'API) | **Nuancé**. Les tooltips `ttHtml` n'utilisent que des données embarquées (`nameEn`/`NAME_FR`/`TT`), et les noms du catalogue passent par `esc()`. D'autres points d'injection réels existent ailleurs (voir P1-1). | l. 2801-2803, 2778 |
| install.ps1 : `irm \| iex` + `-ExecutionPolicy Bypass` sans checksum, zip pris sur `main` | **Confirmé**, et aggravé : le zip n'est pas reproductible, car les sources de l'addon sont absentes du dépôt | install.ps1 l. 7, 14, 18 |
| `readJson` avale les erreurs (reset silencieux de l'historique 7 j) | **Confirmé**. Le workflow présente un chemin de perte encore plus probable (P0-1). | fetch-ah l. 41 |
| Pas de timeout sur les fetch | **Confirmé** dans le script et dans la page. Les délais par défaut d'undici (Node 20) n'ont pas été vérifiés. | fetch-ah l. 20, 31, 150, 202 ; page l. 2343, 2351, 2652, 2666, 2723 |
| RULESET/AH_IDS passés par le workflow mais jamais lus | **Confirmé**. En plus, l'UI invite à les renseigner. | ah.yml l. 27-28 ; page l. 963, 2634 |
| `api`/`apiNs` dupliquées | **Confirmé** | fetch-ah l. 29-38 et 148-156 |
| Schéma `names.json` hétérogène (tableau / 0 / -1 / -2) | **Confirmé**. La page le tolère, et le compteur du log est faux. | fetch-ah l. 163, 183, 203, 215 ; page l. 2735 |
| `sold24` estimé via les baisses de quantité | **Confirmé**. La méthode est documentée dans l'UI mais biaisée (P2-3). | page l. 1263, 1500-1513 ; fetch-ah l. 113-125 |
| IDs `MARKETS` codés en dur | **Confirmé**. C'est aussi un vecteur de perte de données (P0-2). | fetch-ah l. 46-52 |
| Page de 2,6 Mo (icônes base64, dictionnaire TT) | **Nuancé**. L'essentiel n'est pas le base64 (≈ 294 Ko) mais `TT`, le dictionnaire de tooltips Wowhead (≈ 1,54 Mo, soit 57 %). | l. 2798 |
| Conditions d'usage du contenu Wowhead | **À valider** (ce n'est pas un avis juridique). En plus du contenu embarqué, le CI scrape `nether.wowhead.com`. | l. 2798, 1693, 1164 ; fetch-ah l. 202 |
| CSS dupliqué (`:root` sombre, `.histhead`) | **Nuancé**. Le double bloc sombre (media + `[data-theme]`) est un motif voulu, mais aucun JS ne pose `data-theme`. `.histhead` est bien en double et contradictoire. | l. 14-23, 82, 87 |
| Meta `claude:viewport-fit-sides` parasite | **Confirmé**. Le problème réel est plus large : il manque doctype, charset, viewport et `lang` (P1-3). | l. 1-2 |
| Accessibilité (tooltip au survol seulement, `tr` cliquables sans rôle, contraste, pas de `role=tooltip`) | **Confirmé**, avec des contrastes mesurés (P1-11, P2-10) | l. 2827-2833, 1300, 1305, 295 |
| Absence de tests et de LICENSE | **Confirmé**. Le README invite pourtant à forker (P1-10). | racine, README §Running your own scan |

---

## 2. Propositions P0

### P0-1 · Le workflow peut effacer tout l'historique cloud et le pousser en force
- **Où**
  - `.github/workflows/ah.yml` l. 16-17 et 31-39.
  - `scripts/fetch-ah.mjs` l. 41, 159, 222, 236, 245.
- **Problème**
  ```yaml
  if git fetch origin data --depth=1 2>/dev/null; then git archive ... | tar -x -C data; else echo "First run: no data yet"; fi
  ...
  git init -q -b data ... git push -qf ... data
  ```
  - Un échec réseau ou d'authentification passager sur `git fetch` est traité comme un « premier run ».
  - Le script repart alors de zéro : `snaps.json`, `qty24.json` et `names.json` sont vides, et `index.json` ne contient plus aucun marché précédent.
  - La branche `data` est ensuite recréée sans historique, puis **poussée en force**.
  - Même mécanisme avec `readJson` (`catch { return d; }`) : un `snaps.json` tronqué ou corrompu repart silencieusement à `{snaps: []}`.
- **Impact**
  - Perte irréversible des 7 jours d'historique des 15 marchés. Elle se répercute sur les ventes 24 h de la page, de l'addon et du catalogue.
  - `names.json` doit être reconstruit, à raison de 2 500 entrées par run.
  - Aucune sauvegarde n'existe, puisque la branche est orpheline et réécrite à chaque run.
- **Correctif**
  1. Distinguer « branche absente » de « erreur ». Par exemple, `git ls-remote --exit-code origin data` : le code 2 signifie que la branche est absente, toute autre erreur doit provoquer `exit 1`.
  2. Supprimer `2>/dev/null`.
  3. Dans `readJson`, ne renvoyer la valeur par défaut que sur `ENOENT`. Toute autre erreur (JSON invalide) doit faire échouer le run.
  4. Ajouter un garde-fou avant le push : refuser de publier si le nombre total de snapshots chute de plus de 50 % par rapport à la version distante.
  5. Garder une sauvegarde, par exemple `actions/upload-artifact` de `data/` avec 7 jours de rétention, ou une branche `data-prev`.
- **Effort** : S.

### P0-2 · Un marché omis une seule fois par Blizzard voit son dossier supprimé
- **Où** : `fetch-ah.mjs` l. 72 et l. 287.
- **Problème**
  ```js
  if (seen.size && !s) continue; // gone from Blizzard's list
  ...
  for (const d of await readdir("data/ah")...) if (!index.some(h => h.key === d) && !factions.some(...)) await rm(`data/ah/${d}`, { recursive: true, force: true });
  ```
  - `discover()` ignore les erreurs ruleset par ruleset (l. 66-67).
  - Si un seul appel échoue, ou si Blizzard omet temporairement un AH, le marché sort de `groups`. Il n'est alors pas réinjecté depuis `oldIndex`, puisque cela n'arrive que sur un échec de scan (l. 233, 264). Son dossier est ensuite supprimé à la l. 287.
- **Impact**
  - L'historique de ce marché est perdu.
  - Les updaters des joueurs reçoivent des 404 jusqu'à la réapparition du marché.
- **Correctif**
  - Ne supprimer un dossier qu'après N runs consécutifs d'absence : stocker un `missingSince` dans `index.json`.
  - D'ici là, réinjecter l'entrée `prev`.
  - Logger l'omission comme warning.
- **Effort** : S.

### P0-3 · Chaîne d'installation sans intégrité (exécution de code sur les PC des joueurs)
- **Où**
  - `install.ps1` l. 7, 14, 18.
  - Page l. 843 et 847.
  - `Install-Profitmancer.ps1` (zip) l. 123.
  - `Installer-Profitmancer.bat`.
- **Problème**
  - `irm https://doublevb.github.io/grimoire-ah/install.ps1 | iex` télécharge `raw.githubusercontent.com/.../main/Profitmancer-WoW-Forever.zip`, une référence mutable. Aucun hash ni signature n'est vérifié.
  - Le contenu est ensuite exécuté avec `-ExecutionPolicy Bypass`, puis enregistré comme tâche planifiée (wscript → powershell Bypass, toutes les 15 min).
  - Le zip est déposé à la main (commit « Add files via upload ») et ne peut pas être reconstruit depuis le dépôt : les sources Lua de l'addon sont absentes de `main`.
  - Ce qui est rassurant, après lecture : les scripts ne font que des GET (`index.json`, `ProfitmancerData.lua`) et n'envoient rien, comme annoncé. Le script PowerShell de la tâche est copié localement et n'est pas retéléchargé.
- **Impact**
  - Une compromission du compte GitHub, ou un upload erroné, donne une exécution de code arbitraire chez chaque utilisateur qui lance la commande ou le .bat.
  - Rien ne permet de relire ce qui est distribué.
- **Correctif**
  1. Versionner les sources de l'addon et des scripts dans `addon/` et `updater/`.
  2. Construire le zip en CI et le publier comme **asset de Release taggée**, jamais depuis `main`.
  3. Dans `install.ps1`, épingler l'URL de la release **et** son SHA256 (`Get-FileHash` comparé à une constante, `throw` si différent). Exemple de valeur pour le zip actuel : `CE2583…C690`.
  4. Option : signer les scripts PowerShell avec Authenticode, ce qui permettrait de retirer `Bypass`.
  5. Documenter une alternative sans `iex` : télécharger, vérifier, exécuter.
- **Effort** : M.

---

## 3. Propositions P1

### P1-1 · Points d'injection HTML réels (XSS), aggravés par des secrets stockés en clair
- **Où**, page, données venant de l'extérieur insérées sans échappement :

| Ligne(s) | Donnée injectée | Origine |
|---|---|---|
| l. 2775 | `src="${catIcon(r.m[7])}"` : l'icône est une chaîne de `names.json`, issue de Blizzard ou de Wowhead (fetch-ah l. 206 `en.icon`) | `names.json` |
| l. 2777-2778 | `lvl ${r.m[6]}`, `class="cq${r.ql}"`, `data-tt="${r.id}"` et `#${r.id}` (les clés de `catalog.json`) | `catalog.json`, `names.json` |
| l. 2744-2745 | `catFillCls`, qui injecte les noms de classes de `names.json` | `names.json` |
| l. 2645 | `houseOpts`, qui injecte `h.key` et `houseLabel(h)` de `index.json` | `index.json` (contient des noms Blizzard pour les AH inconnus, fetch-ah l. 77) |
| l. 2373, 2385, 2399, 2447 | Noms de royaumes, de rulesets et d'AH venant de l'API Blizzard | API Blizzard |
| l. 2562 | Clés du fichier `Auctionator.lua` | Fichier local |
| l. 1548 | `<td>${x.src}</td>` : libellé de scan, qui contient la clé Auctionator ou `Cloud · AH ${cIds}` | Fichier local, `latest.json` |
| l. 2672 | `cIds` dans `msg()` | `latest.json` |

- **Problème**
  - L'URL cloud est réglable par l'utilisateur (l. 2699). La branche `data` est écrite par un bot.
  - Une donnée malveillante, issue d'une compromission ou d'une URL piégée, s'exécute dans la page.
  - La page stocke en clair `clientId`, `clientSecret` et `token` Blizzard dans `localStorage["grim:settings"]` (l. 1133, 2326-2328), qu'un script injecté peut lire.
  - `esc` (l. 2786) et `chEsc` (l. 1866) sont deux implémentations dupliquées.
- **Impact** : vol du secret Blizzard de l'utilisateur et défiguration de la page.
- **Correctif**
  - Une seule fonction `esc()`, partagée, appliquée à toute donnée non embarquée.
  - Pour les attributs, valider le format : `/^\d+$/` pour les ids, et pour les icônes `/^[\w-]+$/` ou une URL `https://` d'un domaine autorisé.
  - Construire les `<option>` via `new Option(text, value)`.
  - Ajouter une CSP `<meta http-equiv="Content-Security-Policy">` qui limite `connect-src` et `img-src` aux domaines utilisés.
  - Proposer de ne pas mémoriser le secret : stockage en `sessionStorage` ou case « se souvenir ».
- **Effort** : S.

### P1-2 · En-tête HTML incomplet
- **Où** : l. 1-2. La page commence directement par `<title>` puis `<meta name="claude:viewport-fit-sides">`.
- **Problème** : il manque `<!doctype html>`, `<meta charset="utf-8">`, `<meta name="viewport">` et l'attribut `<html lang>`. La meta `claude:` et les sélecteurs `[data-theme]` jamais posés laissent penser qu'un artifact a été déployé tel quel.
- **Impact**
  - La page est rendue en **mode quirks**.
  - Sur téléphone, sans viewport, le rendu se fait sur 980 px de large : les media queries `max-width:640/860px` (l. 55, 519-527) ne s'appliquent jamais.
  - En `file://`, l'encodage est deviné. Sur GitHub Pages, l'en-tête HTTP `text/html; charset=utf-8` compense, vérifié par une requête HEAD.
  - `lang` n'est posé qu'en FR (l. 1119), ce qui gêne les lecteurs d'écran en EN.
- **Correctif** : ajouter le squelette `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">…` et supprimer la meta `claude:`.
- **Effort** : XS.

### P1-3 · Le renommage en cours peut casser des liens et des données utilisateurs
- **Où**
  - `index.html` (redirige vers `grimoire-alchimiste.html`).
  - `Profitmancer.toc` : `## X-Website: …/grimoire-alchimiste.html`.
  - Liens externes vers l'ancienne URL (CurseForge, README) : non vérifiés.
  - Page l. 1079-1080 : préfixe `grim:`, clé `cutNone` (l. 1135), IndexedDB `"grimoire"` (l. 2236).
- **Problème**
  - Si `grimoire-alchimiste.html` disparaît, l'URL publiée par l'addon renvoie une 404.
  - Renommer le préfixe `grim:` ou la base IndexedDB ferait perdre le panier, les réglages, les scans et les personnages des utilisateurs.
- **Impact** : liens morts depuis l'addon et les sites externes, et réinitialisation silencieuse des données locales de chaque utilisateur.
- **Correctif**
  - Conserver un `grimoire-alchimiste.html` qui ne fait que rediriger (avec le hash) vers `profitmancer.html`, et mettre `index.html` à jour.
  - **Ne pas** changer les clés de stockage, ou écrire une migration explicite.
- **Effort** : XS.

### P1-4 · Bug de calcul : le coût affiché est partiel quand un prix de composant manque
- **Où** : `compute()` l. 1219-1232. Affichage l. 1300, 1305, 1323, 1337, 2809, et tri l. 1287.
- **Problème**
  ```js
  const p=costOf(id); if(p.v==null) missing=true; else cost+=p.v*q   // on continue d'additionner
  ...
  cost:x=>x.cost||(x.missing?-1e12:0)                                  // tri sur ce coût partiel
  ```
  - La colonne « Cost », le détail « Reagents », `batchUpd` (`x.batch` n'est jamais null) et le tooltip affichent la somme des seuls composants connus, comme si c'était le coût total.
  - Le profit est bien mis à `null`, mais le tri « Sort: cost » classe ces recettes parmi les moins chères.
- **Impact** : l'utilisateur peut acheter pour une recette qui paraît bon marché alors qu'un composant n'a pas de prix.
- **Correctif** : renvoyer `cost:null` et `batch:null` si `missing`, ou afficher « ≥ x » avec une mention « prix manquant ». Dans le tri, traiter `missing` comme une valeur absente.
- **Effort** : XS.

### P1-5 · Biais du profit : commission HV à 0 par défaut, forcée à 0 pour tout le monde
- **Où**
  - l. 1133 (`cut:"0"`).
  - l. 1135 et 2325 : `_cutfix` remet `S.cut="0"` une fois pour **tous** les utilisateurs, y compris ceux qui avaient choisi 5 % ou 15 %.
  - l. 984 et 636.
- **Problème**
  - `net = sale*(1-cut)` vaut le prix affiché brut. Le dépôt HV est ignoré partout : crafts, flip, leveling.
  - « Margin » se lit comme profit/coût, pas profit/vente (l. 1231). Ce n'est pas un bug, mais rien ne l'indique dans l'UI.
- **Impact**
  - Toutes les recettes dont la marge est inférieure à environ 5 % de la vente paraissent rentables alors qu'elles perdent de l'argent sur un HV de faction.
  - Le plan « Ambitious » (`minMargin:0`) et le Flip sont surestimés.
- **Correctif**
  - Choix produit à valider : par défaut, 5 % pour un HV de faction et 15 % pour un HV neutre. Blackwater est probablement neutre, à vérifier en jeu.
  - Déduire la commission du marché sélectionné.
  - Afficher la commission dans l'en-tête du tableau, et préciser « marge = profit / coût ».
  - Retirer `_cutfix` maintenant que la migration est faite.
- **Effort** : S.

### P1-6 · L'updater dépose du Lua exécuté par le jeu, avec une validation minimale
- **Où** : `Update-Profitmancer.ps1` (zip) l. 18-27 ; `fetch-ah.mjs` l. 127-142.
- **Problème**
  - Toutes les 15 min, l'updater télécharge `ah/<key>/ProfitmancerData.lua` depuis une branche réécrite par force-push.
  - La seule vérification est `Contains("ProfitmancerData={")` sur les 3 premières lignes, puis le fichier est copié dans `Interface\AddOns`.
- **Impact**
  - Une compromission de la branche `data` permet d'exécuter du Lua arbitraire dans le client WoW de tous les joueurs. Ce Lua est cantonné au sandbox addon : pas d'accès disque, mais il peut agir sur l'UI et le chat.
  - Un fichier tronqué casse l'addon jusqu'au run suivant.
- **Correctif**
  - Publier un `ProfitmancerData.sha256`, ou mieux une signature, à vérifier avant le `Move-Item`.
  - Contrôler la structure : seules des lignes `[\d+]={\d+,\d+,\d+,-?\d+}` doivent figurer après l'en-tête.
  - Côté générateur, échapper aussi `\n` dans `esc()`.
- **Effort** : S.

### P1-7 · Fetch sans timeout ni annulation
- **Où**
  - Page l. 2343, 2351 (API Blizzard), 2652, 2666 et 2723 (cloud).
  - `fetch-ah.mjs` l. 20, 31, 150, 202.
- **Problème**
  - Aucun `AbortSignal.timeout()`.
  - Côté page, si une requête pend, `apiBusy` (l. 2480, 2489) reste à `true` et l'auto-refresh toutes les 10 min s'arrête jusqu'au rechargement.
  - Côté CI, une requête lente bloque le scan séquentiel des 15 marchés. Les délais par défaut d'undici n'ont pas été vérifiés, et la limite reste `timeout-minutes: 30`.
- **Correctif** : passer `{signal: AbortSignal.timeout(20000)}` partout. Dans le script, factoriser dans un `api()` unique (voir P2-5), avec retry sur `AbortError`.
- **Effort** : XS.

### P1-8 · Stockage local : quota atteint en silence, historique non borné et sources mélangées
- **Où** : `save()` l. 1080 (`catch(e){}`) ; `state.hist` l. 1138 et 1179-1183 ; `saveSnaps` l. 1480-1484.
- **Problème**
  - `snaps` est plafonné à 2,5 Mo. En revanche, `hist` (par objet et par jour, sans limite) et `prices` (tous les objets de l'HV) ne sont pas bornés.
  - Un `QuotaExceededError` est avalé : panier, réglages, personnages et scans ne sont plus sauvegardés, sans aucun message.
  - `hist` mélange les sources (imports Auctionator de n'importe quel serveur, cloud, API) dans la même série jour par jour, ce qui fausse `stats()`, le mode « History average » (l. 1199, 1215) et les filtres `minAvg`/`minDays`.
- **Correctif**
  - Faire renvoyer un booléen à `save()` et afficher un avertissement une seule fois.
  - Purger `hist` au-delà de 60 jours.
  - Indexer `hist` par marché (`srcKey`).
- **Effort** : S.

### P1-9 · Conditions d'usage du contenu tiers embarqué ou scrapé (à valider ; ce n'est pas un avis juridique)
- **Où**
  - Page l. 2798 : `TT`, tooltips HTML Wowhead EN et FR, 1,54 Mo.
  - l. 1693 (`RITEMS`), l. 1164 (`NAME_FR`).
  - l. 130 et 371-401 : planches d'icônes du jeu en base64.
  - `fetch-ah.mjs` l. 202 : scraping de `nether.wowhead.com/forever/tooltip/item/…` en CI, sans User-Agent, avec 6 workers.
- **Problème** : il s'agit d'une redistribution de textes et d'icônes appartenant à Wowhead et Blizzard, et d'appels automatisés à un endpoint non documenté.
- **Impact** : risque de demande de retrait ou de blocage, ce qui casserait le pipeline des noms.
- **Correctif**
  - Faire valider les conditions de Wowhead et la politique Blizzard sur les assets.
  - Pistes techniques : charger les tooltips à la demande depuis le script officiel `tooltips.js` de Wowhead plutôt que de les embarquer ; s'appuyer en priorité sur l'API Blizzard (noms, icônes via `render.worldofwarcraft.com`) ; ajouter des crédits et une mention de source.
- **Effort** : décision, puis M.

### P1-10 · Pas de LICENSE, alors que le README demande de forker
- **Où** : racine du dépôt ; README « Running your own scan → 1. Fork the repository ».
- **Problème** : sans licence, le code est « tous droits réservés », et forker puis faire tourner le workflow n'est pas autorisé formellement. Ce point s'articule avec P1-9 : le contenu tiers ne peut pas être couvert par une licence du projet.
- **Impact** : contributeurs et forks dans un flou juridique, et aucune réutilisation possible en toute sécurité.
- **Correctif** : ajouter une `LICENSE`, par exemple MIT pour le code, et une section « Données et assets tiers » qui exclut le contenu Wowhead et Blizzard.
- **Effort** : XS.

### P1-11 · Accessibilité : contrastes insuffisants et infobulles inaccessibles au clavier et au tactile
- **Où**
  - l. 295 : `.langsw button[aria-pressed="true"]{background:var(--accent);color:#fff}`. En sombre, `#FFF` sur `#C2A8FF` donne environ **2,0:1**.
  - l. 231 : `.pill.good`. En sombre, `#FFF` sur `#2FBF74` donne environ **2,4:1**.
  - l. 232 : `.pill.bad`. En sombre, `#FFF` sur `#E2574A` donne environ **3,7:1**, pour un texte de 11,5 px.
  - l. 269 : `.tag.bm`. `#FFF` sur `#E8710A` donne environ **3,1:1**.
  - l. 65-66 : lignes verrouillées en `opacity:.55`.
  - Tooltip l. 2827-2833 : écoute uniquement `pointermove`, ignore explicitement le tactile (`if(e.pointerType==="touch") return`), n'a pas de `role="tooltip"` ni `aria-describedby`, et ne réagit pas au focus.
  - Graphiques l. 1407-1409 : survol à la souris uniquement.
- **Impact** : textes illisibles en mode sombre (non conformes au critère WCAG AA), et détail des prix inaccessible au clavier, au mobile et aux lecteurs d'écran.
- **Correctif**
  - Utiliser `color:var(--on-accent)` et des fonds `*-strong` plus sombres en mode sombre, pour atteindre au moins 4,5:1.
  - Ouvrir le tooltip sur `focusin` et sur un appui long, avec `role="tooltip"` et `aria-describedby`.
  - Proposer un équivalent texte des valeurs des graphiques.
- **Effort** : S.

### P1-12 · Faction des vendeurs implicitement Horde (Blackwater non gérée)
- **Où** : l. 2016 `const REAG_FAC=()=>{try{return fl.fac||"H"}…}`, utilisé par `vendorPrice` l. 1196. Les sélecteurs l. 736 et 880 ne proposent que A et H.
- **Problème**
  - Tant que l'utilisateur n'a pas réglé « Vendors: Alliance » dans l'onglet Flip, ou importé un personnage, les composants vendus seulement par des PNJ Alliance ne sont **pas** comptés au prix vendeur. Ils passent au prix HV ou restent manquants.
  - La faction Blackwater, scannée par le CI, n'a aucune option.
- **Impact** : les coûts de recette sont faux pour une partie des joueurs Alliance et Blackwater.
- **Correctif**
  - Déduire la faction du marché choisi (`cloudKey` ou `S.ahIds` comparé à `MARKETS`) ou du personnage actif.
  - Ajouter « Blackwater » et définir quels PNJ (A, H, N) lui sont accessibles. Règle de jeu à vérifier.
- **Effort** : S.

---

## 4. Propositions P2

### P2-1 · Le tri par compétence relègue en fin de liste les recettes de niveau 1
- **Où** : l. 1287 et l. 1290.
- **Problème**
  ```js
  skill:x=>-x.r.skill
  ma=ka<=-1e11||ka===-1
  ```
  - `-1` sert de sentinelle « absent » (pour vol et supply).
  - Les **7 recettes** de compétence 1 (compte obtenu par sonde) sont donc triées après toutes les autres.
- **Impact** : les recettes de départ, utiles aux débutants, sont reléguées à la fin du tri par compétence.
- **Correctif** : utiliser `null` comme sentinelle commune, ou un drapeau de manquant par clé de tri.
- **Effort** : XS.

### P2-2 · Le badge « limited stock » du Flip ne s'affiche jamais pour les vendeurs connus
- **Où** : l. 2047.
- **Problème**
  ```js
  ${r.sus&&!(FLIP_SRC[r.id]||[]).length ? …((FLIP_SRC[r.id]||[]).length?"limited stock":"limited stock?")… : ""}
  ```
  - La condition exige `FLIP_SRC` vide, donc la branche `"limited stock"` est morte.
  - Les objets dont tous les vendeurs ont un stock limité (`sus` vrai via `src.every`, l. 2031) n'ont pas de badge. Le filtre « Hide limited-stock » fonctionne, lui.
- **Impact** : l'utilisateur prévoit un achat en quantité chez un PNJ qui ne vend que quelques unités.
- **Correctif** : remplacer la condition par `r.sus ? … : ""`.
- **Effort** : XS.

### P2-3 · `sold24` et l'historique sont biaisés
- **Où** : page l. 1263-1268 et 1500-1513 ; fetch-ah l. 113-125.
- **Problème**
  - Seules les baisses nettes entre deux scans comptent comme ventes.
  - Les expirations (48 h) et les annulations sont comptées comme ventes.
  - Les relistes et nouvelles annonces masquent les ventes.
  - Un objet absent d'un scan vaut 0 : un scan partiel crée donc de fausses ventes égales à tout le stock.
  - Sur 6 à 24 h d'historique, l'extrapolation multiplie le chiffre jusqu'à ×4.
- **Impact** : la demande est surestimée dans les tableaux « Sold 24h », le catalogue, l'addon et les plans Invest, qui s'en servent pour dimensionner les quantités.
- **Correctif**, côté CI, où les `auction.id` et `time_left` sont disponibles :
  - Compter les annonces disparues qui n'étaient pas en `SHORT` comme « probablement vendues ».
  - Ignorer un scan dont le nombre d'objets chute anormalement.
  - Publier un intervalle de valeurs plutôt qu'un chiffre unique.
- **Effort** : M.

### P2-4 · Variables `RULESET` et `AH_IDS` mortes, et champ d'UI trompeur
- **Où** : ah.yml l. 27-28 ; page l. 963 (« For GitHub (Variables) ») et l. 2634 `cloudCfgTxt`, rafraîchi toutes les 5 s (l. 2795).
- **Problème** : `fetch-ah.mjs` ne lit ni `env.RULESET` ni `env.AH_IDS`, car il scanne tous les marchés. L'UI invite pourtant à les renseigner.
- **Impact** : les utilisateurs qui forkent configurent des variables sans effet et croient filtrer leur marché.
- **Correctif** : supprimer les deux lignes du workflow, le champ `cloudCfg` et son `setInterval`. Documenter `MAIN_KEY`, `NAMES_PER_RUN` et `KEEP_DAYS` dans le README.
- **Effort** : XS.

### P2-5 · `api` et `apiNs` dupliquées dans fetch-ah
- **Où** : l. 29-38 et l. 148-156.
- **Problème** : même boucle de retry avec des délais différents (2 000 ms contre 1 500 ms). La locale et `lastMod` ne sont présents que dans `api`.
- **Impact** : tout correctif (timeout, retry, logs) doit être fait deux fois, avec un risque de divergence.
- **Correctif** : une seule fonction `api(tok, path, {ns, locale, state})`, avec timeout (P1-7).
- **Effort** : XS.

### P2-6 · Schéma de `names.json` hétérogène et compteur faux
- **Où** : fetch-ah l. 163, 183, 189, 203, 206 et 215 ; page l. 2735 et 2783.
- **Problème**
  - `items[id]` peut valoir un tableau à 8 positions, `0` (valeur héritée : le code actuel ne l'écrit plus, il la relit seulement), `-1` ou `-2`.
  - Le log `v.filter(x => x && x !== -1)` compte les `-2` comme « named ».
  - Les `-2` ne sont jamais retentés.
- **Impact** : le log de suivi est faux, les objets inconnus restent sans nom pour toujours, et chaque consommateur doit gérer quatre formes de données.
- **Correctif**
  - Passer à un objet `{s:"ok"|"retry"|"wowhead"|"unknown", n:[...], tries, last}` versionné (`v:2`), avec migration au chargement.
  - Retenter les `-2` tous les N jours.
  - Corriger le compteur.
- **Effort** : S.

### P2-7 · IDs `MARKETS` codés en dur
- **Où** : fetch-ah l. 46-52.
- **Problème**
  - Les 15 IDs d'AH ont été vérifiés à la main en novembre 2026.
  - Un nouvel AH est scanné sous `ah-<id>` (l. 76-78) sans faction ni type de serveur, donc invisible pour l'installeur (`factions`).
  - Un AH renuméroté disparaît : voir P0-2.
- **Impact** : un changement côté Blizzard prive des joueurs de leurs prix sans aucune alerte.
- **Correctif**
  - Déplacer la table dans `data/markets.json`, versionné sur `main`.
  - Échouer bruyamment (warning dans le résumé du job) quand Blizzard liste un ID inconnu ou n'en liste plus un connu.
- **Effort** : S.

### P2-8 · Poids de la page (2,68 Mo, une seule ressource)
Répartition mesurée sur `HEAD` :

| Bloc | Lignes | Taille | Part |
|---|---|---|---|
| `TT` (tooltips HTML Wowhead) | l. 2798 | ≈ 1,54 Mo | 57 % |
| Data URIs (5 planches) | — | ≈ 294 Ko | — |
| `PROFX` | — | ≈ 213 Ko | — |
| `RITEMS` | — | ≈ 117 Ko | — |
| `NAME_FR` | — | ≈ 79 Ko | — |
| `I18N` | — | ≈ 48 Ko | — |

- **Impact**
  - Tout est parsé au démarrage, y compris les tooltips de l'autre langue.
  - Aucun cache séparé : une modification du JS invalide les 2,6 Mo.
  - La compression gzip par GitHub Pages n'a pas été vérifiée.
- **Correctif**
  - Extraire `TT` en `tt.en.json` / `tt.fr.json`, chargés à la demande au premier survol.
  - Extraire les planches en `.webp` servies séparément, avec cache.
  - Placer les données de recettes dans `data/*.json`.
- **Effort** : M.

### P2-9 · CSS empilé en couches correctives
- **Où**
  - `.histhead` l. 82 et l. 87 : `justify-content:space-between;align-items:baseline` est écrasé par `align-items:center`.
  - Redéfinitions successives de `.money`, `.pill`, `th`, `.picks`, `.pick`, `.proftab` et `.rowsT`, réparties dans des blocs comme « Lisibilité renforcée » l. 184, « Compactage » l. 238 et « v33 » l. 489. S'y ajoutent de nombreux `!important` (l. 334-337, 491).
  - Les sélecteurs `:root[data-theme=…]` (l. 19, 434-443, 503) ne servent pas, puisqu'aucun code ne pose `data-theme`. Ce n'est pas un bug, mais du code inutile tant qu'il n'existe pas de bascule de thème.
- **Impact** : il est difficile de prévoir quel style s'applique, et chaque retouche risque une régression visuelle.
- **Correctif** : fusionner les couches dans un seul bloc par composant. Ajouter une bascule clair/sombre ou supprimer ces blocs.
- **Effort** : S.

### P2-10 · Accessibilité : rôles et clavier
- **Où**
  - Lignes de tableau `tr tabindex="0"` cliquables (l. 1300, 1305, 1541, 1656, 1745, 1840) : pas de rôle ni d'`aria-selected`, Entrée uniquement (pas Espace).
  - Onglets : `role="tab"` sans `aria-controls`/`tabpanel` ni navigation aux flèches (l. 582-592, 2213, 933-936).
  - Pastilles de compétence colorées sans texte (`.su`, l. 1260 ; seul un `title` est présent).
  - `<label class="chdrop" tabindex="0">` (l. 831).
- **Impact** : les lecteurs d'écran n'annoncent ni la sélection ni les onglets, et la navigation au clavier est incomplète.
- **Correctif** : mettre un bouton dans la première cellule (ou `role="row"` avec `aria-selected`), appliquer le pattern ARIA Tabs, et ajouter un texte masqué (`.sr-only`) pour les pastilles.
- **Effort** : S.

### P2-11 · Ni tests ni CI de validation
- **Problème**
  - Aucun test des calculs : `compute`, `ingest` (EMV des 15 % les moins chers), `parseMoney`, `buildLeveling`, `sold24`, `luaFile`.
  - La synchronisation entre `data/items.json` (suivi CI) et `ITEMS` (page) est manuelle. Elle est cohérente aujourd'hui (2 363 = 2 363, vérifié par sonde), mais une divergence créerait de fausses ventes lors de la fusion cloud + API (P2-3).
- **Impact** : les bugs de calcul, comme P1-4 et P2-1, passent inaperçus et toute refonte est risquée.
- **Correctif**
  - Extraire la logique pure dans un module ES testé avec `node --test`.
  - Ajouter un workflow `ci.yml` sur PR : tests, vérification items.json == ITEMS, `node --check` du script, `PSScriptAnalyzer` sur les `.ps1`.
- **Effort** : M.

### P2-12 · Re-rendu global à chaque interaction
- **Où** : `renderAll()` l. 2312, appelé à 32 endroits, dont le clic sur une ligne (l. 2315).
- **Problème**
  - Chaque sélection recalcule tous les onglets, même cachés : Invest (`salesStats(0)` × 3 profils), Flip (environ 1 000 lignes), History, Leveling, Recipes.
  - `salesStats` est recalculé plusieurs fois par rendu (l. 1264, 1270, 1524, 1969), et à chaque survol de tooltip (l. 2806).
- **Impact** : l'interface devient lente avec 400 scans, surtout sur mobile (non mesuré).
- **Correctif** : ne rendre que la vue visible et mémoriser `salesStats` par version de `state.snaps`.
- **Effort** : S.

### P2-13 · Code mort
- **Éléments à supprimer**
  - Gestion du stock : `state.owned`, `useStock`, `stockLine()` (jamais appelée), `.stockin` (l. 1139-1140, 1223-1224, 1312-1314, 1931-1932, 2094-2108).
  - Lanceur local `LAUNCHER`/`pullFromLauncher`, qui parle de `Grimoire.bat` et `grimoire-serveur.ps1`, absents des deux zips et du dépôt (l. 2267-2285).
  - `btnQuickImport`, masqué dans un `<span hidden>` (l. 573).
  - `VENDOR_APPROX`, toujours vide (l. 1020).
  - `loadAH`/`connected-realm`, hors Forever.
- **Impact** : le code est plus difficile à lire, et des messages renvoient à des outils qui n'existent pas.
- **Correctif** : supprimer ce code et les libellés FR codés en dur qui l'accompagnent (« Recharger maintenant », « Choisir… », « Hôtel unique »).
- **Effort** : S.

### P2-14 · Workflow peu efficace et actions non épinglées
- **Où** : ah.yml l. 4, 14, 19.
- **Problème**
  - Un cron toutes les 10 min retélécharge les 15 HV complets pour constater 5 fois sur 6 que rien n'a changé (le contrôle a lieu après le téléchargement, fetch-ah l. 239).
  - Chaque run fait un commit et un force-push, même sans changement, car `index.json.t` change à chaque fois.
  - `actions/checkout@v4` et `setup-node@v4` sont épinglés par tag, pas par SHA.
- **Impact** : le quota d'API et les minutes CI sont gaspillés, et une compromission d'un tag d'action toucherait un job qui a le droit d'écrire dans le dépôt.
- **Correctif**
  - Faire une requête conditionnelle (`If-Modified-Since` sur `Last-Modified`) ou n'interroger qu'un seul AH témoin.
  - Ne pousser que si le diff n'est pas vide.
  - Épingler les actions par SHA.
- **Effort** : S.

### P2-15 · L'installeur supprime large
- **Où** : `Install-Profitmancer.ps1` (zip) l. 54-57.
- **Problème** : il supprime `%LOCALAPPDATA%\Grimoire` en entier et tout dossier `Interface\AddOns\Grimoire` qui contient un `Grimoire.toc`, sans vérifier l'auteur (`## Author: Workby`). Un autre addon nommé « Grimoire » serait effacé.
- **Impact** : un addon tiers homonyme ou des données sans rapport sont supprimés sans confirmation.
- **Correctif** : vérifier l'auteur ou un marqueur dans le `.toc` avant suppression, et demander confirmation.
- **Effort** : XS.

### P2-16 · Défauts d'internationalisation et d'attributs
- **Où**
  - l. 1394 : la date du tooltip de graphique est formatée en `"en-GB"` codé en dur, donc en anglais en FR (la regex `DATERX` ne traduit que les mois français).
  - `NAME_FR[19026]` = `Feu d'artifice "Explosion serpentine"`. Il est injecté sans échappement dans `aria-label`/`title` (l. 2049, 2062, 2090, 2134), ce qui casse l'attribut en FR.
- **Impact** : dates en anglais dans l'interface française, et libellé d'accessibilité tronqué pour cet objet.
- **Correctif** : utiliser `toLocaleString(LOC)` et passer `esc()` sur tous les attributs.
- **Effort** : XS.

---

## 5. Plan de retrait définitif de `GrimoireData.lua`

### État constaté
- `fetch-ah.mjs` l. 283 écrit `data/ah/<faction>-auction-house/GrimoireData.lua` dans le même format v2 que `ProfitmancerData.lua`, avec seulement le nom de table changé.
- Le seul client est l'ancien updater `Update-Grimoire.ps1`, contenu dans `Grimoire-WoW-Forever.zip` encore présent sur `main`. Il télécharge `ah/$($cfg.key)/GrimoireData.lua` (l. 12).
- Seules les installations dont la clé est `alliance|horde|blackwater-auction-house` reçoivent encore le fichier. Celles qui ont choisi une autre clé reçoivent déjà une 404.
- L'addon Profitmancer 1.3.7 ne lit pas `GrimoireData` (grep vide dans le zip). `Install-Profitmancer.ps1` l. 53-57 désinstalle la tâche, la configuration et l'addon Grimoire.
- Ni la page ni le README ne pointent vers `Grimoire-WoW-Forever.zip`.
- **Piège** : la constante `LEGACY` (fetch-ah l. 57) est mal nommée. Les dossiers `<faction>-auction-house/ProfitmancerData.lua` sont **ceux qu'utilise l'installeur actuel** (`$index.factions`, Install-Profitmancer l. 85, README). Il ne faut retirer **que** `GrimoireData.lua`.
- **Non mesurable** : `raw.githubusercontent.com` ne fournit aucune télémétrie. On ne peut pas savoir combien d'anciens clients restent, donc la décision repose sur un délai annoncé.

### Conditions de retrait
1. La version courante de l'installeur, qui gère la migration Grimoire → Profitmancer, est disponible depuis au moins 8 semaines.
2. L'obsolescence a été annoncée (README, page CurseForge, onglet Addon du site).
3. La période d'avertissement en jeu (étape 2) est terminée.

### Étapes
1. **Immédiat** : retirer `Grimoire-WoW-Forever.zip` de `main`, pour qu'aucune nouvelle installation Grimoire ne soit possible. Une Release archivée peut le conserver si besoin.
2. **Avertir en jeu (N semaines)**
   - L'ancien addon affiche `GrimoireData.ah` dans chaque tooltip (`Grimoire.lua` l. 114 : `L.cloud .. " · " .. GrimoireData.ah`).
   - Écrire dans ce champ, uniquement pour le fichier Grimoire, un libellé comme `"OBSOLETE → installez Profitmancer (doublevb.github.io/grimoire-ah)"`.
   - Concrètement : un paramètre `label` à `luaFaction(..., "GrimoireData")`.
3. **Gel : fichier figé plutôt qu'une 404**
   - L'URL lue par les clients est fixe (`data/ah/<faction>-auction-house/GrimoireData.lua`), et la l. 281 vide ce dossier à chaque run. Le fichier ne survit donc que si **le job lui-même** le réécrit.
   - Remplacer la l. 283 par l'écriture d'un **contenu constant** : `GrimoireData={v=2,t=<date du gel>,key="…",ah="OBSOLETE",rs="",p={},alt={}}`, sans prix.
   - Avec `p={}`, l'addon retombe sur Auctionator (`Grimoire.lua` l. 52-64) au lieu de garder indéfiniment des prix cloud périmés.
   - À ce stade, aucun avertissement ne s'affiche plus : `ageText` n'est appelé que pour un prix cloud (l. 57-63). L'avertissement n'est visible qu'à l'étape 2.
4. **État final recommandé** : garder ce fichier figé à vie. Il est minuscule, et `luaFaction(..., "GrimoireData")` disparaît au profit d'une constante.
   - Supprimer complètement le fichier reste possible plus tard. Les anciens updaters prendraient alors une 404, se contenteraient de loguer `ERROR`, et l'addon garderait ses derniers prix téléchargés, donc périmés. C'est pourquoi le gel est préférable.
5. **Nettoyage** : renommer `LEGACY` en `FACTION_FILES` et corriger les commentaires l. 7, 55-57 et 135-136. Garder pour l'instant le code de migration de `Install-Profitmancer.ps1` (l. 28, 53-57), sans risque, et le retirer dans une version ultérieure.
6. **Retour arrière** : restaurer la l. 283 d'origine, une seule ligne, en cas de plainte.

---

## 6. Quick wins (< 30 min chacun)

| # | Action | Réf. |
|---|---|---|
| 1 | Ajouter doctype, charset, viewport et `lang`, et supprimer la meta `claude:` | P1-2 |
| 2 | Garder un `grimoire-alchimiste.html` de redirection et mettre `index.html` à jour | P1-3 |
| 3 | Mettre le coût à `null` quand un prix manque, et corriger le tri | P1-4 |
| 4 | `ah.yml` : échouer si le `git fetch` de `data` échoue pour une autre raison que « branche absente » | P0-1 (partiel) |
| 5 | `readJson` : ne renvoyer la valeur par défaut que sur `ENOENT` | P0-1 (partiel) |
| 6 | Ajouter `AbortSignal.timeout()` sur tous les `fetch` | P1-7 |
| 7 | Corriger la sentinelle `-1` du tri par compétence | P2-1 |
| 8 | Corriger la condition du badge « limited stock » | P2-2 |
| 9 | Supprimer `RULESET`/`AH_IDS` et le champ `cloudCfg` | P2-4 |
| 10 | Corriger le compteur « named » du log de `names.json` | P2-6 |
| 11 | `.langsw` : remplacer `color:#fff` par `var(--on-accent)`, et dédoublonner `.histhead` | P1-11, P2-9 |
| 12 | Ajouter `LICENSE` et une section « contenus tiers » | P1-10 |
| 13 | Faire passer `aria-label` et `title` par `esc()`, et formater la date du graphique avec `LOC` | P2-16 |
| 14 | Mettre `role="tooltip"` sur `.wtt` | P1-11 (partiel) |
| 15 | Supprimer `_cutfix` et afficher la commission dans l'en-tête du tableau | P1-5 (partiel) |

---

## 7. Non vérifié

- Délais par défaut d'undici dans le `fetch` de Node 20 (`headersTimeout`/`bodyTimeout`).
- Taille réelle et contenu actuels de la branche `data` (`snaps.json`, `names.json`) : je n'ai pas fait de fetch, pour rester en lecture seule.
- Compression gzip de la page par GitHub Pages : seule une requête HEAD sans `Accept-Encoding` a été faite. Elle a renvoyé 200, `text/html; charset=utf-8`, 2 676 647 octets et `max-age=600`.
- Autorisation CORS du navigateur vers `oauth.battle.net` et `*.api.blizzard.com`, chemin « API Blizzard » de la page.
- Taux de commission réel de l'HV Blackwater, et accès des joueurs Blackwater aux PNJ A, H et N.
- Conformité de la version du zip (1.3.7) avec CurseForge.
- Code Lua de l'addon Profitmancer hors recherche ciblée : `Names.lua` (563 Ko), `Static.lua`, etc. n'ont pas été audités.
- Conditions d'utilisation de Wowhead et de Blizzard (P1-9) : cela relève d'une validation juridique.
- Nombre d'installations Grimoire encore actives : aucune télémétrie n'existe.
