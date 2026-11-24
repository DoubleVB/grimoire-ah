# Migration Grimoire → Profitmancer

Statut au 23/11/2026. Référence : `AUDIT.md` §5 (retrait de `GrimoireData.lua`) et P1-3.

## 1. Déjà fait

- Page principale renommée : `grimoire-alchimiste.html` devient `profitmancer.html`.
- `index.html` et `grimoire-alchimiste.html` ne sont plus que des redirections vers
  `profitmancer.html`. Elles conservent `?query` et `#hash`.
- `Grimoire-WoW-Forever.zip` retiré de `main`. Seul `Profitmancer-WoW-Forever.zip` reste.
- Bot de publication de la branche `data` renommé.
- Addon Profitmancer 1.3.7 : il ne lit plus `GrimoireData`. L'installeur désinstalle
  l'ancienne tâche, la configuration et l'addon Grimoire.
- Serveur de dev local sans dépendance (`npm run dev`).

## 2. Ce qui reste volontairement nommé Grimoire

| Élément | Pourquoi | Risque si on le supprime |
|---|---|---|
| `GrimoireData.lua` (généré par `fetch-ah.mjs`) | Lu par l'ancien updater `Update-Grimoire.ps1` des installations anciennes | 404 chez les anciens clients : ils gardent des prix périmés sans le savoir |
| URL et dépôt `DoubleVB/grimoire-ah` (Pages, `raw.githubusercontent.com`) | Les liens publiés (addon, README, CurseForge, `install.ps1`) pointent dessus | Liens morts, installeur et updaters cassés, champ « Data address » invalide |
| IndexedDB `"grimoire"` | Contient les scans et l'historique locaux des utilisateurs | Perte silencieuse des scans, sauf migration explicite |
| Préfixe localStorage `grim:` (dont `grim:settings`) | Réglages, panier, personnages | Réinitialisation des données de chaque utilisateur |
| `Grimoire.bat`, `grimoire-serveur.ps1` | Cités par le lanceur local `LAUNCHER`, absents du dépôt (code mort, AUDIT P2-13) | Aucun fichier réel : seul du code mort à nettoyer dans la page |
| Redirection `grimoire-alchimiste.html` | L'ancienne URL est publiée par l'addon (`## X-Website`) et par des sites externes | 404 sur les anciens liens et marque-pages |

Ne jamais renommer les clés de stockage sans migration. Ne pas renommer le dépôt
sans avoir mis à jour toutes les URLs publiées.

## 3. Plan de retrait définitif de `GrimoireData.lua`

Prérequis (AUDIT §5) :
1. L'installeur gérant la migration est disponible depuis au moins 8 semaines.
2. L'obsolescence est annoncée (README, CurseForge, onglet Addon du site).
3. La période d'avertissement en jeu est terminée.

| Étape | Action | Condition de passage |
|---|---|---|
| 1 | Retirer le zip Grimoire de `main` (archive en Release si besoin) | Fait |
| 2 | Avertir en jeu : écrire `OBSOLETE → installez Profitmancer` dans `ah` du seul fichier Grimoire (paramètre `label` de `luaFaction`) | Annonce publiée, puis N semaines écoulées |
| 3 | Geler : écrire un contenu constant (`ah="OBSOLETE"`, `p={}`), sans prix. L'addon retombe sur Auctionator | Fin de l'avertissement, aucune plainte |
| 4 | État final : garder ce fichier figé à vie. Le supprimer reste possible, mais les anciens updaters loguent une 404 et gardent des prix périmés | Décision explicite du mainteneur |
| 5 | Nettoyage : renommer `LEGACY` en `FACTION_FILES` (ce sont les fichiers `ProfitmancerData.lua` actuels, à ne pas retirer). Retirer le code de migration de l'installeur dans une version ultérieure | Étape 3 stable |
| 6 | Retour arrière : restaurer l'écriture d'origine (une ligne) | En cas de plainte |

Point d'attention : l'usage restant est non mesurable (aucune télémétrie sur
`raw.githubusercontent.com`). La décision repose donc sur un délai annoncé.

## 4. Dev local

1. Node 20 ou plus requis. Lancer `npm run dev` à la racine (port modifiable avec `PORT=xxxx`).
2. Ouvrir http://localhost:5173 (sert `index.html`, qui redirige vers `profitmancer.html`).
3. Dans l'onglet de configuration cloud, renseigner le champ « Data address » :
   `https://raw.githubusercontent.com/DoubleVB/grimoire-ah/data/`
4. Les routes `/auctionator/*` n'existent pas en local : le serveur est statique,
   elles renvoient 404.
5. Aucun cache (`no-store`) : un simple rechargement suffit après modification.
