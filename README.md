# Grimoire — scan de l'HV dans le cloud

Toutes les heures, GitHub Actions interroge l'API Blizzard (WoW Forever) et publie :

- `latest.json` : les derniers prix de tous les objets ;
- `snaps.json` : 7 jours d'historique des objets du Grimoire.

Les deux fichiers sont publiés sur la branche **`data`**. Le Grimoire les fusionne à chaque ouverture.

## Mise en place (une fois)

1. **Créer le dépôt** : sur GitHub, *New repository*, nom `grimoire-ah`, **Public**. Le dépôt doit être public pour que le Grimoire puisse lire les données. Il ne contient que des prix d'HV : tes identifiants restent dans les *Secrets*, qui ne sont jamais visibles.
2. **Envoyer les fichiers** : *Add file → Upload files*. Glisse le **contenu** du dossier `grimoire-cloud` (les dossiers `.github`, `scripts`, `data`, et ce fichier), puis clique sur *Commit changes*.
   - Le dossier `.github` commence par un point. S'il n'apparaît pas dans l'explorateur Windows, active *Affichage → Éléments masqués*.
3. **Ajouter les secrets** : *Settings → Secrets and variables → Actions → onglet Secrets → New repository secret*.
   - `BLIZZARD_CLIENT_ID` : ton Client ID Blizzard.
   - `BLIZZARD_CLIENT_SECRET` : ton Client secret Blizzard.
4. **Ajouter les variables** : même page, onglet **Variables**, *New repository variable*.
   - `RULESET` et `AH_IDS` : recopie les valeurs affichées dans le Grimoire, onglet *Price source → API Blizzard → « For GitHub (Variables) »*.
   - Facultatif : `REGION` (`eu` par défaut) et `NAMESPACE` (`dynamic-forever-eu` par défaut).
5. **Premier lancement** : onglet *Actions*, accepte l'activation des workflows si GitHub la demande, puis *Scan AH → Run workflow*. Après environ 1 minute, le point doit être vert et une branche `data` doit apparaître.
6. **Brancher le Grimoire** : onglet *Price source → API Blizzard → Data address*, colle :
   `https://raw.githubusercontent.com/DoubleVB/grimoire-ah/data/`

Le scan tourne ensuite automatiquement toutes les heures (à hh:17), PC éteint compris.

## Bon à savoir

- **Délais :** GitHub peut décaler les tâches planifiées de quelques minutes. Les données brutes mettent jusqu'à environ 5 minutes à se mettre à jour.
- **Taille du dépôt :** la branche `data` est réécrite à chaque scan, sans historique, pour que le dépôt reste léger.
- **Mise en pause :** si le dépôt n'a aucune activité pendant 60 jours, GitHub met les tâches planifiées en pause. Il suffit de cliquer sur *Enable workflow* dans l'onglet Actions.
