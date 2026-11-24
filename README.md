# Profitmancer

Gagne de l'or avec tes métiers et l'hôtel des ventes de **WoW Forever**.
*Make gold with your professions and the auction house on WoW Forever.*

- **Addon** : [CurseForge](https://www.curseforge.com/wow/addons/profitmancer)
- **Site** : [doublevb.github.io/grimoire-ah](https://doublevb.github.io/grimoire-ah/)

## Les 3 morceaux

| Morceau | Rôle |
|---|---|
| Addon en jeu | Affiche prix, coût de craft et profit directement dans le jeu |
| Site web | Compagnon : prix, ventes estimées, rentabilité des recettes |
| Scan cloud | Lit tous les hôtels des ventes toutes les 10 min et publie les prix |

## L'addon

- **Infobulles** : prix vendeur, prix HV, ventes par jour, coût de craft, profit.
- **Fenêtres de métiers** : profit par recette, % de chance de monter, liste de courses.
- **Cooldowns** : transmutations, Étoffe lunaire, etc., pour tous tes personnages.
- **Onglets HV** : historique des ventes, listes de courses compatibles Auctionator.
- **Commandes** : `/pfm options`, `/pfm gains`. Anglais et français.

## Installer les prix automatiques (Windows, optionnel)

Une ligne dans PowerShell :

```
irm https://doublevb.github.io/grimoire-ah/install.ps1 | iex
```

Ou télécharge [`Profitmancer-WoW-Forever.zip`](https://github.com/DoubleVB/grimoire-ah/raw/main/Profitmancer-WoW-Forever.zip), extrais-le et lance `Installer-Profitmancer.bat`.
Les prix se rechargent à la connexion, au `/reload` ou au clic gauche sur la minimap.

## Comment ça marche

1. Un workflow GitHub Actions (`.github/workflows/ah.yml`, script `scripts/fetch-ah.mjs`) tourne toutes les 10 min.
2. Il lit l'API Blizzard pour chaque marché (type de serveur × faction).
3. Il publie les résultats sur la branche **`data`** (réécrite à chaque scan, sans historique).
4. L'addon et le site lisent cette branche.

Blizzard publie ses données environ une fois par heure. Les données inchangées ne sont pas re-stockées.

## Développement

Aucune dépendance. `npm run dev`, puis http://localhost:5173.

## Lancer ton propre scan

1. Fork le dépôt (public).
2. *Settings → Secrets → Actions* : ajoute `BLIZZARD_CLIENT_ID` et `BLIZZARD_CLIENT_SECRET`.
3. Optionnel : variables `REGION` (`eu`) et `NAMESPACE` (`dynamic-forever-eu`).
4. *Actions → Scan AH → Run workflow*.

GitHub met les workflows planifiés en pause après 60 jours d'inactivité : clique *Enable workflow*.

## Pour aller plus loin

- [`docs/ROADMAP.md`](docs/ROADMAP.md) : chantiers prévus
- [`docs/SECURITE.md`](docs/SECURITE.md) : sécurité
- [`docs/MIGRATION-GRIMOIRE.md`](docs/MIGRATION-GRIMOIRE.md) : migration depuis Grimoire
- [`AUDIT.md`](AUDIT.md) : audit détaillé
