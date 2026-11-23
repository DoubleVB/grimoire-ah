# Profitmancer — WoW Forever crafting & auction house

Profitmancer helps you make gold with your professions and the auction house on **WoW Forever**. It is an in-game addon, a companion website and an hourly cloud scan of every Forever auction house.

- **Addon:** [CurseForge](https://www.curseforge.com/wow/addons/profitmancer)
- **Website:** [doublevb.github.io/grimoire-ah](https://doublevb.github.io/grimoire-ah/)

## The addon

- **Tooltips:** vendor price, AH market price with sales per day, crafting cost and profit. Hold Shift for the details.
- **Profession windows:** profit or loss next to every recipe, % chance of a skill point, cooldown status, and an Export button that turns a recipe's reagents into a shopping list.
- **Craft cooldowns:** transmutes, Mooncloth, Salt Shaker... for every profession and every character, with a notification when one is ready and a counter on the minimap button.
- **Auction house tabs:** *Sales* (history, totals by item, sales awaiting mail, current listings vs market price) and *Shop lists* (Auctionator-compatible lists with an adjustable number of crafts and prefilled purchases).
- **Options window:** right-click the minimap button or `/pfm options`.
- **Earnings per session:** `/pfm gains`.

English and French.

## Automatic prices (optional, Windows)

Install the free price updater with one line in PowerShell:

```
irm https://doublevb.github.io/grimoire-ah/install.ps1 | iex
```

Or download [`Profitmancer-WoW-Forever.zip`](https://github.com/DoubleVB/grimoire-ah/raw/main/Profitmancer-WoW-Forever.zip), extract it and double-click `Installer-Profitmancer.bat`. It finds your WoW Forever folder, installs the addon if needed and keeps the prices up to date: Blizzard publishes them once an hour, and the updater checks for new ones every 15 minutes. The game loads them at login, `/reload` or a left click on the minimap button.

## How the data works

Every hour, a GitHub Actions workflow (`.github/workflows/ah.yml`, script `scripts/fetch-ah.mjs`) reads the Blizzard auction house API for every WoW Forever auction house (Alliance, Horde, Blackwater) and publishes to the **`data`** branch:

- `index.json`: the list of auction houses;
- `ah/<house>/latest.json`, `catalog.json`: current prices of every item;
- `ah/<house>/snaps.json`: 7 days of history for the website's sales estimates;
- `ah/<house>/ProfitmancerData.lua`: the same prices, ready for the addon;
- `names.json`: item names (English and French), quality, category and icon.

The `data` branch is rewritten on each scan, without history, so the repository stays small.

### Running your own scan

1. Fork the repository (it must be public so the addon and website can read the data).
2. *Settings → Secrets and variables → Actions → Secrets*: add `BLIZZARD_CLIENT_ID` and `BLIZZARD_CLIENT_SECRET` (from the Blizzard developer portal).
3. Optional variables: `REGION` (`eu`), `NAMESPACE` (`dynamic-forever-eu`), `RULESET` and `AH_IDS`.
4. *Actions → Scan AH → Run workflow*. A `data` branch appears after about a minute.

GitHub pauses scheduled workflows after 60 days without activity: click *Enable workflow* in the Actions tab to resume.

---

**FR** — Profitmancer t'aide à gagner de l'or avec tes métiers et l'hôtel des ventes de WoW Forever : un addon (prix, profit des crafts, % de chance de monter, cooldowns de tous tes personnages, historique des ventes, listes de courses, options), un site compagnon et un scan horaire de tous les hôtels des ventes de Forever.
