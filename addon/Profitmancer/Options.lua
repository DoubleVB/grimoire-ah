-- Profitmancer: options window (right-click the minimap button, or /pfm options).
-- Every setting is saved in ProfitmancerDB; "off" flags default to nil so a new install has everything on.
local FR = GetLocale() == "frFR"
local T = FR and {
	title = "Profitmancer · Options",
	secTip = "Infobulles des objets", tipOn = "Prix Profitmancer dans les infobulles", tipVendor = "Ligne PNJ (prix d'achat / de rachat)", tipAH = "Ligne HV (prix du marché, ventes par jour)", tipCraft = "Ligne Craft (coût et profit)", tipDetail = "Toujours le détail (sinon : maintenir Maj)",
	secProf = "Fenêtre de métier", rp = "Profit à côté de chaque recette", chance = "% de chance de monter le métier", cdRow = "État des cooldowns dans la liste", export = "Bouton Export (liste Auctionator)", charBtn = "Bouton « Export recipes » (pour le site)",
	secPrice = "Prix", reload = "Recharger les prix", nag = "Me rappeler quand les prix sont anciens", after = "Après : %s", never = "jamais", quiet = "Messages d'information dans le chat", setupWin = "Proposer l'installation des prix automatiques",
	priceNote = "Blizzard publie les prix une fois par heure ; le programme de mise à jour (Windows) les télécharge en moins de 15 min. Le jeu les lit au chargement : clic gauche sur le bouton de la minicarte (ou /reload) pour prendre les plus récents.",
	noPrices = "Pas encore de prix cloud", from = "%s · prix d'il y a %s",
	secCd = "Cooldowns de craft", toast = "Notification quand un cooldown est prêt", sound = "Son de la notification", dur = "Affichage : %d s", test = "Tester", move = "Déplacer", resetPos = "Position par défaut", badge = "Compteur sur le bouton minimap",
	secSale = "Ventes à l'HV", saleChat = { chat = "Texte : chat général", tab = "Texte : onglet Profitmancer", off = "Texte : pas dans le chat" }, saleToast = "Notification à l'écran à chaque vente",
	secMm = "Bouton de la minicarte", mm = "Afficher le bouton (sinon : /pfm minimap)",
	secLinks = "Liens", lSite = "Site Profitmancer", lUpdater = "Installer les prix auto", lCF = "Page CurseForge", lGit = "GitHub (code et données)", copy = "Copier", copyHint = "Ctrl+C pour copier, puis colle l'adresse dans ton navigateur",
	rpMin = "Profit affiché à partir de : %s", all = "tous",
	secAH = "Hôtel des ventes", salesTab = "Onglet Sales (historique des ventes)", shopTab = "Onglet Shop lists (listes de courses)", scale = "Taille des fenêtres : %d %%", keep = "Garder les ventes : %s", keepAll = "tout", days = "%d j",
	secChars = "Personnages (cooldowns)", noChars = "Aucun personnage avec des cooldowns pour l'instant.", del = "Suppr.", cds = "%d cooldown(s)", rsName = { PvP = "JcJ", PvE = "Normal", RP = "RP", RPPvP = "RP-JcJ", HC = "Hardcore" }, otherRs = "autre type de serveur", otherPrices = "Prix d'un autre type de serveur : relance l'installation du programme de mise à jour.", rsUnknown = "type de serveur inconnu (connecte-le une fois)",
	secData = "Données", guide = "Revoir le guide", session = "Nouvelle session HV", clearSales = "Effacer l'historique des ventes", forgetCd = "Oublier les cooldowns", sure = "Confirmer ?", done = "C'est fait.",
} or {
	title = "Profitmancer · Options",
	secTip = "Item tooltips", tipOn = "Profitmancer prices in tooltips", tipVendor = "Vendor line (buy / sell price)", tipAH = "AH line (market price, sales per day)", tipCraft = "Craft line (cost and profit)", tipDetail = "Always show details (else: hold Shift)",
	secProf = "Profession window", rp = "Profit next to each recipe", chance = "% chance of a skill point", cdRow = "Cooldown status in the list", export = "Export button (Auctionator list)", charBtn = "\"Export recipes\" button (for the website)",
	secPrice = "Prices", reload = "Load the latest prices", nag = "Remind me when prices are old", after = "After: %s", never = "never", quiet = "Information messages in the chat", setupWin = "Offer to install automatic prices",
	priceNote = "Blizzard publishes prices once an hour; the price updater (Windows) downloads them within 15 min. The game reads them when it loads: left-click the minimap button (or /reload) to take the latest.",
	noPrices = "No cloud prices yet", from = "%s · prices from %s ago",
	secCd = "Craft cooldowns", toast = "Notification when a cooldown is ready", sound = "Notification sound", dur = "Shown for: %d s", test = "Test", move = "Move", resetPos = "Default position", badge = "Counter on the minimap button",
	secSale = "Auction house sales", saleChat = { chat = "Text: general chat", tab = "Text: Profitmancer tab", off = "Text: not in chat" }, saleToast = "On-screen notification for each sale",
	secMm = "Minimap button", mm = "Show the button (else: /pfm minimap)",
	secLinks = "Links", lSite = "Profitmancer website", lUpdater = "Install automatic prices", lCF = "CurseForge page", lGit = "GitHub (code and data)", copy = "Copy", copyHint = "Ctrl+C to copy, then paste the address in your web browser",
	rpMin = "Show profit from: %s", all = "all",
	secAH = "Auction house", salesTab = "Sales tab (sales history)", shopTab = "Shop lists tab (shopping lists)", scale = "Window size: %d %%", keep = "Keep sales: %s", keepAll = "all", days = "%d d",
	secChars = "Characters (cooldowns)", noChars = "No character with cooldowns yet.", del = "Delete", cds = "%d cooldown(s)", rsName = { PvP = "PvP", PvE = "Normal", RP = "RP", RPPvP = "RP-PvP", HC = "Hardcore" }, otherRs = "other server type", otherPrices = "Prices from another server type: run the price updater install again.", rsUnknown = "server type unknown (log it in once)",
	secData = "Data", guide = "Open the guide again", session = "New AH session", clearSales = "Clear the sales history", forgetCd = "Forget the cooldowns", sure = "Sure?", done = "Done.",
}
local LINKS = {
	{ T.lSite, "https://doublevb.github.io/grimoire-ah/" },
	{ T.lUpdater, "https://doublevb.github.io/grimoire-ah/#updater" },
	{ T.lCF, "https://www.curseforge.com/wow/addons/profitmancer" },
	{ T.lGit, "https://github.com/DoubleVB/grimoire-ah" },
}
local function say(m) print("|cffb48cffProfitmancer|r: " .. m) end
local DB = function() ProfitmancerDB = ProfitmancerDB or {}; return ProfitmancerDB end

-- After a change that affects the profession window: redraw its rows
local function touchProf()
	DB().optStamp = (DB().optStamp or 0) + 1
	if ProfitmancerChar and ProfitmancerChar.refreshButtons then ProfitmancerChar.refreshButtons() end
end

local win, refreshers = nil, {}
local function refreshAll() for _, f in ipairs(refreshers) do pcall(f) end end

local function build()
	if win then return end
	local w = CreateFrame("Frame", "ProfitmancerOptionsFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	w:SetSize(1010, 664); w:SetPoint("CENTER"); w:SetFrameStrata("DIALOG"); w:SetClampedToScreen(true)
	w:EnableMouse(true); w:SetMovable(true); w:RegisterForDrag("LeftButton")
	w:SetScript("OnDragStart", w.StartMoving); w:SetScript("OnDragStop", w.StopMovingOrSizing)
	if w.SetBackdrop then
		w:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } })
	end
	local title = w:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); title:SetPoint("TOP", 0, -18)
	local ver = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("Profitmancer", "Version")) or (GetAddOnMetadata and GetAddOnMetadata("Profitmancer", "Version")) or ""
	title:SetText("|cffb48cff" .. T.title .. "|r  |cff9e9e9e" .. ver .. "|r")
	local close = CreateFrame("Button", nil, w, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -6, -6)
	tinsert(UISpecialFrames, "ProfitmancerOptionsFrame")

	-- two columns; each widget is placed under the previous one of its column
	local cols = { { x = 26, y = -50 }, { x = 356, y = -50 }, { x = 686, y = -50 } }
	local function nextPos(c, h) local p = cols[c]; local y = p.y; p.y = p.y - h; return p.x, y end
	local function section(c, text)
		cols[c].y = cols[c].y - 6
		local x, y = nextPos(c, 22)
		local fs = w:CreateFontString(nil, "OVERLAY", "GameFontNormal"); fs:SetPoint("TOPLEFT", x, y); fs:SetText(text)
		local line = w:CreateTexture(nil, "ARTWORK"); line:SetHeight(1); line:SetPoint("TOPLEFT", x, y - 16); line:SetWidth(300); line:SetColorTexture(0.71, 0.55, 1, 0.35)
	end
	-- a check box: get() says if it is ticked, set(v) saves it
	local function check(c, text, get, set)
		local x, y = nextPos(c, 24)
		local b = CreateFrame("CheckButton", nil, w, "UICheckButtonTemplate")
		b:SetSize(24, 24); b:SetPoint("TOPLEFT", x - 4, y + 2)
		local fs = w:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); fs:SetPoint("LEFT", b, "RIGHT", 2, 1); fs:SetWidth(272); fs:SetJustifyH("LEFT"); fs:SetText(text)
		b:SetScript("OnClick", function(self) set(self:GetChecked() and true or false); refreshAll() end)
		table.insert(refreshers, function() b:SetChecked(get() and true or false) end)
		return b
	end
	local function button(parent, text, wdt, onClick)
		local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate"); b:SetSize(wdt, 22); b:SetText(text)
		b:SetScript("OnClick", onClick); return b
	end
	-- a button that asks once more before doing something that can't be undone
	local function confirmButton(text, wdt, action)
		local b
		b = button(w, text, wdt, function()
			if b.armed then b.armed = nil; b:SetText(text); action(); say(T.done)
			else b.armed = true; b:SetText(T.sure); C_Timer.After(4, function() if b.armed then b.armed = nil; b:SetText(text) end end) end
		end)
		return b
	end

	-- a button that cycles through values: label(v) gives its text
	local function cycle(c, values, get, set, label, indent)
		local x, y = nextPos(c, 28)
		local b = button(w, "", 230, nil)
		b:SetPoint("TOPLEFT", x + (indent or 0), y)
		b:SetScript("OnClick", function()
			local cur, nxt = get(), values[1]
			for i, v in ipairs(values) do if v == cur then nxt = values[i % #values + 1] end end
			set(nxt); refreshAll()
		end)
		table.insert(refreshers, function() b:SetText(label(get())) end)
		return b
	end
	local function coins(c)
		if c == false then return T.all end
		if c >= 10000 then return (c / 10000) .. (FR and " po" or "g") end
		if c >= 100 then return (c / 100) .. (FR and " pa" or "s") end
		return c .. (FR and " pc" or "c")
	end

	-- ——— Left column ———
	section(1, T.secTip)
	check(1, T.tipOn, function() return not DB().off end, function(v) DB().off = not v or nil end)
	check(1, T.tipVendor, function() return not DB().noVendor end, function(v) DB().noVendor = not v or nil end)
	check(1, T.tipAH, function() return not DB().noAH end, function(v) DB().noAH = not v or nil end)
	check(1, T.tipCraft, function() return not DB().noCraft end, function(v) DB().noCraft = not v or nil end)
	check(1, T.tipDetail, function() return DB().detail end, function(v) DB().detail = v or nil end)

	section(1, T.secProf)
	check(1, T.rp, function() return not DB().rpOff end, function(v) DB().rpOff = not v or nil; touchProf() end)
	check(1, T.chance, function() return not DB().chanceOff end, function(v) DB().chanceOff = not v or nil; touchProf() end)
	check(1, T.cdRow, function() return not DB().cdRowOff end, function(v) DB().cdRowOff = not v or nil; touchProf() end)
	check(1, T.export, function() return not DB().exportOff end, function(v) DB().exportOff = not v or nil; touchProf() end)
	check(1, T.charBtn, function() return not DB().charBtnOff end, function(v) DB().charBtnOff = not v or nil; touchProf() end)
	cycle(1, { false, 0, 1000, 10000, 50000 }, function() return DB().rpMin or false end, function(v) DB().rpMin = v or nil; touchProf() end,
		function(v) return T.rpMin:format(coins(v)) end)

	section(1, T.secPrice)
	do
		local x, y = nextPos(1, 20)
		local st = w:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); st:SetPoint("TOPLEFT", x, y); st:SetWidth(310); st:SetJustifyH("LEFT")
		table.insert(refreshers, function()
			local A, D = ProfitmancerAPI, ProfitmancerData
			local a = A and A.dataAge and A.dataAge()
			if D and a then
				local old = a > (DB().nagAfter or 9000)
				st:SetText(T.from:format((A.market and A.market()) or D.ah or "?", (old and "|cffff5a4a" or "|cff3ec46d") .. A.ageShort(a) .. "|r") .. ((A.otherMarket and A.otherMarket()) and ("\n|cffff5a4a" .. T.otherPrices .. "|r") or ""))
			else st:SetText("|cffff5a4a" .. T.noPrices .. "|r") end
		end)
		local x2, y2 = nextPos(1, 28)
		local rb = button(w, T.reload, 170, function() if ProfitmancerAPI and ProfitmancerAPI.reload then ProfitmancerAPI.reload() end end)
		rb:SetPoint("TOPLEFT", x2, y2)
	end
	check(1, T.nag, function() return not DB().noNag end, function(v) DB().noNag = not v or nil end)
	do
		local x, y = nextPos(1, 28)
		local CH = { 3600, 9000, 21600 }
		local b = button(w, "", 150, nil)
		b:SetPoint("TOPLEFT", x + 22, y)
		b:SetScript("OnClick", function()
			local cur, nxt = DB().nagAfter or 9000, CH[1]
			for i, v in ipairs(CH) do if v == cur then nxt = CH[i % #CH + 1] end end
			DB().nagAfter = nxt; refreshAll()
		end)
		table.insert(refreshers, function()
			local v = DB().nagAfter or 9000
			b:SetText(T.after:format(v >= 3600 and (math.floor(v / 360) / 10 .. " h"):gsub("%.", FR and "," or ".") or v))
			b:SetEnabled(not DB().noNag)
		end)
	end
	check(1, T.quiet, function() return not DB().quiet end, function(v) DB().quiet = not v or nil end)
	check(1, T.setupWin, function() return not DB().noSetup end, function(v) DB().noSetup = not v or nil end)
	do
		local x, y = nextPos(1, 56)
		local n = w:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); n:SetPoint("TOPLEFT", x, y - 2); n:SetWidth(310); n:SetJustifyH("LEFT"); n:SetText(T.priceNote)
	end

	-- ——— Right column ———
	section(2, T.secCd)
	check(2, T.toast, function() return DB().cdToast ~= false end, function(v) if v then DB().cdToast = nil else DB().cdToast = false end end)
	check(2, T.sound, function() return not DB().cdSoundOff end, function(v) DB().cdSoundOff = not v or nil end)
	do
		local x, y = nextPos(2, 28)
		local D = { 4, 6, 8, 10, 15 }
		local b = button(w, "", 110, function()
			local cur, nxt = DB().cdToastDur or 6, D[1]
			for i, v in ipairs(D) do if v == cur then nxt = D[i % #D + 1] end end
			DB().cdToastDur = nxt; refreshAll()
		end)
		b:SetPoint("TOPLEFT", x, y)
		table.insert(refreshers, function() b:SetText(T.dur:format(DB().cdToastDur or 6)) end)
		local t = button(w, T.test, 90, function() if ProfitmancerCooldowns then ProfitmancerCooldowns.test() end end)
		t:SetPoint("LEFT", b, "RIGHT", 6, 0)
		local x2, y2 = nextPos(2, 28)
		local m = button(w, T.move, 110, function() if ProfitmancerCooldowns then ProfitmancerCooldowns.unlock() end end)
		m:SetPoint("TOPLEFT", x2, y2)
		local r = button(w, T.resetPos, 150, function() if ProfitmancerCooldowns then ProfitmancerCooldowns.resetPos(); ProfitmancerCooldowns.test() end end)
		r:SetPoint("LEFT", m, "RIGHT", 6, 0)
	end
	check(2, T.badge, function() return not DB().cdBadgeOff end, function(v) DB().cdBadgeOff = not v or nil; if ProfitmancerCooldowns then ProfitmancerCooldowns.badge() end end)

	section(2, T.secSale)
	cycle(2, { "chat", "tab", "off" }, function() return DB().saleChat or (DB().saleTab and "tab") or "chat" end,
		function(v) DB().saleChat = v; DB().saleTab = nil; if ProfitmancerSaleTab then ProfitmancerSaleTab(v == "tab") end end,
		function(v) return T.saleChat[v] end)
	check(2, T.saleToast, function() return not DB().saleToastOff end, function(v) DB().saleToastOff = not v or nil end)
	check(2, T.sound, function() return not DB().saleSoundOff end, function(v) DB().saleSoundOff = not v or nil end)
	do
		local x, y = nextPos(2, 28)
		local t = button(w, T.test, 90, function() if ProfitmancerSaleTest then ProfitmancerSaleTest() end end)
		t:SetPoint("TOPLEFT", x, y)
		local x2, y2 = nextPos(2, 28)
		local m = button(w, T.move, 110, function() if ProfitmancerSaleMove then ProfitmancerSaleMove() end end)
		m:SetPoint("TOPLEFT", x2, y2)
		local r = button(w, T.resetPos, 150, function() if ProfitmancerSaleResetPos then ProfitmancerSaleResetPos() end end)
		r:SetPoint("LEFT", m, "RIGHT", 6, 0)
	end

	section(2, T.secMm)
	check(2, T.mm, function() return not DB().mmHide end, function(v) if ProfitmancerAPI and ProfitmancerAPI.minimap then ProfitmancerAPI.minimap(v) else DB().mmHide = not v end end)

	section(2, T.secLinks)
	local edit
	for _, l in ipairs(LINKS) do
		local x, y = nextPos(2, 26)
		local fs = w:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); fs:SetPoint("TOPLEFT", x, y - 5); fs:SetText(l[1])
		local b = button(w, T.copy, 80, function() edit:SetText(l[2]); edit.url = l[2]; edit:Show(); edit:SetFocus(); edit:HighlightText() end)
		b:SetPoint("TOPLEFT", x + 228, y)
	end
	do
		local x, y = nextPos(2, 44)
		edit = CreateFrame("EditBox", nil, w, "InputBoxTemplate")
		edit:SetSize(300, 22); edit:SetPoint("TOPLEFT", x + 6, y); edit:SetAutoFocus(false); edit:Hide()
		edit:SetScript("OnTextChanged", function(self, user) if user and self.url then self:SetText(self.url); self:HighlightText() end end)
		edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
		edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
		local h = w:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); h:SetPoint("TOPLEFT", edit, "BOTTOMLEFT", -4, -2); h:SetText(T.copyHint)
		edit:HookScript("OnShow", function() h:Show() end); edit:HookScript("OnHide", function() h:Hide() end); h:Hide()
	end

	-- ——— Third column ———
	local function replaceAH() if ProfitmancerAH and ProfitmancerAH.place then pcall(ProfitmancerAH.place) end end
	section(3, T.secAH)
	check(3, T.salesTab, function() return not DB().salesTabOff end, function(v) DB().salesTabOff = not v or nil; if not v and ProfitmancerSales then ProfitmancerSales.hide() end; replaceAH() end)
	check(3, T.shopTab, function() return not DB().shopTabOff end, function(v) DB().shopTabOff = not v or nil; if not v and ProfitmancerShopping and ProfitmancerShopping.hide then ProfitmancerShopping.hide() end; replaceAH() end)
	cycle(3, { 0.8, 0.9, 1, 1.1, 1.2 }, function() return DB().panelScale or 1 end, function(v) DB().panelScale = (v ~= 1) and v or nil end,
		function(v) return T.scale:format(math.floor(v * 100 + 0.5)) end)
	cycle(3, { false, 30, 90, 365 }, function() return DB().salesKeep or false end, function(v) DB().salesKeep = v or nil; if v and ProfitmancerGains and ProfitmancerGains.prune then ProfitmancerGains.prune() end end,
		function(v) return T.keep:format(v and T.days:format(v) or T.keepAll) end)

	section(3, T.secChars)
	do
		local list = {}
		local empty = w:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		for i = 1, 6 do
			local x, y = nextPos(3, 24)
			if i == 1 then empty:SetPoint("TOPLEFT", x, y - 4); empty:SetText(T.noChars) end
			local cb = CreateFrame("CheckButton", nil, w, "UICheckButtonTemplate"); cb:SetSize(24, 24); cb:SetPoint("TOPLEFT", x - 4, y + 2)
			local fs = w:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); fs:SetPoint("LEFT", cb, "RIGHT", 2, 1); fs:SetWidth(180); fs:SetJustifyH("LEFT")
			local del
			del = button(w, T.del, 70, function()
				if not del.key then return end
				if del.armed then del.armed = nil; ProfitmancerCooldowns.deleteChar(del.key); refreshAll()
				else del.armed = true; del:SetText(T.sure); C_Timer.After(4, function() if del.armed then del.armed = nil; del:SetText(T.del) end end) end
			end)
			del:SetPoint("TOPLEFT", x + 222, y)
			cb:SetScript("OnClick", function(self) if del.key then ProfitmancerCooldowns.hideChar(del.key, not self:GetChecked()) end end)
			list[i] = { cb = cb, fs = fs, del = del }
		end
		table.insert(refreshers, function()
			local cs = ProfitmancerCooldowns and ProfitmancerCooldowns.chars() or {}
			empty:SetShown(#cs == 0)
			for i, r in ipairs(list) do
				local c = cs[i]
				r.cb:SetShown(c ~= nil); r.fs:SetShown(c ~= nil); r.del:SetShown(c ~= nil)
				if c then
					r.cb:SetChecked(not c.hidden); r.del.key = c.key; r.del.armed = nil; r.del:SetText(T.del)
					local tag = c.rs and (T.rsName[c.rs] or c.rs) or nil
					local note = c.other and (" |cffd08a3a(" .. (tag and (tag .. ", " .. T.otherRs) or T.rsUnknown) .. ")|r") or (tag and (" |cff7f7f7f[" .. tag .. "]|r") or "")
					r.fs:SetText(c.name .. note .. "  |cff9e9e9e" .. T.cds:format(c.count) .. "|r")
				else r.del.key = nil end
			end
		end)
	end

	section(3, T.secData)
	do
		local x, y = nextPos(3, 28)
		local g = button(w, T.guide, 150, function() w:Hide(); if ProfitmancerGuide_Open then ProfitmancerGuide_Open(1) end end)
		g:SetPoint("TOPLEFT", x, y)
		local s = confirmButton(T.session, 150, function() if ProfitmancerGains then ProfitmancerGains.cmd("reset") end end)
		s:SetPoint("LEFT", g, "RIGHT", 6, 0)
		local x2, y2 = nextPos(3, 28)
		local c = confirmButton(T.clearSales, 150, function()
			for _, G in pairs(DB().gains or {}) do if type(G) == "table" and G.log then wipe(G.log) end end
			if ProfitmancerSales then ProfitmancerSales.refresh() end
		end)
		c:SetPoint("TOPLEFT", x2, y2)
		local f = confirmButton(T.forgetCd, 150, function() if ProfitmancerCooldowns then ProfitmancerCooldowns.forget() end end)
		f:SetPoint("LEFT", c, "RIGHT", 6, 0)
	end

	w:SetScript("OnShow", refreshAll)
	w:Hide()
	win = w
end

ProfitmancerOptions = {
	toggle = function()
		build()
		if win:IsShown() then win:Hide() else win:Show() end
	end,
}
