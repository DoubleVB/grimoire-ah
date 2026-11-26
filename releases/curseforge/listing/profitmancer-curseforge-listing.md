# Profitmancer — CurseForge listing

## Project name
Profitmancer

## Summary (one sentence)
Shows each item's vendor price, auction house market price and crafting profit right in its tooltip.

## Category
Auction & Economy (secondary: Professions, Tooltip)

## Game version
WoW Forever (Interface 16001)

## Description

### What's new in 1.3.9
- On-screen notification when an auction sells (sound, movable, can be turned off).
- Choose where the sale text goes: general chat, a Profitmancer tab, or nowhere.
- Sale messages show the item icon and a clickable name, and keep their look after a `/reload`.

**Profitmancer adds three short lines to every item tooltip, so you know at a glance what an item is worth and whether crafting it pays off.**

- **Vendor** – what an NPC sells it for (in green when that is cheaper than the auction house), otherwise what an NPC pays you for it.
- **AH** – the market price (average of the cheapest 15 % of listings) and, with the optional price updater, how many sell per day.
- **Craft** – the cost of the reagents (cheapest of vendor or AH for each one) and the profit or loss when you sell the result at the auction house.

Hold **Shift** for the details: lowest buyout, quantity listed, 24 h sales, the profession and skill of the recipe, the nearest vendor with coordinates, how many recipes use a reagent and its most profitable use.

Covers 2,000+ recipes from Alchemy, Cooking, Blacksmithing, Leatherworking, Tailoring, Engineering, Enchanting, Mining (smelting) and First Aid. English and French.

### Where the prices come from
- **Auctionator** (recommended): Profitmancer uses the prices from your own Auctionator scans, and updates as soon as you scan.
- **Hourly cloud prices** (optional): every WoW Forever auction house (Alliance, Horde, Blackwater) is scanned every hour through the Blizzard API. The free price updater on the Profitmancer website keeps the addon's price file up to date, with 24 h sales for every item. Prices load at login or with `/pfm reload`.

### Minimap button and commands
- Minimap button: left click loads the latest prices, right click shows the status, drag to move it.
- `/pfm` status · `/pfm reload` load the latest prices · `/pfm detail` always show the details · `/pfm minimap` hide/show the button · `/pfm nag` reminders on/off · `/pfm off` / `/pfm on`.

### Companion website
Rankings of the most profitable crafts, leveling guides, shopping lists for Auctionator, sales history and a catalog of every item at the auction house: https://doublevb.github.io/grimoire-ah/grimoire-alchimiste.html

---

**FR** — Profitmancer ajoute trois lignes dans l'infobulle de chaque objet : prix PNJ, prix à l'hôtel des ventes (et ventes par jour) et profit du craft. Maintiens Maj pour le détail. Fonctionne avec Auctionator, ou avec les prix horaires du programme de mise à jour disponible sur le site.

## Changelog (1.2.1)
First public release.
- Vendor, AH and Craft lines in item tooltips, details with Shift.
- Prices from Auctionator scans or from the hourly cloud price file.
- Minimap button and /pfm commands.
- English and French.
