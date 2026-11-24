# Sécurité et perte de données (synthèse de AUDIT.md)

Références de lignes : `HEAD:grimoire-alchimiste.html` (page), `scripts/fetch-ah.mjs` (fetch), `.github/workflows/ah.yml` (ah.yml), `install.ps1`. Les numéros peuvent varier après le renommage en `profitmancer.html`.

## 1. Perte de données (P0)

### 1.1 Branche `data` effacée puis poussée en force (P0-1)
- **Risque** : un `git fetch` raté (réseau, auth) est traité comme « premier run ». Le script repart de zéro et la branche orpheline est réécrite par `git push -f`. Perte irréversible de 7 jours d'historique des 15 marchés, et de `names.json`.
- **Où** : `ah.yml` l. 16-17 et 31-39 ; `fetch-ah.mjs` l. 41 (`readJson` avale toute erreur), 159, 222, 236, 245.
- **Correctif**
  ```bash
  git ls-remote --exit-code origin data   # code 2 = branche absente ; autre erreur => exit 1
  ```
  ```js
  catch (e) { if (e.code === "ENOENT") return d; throw e; }
  ```
  Retirer `2>/dev/null`, refuser le push si les snapshots chutent de plus de 50 %, garder une sauvegarde (`upload-artifact` 7 jours ou branche `data-prev`).

### 1.2 Marché absent une seule fois = dossier supprimé (P0-2)
- **Risque** : si Blizzard omet un AH ou qu'un appel ruleset échoue, le marché sort de `groups`, n'est pas réinjecté depuis `oldIndex`, et son dossier est supprimé. Historique perdu, 404 chez les joueurs.
- **Où** : `fetch-ah.mjs` l. 66-67, 72, 233, 264, 287.
- **Correctif** : stocker `missingSince` dans `index.json`, réinjecter l'entrée `prev`, ne supprimer qu'après N runs consécutifs d'absence, logger un warning.
  ```js
  if (!seenNow && daysMissing(prev) < N) { keep.push(prev); continue; } // avant le rm l. 287
  ```

## 2. Exécution de code chez les joueurs (P0/P1)

### 2.1 Installation sans intégrité (P0-3)
- **Risque** : `irm .../install.ps1 | iex`, puis zip téléchargé depuis `raw.githubusercontent.com/.../main/` (référence mutable), sans hash ni signature, exécuté en `-ExecutionPolicy Bypass` et enregistré comme tâche planifiée (15 min). Le zip est déposé à la main, ses sources Lua ne sont pas dans le dépôt. Une compromission du compte donne une exécution arbitraire chez chaque utilisateur.
- **Où** : `install.ps1` l. 7, 14, 18 ; page l. 843 et 847 ; `Install-Profitmancer.ps1` (zip) l. 123 ; `Installer-Profitmancer.bat`.
- **Correctif** : versionner `addon/` et `updater/`, construire le zip en CI, le publier en asset de Release taggée, épingler URL et SHA256.
  ```powershell
  $h = (Get-FileHash $zip -Algorithm SHA256).Hash
  if ($h -ne $ExpectedSha256) { throw "SHA256 invalide : $h" }
  ```
  Option : signature Authenticode pour retirer `Bypass`. Documenter une variante sans `iex` (télécharger, vérifier, exécuter). Hash du zip audité : `CE2583...C690`.

### 2.2 Updater : Lua non vérifié (P1-6)
- **Risque** : `ProfitmancerData.lua` est téléchargé toutes les 15 min depuis une branche réécrite en force, validé par un simple `Contains("ProfitmancerData={")`, puis copié dans `Interface\AddOns`. Compromission de `data` = Lua arbitraire dans le client WoW (sandbox addon) ; fichier tronqué = addon cassé.
- **Où** : `Update-Profitmancer.ps1` (zip) l. 18-27 ; `fetch-ah.mjs` l. 127-142.
- **Correctif** : publier un `.sha256` (ou signature) vérifié avant le `Move-Item` ; n'accepter après l'en-tête que des lignes `[\d+]={\d+,\d+,\d+,-?\d+}` ; échapper aussi `\n` dans `esc()` côté générateur.

### 2.3 Installeur qui supprime trop (P2-15)
- **Risque** : suppression de `%LOCALAPPDATA%\Grimoire` et de tout `AddOns\Grimoire` contenant un `Grimoire.toc`, sans vérifier l'auteur. Un addon homonyme est effacé sans confirmation.
- **Où** : `Install-Profitmancer.ps1` (zip) l. 54-57.
- **Correctif** : contrôler `## Author: Workby` dans le `.toc` avant `Remove-Item`, demander confirmation.

## 3. Injection et secrets côté page (P1-1)

### 3.1 XSS par données externes
- **Risque** : des valeurs venant de `names.json`, `catalog.json`, `index.json`, `latest.json`, de l'API Blizzard ou d'`Auctionator.lua` sont insérées en `innerHTML` sans échappement. L'URL cloud est réglable (l. 2699) et la branche `data` est écrite par un bot : une donnée piégée s'exécute dans la page. Les tooltips `ttHtml` (données embarquées) ne sont pas concernés.
- **Où** (page) : l. 2775 (`catIcon(r.m[7])`), 2777-2778 (`r.m[6]`, `r.ql`, `r.id`), 2744-2745 (`catFillCls`), 2645 (`houseOpts`), 2373/2385/2399/2447 (noms royaumes/AH), 2562 (clés Auctionator), 1548 (`x.src`), 2672 (`cIds`). Aussi `aria-label`/`title` non échappés (l. 2049, 2062, 2090, 2134, ex. `NAME_FR[19026]` contient des guillemets).
- **Correctif** : une seule `esc()` (dédoublonner l. 2786 et 1866), appliquée à toute donnée non embarquée ; valider les formats d'attributs ; `new Option()` pour les `<option>`.
  ```js
  const safeId = v => /^\d+$/.test(v) ? v : "";
  const safeIcon = v => /^[\w-]+$/.test(v) ? v : "inv_misc_questionmark";
  ```

### 3.2 Secret Blizzard en clair
- **Risque** : `clientId`, `clientSecret` et `token` sont stockés dans `localStorage["grim:settings"]`, lisibles par tout script injecté (voir 3.1).
- **Où** : page l. 1133, 2326-2328.
- **Correctif** : ne pas persister le secret par défaut (`sessionStorage`, ou case « se souvenir » explicite). Ajouter une CSP :
  ```html
  <meta http-equiv="Content-Security-Policy" content="default-src 'self'; connect-src 'self' https://oauth.battle.net https://*.api.blizzard.com https://raw.githubusercontent.com; img-src 'self' data: https:">
  ```
  La page contient des scripts et styles inline : prévoir `'unsafe-inline'` ou des nonces, à valider.

## 4. Robustesse réseau et stockage (P1)

- **Fetch sans timeout (P1-7)** : page l. 2343, 2351, 2652, 2666, 2723 ; `fetch-ah.mjs` l. 20, 31, 150, 202. Une requête qui pend laisse `apiBusy` à `true` (l. 2480, 2489) et bloque l'auto-refresh ; en CI elle bloque le scan jusqu'à `timeout-minutes: 30`. Correctif : `fetch(url, { signal: AbortSignal.timeout(20000) })`.
- **Quota localStorage avalé (P1-8)** : `save()` l. 1080 (`catch(e){}`) perd silencieusement panier, réglages, scans ; `hist` (l. 1138, 1179-1183) n'est pas borné. Correctif : `save()` renvoie un booléen et avertit une fois ; purger `hist` au-delà de 60 jours.
- **Renommage (P1-3)** : ne pas changer le préfixe `grim:` ni l'IndexedDB `"grimoire"` (l. 1079-1080, 2236) sans migration, sinon réinitialisation des données locales ; garder un `grimoire-alchimiste.html` de redirection.

## 5. Chaîne d'approvisionnement CI (P2-14)

- **Risque** : `actions/checkout@v4` et `setup-node@v4` épinglés par tag, dans un job qui peut écrire dans le dépôt. Token dans l'URL de push (`git push -qf ...` dans `ah.yml` l. 31-39) : à vérifier qu'il n'apparaît pas dans les logs.
- **Où** : `ah.yml` l. 4, 14, 19, 31-39.
- **Correctif** : épingler par SHA (`uses: actions/checkout@<sha40> # v4`), `permissions: contents: write` minimal, ne pousser que si le diff n'est pas vide.

## 6. Checklist de vérification après correction

- [ ] Simuler un `git fetch` en échec dans `ah.yml` : le run échoue, la branche `data` reste intacte.
- [ ] Corrompre `snaps.json` : `readJson` lève une erreur, aucun reset silencieux.
- [ ] Retirer un AH de la réponse Blizzard (mock) : son dossier `data/ah/<clé>` subsiste et un warning est loggé.
- [ ] Un test de chute de snapshots supérieure à 50 % bloque le push.
- [ ] `install.ps1` pointe vers une Release taggée et échoue (`throw`) avec un zip modifié d'un octet.
- [ ] Le zip est reconstruit en CI depuis `addon/` et `updater/` ; le SHA256 publié correspond.
- [ ] L'updater rejette un `ProfitmancerData.lua` tronqué ou dont le hash diffère.
- [ ] Injecter `"><img src=x onerror=alert(1)>` dans `names.json`, `catalog.json`, `index.json`, `latest.json` et un `Auctionator.lua` : aucune exécution.
- [ ] `localStorage["grim:settings"]` ne contient plus `clientSecret` par défaut ; la CSP ne casse aucune fonction.
- [ ] Un `fetch` simulé qui pend s'interrompt après 20 s et `apiBusy` revient à `false`.
- [ ] Quota localStorage saturé : un avertissement visible s'affiche.
- [ ] Les logs d'un run CI ne contiennent ni token ni secret ; les actions sont épinglées par SHA.
