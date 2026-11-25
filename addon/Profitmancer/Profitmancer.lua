-- Profitmancer: vendor price, auction house price and craft profit in item tooltips (hold Shift for the details).
-- Prices come from ProfitmancerData.lua (hourly cloud scan, refreshed by the Profitmancer updater; loaded at login or /reload)
-- and from Auctionator's own scans when they are fresher.
local ADDON = ...
-- The Forever client runs on the modern engine: some old globals only exist under C_* namespaces
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local ReloadUI = (C_UI and C_UI.Reload) or ReloadUI
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local S = ProfitmancerStatic or { rec = {}, vend = { H = {}, A = {} }, npc = { H = {}, A = {} }, bm = {}, profs = {} }
local FR = GetLocale() == "frFR"

-- WoW Forever has no realms: characters live on a server type (ruleset) with its own auction houses.
-- Returns "PvP", "PvE", "RP", "RPPvP" or "HC" (same names as Auctionator), or nil when the client can't tell.
function ProfitmancerRuleset()
	local G, E = C_GameRules, Enum and Enum.GameRule
	if not (G and G.IsGameRuleActive and E) then return nil end
	local function on(r) if not r then return false end local ok, v = pcall(G.IsGameRuleActive, r); return ok and v end
	local pvp, rp = on(E.PvPRuleset), on(E.RPRuleset)
	if pvp and rp then return "RPPvP" elseif pvp then return "PvP" elseif rp then return "RP" elseif on(E.HardcoreRuleset) then return "HC" end
	return "PvE"
end

local L = FR and {
	perDay = "/j", vendor = "PNJ", vendorL = "PNJ", ahL = "HV", craftL = "Craft", buy = "(achat)", sell = "(rachat)", notListed = "pas en vente à l'HV", emv = "Prix marché (EMV)", low = "Plus bas", listed = "En vente",
	sold = "Vendus 24 h", craft = "Coût du craft", profit = "Profit / craft", usedIn = "Utilisé dans", recipes = "recettes",
	best = "Meilleur usage", buyAt = "Acheter chez", cheaper = "moins cher qu'à l'HV", source = "Source", cloud = "cloud",
	ago = "il y a", today = "scan d'aujourd'hui", days = "j", hours = "h", min = "min", noData = "Pas encore de prix : fais un scan complet avec Auctionator, ou installe le programme de mise à jour gratuit (les prix de Blizzard, publiés une fois par heure) depuis le site Profitmancer : doublevb.github.io/grimoire-ah",
	profs = { alch = "Alchimie", cook = "Cuisine", bs = "Forge", lw = "Travail du cuir", tail = "Couture", eng = "Ingénierie", ench = "Enchantement", mine = "Minage", fa = "Secourisme" },
	help = "/pfm guide : le guide de l'addon · /pfm reload : recharger les prix · /pfm gains : gains HV de la session (history, reset) · /pfm ventes : historique des ventes · /pfm courses : listes de courses · /pfm cd : cooldowns de craft · /pfm options : options · /pfm setup : prix automatiques · /pfm export : personnages pour le site · /pfm detail : toujours le détail · /pfm minimap : bouton on/off · /pfm nag : rappels on/off · /pfm off|on",
	pricesW = "prix", loaded = "prix d'il y a", combat = "impossible de recharger en combat.",
	same = "pas encore de nouveaux prix : ce sont les derniers disponibles (données Blizzard d'il y a %s). Blizzard publie une fois par heure, les suivants arrivent en général dans l'heure.", hourly = "Blizzard publie les prix une fois par heure", noRsYet = "Pas encore de prix pour ton type de serveur (%s) : ce sont ceux des serveurs %s en attendant.", otherRs = "Ces prix sont ceux des serveurs %s, pas de ton type de serveur (%s) : relance l'installation du programme de mise à jour pour avoir les bons.",
	stale = "prix d'il y a %s, des prix plus récents sont sûrement prêts : clique sur le bouton de la minicarte ou tape /pfm reload.",
	setupT = "Profitmancer · prix automatiques", setupTxt = "Pour avoir automatiquement les prix de ton hôtel des ventes, mis à jour à chaque publication de Blizzard (une fois par heure), et les ventes 24 h, installe le programme de mise à jour gratuit (Windows). Copie cette adresse (Ctrl+C) et ouvre-la dans ton navigateur internet (Chrome, Edge, Firefox) : la page explique tout.", setupAtr = "Sans lui, Profitmancer utilise tes scans Auctionator.", later = "Plus tard", never = "Ne plus afficher",
	mmLeft = "Clic : prix", mmRight = "Clic droit : options · Maj+clic : export",
} or {
	perDay = "/day", vendor = "Vendor", vendorL = "Vendor", ahL = "AH", craftL = "Craft", buy = "(buy)", sell = "(sell)", notListed = "not listed on the AH", emv = "Market (EMV)", low = "Lowest", listed = "Listed",
	sold = "Sold 24h", craft = "Craft cost", profit = "Profit / craft", usedIn = "Used in", recipes = "recipes",
	best = "Best use", buyAt = "Buy from", cheaper = "cheaper than the AH", source = "Source", cloud = "cloud",
	ago = "", today = "today's scan", days = "d", hours = "h", min = "min", noData = "No prices yet: do a full Auctionator scan, or install the free price updater (Blizzard's prices, published once an hour) from the Profitmancer website: doublevb.github.io/grimoire-ah",
	profs = {},
	help = "/pfm guide: the addon guide · /pfm reload: load the latest prices · /pfm gains: AH earnings this session (history, reset) · /pfm sales: sales history · /pfm shopping: shopping lists · /pfm cd: craft cooldowns · /pfm options: options · /pfm setup: automatic prices · /pfm export: characters for the website · /pfm detail: always show details · /pfm minimap: button on/off · /pfm nag: reminders on/off · /pfm off|on",
	pricesW = "prices", loaded = "prices from", combat = "can't reload during combat.",
	same = "no newer prices yet: these are the latest available (Blizzard data from %s ago). Blizzard publishes once an hour, the next ones usually arrive within the hour.", hourly = "Blizzard publishes prices once an hour", noRsYet = "No prices for your server type (%s) yet: showing the %s servers' prices meanwhile.", otherRs = "These prices are from the %s servers, not your server type (%s): run the price updater install again to get yours.",
	stale = "prices from %s ago, newer prices are probably ready: click the minimap button or type /pfm reload.",
	setupT = "Profitmancer · automatic prices", setupTxt = "To get the prices of your auction house automatically, updated each time Blizzard publishes them (once an hour), with 24 h sales, install the free price updater (Windows). Copy this address (Ctrl+C) and open it in your web browser (Chrome, Edge, Firefox): the page explains everything.", setupAtr = "Without it, Profitmancer uses your Auctionator scans.", later = "Later", never = "Don't show again",
	mmLeft = "Click: prices", mmRight = "Right-click: options · Shift+click: export",
}

ProfitmancerDB = ProfitmancerDB or {}

-- ——— Indexes built once from the static data ———
local byProduct, usedIn = {}, {}
for _, r in ipairs(S.rec) do
	local id = r[1]
	byProduct[id] = byProduct[id] or {}
	table.insert(byProduct[id], r)
	for _, x in ipairs(r[5]) do
		usedIn[x[1]] = usedIn[x[1]] or {}
		table.insert(usedIn[x[1]], r)
	end
end

local function faction()
	return UnitFactionGroup("player") == "Alliance" and "A" or "H"
end

-- ——— Prices: cloud file first while it is recent, Auctionator's scan of today otherwise ———
local function auctionator(id)
	local api = Auctionator and Auctionator.API and Auctionator.API.v1
	if not (api and api.GetAuctionPriceByItemID) then return nil end
	local ok, p = pcall(api.GetAuctionPriceByItemID, ADDON, id)
	if not ok or type(p) ~= "number" then return nil end
	local okA, age = pcall(api.GetAuctionAgeByItemID, ADDON, id)
	return p, okA and type(age) == "number" and age or nil
end

-- Prices are looked up a lot (every tooltip refresh, every recipe of a list): remember them for 10 seconds
local priceCache, priceAt = {}, 0
local priceRaw
-- ——— Market: the price file can hold every server type of a faction ("alt"); use the character's one ———
local RSN = FR and { PvP = "JcJ", PvE = "Normal", RP = "RP", RPPvP = "RP-JcJ", HC = "Hardcore" } or { PvP = "PvP", PvE = "Normal", RP = "RP", RPPvP = "RP-PvP", HC = "Hardcore" }
local function pickMarket()
	local D = ProfitmancerData
	if not D or D.picked then return D end
	local cur = ProfitmancerRuleset and ProfitmancerRuleset()
	if not cur then return D end -- the game can't tell yet: try again later
	D.picked = true
	if D.alt and D.rs ~= cur and D.alt[cur] then
		local A = D.alt[cur]
		if D.rs then D.alt[D.rs] = { t = D.t, ah = D.ah, p = D.p } end
		D.p, D.t, D.ah, D.rs = A.p, A.t, A.ah, cur
		D.alt[cur] = nil
		if priceCache then priceCache = {} end
	end
	-- prices of another server type (an old single-market file, or a server type the scan doesn't have yet)
	D.other = (D.rs and D.rs ~= "" and D.rs ~= cur) and cur or nil
	if D.other then
		local a, b = RSN[D.rs] or D.rs, RSN[D.other] or D.other
		D.otherMsg = D.alt and L.noRsYet:format(b, a) or L.otherRs:format(a, b)
	end
	return D
end
-- "Horde · Normal", in the player's language
local function marketName()
	local D = pickMarket()
	if not D then return "?" end
	local ah = D.ah or "?"
	if D.rs and RSN[D.rs] then return (ah:match("^(.-) · ") or ah) .. " · " .. RSN[D.rs] end
	return ah
end
local function price(id)
	local now = GetTime()
	if now - priceAt > 10 then priceCache, priceAt = {}, now end
	local v = priceCache[id]
	if v == nil then v = priceRaw(id) or false; priceCache[id] = v end
	return v or nil
end
function priceRaw(id)
	local D = pickMarket()
	local c = D and D.p and D.p[id]
	local cloudAge = D and D.t and (time() - D.t) or nil
	local ap, aage = auctionator(id)
	if c and (cloudAge < 6 * 3600 or not ap or (aage and aage > 0)) then
		return { emv = c[1], min = c[2], qty = c[3], sold = c[4] >= 0 and c[4] or nil, src = "cloud", age = cloudAge }
	end
	if ap then
		return { emv = ap, min = ap, qty = c and c[3] or nil, sold = c and c[4] >= 0 and c[4] or nil, src = "auctionator", days = aage }
	end
	if c then return { emv = c[1], min = c[2], qty = c[3], sold = c[4] >= 0 and c[4] or nil, src = "cloud", age = cloudAge } end
	return nil
end

local function vendorBuy(id) return S.vend[faction()][id] end

-- Reagent cost: the cheaper of the vendor and the AH
local function cost(id)
	local v, p = vendorBuy(id), price(id)
	local a = p and p.emv
	if v and (not a or v <= a) then return v, "vendor" end
	return a, "ah"
end

-- Cheapest known way to craft one item (cost per item made), with the recipe used
local function craftCost(id)
	local best, bestRec
	for _, r in ipairs(byProduct[id] or {}) do
		local total, ok = 0, true
		for _, x in ipairs(r[5]) do
			local c = cost(x[1])
			if not c then ok = false break end
			total = total + c * x[2]
		end
		if ok then
			total = total / math.max(1, r[4])
			if not best or total < best then best, bestRec = total, r end
		end
	end
	return best, bestRec or (byProduct[id] and byProduct[id][1])
end

-- ——— Formatting ———
local G, SI, CO = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:1:0|t", "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:1:0|t", "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:1:0|t"
local function money(c, signed)
	if not c then return "?" end
	local sign = ""
	if signed then sign = c < 0 and "-" or "+" end
	c = math.floor(math.abs(c) + 0.5)
	local g, s, cp = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
	if g > 0 then return sign .. g .. G .. (s > 0 and (" " .. s .. SI) or "") end -- gold: copper is noise
	if s > 0 then return sign .. s .. SI .. (cp > 0 and (" " .. cp .. CO) or "") end
	return sign .. cp .. CO
end
local function ageText(p)
	if p.src == "auctionator" then
		if p.days == 0 then return "Auctionator · " .. L.today end
		return "Auctionator · " .. (p.days and ((FR and L.ago .. " " or "") .. p.days .. " " .. L.days) or "?")
	end
	local a = p.age or 0
	local t = a < 3600 and (math.floor(a / 60) .. " " .. L.min) or a < 172800 and (math.floor(a / 3600) .. " " .. L.hours) or (math.floor(a / 86400) .. " " .. L.days)
	return L.cloud .. " · " .. marketName() .. " · " .. (FR and (L.ago .. " " .. t) or (t .. " ago"))
end
local PURPLE, GREEN, RED, GREY, YEL, BLUE = 0.71, { 0.12, 1, 0 }, { 1, 0.35, 0.29 }, { 0.62, 0.62, 0.62 }, { 1, 0.82, 0 }, { 0.44, 0.84, 1 }

local WHITE = { 1, 1, 1 }
local function sideLine(tt, left, right, col)
	tt:AddDoubleLine(left, right, 0.71, 0.55, 1, col[1], col[2], col[3])
end
local function addLine(tt, right, col)
	tt:AddDoubleLine("Profitmancer", right, PURPLE, 0.55, 1, col[1], col[2], col[3])
end
local function detail(tt, left, right, col)
	col = col or { 1, 1, 1 }
	tt:AddDoubleLine("  " .. left, right, YEL[1], YEL[2], YEL[3], col[1], col[2], col[3])
end

-- ——— The tooltip ———
local function addInfo(tt, id)
	if not id or ProfitmancerDB.off then return end
	local p = price(id)
	local isProduct = byProduct[id] ~= nil
	local isReagent = usedIn[id] ~= nil
	local vb = vendorBuy(id)
	if not p and not isProduct and not isReagent and not vb then return end
	local perDay = p and p.sold and (" |cff9d9d9d· " .. p.sold .. L.perDay .. "|r") or ""

	-- Three short lines, in this order: vendor price, auction house price, craft cost (with the profit)
	local cc, rec = nil, nil
	if isProduct then cc, rec = craftCost(id) end
	-- 1. Vendor: what an NPC sells it for (green when cheaper than the AH), else what an NPC pays you for it
	if vb and not ProfitmancerDB.noVendor then
		sideLine(tt, L.vendorL, money(vb) .. " |cff9d9d9d" .. L.buy .. "|r", (p and p.emv and vb < p.emv) and GREEN or WHITE)
	elseif not ProfitmancerDB.noVendor then
		local sell = select(11, GetItemInfo(id))
		if sell and sell > 0 then sideLine(tt, L.vendorL, money(sell) .. " |cff9d9d9d" .. L.sell .. "|r", WHITE) end
	end
	-- 2. Auction house: market price (EMV) and sales per day
	if ProfitmancerDB.noAH then -- line turned off in the options
	elseif p then sideLine(tt, L.ahL, money(p.emv) .. perDay, WHITE)
	else sideLine(tt, L.ahL, L.notListed, GREY) end
	-- 3. Craft: cost of one craft, then the profit when it is sold at the AH
	if isProduct and not ProfitmancerDB.noCraft then
		if cc and p and p.emv then
			local pr = p.emv - cc
			local pct = cc > 0 and math.floor(pr / cc * 100 + 0.5) or 0
			local c = pr >= 0 and "|cff1eff00" or "|cffff5a4a"
			sideLine(tt, L.craftL, money(cc) .. "  " .. c .. money(pr, true) .. " (" .. (pct >= 0 and "+" or "") .. pct .. "%)|r", WHITE)
		elseif cc then sideLine(tt, L.craftL, money(cc), WHITE)
		end
	end

	-- Details with Shift
	if not (IsShiftKeyDown() or ProfitmancerDB.detail) then return end
	if p then
		if p.min and p.min ~= p.emv then detail(tt, L.low, money(p.min)) end
		if p.qty then detail(tt, L.listed, tostring(p.qty)) end
		if p.sold then detail(tt, L.sold, "~" .. p.sold) end
	end
	if isProduct then
		if rec then
			local prof = L.profs[rec[2]] or S.profs[rec[2]] or rec[2]
			tt:AddLine("  " .. prof .. " " .. rec[3], GREY[1], GREY[2], GREY[3])
		end
	end
	if vb then
		local n = S.npc[faction()][id]
		local more = p and p.emv and vb < p.emv and (" (" .. L.cheaper .. ")") or ""
		detail(tt, L.vendor, money(vb) .. more, GREEN)
		if n then tt:AddLine("  " .. L.buyAt .. " " .. n[1] .. " · " .. n[2] .. " " .. n[3] .. ", " .. n[4], BLUE[1], BLUE[2], BLUE[3]) end
	end
	if isReagent then
		local list, bestName, bestPr = usedIn[id], nil, nil
		for _, r in ipairs(list) do
			local c = craftCost(r[1]); local q = price(r[1])
			if c and q and q.emv then
				local pr = q.emv - c
				if not bestPr or pr > bestPr then bestPr, bestName = pr, r[1] end
			end
		end
		detail(tt, L.usedIn, #list .. " " .. L.recipes)
		if bestName then
			local name = GetItemInfo(bestName) or ("#" .. bestName)
			tt:AddLine("  " .. L.best .. ": " .. name .. " (" .. money(bestPr, true) .. ")", GREY[1], GREY[2], GREY[3])
		end
	end
	if p then tt:AddLine("  " .. L.source .. ": " .. ageText(p), GREY[1], GREY[2], GREY[3]) end
end

local reported, calls, lastId = false, 0, nil
local function safeAddInfo(tt, id)
	calls = calls + 1; lastId = id
	local ok, err = pcall(addInfo, tt, id)
	if not ok and (not reported or GetTime() - reported > 30) then
		reported = GetTime()
		print("|cffb48cffProfitmancer|r error (please report): " .. tostring(err))
	end
end

local function itemIdOf(tt, data)
	if data and data.id and data.type == (Enum.TooltipDataType and Enum.TooltipDataType.Item) then return data.id end
	local _, link = tt:GetItem()
	return link and tonumber(link:match("item:(%d+)"))
end

if TooltipDataProcessor and Enum.TooltipDataType then
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
		if tt == GameTooltip or tt == ItemRefTooltip or (tt.GetName and tt:GetName() and tt:GetName():find("^ShoppingTooltip")) then
			safeAddInfo(tt, itemIdOf(tt, data))
		end
	end)
else
	for _, tt in ipairs({ GameTooltip, ItemRefTooltip }) do
		tt:HookScript("OnTooltipSetItem", function(self) safeAddInfo(self, itemIdOf(self)) end)
	end
end

-- Shift pressed or released: redraw the tooltip so the details appear / disappear
local f = CreateFrame("Frame")
f:RegisterEvent("MODIFIER_STATE_CHANGED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, ev, key)
	if ev == "PLAYER_LOGIN" then
		if not ProfitmancerData and not (Auctionator and Auctionator.API) then print("|cffb48cffProfitmancer|r: " .. L.noData) end
		local D = pickMarket()
		if D and D.other then print("|cffb48cffProfitmancer|r: |cffff5a4a" .. D.otherMsg .. "|r") end
		return
	end
	if (key == "LSHIFT" or key == "RSHIFT") and GameTooltip:IsShown() and GameTooltip:GetItem() then
		if GameTooltip.RefreshData then pcall(GameTooltip.RefreshData, GameTooltip)
		else
			local owner = GameTooltip:GetOwner()
			if owner and owner:GetScript("OnEnter") then owner:GetScript("OnEnter")(owner) end
		end
	end
end)

-- ——— Freshness: age of the loaded prices, one-click reload, reminder when newer prices are probably on disk ———
local function dataAge()
	local D = pickMarket()
	return D and D.t and (time() - D.t) or nil
end
local function ageShort(a)
	if not a then return "?" end
	if a < 3600 then return math.floor(a / 60) .. " " .. L.min end
	if a < 172800 then return math.floor(a / 3600 + 0.5) .. " " .. L.hours end
	return math.floor(a / 86400 + 0.5) .. " " .. L.days
end
local function loadedText(a) return FR and (L.loaded .. " " .. ageShort(a)) or (L.loaded .. " " .. ageShort(a) .. " ago") end
local function status()
	local D, n = ProfitmancerData, 0
	if D and D.p then for _ in pairs(D.p) do n = n + 1 end end
	print("|cffb48cffProfitmancer|r: " .. (D and (n .. " " .. L.pricesW .. " · " .. marketName() .. " · " .. loadedText(dataAge())) or L.noData)
		.. (ProfitmancerDB.off and " · OFF" or "") .. (ProfitmancerDB.detail and " · detail" or ""))
end
local function reloadPrices()
	if InCombatLockdown() then print("|cffb48cffProfitmancer|r: " .. L.combat) return end
	ProfitmancerDB.reloadFrom = ProfitmancerData and ProfitmancerData.t or 0 -- to tell, after the reload, whether newer prices came in
	ReloadUI()
end

local showSetup -- defined below (setup window)
-- Minimap button: left click = reload the prices, right click = status, drag = move
local mm
local function placeMM()
	local a = math.rad(ProfitmancerDB.mmAngle or 200)
	mm:ClearAllPoints()
	mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * 80, math.sin(a) * 80)
end
local function makeMM()
	if mm or not Minimap then return end
	mm = CreateFrame("Button", "ProfitmancerMinimapButton", Minimap)
	mm:SetSize(31, 31); mm:SetFrameStrata("MEDIUM"); mm:SetFrameLevel(8)
	mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	local bg = mm:CreateTexture(nil, "BACKGROUND"); bg:SetSize(20, 20); bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background"); bg:SetPoint("TOPLEFT", 7, -5)
	local ic = mm:CreateTexture(nil, "ARTWORK"); ic:SetSize(18, 18); ic:SetTexture("Interface\\Icons\\INV_Misc_Coin_02"); ic:SetPoint("TOPLEFT", 7, -6); mm.icon = ic
	local bd = mm:CreateTexture(nil, "OVERLAY"); bd:SetSize(53, 53); bd:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder"); bd:SetPoint("TOPLEFT")
	mm:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	mm:RegisterForDrag("LeftButton")
	mm:SetScript("OnClick", function(_, button)
		if IsShiftKeyDown() and ProfitmancerChar then ProfitmancerChar.export()
		elseif button == "RightButton" then
			if ProfitmancerOptions then ProfitmancerOptions.toggle() else status() end
		else reloadPrices() end
	end)
	mm:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			local px, py = GetCursorPosition()
			local sc = Minimap:GetEffectiveScale()
			ProfitmancerDB.mmAngle = math.deg(atan2(py / sc - my, px / sc - mx))
			placeMM()
		end)
	end)
	mm:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	mm:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("Profitmancer", 0.71, 0.55, 1)
		local D = ProfitmancerData
		if D then
			local a = dataAge()
			local old = a and a > 9000
			GameTooltip:AddDoubleLine(marketName(), loadedText(a), 1, 1, 1, old and 1 or 0.6, old and 0.35 or 1, old and 0.29 or 0.6)
			if D.other then GameTooltip:AddLine(D.otherMsg, 1, 0.35, 0.29, true) end
		else
			GameTooltip:AddLine(L.noData, 1, 0.35, 0.29, true)
		end
		if ProfitmancerGains then pcall(ProfitmancerGains.tooltip, GameTooltip) end
		if ProfitmancerSales and ProfitmancerSales.tooltip then pcall(ProfitmancerSales.tooltip, GameTooltip) end
		if ProfitmancerCooldowns then pcall(ProfitmancerCooldowns.tooltip, GameTooltip) end
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("|cffffd100" .. L.mmLeft .. "|r  |cff9e9e9e· " .. L.mmRight .. "|r")
		GameTooltip:Show()
	end)
	mm:SetScript("OnLeave", function() GameTooltip:Hide() end)
	placeMM()
	if ProfitmancerDB.mmHide then mm:Hide() end
end

-- Reminder: Blizzard publishes the auction data once an hour and the cloud scan + updater add up to ~1 h, so normal prices are 1-2 h old.
-- Only remind when the loaded prices are over 2.5 h old AND the game has been running long enough for the updater to bring newer ones.
local lastNag, bootT = 0, nil
local function nag()
	local a = dataAge()
	if not a or a < (ProfitmancerDB.nagAfter or 9000) or ProfitmancerDB.noNag or GetTime() - lastNag < 3600 then return end
	if bootT and GetTime() - bootT < 1200 and ProfitmancerDB.sameAfterReload then return end
	lastNag = GetTime()
	print("|cffb48cffProfitmancer|r: " .. L.stale:format(ageShort(a)))
end
-- ——— First run without cloud prices: show where to get the free price updater (an addon can't download anything itself) ———
local SETUP_URL = "https://doublevb.github.io/grimoire-ah/#updater"
local setupWin
function showSetup()
	if not setupWin then
		local w = CreateFrame("Frame", "ProfitmancerSetup", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
		w:SetSize(480, 200); w:SetPoint("CENTER", 0, 120); w:SetFrameStrata("DIALOG")
		w:EnableMouse(true); w:SetMovable(true); w:RegisterForDrag("LeftButton")
		w:SetScript("OnDragStart", w.StartMoving); w:SetScript("OnDragStop", w.StopMovingOrSizing)
		if w.SetBackdrop then
			w:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } })
		end
		local t = w:CreateFontString(nil, "OVERLAY", "GameFontNormal"); t:SetPoint("TOP", 0, -18); t:SetText(L.setupT)
		local d = w:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); d:SetPoint("TOPLEFT", 24, -40); d:SetPoint("TOPRIGHT", -24, -40); d:SetJustifyH("LEFT"); d:SetText(L.setupTxt)
		local e = CreateFrame("EditBox", nil, w, "InputBoxTemplate")
		e:SetSize(400, 24); e:SetPoint("TOP", 0, -100); e:SetAutoFocus(false); e:SetText(SETUP_URL)
		e:SetScript("OnTextChanged", function(self, user) if user then self:SetText(SETUP_URL); self:HighlightText() end end)
		e:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
		e:SetScript("OnMouseUp", function(self) self:SetFocus(); self:HighlightText() end)
		e:SetScript("OnEscapePressed", function() w:Hide() end)
		local a = w:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); a:SetPoint("TOP", 0, -128); a:SetText(L.setupAtr)
		local b1 = CreateFrame("Button", nil, w, "UIPanelButtonTemplate"); b1:SetSize(130, 22); b1:SetPoint("BOTTOMRIGHT", w, "BOTTOM", -6, 16); b1:SetText(L.later)
		b1:SetScript("OnClick", function() w:Hide() end)
		local b2 = CreateFrame("Button", nil, w, "UIPanelButtonTemplate"); b2:SetSize(150, 22); b2:SetPoint("BOTTOMLEFT", w, "BOTTOM", 6, 16); b2:SetText(L.never)
		b2:SetScript("OnClick", function() ProfitmancerDB.noSetup = true; w:Hide() end)
		tinsert(UISpecialFrames, "ProfitmancerSetup")
		setupWin = w
		setupWin.edit = e
	end
	ProfitmancerDB.setupT = time()
	setupWin:Show(); setupWin.edit:SetFocus(); setupWin.edit:HighlightText()
end
local function maybeSetup()
	if ProfitmancerData or ProfitmancerDB.noSetup then return end
	if ProfitmancerDB.setupT and time() - ProfitmancerDB.setupT < 3 * 86400 then return end -- at most every 3 days
	showSetup()
end
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function()
	ProfitmancerDB = ProfitmancerDB or {}
	makeMM()
	bootT = GetTime()
	-- After a click on "load the latest prices": say so when nothing newer had arrived yet
	ProfitmancerDB.sameAfterReload = nil
	if ProfitmancerDB.reloadFrom then
		local before, D = ProfitmancerDB.reloadFrom, ProfitmancerData
		ProfitmancerDB.reloadFrom = nil
		if D and D.t and before > 0 and D.t <= before then
			ProfitmancerDB.sameAfterReload = true
			if not ProfitmancerDB.quiet then C_Timer.After(3, function() print("|cffb48cffProfitmancer|r: " .. L.same:format(ageShort(dataAge()))) end) end
		end
	end
	C_Timer.After(15, nag)
	C_Timer.After(6, maybeSetup)
	C_Timer.NewTicker(600, nag)
end)

-- Small API for the other Profitmancer files (recipe list in the profession window)
ProfitmancerAPI = {
	-- profit of one item made (AH market price minus the cheapest crafting cost), and the cost
	profit = function(id)
		local cc = craftCost(id)
		local p = price(id)
		if cc and p and p.emv then return p.emv - cc, cc end
		return nil, cc
	end,
	money = money,
	vendor = function(id) return vendorBuy(id) end,
	-- for the options window
	dataAge = function() return dataAge() end, ageShort = ageShort, reload = function() reloadPrices() end, setup = function() showSetup() end,
	minimap = function(show) ProfitmancerDB.mmHide = not show; if mm then mm:SetShown(show) end end,
	status = function() status() end,
	market = function() return marketName() end,
	otherMarket = function() local D = pickMarket(); return D and D.other and (RSN[D.rs] or D.rs) or nil end,
	ah = function(id) local p = price(id); return p and p.emv end,
	-- every item a known recipe makes (for finding recipe rows by name)
	products = function() local t = {} for id in pairs(byProduct) do t[#t + 1] = id end return t end,
}

SLASH_PROFITMANCER1 = "/profitmancer"
SLASH_PROFITMANCER2 = "/pfm"
SlashCmdList.PROFITMANCER = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	local tid = msg:match("^test%s*(%d*)$")
	if tid then
		-- Diagnostic: build the tooltip lines for an item on a fake tooltip and print them (or the error) in the chat
		local id = tonumber(tid) or 9179
		local out = {}
		local fake = { AddDoubleLine = function(_, l, r) out[#out + 1] = tostring(l) .. " | " .. tostring(r) end, AddLine = function(_, l) out[#out + 1] = tostring(l) end }
		local ok, err = pcall(addInfo, fake, id)
		print("|cffb48cffProfitmancer|r test #" .. id .. ": " .. (ok and (#out .. " line(s)") or ("ERROR " .. tostring(err))))
		for _, l in ipairs(out) do print("  " .. l) end
		print("  hook: " .. (TooltipDataProcessor and "TooltipDataProcessor" or "OnTooltipSetItem") .. " · calls " .. calls .. " · last id " .. tostring(lastId))
		return
	end
	if msg == "reload" or msg == "r" then return reloadPrices()
	elseif msg == "export" or msg == "char" or msg == "chars" then if ProfitmancerChar then ProfitmancerChar.export() end return
	elseif msg == "setup" or msg == "updater" then return showSetup()
	elseif msg == "options" or msg == "option" or msg == "config" or msg == "opt" then if ProfitmancerOptions then ProfitmancerOptions.toggle() end return
	elseif msg == "debug" then if ProfitmancerRecipeProfitDebug then ProfitmancerRecipeProfitDebug() end return
	elseif msg == "guide" or msg == "tuto" or msg == "tutorial" or msg == "aide" then if ProfitmancerGuide_Open then ProfitmancerGuide_Open(1) end return
	elseif msg == "sales" or msg == "ventes" or msg == "historique" or msg == "history" then if ProfitmancerSales then ProfitmancerSales.toggle() end return
	elseif msg == "shopping" or msg == "courses" or msg == "shop" then if ProfitmancerShopping then ProfitmancerShopping.toggle() end return
	elseif msg:match("^cd") or msg:match("^cooldown") then if ProfitmancerCooldowns then ProfitmancerCooldowns.cmd(msg:match("^%S+%s+(.+)$")) end return
	elseif msg:match("^gains") or msg:match("^session") or msg:match("^hdv") or msg:match("^ah%s") or msg == "ah" then
		if ProfitmancerGains then ProfitmancerGains.cmd(msg:match("^%S+%s+(.+)$")) end return
	elseif msg == "off" then ProfitmancerDB.off = true
	elseif msg == "on" then ProfitmancerDB.off = nil
	elseif msg == "detail" then ProfitmancerDB.detail = not ProfitmancerDB.detail
	elseif msg == "minimap" then ProfitmancerDB.mmHide = not ProfitmancerDB.mmHide; if mm then mm:SetShown(not ProfitmancerDB.mmHide) end
	elseif msg == "nag" then ProfitmancerDB.noNag = not ProfitmancerDB.noNag
	end
	status()
	print(L.help)
end
