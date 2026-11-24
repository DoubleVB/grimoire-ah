# Profitmancer — WoW Forever crafting & auction house

Profitmancer helps you make gold with your professions and the auction house on **WoW Forever**. It is an in-game addon, a companion website and a cloud scan (every 10 minutes) of every Forever auction house.

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

A GitHub Actions workflow (`.github/workflows/ah.yml`, script `scripts/fetch-ah.mjs`) runs every 10 minutes by cron (GitHub sometimes skips scheduled runs; Blizzard publishes new data about once an hour and unchanged data is not stored twice). It reads the Blizzard auction house API for every WoW Forever market, one per server type (PvP, Normal, RP, RP-PvP) and faction (Alliance, Horde, Blackwater), and publishes to the **`data`** branch:

- `index.json`: the list of markets;
- `ah/<server type>-<faction>/latest.json`, `catalog.json` (e.g. `pvp-horde`, `pve-alliance`): current prices of every item;
- `ah/<server type>-<faction>/snaps.json`: 7 days of history for the website's sales estimates;
- `ah/<server type>-<faction>/ProfitmancerData.lua`: the same prices, ready for the addon;
- `ah/<faction>-auction-house/ProfitmancerData.lua`: every server type of a faction in one file, the one the price updater downloads (the addon uses the prices of the server type you play on);
- `names.json`: item names (English and French), quality, category and icon.

The `data` branch is rewritten on each scan, without history, so the repository stays small.

## Local development

No `npm install` needed: there are no dependencies. Run `npm run dev`, then open http://localhost:5173.

### Running your own scan

1. Fork the repository (it must be public so the addon and website can read the data).
2. *Settings → Secrets and variables → Actions → Secrets*: add `BLIZZARD_CLIENT_ID` and `BLIZZARD_CLIENT_SECRET` (from the Blizzard developer portal).
3. Optional variables: `REGION` (`eu`) and `NAMESPACE` (`dynamic-forever-eu`).
4. *Actions → Scan AH → Run workflow*. A `data` branch appears after about a minute.

GitHub pauses scheduled workflows after 60 days without activity: click *Enable workflow* in the Actions tab to resume.

---

**FR** — Profitmancer t'aide à gagner de l'or avec tes métiers et l'hôtel des ventes de WoW Forever : un addon (prix, profit des crafts, % de chance de monter, cooldowns de tous tes personnages, historique des ventes, listes de courses, options), un site compagnon et un scan cloud (toutes les 10 minutes) de tous les hôtels des ventes de Forever.
