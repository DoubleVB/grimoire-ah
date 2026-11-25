-- Profitmancer: shopping lists at the auction house, in a panel docked to the auction house window (like the sales history).
-- Lists are shared by all your characters and use Auctionator's import/export format:  List name^"Exact name";;0;0;0;0;0;0;0;0;;#;;quantity^...
-- Clicking an item searches it in the auction house. Buying stays a click on Blizzard's own Buy button: the game only
-- allows purchases from a real click of the player, an addon can't buy on its own.
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local FR = GetLocale() == "frFR"
local T = FR and {
	btn = "Courses", btnTip = "Tes listes de courses : clique sur un objet pour le chercher à l'HV. Import/export au format Auctionator.",
	title = "Profitmancer · listes de courses", new = "Nouvelle", del = "Supprimer", delSure = "Confirmer ?", import = "Importer", export = "Exporter",
	add = "Ajouter", addHint = "Nom ou Maj+clic sur un objet", qty = "Qté", searchNext = "Chercher le suivant", noList = "Aucune liste : crée-en une ou importe une liste Auctionator.",
	empty = "Liste vide : ajoute un objet ci-dessous, ou utilise EXPORT dans une fenêtre de métier.", have = "sacs", newName = "Liste %d",
	impTitle = "Importer des listes (format Auctionator)", impHelp = "Colle le texte exporté depuis Auctionator (Achats > Exporter) ou depuis Profitmancer, puis Importer.",
	expTitle = "Exporter la liste (format Auctionator)", expHelp = "Ctrl+C pour copier, puis Auctionator > Achats > Importer, ou partage-la.",
	imported = "%d liste(s) importée(s).", nothing = "aucune liste reconnue dans ce texte.", close = "Fermer", ok = "Importer",
	done = "tout est dans tes sacs", searching = "recherche : %s", noAH = "ouvre l'hôtel des ventes pour chercher.",
	buyInfo = "Achat : clique sur Acheter dans l'hôtel des ventes (le jeu n'autorise pas un addon à acheter seul).",
	rows = "%d–%d sur %d", added = "ajouté à « %s ».", backList = "Ma liste", toBuy = "à acheter : %d",
	crafts = "Crafts :", craftsTip = "Nombre de crafts : toutes les quantités de la liste suivent. Tape un nombre ou utilise - / + (Maj = 10). Chaque quantité reste modifiable à la main (Maj = 10, Ctrl = 100).",
} or {
	btn = "Shop lists", btnTip = "Your shopping lists: click an item to search it at the AH. Import/export in Auctionator's format.",
	title = "Profitmancer · shopping lists", new = "New", del = "Delete", delSure = "Sure?", import = "Import", export = "Export",
	add = "Add", addHint = "Name or Shift+click an item", qty = "Qty", searchNext = "Search next", noList = "No list yet: create one or import an Auctionator list.",
	empty = "Empty list: add an item below, or use EXPORT in a profession window.", have = "bags", newName = "List %d",
	impTitle = "Import lists (Auctionator format)", impHelp = "Paste the text exported from Auctionator (Shopping > Export) or from Profitmancer, then Import.",
	expTitle = "Export the list (Auctionator format)", expHelp = "Ctrl+C to copy, then Auctionator > Shopping > Import, or share it.",
	imported = "%d list(s) imported.", nothing = "no list found in this text.", close = "Close", ok = "Import",
	done = "all in your bags", searching = "searching: %s", noAH = "open the auction house to search.",
	buyInfo = "Buying: click Buy in the auction house (the game doesn't let an addon buy on its own).",
	rows = "%d–%d of %d", added = "added to \"%s\".", backList = "My list", toBuy = "to buy: %d",
	crafts = "Crafts:", craftsTip = "Number of crafts: every quantity in the list follows. Type a number or use - / + (Shift = 10). Each quantity can still be changed by hand (Shift = 10, Ctrl = 100).",
}
local function say(s) print("|cffb48cffProfitmancer|r: " .. s) end
local function clean(s) return (tostring(s or ""):gsub("[%^;\"]", "")) end
local function trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

-- ——— Data: ProfitmancerDB.lists = { { name = "...", items = { { term = "...", qty = n, exact = true } } } }, ProfitmancerDB.listSel ———
local function lists()
	ProfitmancerDB = ProfitmancerDB or {}
	ProfitmancerDB.lists = ProfitmancerDB.lists or {}
	return ProfitmancerDB.lists
end
local function current()
	local L = lists()
	local i = ProfitmancerDB.listSel or 1
	if i > #L then i = #L end
	if i < 1 then i = 1 end
	ProfitmancerDB.listSel = i
	return L[i], i
end
local function findList(name)
	for i, l in ipairs(lists()) do if l.name == name then return l, i end end
end

-- Auctionator text -> lists. One list per line: name^term^term...; a term is "searchText";...;quantity (or plain text).
local function parse(text)
	local out = {}
	for line in (tostring(text or "") .. "\n"):gmatch("([^\r\n]*)[\r\n]") do
		line = trim(line)
		if line:find("%^") then
			local parts = {}
			for p in (line .. "^"):gmatch("([^%^]*)%^") do parts[#parts + 1] = p end
			local l = { name = trim(parts[1]) ~= "" and trim(parts[1]) or "Import", items = {} }
			for k = 2, #parts do
				local p = parts[k]
				if trim(p) ~= "" then
					local fields = {}
					for f in (p .. ";"):gmatch("([^;]*);") do fields[#fields + 1] = f end
					local term = trim(fields[1] or "")
					local exact = term:match('^".*"$') ~= nil
					term = term:gsub('^"', ""):gsub('"$', "")
					local qty = tonumber(fields[#fields]) or 0
					if term ~= "" then l.items[#l.items + 1] = { term = term, qty = qty, exact = exact } end
				end
			end
			out[#out + 1] = l
		end
	end
	return out
end
local function serialize(l)
	local parts = { clean(l.name) }
	for _, it in ipairs(l.items) do
		parts[#parts + 1] = (it.exact ~= false and ('"' .. clean(it.term) .. '"') or clean(it.term)) .. ";;0;0;0;0;0;0;0;0;;#;;" .. (it.qty or 0)
	end
	return table.concat(parts, "^")
end

-- Number of crafts of a list: every item keeps its amount per craft (it.per) and its quantity follows the count.
-- Items without that amount (imported, added by hand) take it from their current quantity, so they scale the same way.
local function setCrafts(l, n)
	n = math.max(1, math.floor(tonumber(n) or 1))
	local old = l.crafts or 1
	for _, it in ipairs(l.items) do
		if not it.per then it.per = (it.qty or 0) / old end
		it.qty = math.ceil(it.per * n - 1e-6)
	end
	l.crafts = n
end
-- A quantity typed or stepped by hand: it becomes this item's new amount for the current number of crafts
local function setQty(l, it, q)
	it.qty = math.max(0, math.floor(tonumber(q) or 0))
	it.per = it.qty / ((l and l.crafts) or 1)
end

-- Add or merge a list (from the recipe EXPORT button or an import)
local function addList(l)
	local L = lists()
	local ex, i = findList(l.name)
	if ex and l.crafts then
		-- the same recipe exported again: its reagents are already there, add the crafts
		for _, it in ipairs(l.items) do
			local found
			for _, e in ipairs(ex.items) do if e.term:lower() == it.term:lower() then found = e end end
			if found then found.per = found.per or it.per; found.id = found.id or it.id
			else ex.items[#ex.items + 1] = { term = it.term, id = it.id, per = it.per, qty = 0, exact = it.exact } end
		end
		setCrafts(ex, (ex.crafts or 1) + l.crafts)
	elseif ex then
		for _, it in ipairs(l.items) do
			local found
			for _, e in ipairs(ex.items) do if e.term:lower() == it.term:lower() then found = e end end
			if found then setQty(ex, found, (found.qty or 0) + (it.qty or 0)); found.id = found.id or it.id
			else if not it.per then it.per = (it.qty or 0) / (ex.crafts or 1) end; ex.items[#ex.items + 1] = it end
		end
	else
		L[#L + 1] = l
		i = #L
	end
	ProfitmancerDB.listSel = i
	return i
end

-- An entry saved as "item 1234" (the game didn't know the item's name yet when the list was made): give it its real name
-- as soon as the game knows it; until then ask the game to load it (the list is redrawn when it arrives)
local healWait = {}
local function heal(it)
	if not it or type(it.term) ~= "string" then return end
	local n = tonumber(it.term:match("^item (%d+)$"))
	if not n then return end
	it.id = it.id or n
	local name = GetItemInfo(it.id)
	if name then it.term = name; healWait[it.id] = nil
	elseif not healWait[it.id] then
		healWait[it.id] = true
		if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, it.id) end
	end
end
ProfitmancerShoppingHeal = heal

-- How many are in the bags (by name: works for items the game knows)
local function bagCount(term)
	local ok, n = pcall(function()
		if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(term) end
		return GetItemCount(term)
	end)
	return ok and tonumber(n) or 0
end

-- ——— Search in the auction house window ———
local pending -- { term, id, need }: the item being looked up, to open its purchase once the results arrive
local showBar -- the small bar above the auction house window (defined further down)
local function search(term, id, need)
	local n = type(term) == "string" and tonumber(term:match("^item (%d+)$"))
	if n then id = id or n; term = GetItemInfo(id) or term end
	if AuctionHouseFrame and AuctionHouseFrame:IsShown() then
		-- our view is closed so the auction house results are visible, with the small list bar above the window
		if ProfitmancerAH and ProfitmancerAH.hideAll then ProfitmancerAH.hideAll() end
		local bar = AuctionHouseFrame.SearchBar
		if AuctionHouseFrame.SetDisplayMode and AuctionHouseFrameDisplayMode and AuctionHouseFrameDisplayMode.Buy then
			pcall(AuctionHouseFrame.SetDisplayMode, AuctionHouseFrame, AuctionHouseFrameDisplayMode.Buy)
		end
		if bar and bar.SearchBox then
			pending = { term = term, id = id, need = need, t = GetTime() }
			bar.SearchBox:SetText(term)
			if bar.StartSearch then pcall(bar.StartSearch, bar) elseif bar.SearchButton then bar.SearchButton:Click() end
			if showBar then showBar() end
			return true
		end
	elseif AuctionFrame and AuctionFrame:IsShown() and BrowseName then
		if ProfitmancerAH and ProfitmancerAH.hideAll then ProfitmancerAH.hideAll() end
		if AuctionFrameTab1 then pcall(AuctionFrameTab1.Click, AuctionFrameTab1) end
		BrowseName:SetText(term)
		if AuctionFrameBrowse_Search then pcall(AuctionFrameBrowse_Search) end
		if showBar then showBar() end
		return true
	end
	say(T.noAH)
	return false
end

-- When the results arrive: open the matching item's purchase and put the missing quantity in it (the player then clicks Buy)
local function openPurchase()
	local p = pending
	if not p or GetTime() - p.t > 10 or not (C_AuctionHouse and C_AuctionHouse.GetBrowseResults) then return end
	local want = p.term:lower()
	for _, r in ipairs(C_AuctionHouse.GetBrowseResults() or {}) do
		local key = r.itemKey
		local info = key and C_AuctionHouse.GetItemKeyInfo and C_AuctionHouse.GetItemKeyInfo(key)
		if key and ((p.id and key.itemID == p.id) or (info and info.itemName and info.itemName:lower() == want)) then
			pending = nil
			if AuctionHouseFrame.SelectBrowseResult then pcall(AuctionHouseFrame.SelectBrowseResult, AuctionHouseFrame, r) end
			if p.need and p.need > 0 then
				local function setQty()
					local bf = AuctionHouseFrame.CommoditiesBuyFrame
					local bd = bf and bf.BuyDisplay
					if not (bf and bf:IsShown() and bd) then return end
					local qi = bd.QuantityInput
					if bd.SetQuantitySelected then pcall(bd.SetQuantitySelected, bd, p.need) end
					if qi and qi.SetQuantity then pcall(qi.SetQuantity, qi, p.need) end
					local ib = qi and qi.InputBox
					if ib then ib:SetText(tostring(p.need)); local f = ib:GetScript("OnTextChanged"); if f then pcall(f, ib, true) end end
				end
				C_Timer.After(0.2, setQty); C_Timer.After(0.6, setQty)
			end
			return
		end
	end
end

-- ——— Copy / paste window ———
local box
local function textWindow(title, help, text, onOk)
	if not box then
		box = CreateFrame("Frame", "ProfitmancerListText", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
		box:SetSize(520, 150); box:SetPoint("CENTER", 0, 140); box:SetFrameStrata("DIALOG")
		box:EnableMouse(true); box:SetMovable(true); box:RegisterForDrag("LeftButton")
		box:SetScript("OnDragStart", box.StartMoving); box:SetScript("OnDragStop", box.StopMovingOrSizing)
		if box.SetBackdrop then
			box:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } })
		end
		box.t = box:CreateFontString(nil, "OVERLAY", "GameFontNormal"); box.t:SetPoint("TOP", 0, -18)
		box.h = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); box.h:SetPoint("TOP", 0, -38); box.h:SetWidth(470)
		local e = CreateFrame("EditBox", nil, box, "InputBoxTemplate")
		e:SetSize(460, 24); e:SetPoint("TOP", 0, -64); e:SetAutoFocus(true); e:SetMaxLetters(0)
		e:SetScript("OnEscapePressed", function() box:Hide() end)
		e:SetScript("OnTextChanged", function(self, user) if user and box.readonly then self:SetText(box.text or ""); self:HighlightText() end end)
		e:SetScript("OnEnterPressed", function() if box.onOk then box.ok:Click() end end)
		box.edit = e
		box.ok = CreateFrame("Button", nil, box, "UIPanelButtonTemplate"); box.ok:SetSize(100, 22); box.ok:SetPoint("BOTTOMRIGHT", box, "BOTTOM", -6, 14); box.ok:SetText(T.ok)
		box.ok:SetScript("OnClick", function() local f = box.onOk; box:Hide(); if f then f(box.edit:GetText()) end end)
		box.close = CreateFrame("Button", nil, box, "UIPanelButtonTemplate"); box.close:SetSize(100, 22); box.close:SetText(T.close)
		box.close:SetScript("OnClick", function() box:Hide() end)
		tinsert(UISpecialFrames, "ProfitmancerListText")
	end
	box.t:SetText(title); box.h:SetText(help)
	box.onOk, box.readonly, box.text = onOk, not onOk, text
	box.ok:SetShown(onOk ~= nil)
	box.close:ClearAllPoints()
	if onOk then box.close:SetPoint("BOTTOMLEFT", box, "BOTTOM", 6, 14) else box.close:SetPoint("BOTTOM", 0, 14) end
	box:Show()
	box.edit:SetText(text or ""); box.edit:SetFocus()
	if text and text ~= "" then box.edit:SetCursorPosition(0); box.edit:HighlightText() end
end

-- ——— Panel: list of lists on the left (like Auctionator), items of the selected list on the right ———
local panel, rows, lrows = nil, {}, {}
local MAXROWS, ROW_H, ROWS, MAXL, LROWS = 18, 32, 12, 20, 12
local state = { offset = 0, loff = 0, delAt = 0 }
local render, styleBtn
local btn

local function mkBtn(parent, w, text, fn)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(w, 22); b:SetText(text); b:SetScript("OnClick", fn)
	return b
end

local function build()
	if panel then return end
	panel = CreateFrame("Frame", "ProfitmancerShoppingPanel", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	panel:SetSize(560, 480); panel:SetClampedToScreen(true)
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

	-- left column: the lists
	local left = CreateFrame("Frame", nil, panel, BackdropTemplateMixin and "BackdropTemplate" or nil)
	left:SetPoint("TOPLEFT", 10, -36); left:SetPoint("BOTTOMLEFT", 10, 40); left:SetWidth(230)
	if left.SetBackdrop then
		left:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
		left:SetBackdropColor(0.07, 0.055, 0.04, 0.85); left:SetBackdropBorderColor(0.55, 0.44, 0.24)
	end
	panel.left = left
	for i = 1, MAXL do
		local r = CreateFrame("Button", nil, left)
		r:SetHeight(26); r:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 26); r:SetPoint("RIGHT", -4, 0)
		local hl = r:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.08)
		r.sel = r:CreateTexture(nil, "BACKGROUND"); r.sel:SetAllPoints(); r.sel:SetColorTexture(0.71, 0.55, 1, 0.25)
		r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal"); r.name:SetPoint("LEFT", 6, 0); r.name:SetPoint("RIGHT", -34, 0); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
		r.count = r:CreateFontString(nil, "OVERLAY", "GameFontDisable"); r.count:SetPoint("RIGHT", -6, 0)
		r:SetScript("OnClick", function(self) if self.idx then ProfitmancerDB.listSel = self.idx; state.offset = 0; state.lastSearch = nil; render() end end)
		lrows[i] = r
	end
	left:EnableMouseWheel(true)
	left:SetScript("OnMouseWheel", function(_, d) state.loff = state.loff - d * 3; render() end)

	-- under the lists: New, Delete, Import, Export
	local newB = mkBtn(panel, 112, T.new, function() local L = lists(); L[#L + 1] = { name = T.newName:format(#L + 1), items = {} }; ProfitmancerDB.listSel = #L; render() end)
	newB:SetPoint("BOTTOMLEFT", 10, 12)
	panel.delB = mkBtn(panel, 112, T.del, function()
		if state.delAt < GetTime() then state.delAt = GetTime() + 4; render(); C_Timer.After(4.1, function() render() end) return end
		state.delAt = 0
		local _, i = current(); if i and lists()[i] then table.remove(lists(), i) end
		render()
	end)
	panel.delB:SetPoint("LEFT", newB, "RIGHT", 6, 0)
	local imp = mkBtn(panel, 112, T.import, function()
		textWindow(T.impTitle, T.impHelp, "", function(txt)
			local got = parse(txt)
			for _, l in ipairs(got) do addList(l) end
			say(#got > 0 and T.imported:format(#got) or T.nothing)
			render()
		end)
	end)
	imp:SetPoint("LEFT", panel.delB, "RIGHT", 6, 0)
	local exp = mkBtn(panel, 112, T.export, function() local l = current(); if l then textWindow(T.expTitle, T.expHelp, serialize(l)) end end)
	exp:SetPoint("LEFT", imp, "RIGHT", 6, 0)

	-- right column: the items of the selected list
	local right = CreateFrame("Frame", nil, panel)
	right:SetPoint("TOPLEFT", left, "TOPRIGHT", 10, 0); right:SetPoint("BOTTOMRIGHT", -10, 40)
	panel.right = right
	panel.lname = right:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); panel.lname:SetPoint("TOPLEFT", 4, -4); panel.lname:SetPoint("RIGHT", -170, 0); panel.lname:SetJustifyH("LEFT"); panel.lname:SetWordWrap(false)
	panel.nextS = mkBtn(right, 160, T.searchNext, function()
		local l = current(); if not l or #l.items == 0 then return end
		local n = #l.items
		for k = 1, n do
			local idx = ((state.lastSearch or 0) + k - 1) % n + 1
			local it = l.items[idx]
			if bagCount(it.term) < (it.qty or 0) or (it.qty or 0) == 0 then state.lastSearch = idx; search(it.term, it.id, math.max(0, (it.qty or 0) - bagCount(it.term))); render(); return end
		end
		say(T.done)
	end)
	panel.nextS:SetPoint("TOPRIGHT", 0, 0)
	-- number of crafts for the whole list: - [ 5 ] +  (every item's quantity follows; Shift = 10 at a time)
	local function crafts(v) local l = current(); if not l then return end; setCrafts(l, v); render() end
	panel.cPlus = mkBtn(right, 24, "+", function() local l = current(); if l then crafts((l.crafts or 1) + (IsShiftKeyDown() and 10 or 1)) end end)
	panel.cPlus:SetPoint("RIGHT", panel.nextS, "LEFT", -12, 0)
	panel.cBox = CreateFrame("EditBox", nil, right, "InputBoxTemplate")
	panel.cBox:SetSize(40, 20); panel.cBox:SetPoint("RIGHT", panel.cPlus, "LEFT", -6, 0); panel.cBox:SetAutoFocus(false); panel.cBox:SetNumeric(true); panel.cBox:SetMaxLetters(4); panel.cBox:SetJustifyH("CENTER")
	panel.cBox:SetScript("OnEnterPressed", function(self) self:ClearFocus(); crafts(self:GetText()) end)
	panel.cBox:SetScript("OnEditFocusLost", function(self) local l = current(); if l and tonumber(self:GetText()) and tonumber(self:GetText()) ~= (l.crafts or 1) then crafts(self:GetText()) end end)
	panel.cBox:SetScript("OnEscapePressed", function(self) self:ClearFocus(); render() end)
	panel.cMinus = mkBtn(right, 24, "-", function() local l = current(); if l then crafts((l.crafts or 1) - (IsShiftKeyDown() and 10 or 1)) end end)
	panel.cMinus:SetPoint("RIGHT", panel.cBox, "LEFT", -6, 0)
	panel.cLabel = right:CreateFontString(nil, "OVERLAY", "GameFontNormal"); panel.cLabel:SetPoint("RIGHT", panel.cMinus, "LEFT", -6, 0); panel.cLabel:SetText(T.crafts)
	local tipF = CreateFrame("Frame", nil, right); tipF:SetAllPoints(panel.cLabel); tipF:EnableMouse(true)
	tipF:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine(T.crafts, 1, 0.82, 0); GameTooltip:AddLine(T.craftsTip, 1, 1, 1, true); GameTooltip:Show() end)
	tipF:SetScript("OnLeave", function() GameTooltip:Hide() end)
	panel.lname:ClearAllPoints(); panel.lname:SetPoint("TOPLEFT", 4, -4); panel.lname:SetPoint("RIGHT", panel.cLabel, "LEFT", -10, 0)
	for i = 1, MAXROWS do
		local r = CreateFrame("Button", nil, right)
		r:SetHeight(ROW_H); r:SetPoint("TOPLEFT", 0, -28 - (i - 1) * ROW_H); r:SetPoint("RIGHT", 0, 0)
		local hl = r:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.08)
		if i % 2 == 0 then local bg = r:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(1, 1, 1, 0.03) end
		r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(28, 28); r.icon:SetPoint("LEFT", 4, 0)
		r.del = CreateFrame("Button", nil, r, "UIPanelCloseButton"); r.del:SetSize(26, 26); r.del:SetPoint("RIGHT", 2, 0)
		r.plus = CreateFrame("Button", nil, r, "UIPanelButtonTemplate"); r.plus:SetSize(24, 22); r.plus:SetPoint("RIGHT", r.del, "LEFT", -2, 0); r.plus:SetText("+")
		r.minus = CreateFrame("Button", nil, r, "UIPanelButtonTemplate"); r.minus:SetSize(24, 22); r.minus:SetPoint("RIGHT", r.plus, "LEFT", -2, 0); r.minus:SetText("-")
		-- the quantity: a box to type any number (Enter or clicking elsewhere keeps it)
		r.qbox = CreateFrame("EditBox", nil, r, "InputBoxTemplate")
		r.qbox:SetSize(44, 20); r.qbox:SetPoint("RIGHT", r.minus, "LEFT", -8, 0); r.qbox:SetAutoFocus(false); r.qbox:SetNumeric(true); r.qbox:SetMaxLetters(5); r.qbox:SetJustifyH("CENTER")
		local function keep(self)
			local l, it = current(), r.item
			if it and l and tonumber(self:GetText()) and tonumber(self:GetText()) ~= it.qty then setQty(l, it, self:GetText()) end
			self:ClearFocus(); render()
		end
		r.qbox:SetScript("OnEnterPressed", keep)
		r.qbox:SetScript("OnEditFocusLost", function(self) if r.item and tonumber(self:GetText()) and tonumber(self:GetText()) ~= r.item.qty then keep(self) end end)
		r.qbox:SetScript("OnEscapePressed", function(self) self:ClearFocus(); render() end)
		r.qty = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); r.qty:SetPoint("RIGHT", r.qbox, "LEFT", -10, 0); r.qty:SetJustifyH("RIGHT")
		r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0); r.name:SetPoint("RIGHT", r.qty, "LEFT", -6, 0)
		r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
		-- - / + : 1 at a time, 10 with Shift, 100 with Ctrl
		local function step(d)
			local it = r.item; if not it then return end
			local k = IsControlKeyDown() and 100 or IsShiftKeyDown() and 10 or 1
			setQty(current(), it, math.max(0, (it.qty or 0) + d * k)); render()
		end
		r.plus:SetScript("OnClick", function() step(1) end)
		r.minus:SetScript("OnClick", function() step(-1) end)
		r.del:SetScript("OnClick", function()
			local l = current(); if not l or not r.item then return end
			for k, it in ipairs(l.items) do if it == r.item then table.remove(l.items, k) break end end
			render()
		end)
		r:SetScript("OnClick", function()
			if not r.item then return end
			local l = current()
			for k, it in ipairs(l and l.items or {}) do if it == r.item then state.lastSearch = k end end
			search(r.item.term, r.item.id, math.max(0, (r.item.qty or 0) - bagCount(r.item.term)))
			render()
		end)
		r:SetScript("OnEnter", function(self)
			if not self.item then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			local _, link = GetItemInfo(self.item.term)
			if link then GameTooltip:SetHyperlink(link) else GameTooltip:AddLine(self.item.term, 1, 1, 1) end
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine(T.buyInfo, 0.62, 0.62, 0.62, true)
			GameTooltip:Show()
		end)
		r:SetScript("OnLeave", function() GameTooltip:Hide() end)
		rows[i] = r
	end
	right:EnableMouseWheel(true)
	right:SetScript("OnMouseWheel", function(_, d) state.offset = state.offset - d * 3; render() end)
	panel.msg = right:CreateFontString(nil, "OVERLAY", "GameFontDisable"); panel.msg:SetPoint("TOPLEFT", 6, -40); panel.msg:SetPoint("RIGHT", -6, 0); panel.msg:SetJustifyH("LEFT")
	panel.page = right:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); panel.page:SetPoint("BOTTOMRIGHT", 0, 2)

	-- add an item: name box (accepts Shift+click links) + quantity + Add, at the bottom right
	local addB = mkBtn(panel, 90, T.add, nil)
	addB:SetPoint("BOTTOMRIGHT", -12, 12)
	panel.qtyBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
	panel.qtyBox:SetSize(44, 20); panel.qtyBox:SetPoint("RIGHT", addB, "LEFT", -12, 0); panel.qtyBox:SetAutoFocus(false); panel.qtyBox:SetNumeric(true); panel.qtyBox:SetText("1")
	panel.addBox = CreateFrame("EditBox", "ProfitmancerShoppingAddBox", panel, "InputBoxTemplate")
	panel.addBox:SetHeight(20); panel.addBox:SetPoint("RIGHT", panel.qtyBox, "LEFT", -18, 0); panel.addBox:SetPoint("LEFT", exp, "RIGHT", 24, 0); panel.addBox:SetAutoFocus(false)
	local ph = panel.addBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); ph:SetPoint("LEFT", 4, 0); ph:SetPoint("RIGHT", -4, 0); ph:SetJustifyH("LEFT"); ph:SetWordWrap(false); ph:SetText(T.addHint)
	panel.addBox:SetScript("OnTextChanged", function(self) ph:SetShown((self:GetText() or "") == "") end)
	panel.addBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	local function doAdd()
		local txt = panel.addBox:GetText() or ""
		local term = txt:match("%[(.-)%]") or trim(txt) -- an item link gives its name
		local lid = tonumber(txt:match("item:(%d+)"))
		if term == "" then return end
		local l = current()
		if not l then lists()[1] = { name = T.newName:format(1), items = {} }; ProfitmancerDB.listSel = 1; l = lists()[1] end
		addList({ name = l.name, items = { { term = term, id = lid, qty = tonumber(panel.qtyBox:GetText()) or 1, exact = true } } })
		panel.addBox:SetText(""); panel.addBox:ClearFocus(); render()
	end
	addB:SetScript("OnClick", doAdd)
	panel.addBox:SetScript("OnEnterPressed", doAdd)
	if ChatEdit_InsertLink then
		hooksecurefunc("ChatEdit_InsertLink", function(link)
			if panel and panel:IsShown() and panel.addBox:HasFocus() and link then panel.addBox:SetText(link) end
		end)
	end
	panel:SetScript("OnShow", function() render() end)
	panel:Hide()
	ProfitmancerAH.own(panel)
	ProfitmancerAH.view(panel, function() styleBtn(false) end)
end

function render()
	if not panel or not panel:IsShown() then return end
	local L = lists()
	local l, sel = current()
	-- lists
	state.loff = math.max(0, math.min(state.loff, #L - LROWS))
	for k = 1, MAXL do
		local r, idx = lrows[k], state.loff + k
		local x = (k <= LROWS) and L[idx] or nil
		r.idx = x and idx or nil
		if x then
			r.name:SetText(x.name); r.count:SetText(#x.items); r.sel:SetShown(idx == sel); r:Show()
		else r:Hide() end
	end
	panel.delB:SetText(state.delAt > GetTime() and T.delSure or T.del)
	panel.delB:SetEnabled(l ~= nil)
	-- items
	panel.lname:SetText(l and l.name or "")
	for _, w in ipairs({ panel.cLabel, panel.cMinus, panel.cBox, panel.cPlus }) do w:SetShown(l ~= nil and #l.items > 0) end
	if l and not panel.cBox:HasFocus() then panel.cBox:SetText(tostring(l.crafts or 1)) end
	local items = l and l.items or {}
	state.offset = math.max(0, math.min(state.offset, #items - ROWS))
	for k = 1, MAXROWS do
		local r, it = rows[k], (k <= ROWS) and items[state.offset + k] or nil
		r.item = it
		if it then
			heal(it)
			local have = bagCount(it.term)
			local tex, iid = ProfitmancerAH.icon(it.id, it.term)
			if iid and not it.id then it.id = iid end -- remembered once the game knows the item
			r.icon:SetTexture(tex)
			local ok = (it.qty or 0) > 0 and have >= it.qty
			local mark = (state.lastSearch and items[state.lastSearch] == it) and "|cffb48cff> |r" or ""
			r.name:SetText(mark .. (ok and ("|cff3ec46d" .. it.term .. "|r") or it.term))
			r.qty:SetText("|cff9e9e9e(" .. T.have .. " " .. have .. ")|r")
			if not r.qbox:HasFocus() then r.qbox:SetText(tostring(it.qty or 0)) end
			if ok then r.qbox:SetTextColor(0.24, 0.77, 0.43) else r.qbox:SetTextColor(1, 1, 1) end
			r:Show()
		else
			r:Hide()
		end
	end
	panel.msg:SetShown(not l or #items == 0)
	panel.msg:SetText(not l and T.noList or T.empty)
	panel.nextS:SetEnabled(#items > 0)
	panel.page:SetText(#items > ROWS and T.rows:format(state.offset + 1, math.min(#items, state.offset + ROWS), #items) or "")
end

local function dock()
	ProfitmancerAH.dock(panel)
	local h = (panel.docked and ProfitmancerAH.host() and ProfitmancerAH.host():GetHeight() - 56 or 480) / (ProfitmancerDB.panelScale or 1)
	ROWS = math.max(5, math.min(MAXROWS, math.floor((h - 110) / ROW_H)))
	LROWS = math.max(5, math.min(MAXL, math.floor((h - 90) / 26)))
end

function styleBtn(open) ProfitmancerAH.style(btn, open) end

local function toggle(show)
	build()
	if show == nil then show = not panel:IsShown() end
	if show then
		ProfitmancerAH.hideAll(panel)
		if ProfitmancerShoppingBar then ProfitmancerShoppingBar:Hide() end
		dock(); panel:Show(); render()
	else panel:Hide() end
	styleBtn(show)
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, e, itemID)
	if e == "GET_ITEM_INFO_RECEIVED" then
		-- an item name we were waiting for has arrived: redraw so "item 1234" becomes its real name
		if itemID and healWait[itemID] and panel and panel:IsShown() then render() end
		return
	end
	if e == "AUCTION_HOUSE_SHOW" then
		if not btn and ProfitmancerAH.host() then
			btn = ProfitmancerAH.button("ProfitmancerShoppingButton", "Interface\\Icons\\INV_Misc_Bag_10", T.btn, T.btnTip, T.buyInfo, function() toggle() end)
			ProfitmancerAH.register(btn)
		end
		styleBtn(false)
	elseif e == "AUCTION_HOUSE_CLOSED" then
		if panel and panel.docked then panel:Hide(); styleBtn(false) end
	elseif e == "BAG_UPDATE_DELAYED" then
		if panel and panel:IsShown() then render() end
	end
end)

-- ——— Small bar above the auction house window while buying from a list: previous / next item, back to the list ———
local sbar
local function step(d)
	local l = current(); if not l or #l.items == 0 then return end
	local n = #l.items
	local idx = (((state.lastSearch or 0) + d - 1) % n) + 1
	state.lastSearch = idx
	local it = l.items[idx]
	search(it.term, it.id, math.max(0, (it.qty or 0) - bagCount(it.term)))
end
function showBar()
	local h = ProfitmancerAH.host()
	if not h then return end
	if not sbar then
		sbar = CreateFrame("Frame", "ProfitmancerShoppingBar", h, BackdropTemplateMixin and "BackdropTemplate" or nil)
		sbar:SetSize(430, 34); sbar:SetPoint("BOTTOMRIGHT", h, "TOPRIGHT", -30, -2); sbar:SetFrameLevel(math.min(h:GetFrameLevel() + 520, 9000))
		if sbar.SetBackdrop then
			sbar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
			sbar:SetBackdropColor(0.105, 0.085, 0.065, 0.97); sbar:SetBackdropBorderColor(0.71, 0.55, 1)
		end
		local prev = CreateFrame("Button", nil, sbar, "UIPanelButtonTemplate"); prev:SetSize(28, 22); prev:SetPoint("LEFT", 6, 0); prev:SetText("<")
		prev:SetScript("OnClick", function() step(-1) end)
		local back = CreateFrame("Button", nil, sbar, "UIPanelButtonTemplate"); back:SetSize(90, 22); back:SetPoint("RIGHT", -6, 0); back:SetText(T.backList)
		back:SetScript("OnClick", function() sbar:Hide(); toggle(true) end)
		local nxt = CreateFrame("Button", nil, sbar, "UIPanelButtonTemplate"); nxt:SetSize(28, 22); nxt:SetPoint("RIGHT", back, "LEFT", -6, 0); nxt:SetText(">")
		nxt:SetScript("OnClick", function() step(1) end)
		sbar.icon = sbar:CreateTexture(nil, "ARTWORK"); sbar.icon:SetSize(24, 24); sbar.icon:SetPoint("LEFT", prev, "RIGHT", 8, 0)
		sbar.txt = sbar:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); sbar.txt:SetPoint("LEFT", sbar.icon, "RIGHT", 6, 0); sbar.txt:SetPoint("RIGHT", nxt, "LEFT", -6, 0)
		sbar.txt:SetJustifyH("LEFT"); sbar.txt:SetWordWrap(false)
		sbar:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine("Profitmancer", 0.71, 0.55, 1)
			GameTooltip:AddLine(T.buyInfo, 1, 1, 1, true); GameTooltip:Show()
		end)
		sbar:SetScript("OnLeave", function() GameTooltip:Hide() end)
		sbar:EnableMouse(true)
	end
	local l = current()
	local it = l and state.lastSearch and l.items[state.lastSearch]
	if not it then sbar:Hide() return end
	local need = math.max(0, (it.qty or 0) - bagCount(it.term))
	sbar.icon:SetTexture((ProfitmancerAH.icon(it.id, it.term)))
	sbar.txt:SetText(it.term .. "  |cff9e9e9e" .. T.toBuy:format(need) .. "  (" .. state.lastSearch .. "/" .. #l.items .. ")|r")
	sbar:Show()
end
local ev2 = CreateFrame("Frame")
for _, e in ipairs({ "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "AUCTION_HOUSE_BROWSE_RESULTS_ADDED", "AUCTION_HOUSE_CLOSED", "BAG_UPDATE_DELAYED" }) do pcall(ev2.RegisterEvent, ev2, e) end
ev2:SetScript("OnEvent", function(_, e)
	if e == "AUCTION_HOUSE_CLOSED" then if sbar then sbar:Hide() end; pending = nil
	elseif e == "BAG_UPDATE_DELAYED" then if sbar and sbar:IsShown() then showBar() end
	else C_Timer.After(0.05, function() pcall(openPurchase) end) end
end)

ProfitmancerShopping = {
	toggle = function() toggle() end,
	hide = function() if panel and panel:IsShown() then panel:Hide(); styleBtn(false) end end,
	-- from the recipe EXPORT window: add the reagents as a list (merged into a list of the same name)
	addList = function(l) local i = addList(l); if panel and panel:IsShown() then render() end; say(T.added:format(l.name)); return i end,
	parse = parse, serialize = serialize, setCrafts = setCrafts, setQty = setQty,
}
