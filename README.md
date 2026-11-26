# Profitmancer

Make gold with your professions and the auction house on **WoW Forever**.

- **Addon:** [CurseForge](https://www.curseforge.com/wow/addons/profitmancer)
- **Website:** [doublevb.github.io/grimoire-ah](https://doublevb.github.io/grimoire-ah/)

## What's new in 1.3.9

- **On-screen sale notification:** a pop-up like the cooldown one shows what sold and for how much (sound, Move and Test buttons).
- **Your choice in the options:** sale text in the general chat, in a Profitmancer tab or not in chat, with or without the pop-up.
- **Clearer sale messages:** item icon and clickable coloured name, coins lined up with the text, shorter wording. They keep their look after a `/reload` with chat history addons.
- **Sale notifications** now show up reliably. New `/pfm gains saletest` command to test the display.

### 1.3.8

- **Sale notifications:** a message tells you what sold and for how much (optional dedicated chat tab, Test button in the options).
- **Export straight to your shopping lists:** the recipe goes into your AH shopping lists with a confirmation pop-up (Shift+click: Auctionator copy window).
- **Minimap tooltip:** more compact, with the items you have listed at the AH and their total value.
- Smaller red cooldown counter, round and centered glow on the minimap icon.

Older versions: [`releases/discord/discord-posts.txt`](releases/discord/discord-posts.txt).

## The 3 parts

| Part | Role |
|---|---|
| In-game addon | Shows prices, crafting cost and profit directly in the game |
| Website | Companion: prices, estimated sales, recipe profitability |
| Cloud scan | Reads every auction house every 10 min and publishes the prices |

## The addon

- **Tooltips:** vendor price, AH price, sales per day, crafting cost, profit.
- **Profession windows:** profit per recipe, % chance of a skill point, shopping list.
- **Cooldowns:** transmutes, Mooncloth, etc., for all your characters.
- **Auction house tabs:** sales history, Auctionator-compatible shop lists.
- **Commands:** `/pfm options`, `/pfm gains`. English and French.

## Install automatic prices (Windows, optional)

One line in PowerShell:

```
irm https://doublevb.github.io/grimoire-ah/install.ps1 | iex
```

Or download [`Profitmancer-WoW-Forever.zip`](https://github.com/DoubleVB/grimoire-ah/raw/main/releases/github/Profitmancer-WoW-Forever.zip), extract it and run `Installer-Profitmancer.bat`.
Prices reload at login, on `/reload` or on a left click on the minimap button.

## How it works

1. A GitHub Actions workflow (`.github/workflows/ah.yml`, script `scripts/fetch-ah.mjs`) runs every 10 min.
2. It reads the Blizzard API for every market (server type × faction).
3. It publishes the results to the **`data`** branch (rewritten on each scan, no history).
4. The addon and the website read that branch.

Blizzard publishes its data about once an hour. Unchanged data is not stored twice.

## Development

No dependencies. Run `npm run dev`, then open http://localhost:5173.

## Run your own scan

1. Fork the repository (public).
2. *Settings → Secrets → Actions*: add `BLIZZARD_CLIENT_ID` and `BLIZZARD_CLIENT_SECRET`.
3. Optional: variables `REGION` (`eu`) and `NAMESPACE` (`dynamic-forever-eu`).
4. *Actions → Scan AH → Run workflow*.

GitHub pauses scheduled workflows after 60 days of inactivity: click *Enable workflow*.

## Further reading

- [`docs/ROADMAP.md`](docs/ROADMAP.md): planned work
- [`docs/SECURITE.md`](docs/SECURITE.md): security
- [`docs/MIGRATION-GRIMOIRE.md`](docs/MIGRATION-GRIMOIRE.md): migrating from Grimoire
- [`AUDIT.md`](docs/AUDIT.md): detailed audit
