-- Profitmancer: your auction house sales, laid out like the auction house's own Auctions tab and docked in its window.
-- Left: views (history, by item, sold awaiting mail, currently listed) and a summary. Right: a table with sortable columns.
-- A plain button under the auction house opens it (Blizzard's own tabs are left alone, so buying never gets blocked).
-- /pfm sales opens it anywhere (the "awaiting mail" and "listed" views need the auction house open).
local FR = GetLocale() == "frFR"
local T = FR and {
	btn = "Ventes", btnTip = "Tes ventes à l'hôtel des ventes : historique, totaux par objet, ventes en attente de courrier et objets en vente.",
	title = "Profitmancer · ventes", search = "Rechercher",
	p1 = "24 h", p7 = "7 j", p30 = "30 j", pAll = "Tout",
	vHist = "Historique", vItem = "Par objet", vPend = "Vendu · en attente", vLive = "En vente",
	cItem = "Objet", cQty = "Qté", cUnit = "Prix unitaire", cTotal = "Total", cWhen = "Date", cSales = "Ventes", cAvg = "Prix moyen", cLast = "Dernière",
	cIncoming = "À recevoir", cMail = "Courrier", cBuyout = "Prix unitaire", cMarket = "Marché", cLeft = "Temps",
	sTotal = "Total vendu", sCount = "%d vente(s) · moyenne %s", sBest = "Meilleur : %s", sPend = "En attente : %s (%d)", sLive = "En vente : %s (%d)",
	emptyHist = "Aucune vente sur cette période. Les ventes sont enregistrées quand tu récupères l'or des courriers « Vente réussie ».",
	emptyPend = "Aucune vente en attente de courrier.", emptyLive = "Aucun objet en vente.", needAH = "Ouvre l'hôtel des ventes pour voir cette liste.",
	each = "l'unité", rows = "%d–%d sur %d", unknown = "quantité inconnue", under = "plus cher que le marché : risque de ne pas se vendre", ok = "au prix du marché ou moins",
	mailIn = "arrive dans", sold = "Vendu",
} or {
	btn = "Sales", btnTip = "Your auction house sales: history, totals per item, sales awaiting mail and items currently listed.",
	title = "Profitmancer · sales", search = "Search",
	p1 = "24 h", p7 = "7 d", p30 = "30 d", pAll = "All",
	vHist = "History", vItem = "By item", vPend = "Sold · awaiting mail", vLive = "Listed",
	cItem = "Item", cQty = "Qty", cUnit = "Unit price", cTotal = "Total", cWhen = "Date", cSales = "Sales", cAvg = "Avg price", cLast = "Last",
	cIncoming = "Incoming", cMail = "Mail", cBuyout = "Unit price", cMarket = "Market", cLeft = "Time",
	sTotal = "Total sold", sCount = "%d sale(s) · average %s", sBest = "Best: %s", sPend = "Awaiting mail: %s (%d)", sLive = "Listed: %s (%d)",
	emptyHist = "No sale in this period. Sales are recorded when you take the gold from \"Auction successful\" mails.",
	emptyPend = "No sale awaiting mail.", emptyLive = "Nothing listed.", needAH = "Open the auction house to see this list.",
	each = "each", rows = "%d–%d of %d", unknown = "quantity unknown", under = "above the market price: may not sell", ok = "at or below the market price",
	mailIn = "arrives in", sold = "Sold",
}
local G, SI, CO = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:1:0|t", "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:1:0|t", "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:1:0|t"
local function money(c)
	if not c then return "|cff6f6f6f–|r" end
	c = math.floor(math.abs(c) + 0.5)
	local g, s, cp = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
	if g > 0 then return g .. G .. (s > 0 and (" " .. s .. SI) or "") end
	if s > 0 then return s .. SI .. (cp > 0 and (" " .. cp .. CO) or "") end
	return cp .. CO
end
local function ago(t)
	local d = time() - t
	if d < 3600 then return math.max(1, math.floor(d / 60)) .. " min" end
	if d < 86400 then return math.floor(d / 3600) .. " h" end
	return date(FR and "%d/%m" or "%m/%d", t)
end
local function left(sec)
	if not sec then return "" end
	if sec < 3600 then return math.max(1, math.floor(sec / 60)) .. "m" end
	if sec < 86400 then return math.floor(sec / 3600) .. "h" end
	return math.floor(sec / 86400) .. (FR and "j" or "d")
end
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo

local panel, rows, ROWS, ROW_H, MAXROWS = nil, {}, 15, 30, 20
local state = { view = "hist", period = 7, query = "", offset = 0, sort = {} }
local data = {}

local function host() return AuctionHouseFrame or AuctionFrame end
local ahBtn, styleBtn -- the Sales button (defined further down)

-- ——— Data ———
local function matches(name) local q = state.query:lower(); return q == "" or tostring(name or ""):lower():find(q, 1, true) end
local function history()
	local out, min = {}, state.period > 0 and (time() - state.period * 86400) or 0
	for _, s in ipairs(ProfitmancerGains and ProfitmancerGains.log() or {}) do
		if s[4] >= min and matches(s[1]) then
			local q = (s[3] or 0) > 0 and s[3] or nil
			out[#out + 1] = { name = s[1], id = s[5], qty = q, total = s[2], unit = q and s[2] / q or nil, t = s[4], src = s }
		end
	end
	return out
end
local function byItem()
	local by, out = {}, {}
	for _, s in ipairs(history()) do
		local b = by[s.name]
		if not b then b = { name = s.name, id = s.id, n = 0, qty = 0, qtyKnown = 0, total = 0, last = 0 }; by[s.name] = b; out[#out + 1] = b end
		b.n, b.total, b.last = b.n + 1, b.total + s.total, math.max(b.last, s.t)
		b.id = b.id or s.id
		if s.qty then b.qty, b.qtyKnown = b.qty + s.qty, b.qtyKnown + s.total end
	end
	for _, b in ipairs(out) do b.unit = b.qty > 0 and b.qtyKnown / b.qty or nil; if b.qty == 0 then b.qty = nil end end
	return out
end
-- Your auctions as the auction house's Auctions tab sees them (modern auction house only)
local owned, ownedAt = {}, 0
local function isCommodity(id)
	local A = C_AuctionHouse
	if not (id and A and A.GetItemCommodityStatus and Enum and Enum.ItemCommodityStatus) then return nil end
	local ok, st = pcall(A.GetItemCommodityStatus, id)
	return ok and st == Enum.ItemCommodityStatus.Commodity
end
local function readOwned()
	local A = C_AuctionHouse
	owned = {}
	if not (A and A.GetNumOwnedAuctions and A.GetOwnedAuctionInfo) then return end
	local ok, n = pcall(A.GetNumOwnedAuctions)
	for i = 1, (ok and n or 0) do
		local ok2, a = pcall(A.GetOwnedAuctionInfo, i)
		if ok2 and a then
			local id = a.itemKey and a.itemKey.itemID
			local name = (a.itemLink and a.itemLink:match("%[(.-)%]")) or (id and GetItemInfo(id)) or (id and ("item " .. id)) or "?"
			local q = a.quantity or 1
			local price = a.buyoutAmount or a.bidAmount
			-- commodities show a unit price, other items the price of the whole auction
			local unit, total
			if price then
				if isCommodity(id) or (isCommodity(id) == nil and q > 1) then unit, total = price, price * q else unit, total = price / q, price end
			end
			local sold = Enum and Enum.AuctionStatus and a.status == Enum.AuctionStatus.Sold or a.status == 1
			if id and ProfitmancerLearnItem then ProfitmancerLearnItem(name, id) end
			owned[#owned + 1] = { name = name, id = id, link = a.itemLink, qty = q, unit = unit, total = total, sold = sold, left = a.timeLeftSeconds, id2 = a.auctionID }
		end
	end
	ownedAt = GetTime()
	-- remember the listed total (per character) so the minimap tooltip can show it outside the auction house
	local n, q, v = 0, 0, 0
	for _, a in ipairs(owned) do if not a.sold then n, q, v = n + 1, q + (a.qty or 1), v + (a.total or 0) end end
	ProfitmancerDB.listed = ProfitmancerDB.listed or {}
	ProfitmancerDB.listed[(UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")] = { n = n, q = q, v = v }
end
local function queryOwned()
	local A = C_AuctionHouse
	if A and A.QueryOwnedAuctions and AuctionHouseFrame and AuctionHouseFrame:IsShown() then pcall(A.QueryOwnedAuctions, {}) end
	readOwned()
end
local function pending()
	local out = {}
	for _, a in ipairs(owned) do if a.sold and matches(a.name) then out[#out + 1] = a end end
	return out
end
local function live()
	local out, P = {}, ProfitmancerAPI
	for _, a in ipairs(owned) do
		if not a.sold and matches(a.name) then
			a.market = a.id and P and P.ah and P.ah(a.id) or nil
			a.diff = (a.market and a.unit and a.market > 0) and (a.unit - a.market) / a.market or nil
			out[#out + 1] = a
		end
	end
	return out
end

-- ——— Views: their columns (key, title, width, numeric) ———
local VIEWS = {
	hist = { label = T.vHist, get = history, sort = { "t", true }, empty = T.emptyHist, cols = {
		{ "qty", T.cQty, 44 }, { "unit", T.cUnit, 96 }, { "total", T.cTotal, 96 }, { "t", T.cWhen, 52 } } },
	item = { label = T.vItem, get = byItem, sort = { "total", true }, empty = T.emptyHist, cols = {
		{ "n", T.cSales, 50 }, { "qty", T.cQty, 44 }, { "unit", T.cAvg, 96 }, { "total", T.cTotal, 96 }, { "last", T.cLast, 52 } } },
	pend = { label = T.vPend, get = pending, sort = { "left", false }, empty = T.emptyPend, ah = true, cols = {
		{ "qty", T.cQty, 44 }, { "unit", T.cUnit, 96 }, { "total", T.cIncoming, 96 }, { "left", T.cMail, 52 } } },
	live = { label = T.vLive, get = live, sort = { "left", false }, empty = T.emptyLive, ah = true, cols = {
		{ "qty", T.cQty, 44 }, { "unit", T.cBuyout, 96 }, { "market", T.cMarket, 96 }, { "left", T.cLeft, 60 } } },
}
local ORDER = { "hist", "item", "pend", "live" }

local function cell(v, key, r)
	if key == "unit" or key == "total" or key == "market" then
		if key == "market" and v and r.diff then
			return (r.diff > 0.05 and "|cffff6a5a" or "|cff3ec46d") .. money(v) .. "|r"
		end
		return money(v)
	elseif key == "t" or key == "last" then return v and ago(v) or ""
	elseif key == "left" then return left(v)
	elseif key == "qty" then return v and ("x" .. v) or "|cff9e9e9ex?|r"
	end
	return v and tostring(v) or ""
end

-- ——— Display ———
local function summary()
	local h, total, best, bestV = history(), 0, nil, 0
	for _, s in ipairs(h) do total = total + s.total end
	for _, b in ipairs(byItem()) do if b.total > bestV then best, bestV = b.name, b.total end end
	local pTot, pN, lTot, lN = 0, 0, 0, 0
	for _, a in ipairs(owned) do
		if a.sold then pTot, pN = pTot + (a.total or 0), pN + 1 else lTot, lN = lTot + (a.total or 0), lN + 1 end
	end
	local lines = {
		"|cffffd100" .. T.sTotal .. "|r", "|cff3ec46d" .. money(total) .. "|r",
		"|cff9e9e9e" .. T.sCount:format(#h, #h > 0 and money(total / #h) or "–") .. "|r",
		best and ("|cff9e9e9e" .. T.sBest:format("|r" .. best)) or "",
		" ",
		T.sPend:format(money(pTot), pN), T.sLive:format(money(lTot), lN),
	}
	panel.sumFS:SetText(table.concat(lines, "\n"))
end

local function render()
	if not panel or not panel:IsShown() then return end
	local V = VIEWS[state.view]
	if V.ah and GetTime() - ownedAt > 2 then readOwned() end
	data = V.get()
	local s = state.sort[state.view] or V.sort
	local key, desc = s[1], s[2]
	table.sort(data, function(a, b)
		local x, y = a[key], b[key]
		if x == y then return tostring(a.name) < tostring(b.name) end
		if x == nil then return false elseif y == nil then return true end
		if type(x) ~= type(y) then x, y = tostring(x), tostring(y) end
		if desc then return x > y else return x < y end
	end)
	-- left column
	for _, k in ipairs(ORDER) do
		local b = panel.vb[k]
		b.sel:SetShown(k == state.view)
		local n = (k == "pend" and #pending()) or (k == "live" and #live()) or nil
		b.txt:SetText(VIEWS[k].label .. (n and n > 0 and ("  |cff9e9e9e" .. n .. "|r") or ""))
	end
	summary()
	for p, b in pairs(panel.pb) do
		b:SetEnabled(not V.ah)
		if p == state.period and not V.ah then b:LockHighlight() else b:UnlockHighlight() end
	end
	-- column headers: name on the left, the view's columns from the right edge
	local x = -8
	for i = 6, 1, -1 do panel.hd[i]:Hide() end
	for i = #V.cols, 1, -1 do
		local c, h = V.cols[i], panel.hd[i]
		h:ClearAllPoints(); h:SetPoint("TOPRIGHT", panel.head, "TOPRIGHT", x, 0); h:SetSize(c[3], 22)
		h.key = c[1]; h.txt:SetText(c[2] .. (c[1] == key and (desc and " |cffffd100v|r" or " |cffffd100^|r") or "")); h:Show()
		x = x - c[3] - 6
	end
	panel.hName.key = "name"; panel.hName.txt:SetText(T.cItem .. (key == "name" and (desc and " |cffffd100v|r" or " |cffffd100^|r") or ""))
	panel.hName:SetPoint("RIGHT", panel.head, "RIGHT", x, 0)
	-- rows
	state.offset = math.max(0, math.min(state.offset, #data - ROWS))
	for i = 1, MAXROWS do
		local r, d = rows[i], (i <= ROWS) and data[state.offset + i] or nil
		r.data = d
		if d then
			if not d.id and ProfitmancerItemID then d.id = ProfitmancerItemID(d.name); if d.id and d.src then d.src[5] = d.id end end
			local icon, iid = ProfitmancerAH.icon(d.id, d.name)
			if iid and not d.id then d.id = iid; if d.src then d.src[5] = iid end end
			r.icon:SetTexture(icon)
			local pre = (state.view == "pend") and ("|cff3ec46d" .. T.sold .. ":|r ") or ""
			r.name:SetText(pre .. d.name)
			local cx = -8
			for j = 1, 6 do r.c[j]:Hide() end
			for j = #V.cols, 1, -1 do
				local c, fs = V.cols[j], r.c[j]
				fs:ClearAllPoints(); fs:SetPoint("RIGHT", r, "RIGHT", cx, 0); fs:SetWidth(c[3])
				fs:SetText(cell(d[c[1]], c[1], d)); fs:Show()
				cx = cx - c[3] - 6
			end
			r.name:SetPoint("RIGHT", r, "RIGHT", cx, 0)
			r:Show()
		else
			r:Hide()
		end
	end
	local noAH = V.ah and not (AuctionHouseFrame and AuctionHouseFrame:IsShown())
	panel.empty:SetText(noAH and T.needAH or V.empty)
	panel.empty:SetShown(#data == 0)
	panel.page:SetText(#data > ROWS and T.rows:format(state.offset + 1, math.min(#data, state.offset + ROWS), #data) or "")
end

local function frameBox(f, a)
	if f.SetBackdrop then
		f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
		f:SetBackdropColor(0.07, 0.055, 0.04, a or 0.85); f:SetBackdropBorderColor(0.55, 0.44, 0.24)
	end
end

local function build()
	if panel then return end
	panel = CreateFrame("Frame", "ProfitmancerSalesPanel", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	panel:SetSize(560, 480); panel:SetFrameStrata("HIGH"); panel:SetClampedToScreen(true)
	panel:EnableMouse(true); panel:SetMovable(true); panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", function(self) if not self.docked then self:StartMoving() end end)
	panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
	if panel.SetBackdrop then
		panel:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
		panel:SetBackdropBorderColor(0.6, 0.6, 0.6)
	end
	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal"); title:SetPoint("TOPLEFT", 14, -12); title:SetText(T.title)
	local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", 2, 2)
	panel.titleFS, panel.closeB = title, close
	close:SetScript("OnClick", function() panel:Hide(); styleBtn(false) end)

	-- top: period buttons (history views) + search, right of the title
	panel.pb = {}
	local prev
	for _, p in ipairs({ { 1, T.p1 }, { 7, T.p7 }, { 30, T.p30 }, { 0, T.pAll } }) do
		local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
		b:SetSize(52, 22); b:SetText(p[2])
		if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", 252, -34) end
		b:SetScript("OnClick", function() state.period = p[1]; state.offset = 0; render() end)
		panel.pb[p[1]] = b; prev = b
	end
	local sb = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
	sb:SetSize(170, 22); sb:SetPoint("TOPRIGHT", -16, -34); sb:SetAutoFocus(false)
	sb:SetScript("OnTextChanged", function(self) state.query = self:GetText() or ""; state.offset = 0; render() end)
	sb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	local ph = sb:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); ph:SetPoint("LEFT", 4, 0); ph:SetText(T.search)
	sb:HookScript("OnTextChanged", function(self) ph:SetShown((self:GetText() or "") == "") end)

	-- left column: the views (like the Auctions tab's categories) and the summary
	local leftF = CreateFrame("Frame", nil, panel, BackdropTemplateMixin and "BackdropTemplate" or nil)
	leftF:SetPoint("TOPLEFT", 10, -64); leftF:SetPoint("BOTTOMLEFT", 10, 26); leftF:SetWidth(196)
	frameBox(leftF)
	panel.vb = {}
	for i, k in ipairs(ORDER) do
		local b = CreateFrame("Button", nil, leftF)
		b:SetHeight(26); b:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 27); b:SetPoint("RIGHT", -4, 0)
		local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.08)
		b.sel = b:CreateTexture(nil, "BACKGROUND"); b.sel:SetAllPoints(); b.sel:SetColorTexture(0.71, 0.55, 1, 0.25)
		b.txt = b:CreateFontString(nil, "OVERLAY", "GameFontNormal"); b.txt:SetPoint("LEFT", 8, 0); b.txt:SetPoint("RIGHT", -6, 0); b.txt:SetJustifyH("LEFT")
		b:SetScript("OnClick", function()
			state.view = k; state.offset = 0
			if VIEWS[k].ah then queryOwned() end
			render()
		end)
		panel.vb[k] = b
	end
	local sep = leftF:CreateTexture(nil, "ARTWORK"); sep:SetHeight(1); sep:SetPoint("TOPLEFT", 8, -4 - #ORDER * 27 - 6); sep:SetPoint("RIGHT", -8, 0); sep:SetColorTexture(0.55, 0.44, 0.24, 0.6)
	panel.sumFS = leftF:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	panel.sumFS:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 2, -10); panel.sumFS:SetPoint("RIGHT", -8, 0); panel.sumFS:SetJustifyH("LEFT"); panel.sumFS:SetSpacing(3)

	-- right: column headers + the table, framed like the auction house's list
	local inset = CreateFrame("Frame", nil, panel, BackdropTemplateMixin and "BackdropTemplate" or nil)
	inset:SetPoint("TOPLEFT", leftF, "TOPRIGHT", 8, 0); inset:SetPoint("BOTTOMRIGHT", -10, 26)
	frameBox(inset)
	panel.inset = inset
	local head = CreateFrame("Frame", nil, inset, BackdropTemplateMixin and "BackdropTemplate" or nil)
	head:SetPoint("TOPLEFT", 4, -4); head:SetPoint("TOPRIGHT", -4, -4); head:SetHeight(24)
	if head.SetBackdrop then
		head:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" }); head:SetBackdropColor(0.16, 0.12, 0.08, 1)
	end
	panel.head = head
	local function header(parent)
		local h = CreateFrame("Button", nil, parent)
		h:SetHeight(22)
		local hl = h:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.08)
		h.txt = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); h.txt:SetAllPoints()
		h:SetScript("OnClick", function(self)
			local V = VIEWS[state.view]
			local s = state.sort[state.view] or V.sort
			-- clicking the sorted column flips the order; another column sorts it (largest first, names A→Z)
			if s[1] == self.key then state.sort[state.view] = { s[1], not s[2] }
			else state.sort[state.view] = { self.key, self.key ~= "name" and self.key ~= "left" } end
			render()
		end)
		return h
	end
	panel.hName = header(head); panel.hName:SetPoint("LEFT", head, "LEFT", 40, 0); panel.hName.txt:SetJustifyH("LEFT")
	panel.hd = {}
	for i = 1, 6 do local h = header(head); h.txt:SetJustifyH("RIGHT"); panel.hd[i] = h end

	for i = 1, MAXROWS do
		local r = CreateFrame("Button", nil, inset)
		r:SetHeight(ROW_H); r:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -2 - (i - 1) * ROW_H); r:SetPoint("RIGHT", head, "RIGHT", 0, 0)
		local hl = r:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.08)
		if i % 2 == 0 then local bg = r:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(1, 1, 1, 0.03) end
		r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(26, 26); r.icon:SetPoint("LEFT", 6, 0)
		r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
		r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
		r.c = {}
		for j = 1, 6 do local fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); fs:SetJustifyH("RIGHT"); r.c[j] = fs end
		r:SetScript("OnEnter", function(self)
			local d = self.data; if not d then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			if d.link then pcall(GameTooltip.SetHyperlink, GameTooltip, d.link)
			elseif d.id then pcall(GameTooltip.SetItemByID, GameTooltip, d.id) else GameTooltip:AddLine(d.name, 1, 1, 1) end
			GameTooltip:AddLine(" ")
			if d.t then GameTooltip:AddDoubleLine(date(FR and "%d/%m/%Y %H:%M" or "%m/%d/%Y %H:%M", d.t), money(d.total), 0.8, 0.8, 0.8, 0.24, 0.77, 0.43) end
			if d.n then GameTooltip:AddDoubleLine(T.cSales .. " : " .. d.n, money(d.total), 0.8, 0.8, 0.8, 0.24, 0.77, 0.43) end
			if d.qty and d.unit and d.qty > 1 then GameTooltip:AddDoubleLine("x" .. d.qty, money(d.unit) .. " " .. T.each, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
			elseif not d.qty then GameTooltip:AddLine(T.unknown, 0.6, 0.6, 0.6) end
			if d.sold and d.left then GameTooltip:AddLine(T.cMail .. " : " .. T.mailIn .. " " .. left(d.left), 0.8, 0.8, 0.8) end
			if d.diff then GameTooltip:AddLine(d.diff > 0.05 and T.under or T.ok, d.diff > 0.05 and 1 or 0.24, d.diff > 0.05 and 0.42 or 0.77, d.diff > 0.05 and 0.35 or 0.43, true) end
			GameTooltip:Show()
		end)
		r:SetScript("OnLeave", function() GameTooltip:Hide() end)
		rows[i] = r
	end
	inset:EnableMouseWheel(true)
	inset:SetScript("OnMouseWheel", function(_, d) state.offset = state.offset - d * 3; render() end)
	panel.empty = inset:CreateFontString(nil, "OVERLAY", "GameFontDisable"); panel.empty:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 12, -16); panel.empty:SetPoint("RIGHT", head, "RIGHT", -12, 0)
	panel.empty:SetJustifyH("LEFT")
	panel.page = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); panel.page:SetPoint("BOTTOMRIGHT", -16, 9)
	panel:SetScript("OnShow", function() queryOwned(); render() end)
	panel:Hide()
	ProfitmancerAH.own(panel)
	ProfitmancerAH.view(panel, function() styleBtn(false) end)
end

local function dock()
	ProfitmancerAH.dock(panel)
	local h = (panel.docked and ProfitmancerAH.host() and ProfitmancerAH.host():GetHeight() - 56 or 480) / (ProfitmancerDB.panelScale or 1)
	ROWS = math.max(6, math.min(MAXROWS, math.floor((h - 110) / ROW_H)))
	for i, r in ipairs(rows) do if i > ROWS then r:Hide() end end
end

-- The "Sales" tab-styled button, after the auction house tabs (placed by AHTab.lua, with Shopping after it)
function styleBtn(open) ProfitmancerAH.style(ahBtn, open) end

local function toggle(show)
	build()
	if show == nil then show = not panel:IsShown() end
	if show then
		ProfitmancerAH.hideAll(panel)
		dock(); panel:Show(); render()
	else panel:Hide() end
	styleBtn(show)
end

local function makeButton()
	if ahBtn or not ProfitmancerAH.host() then return end
	ahBtn = ProfitmancerAH.button("ProfitmancerSalesButton", "Interface\\Icons\\INV_Misc_Coin_02", T.btn, T.btnTip, nil, function()
		ProfitmancerDB.salesSeen = true
		if ahBtn.pulse then ahBtn.pulse:Stop(); ahBtn.glow:Hide() end
		toggle()
	end)
	-- soft purple glow that pulses until the panel has been opened once
	local glow = ahBtn:CreateTexture(nil, "BACKGROUND")
	glow:SetPoint("TOPLEFT", -6, 6); glow:SetPoint("BOTTOMRIGHT", 6, -6)
	glow:SetColorTexture(0.71, 0.55, 1, 0.35); glow:SetBlendMode("ADD")
	local ag = glow:CreateAnimationGroup(); ag:SetLooping("BOUNCE")
	local fade = ag:CreateAnimation("Alpha"); fade:SetFromAlpha(0.15); fade:SetToAlpha(0.9); fade:SetDuration(1.1); fade:SetSmoothing("IN_OUT")
	ahBtn.glow, ahBtn.pulse = glow, ag
	ProfitmancerAH.register(ahBtn)
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "OWNED_AUCTIONS_UPDATED", "AUCTION_HOUSE_AUCTION_CREATED", "AUCTION_CANCELED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, e)
	if e == "AUCTION_HOUSE_SHOW" then
		pcall(makeButton)
		if ahBtn then
			if ProfitmancerDB.salesSeen then ahBtn.pulse:Stop(); ahBtn.glow:Hide() else ahBtn.glow:Show(); ahBtn.pulse:Play() end
			styleBtn(false)
		end
	elseif e == "AUCTION_HOUSE_CLOSED" then
		if panel and panel.docked then panel:Hide(); styleBtn(false) end
	elseif e == "OWNED_AUCTIONS_UPDATED" then
		readOwned(); if panel and panel:IsShown() then render() end
	elseif panel and panel:IsShown() then
		queryOwned(); render()
	end
end)

ProfitmancerSales = {
	toggle = function() toggle() end,
	hide = function() if panel and panel:IsShown() then panel:Hide(); styleBtn(false) end end,
	refresh = function() if panel and panel:IsShown() then render() end end,
	-- Minimap tooltip line: items currently listed on the auction house (all characters, last known)
	tooltip = function(tt)
		local n, q, val = 0, 0, 0
		for _, e in pairs(ProfitmancerDB.listed or {}) do n, q, val = n + (e.n or 0), q + (e.q or 0), val + (e.v or 0) end
		if n == 0 then return end
		tt:AddDoubleLine(FR and "En vente" or "Listed", q .. (FR and " obj." or " items") .. (val > 0 and ("  " .. money(val)) or ""), 0.71, 0.55, 1, 1, 1, 1)
	end,
}
