-- Profitmancer: "Export" button on the profession window. Turns the selected recipe into an Auctionator shopping list
-- (Auctionator > Shopping > Import): the reagents you still need for the number of crafts in the window's quantity box.
-- Reagents sold by a vendor are left out of the list and named in the window instead.
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local FR = GetLocale() == "frFR"
local T = FR and {
	btn = "Exporter", tip = "Copie les composants de cette recette en liste de courses Auctionator (Auctionator > Achats > Importer), pour le nombre de crafts indiqué en bas (1 si vide), moins ce que tu as déjà dans tes sacs.",
	title = "Profitmancer · liste de courses Auctionator", help = "Ctrl+C pour copier, puis Auctionator > onglet Achats (Shopping) > Importer, et colle.",
	vendor = "Plus cher à l'HV que chez un PNJ :", vline = "%s x%d : HV %s vs PNJ %s (+%s au total)", all = "Tu as déjà tous les composants à acheter à l'HV pour %d craft(s).", none = "Sélectionne d'abord une recette.",
	close = "Fermer", addList = "Ajouter à mes courses", sent = "Envoyé à ta liste de courses HV", sentHint = "Maj+clic sur Exporter : copier pour Auctionator",
} or {
	btn = "Export", tip = "Copies this recipe's reagents as an Auctionator shopping list (Auctionator > Shopping > Import), for the number of crafts in the box below (1 if empty), minus what is already in your bags.",
	title = "Profitmancer · Auctionator shopping list", help = "Ctrl+C to copy, then Auctionator > Shopping tab > Import, and paste.",
	vendor = "More expensive at the AH than at a vendor:", vline = "%s x%d: AH %s vs vendor %s (+%s total)", all = "You already have every AH reagent for %d craft(s).", none = "Select a recipe first.",
	close = "Close", addList = "Add to my shopping", sent = "Sent to your AH shopping list", sentHint = "Shift+click Export: copy for Auctionator",
}
local function say(s) print("|cffb48cffProfitmancer|r: " .. s) end
local function clean(s) return (tostring(s or ""):gsub("[%^;\"]", "")) end
local function faction() local f = UnitFactionGroup("player"); return f == "Alliance" and "A" or "H" end
local function isVendor(id)
	local S = ProfitmancerStatic
	return id and S and S.vend and S.vend[faction()] and S.vend[faction()][id] ~= nil
end
local function idOf(link) return link and tonumber(link:match("item:(%d+)")) end

-- Number of crafts typed in the window's quantity box (1 when empty or 0)
local function crafts()
	for _, n in ipairs({ "TradeSkillInputBox", "CraftInputBox" }) do
		local b = _G[n]
		if b and b.GetNumber then local v = b:GetNumber(); if v and v > 0 then return v end end
	end
	local pf = ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.CreateMultipleInputBox
	if pf and pf.GetValue then local ok, v = pcall(pf.GetValue, pf); if ok and v and v > 0 then return v end end
	return 1
end

-- The selected recipe: name and reagents { name, id, perCraft, have }
local function selected()
	-- classic profession window
	if GetTradeSkillSelectionIndex and GetTradeSkillNumReagents and TradeSkillFrame and TradeSkillFrame:IsShown() then
		local i = GetTradeSkillSelectionIndex()
		if i and i > 0 then
			local name, kind = GetTradeSkillInfo(i)
			if name and kind ~= "header" and kind ~= "subheader" then
				local list = {}
				for r = 1, GetTradeSkillNumReagents(i) or 0 do
					local rn, _, need, have = GetTradeSkillReagentInfo(i, r)
					local id = GetTradeSkillReagentItemLink and idOf(GetTradeSkillReagentItemLink(i, r))
					if rn and need then list[#list + 1] = { rn, id, need, have or 0 } end
				end
				return name, list
			end
		end
	end
	-- classic Enchanting window
	if GetCraftSelectionIndex and GetCraftNumReagents and CraftFrame and CraftFrame:IsShown() then
		local i = GetCraftSelectionIndex()
		if i and i > 0 then
			local name = GetCraftInfo(i)
			local list = {}
			for r = 1, GetCraftNumReagents(i) or 0 do
				local rn, _, need, have = GetCraftReagentInfo(i, r)
				local id = GetCraftReagentItemLink and idOf(GetCraftReagentItemLink(i, r))
				if rn and need then list[#list + 1] = { rn, id, need, have or 0 } end
			end
			if name then return name, list end
		end
	end
	-- modern profession window
	local U = C_TradeSkillUI
	local form = ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.SchematicForm
	if U and U.GetRecipeSchematic and form and form.GetRecipeInfo then
		local ok, info = pcall(form.GetRecipeInfo, form)
		if ok and info and info.recipeID then
			local sch = U.GetRecipeSchematic(info.recipeID, false)
			local list = {}
			for _, slot in ipairs(sch and sch.reagentSlotSchematics or {}) do
				local r = slot.reagents and slot.reagents[1]
				if r and r.itemID and (slot.reagentType == nil or slot.reagentType == 1 or (Enum and Enum.CraftingReagentType and slot.reagentType == Enum.CraftingReagentType.Basic)) then
					local rn = GetItemInfo(r.itemID) or ("item " .. r.itemID)
					local have = (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(r.itemID)) or (GetItemCount and GetItemCount(r.itemID)) or 0
					list[#list + 1] = { rn, r.itemID, slot.quantityRequired or 1, have }
				end
			end
			return info.name or (sch and sch.name), list
		end
	end
	return nil
end

-- ——— Copy window ———
local win
local function show(text, note, list)
	if not win then
		win = CreateFrame("Frame", "ProfitmancerShopExport", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
		win:SetSize(520, 150); win:SetPoint("CENTER", 0, 140); win:SetFrameStrata("DIALOG")
		win:EnableMouse(true); win:SetMovable(true); win:RegisterForDrag("LeftButton")
		win:SetScript("OnDragStart", win.StartMoving); win:SetScript("OnDragStop", win.StopMovingOrSizing)
		if win.SetBackdrop then
			win:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } })
		end
		local t = win:CreateFontString(nil, "OVERLAY", "GameFontNormal"); t:SetPoint("TOP", 0, -18); t:SetText(T.title)
		local h = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); h:SetPoint("TOP", 0, -38); h:SetText(T.help)
		local e = CreateFrame("EditBox", nil, win, "InputBoxTemplate")
		e:SetSize(460, 24); e:SetPoint("TOP", 0, -60); e:SetAutoFocus(true); e:SetMaxLetters(0)
		e:SetScript("OnEscapePressed", function() win:Hide() end)
		e:SetScript("OnTextChanged", function(self, user) if user then self:SetText(win.text or ""); self:HighlightText() end end)
		e:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
		win.edit = e
		win.note = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); win.note:SetPoint("TOP", 0, -92); win.note:SetWidth(470); win.note:SetJustifyH("LEFT")
		local b = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
		b:SetSize(100, 22); b:SetPoint("BOTTOMLEFT", win, "BOTTOM", 6, 14); b:SetText(T.close); b:SetScript("OnClick", function() win:Hide() end)
		-- straight into the Profitmancer shopping lists (auction house > Shopping button)
		local a = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
		a:SetSize(170, 22); a:SetPoint("BOTTOMRIGHT", win, "BOTTOM", -6, 14); a:SetText("|cffb48cff" .. T.addList .. "|r")
		a:SetScript("OnClick", function() if win.list and ProfitmancerShopping then ProfitmancerShopping.addList(win.list) end; win:Hide() end)
		win.add = a
		tinsert(UISpecialFrames, "ProfitmancerShopExport")
	end
	win.text, win.list = text, list
	win.add:SetShown(list ~= nil and ProfitmancerShopping ~= nil)
	win.note:SetText(note or "")
	win:SetHeight(150 + ((note and note ~= "") and (win.note:GetStringHeight() or 0) + 8 or 0))
	win:Show()
	win.edit:SetText(text); win.edit:SetFocus(); win.edit:SetCursorPosition(0); win.edit:HighlightText()
end

-- ——— Pop-up in the middle of the screen, same look as the craft cooldown notification; fades by itself (click to close) ———
local pop
local function popup(listName, note)
	if not pop then
		pop = CreateFrame("Button", "ProfitmancerShopSent", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
		pop:SetSize(330, 66); pop:SetPoint("CENTER", 0, 120); pop:SetFrameStrata("FULLSCREEN_DIALOG"); pop:SetClampedToScreen(true)
		if pop.SetBackdrop then
			pop:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
			pop:SetBackdropColor(0.07, 0.055, 0.04, 0.95); pop:SetBackdropBorderColor(1, 0.82, 0.2)
		end
		pop.icon = pop:CreateTexture(nil, "ARTWORK"); pop.icon:SetSize(42, 42); pop.icon:SetPoint("LEFT", 12, 0)
		pop.icon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
		local ig = pop:CreateTexture(nil, "OVERLAY"); ig:SetTexture("Interface\\Buttons\\UI-ActionButton-Border"); ig:SetBlendMode("ADD"); ig:SetVertexColor(0.24, 0.77, 0.43)
		ig:SetPoint("CENTER", pop.icon, "CENTER"); ig:SetSize(78, 78)
		pop.title = pop:CreateFontString(nil, "OVERLAY", "GameFontNormal"); pop.title:SetPoint("TOPLEFT", pop.icon, "TOPRIGHT", 10, -2); pop.title:SetPoint("RIGHT", -10, 0); pop.title:SetJustifyH("LEFT")
		pop.text = pop:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); pop.text:SetPoint("TOPLEFT", pop.title, "BOTTOMLEFT", 0, -4); pop.text:SetPoint("RIGHT", -10, 0); pop.text:SetJustifyH("LEFT"); pop.text:SetWordWrap(false)
		pop:SetScript("OnClick", function(self) self:Hide() end)
		pop:SetScript("OnEnter", function(self) self.hold = true; self:SetAlpha(1) end)
		pop:SetScript("OnLeave", function(self) self.hold = false end)
		pop:SetScript("OnUpdate", function(self, el)
			if self.hold then return end
			self.t = (self.t or 0) + el
			if self.t < 0.3 then self:SetAlpha(self.t / 0.3)
			elseif self.t > self.life then
				self:SetAlpha(math.max(0, 1 - (self.t - self.life) / 0.8)); if self.t > self.life + 0.8 then self:Hide() end
			end
		end)
	end
	pop.title:SetText(T.sent)
	pop.text:SetText(listName)
	-- vendor warning (red) under the name: taller window
	local extra = note ~= "" and note or nil
	if extra then
		pop.note = pop.note or pop:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		pop.note:ClearAllPoints(); pop.note:SetPoint("TOPLEFT", pop.icon, "BOTTOMLEFT", 0, -10); pop.note:SetWidth(300); pop.note:SetJustifyH("LEFT")
		pop.note:SetText(extra); pop.note:Show()
		pop:SetHeight(66 + 14 + pop.note:GetStringHeight())
	else
		if pop.note then pop.note:Hide() end
		pop:SetHeight(66)
	end
	pop.t, pop.life, pop.hold = 0, extra and 7 or 3.5, false
	pop:SetAlpha(0); pop:Show()
end
local export
local waits = 0
local wantWindow
function export(retry)
	local name, list = selected()
	if not name then say(T.none) return end
	-- the game may not know some reagent names yet ("item 1234"): ask for them and try again a moment later (up to ~2 s)
	if retry ~= true then waits = 0 end
	local missing = false
	for _, r in ipairs(list or {}) do
		if r[2] and type(r[1]) == "string" and r[1]:match("^item %d+$") then
			missing = true
			if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, r[2]) end
		end
	end
	if missing and waits < 8 then waits = waits + 1; C_Timer.After(0.25, function() export(true) end) return end
	local n = crafts()
	-- every reagent goes in the list (vendor ones too); those cheaper at a vendor are flagged in red with the difference
	local terms, vend, items = {}, {}, {}
	local A = ProfitmancerAPI
	local fmt = A and A.money or function(c) return tostring(c) end
	for _, r in ipairs(list or {}) do
		local rn, id, per, have = r[1], r[2], r[3], r[4]
		local buy = per * n - (have or 0)
		-- the Profitmancer list keeps every reagent with its amount per craft: its "Crafts" box at the auction house
		-- scales them all, and what is already in the bags is counted when searching
		items[#items + 1] = { term = clean(rn), id = id, qty = per * n, per = per, exact = true }
		if buy > 0 then
			terms[#terms + 1] = "\"" .. clean(rn) .. "\";;0;0;0;0;0;0;0;0;;#;;" .. buy
			local v = id and A and A.vendor and A.vendor(id)
			local a = id and A and A.ah and A.ah(id)
			if v and a and a > v then
				vend[#vend + 1] = T.vline:format(rn, buy, fmt(a), fmt(v), fmt((a - v) * buy))
			end
		end
	end
	local note = #vend > 0 and ("|cffff5a4a" .. T.vendor .. "\n" .. table.concat(vend, "\n") .. "|r") or ""
	if #terms == 0 then say(T.all:format(n) .. (note ~= "" and (" " .. note) or "")) return end
	local lname = clean("Profitmancer " .. name .. (n > 1 and (" x" .. n) or ""))
	local l = { name = clean("Profitmancer " .. name), items = items, crafts = n }
	if ProfitmancerShopping and not wantWindow then
		-- straight into the AH shopping lists, no window
		ProfitmancerShopping.addList(l)
		popup(l.name, note)
	else
		show(lname .. "^" .. table.concat(terms, "^"), note, l)
	end
end

-- ——— The button, at the top right of the recipe details ———
local made = {}
local function addButton()
	for _, fname in ipairs({ "TradeSkillFrame", "CraftFrame", "ProfessionsFrame" }) do
		local f = _G[fname]
		if f and not made[f] then
			local b = CreateFrame("Button", "ProfitmancerRecipeExport" .. fname, f, "UIPanelButtonTemplate")
			b:SetSize(100, 22)
			-- Placed in proportion to the window (so the UI scale doesn't matter): right of the recipe name, under the star
			-- On the "Reagents:" line, at its right end: that line has free space whatever the recipe's description
			local label
			local lastLook = 0
			local function findLabel()
				if label and label:IsShown() then return label end
				if GetTime() - lastLook < 2 then return label end -- not found: look again at most every 2 s
				lastLook = GetTime()
				label = _G.TradeSkillReagentLabel or _G.CraftReagentLabel
				if label then return label end
				local want = ((SPELL_REAGENTS or "Reagents:"):gsub("[%s:]+$", "")):lower()
				local function walk(x, d)
					if label or d > 8 then return end
					for _, r in ipairs({ x:GetRegions() }) do
						if r.GetObjectType and r:GetObjectType() == "FontString" then
							local t = r:GetText()
							t = t and t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
							if t and (t:gsub("[%s:]+$", "")):lower() == want then label = r return end
						end
					end
					for _, c in ipairs({ x:GetChildren() }) do walk(c, d + 1) end
				end
				walk(f, 0)
				return label
			end
			-- Best spot: the bottom row of the recipe details, left of the "Track Recipe" box. That row never holds text,
			-- whatever the profession or the length of the recipe's description and reagents.
			local track
			local lastTrack = 0
			local function findTrack()
				if track and track:IsShown() then return track end
				if GetTime() - lastTrack < 2 then return nil end
				lastTrack = GetTime()
				local cp = rawget(f, "CraftingPage")
				local sf = type(cp) == "table" and rawget(cp, "SchematicForm")
				local t = type(sf) == "table" and rawget(sf, "TrackRecipeCheckbox") or nil
				if not (type(t) == "table" and t.IsShown) then
					-- any check box low in the window's right half (the "Track Recipe" one)
					t = nil
					local fr, fb, fl = f:GetRight(), f:GetBottom(), f:GetLeft()
					local function walk(x, d)
						if d > 7 or not fr then return end
						for _, c in ipairs({ x:GetChildren() }) do
							if c ~= b and c.GetObjectType and c:GetObjectType() == "CheckButton" and c:IsShown() then
								local cl, cb = c:GetLeft(), c:GetBottom()
								if cl and cb and cl > (fl + fr) / 2 and cb - fb < 90 and (not t or cl > (t:GetLeft() or 0)) then t = c end
							end
							walk(c, d + 1)
						end
					end
					walk(f, 0)
				end
				track = t
				return (track and track:IsShown()) and track or nil
			end
			local lastKey
			local function place()
				if ProfitmancerDB.exportOff then b:Hide(); lastKey = nil return end
				local tr = findTrack()
				if tr then
					local key = "T" .. math.floor(tr:GetLeft() or 0) .. ":" .. math.floor(tr:GetBottom() or 0)
					if key ~= lastKey then
						lastKey = key
						b:SetFrameStrata(f:GetFrameStrata())
						b:SetFrameLevel(math.min(f:GetFrameLevel() + 500, 9000))
						b:ClearAllPoints()
						b:SetPoint("RIGHT", tr, "LEFT", -14, 0)
					end
					b:Show()
					return
				end
				local l = findLabel()
				local fr, ll = f:GetRight(), l and l:IsShown() and l:GetLeft()
				local key
				if l and fr and ll and l:GetTop() then key = "L" .. math.floor((fr - 56 - b:GetWidth()) - ll) .. ":" .. math.floor(l:GetTop())
				else key = "F" .. math.floor(f:GetWidth() or 0) .. ":" .. math.floor(f:GetHeight() or 0) end
				if key == lastKey then return end -- nothing moved: leave the button alone
				lastKey = key
				-- above the recipe details panel, which sits on its own higher layer
				b:SetFrameStrata(f:GetFrameStrata())
				b:SetFrameLevel(math.min(f:GetFrameLevel() + 500, 9000))
				b:ClearAllPoints()
				if key:sub(1, 1) == "L" then
					-- right edge of the button 56 px from the window's right edge, vertically centred on the label
					b:SetPoint("LEFT", l, "LEFT", (fr - 56 - b:GetWidth()) - ll, 0)
				else
					local w, h = f:GetWidth(), f:GetHeight()
					if w and h and w > 200 and h > 200 then b:SetPoint("CENTER", f, "TOPLEFT", w * 0.868, -h * 0.265)
					else b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -56, -176) end
				end
				b:SetShown(not l or l:IsShown())
			end
			-- the label moves with the description of the selected recipe: follow it
			local acc = 0
			local drv = CreateFrame("Frame", nil, f)
			drv:SetScript("OnUpdate", function(_, dt) acc = acc + dt; if acc > 0.3 then acc = 0; pcall(place) end end)
			place()
			f:HookScript("OnSizeChanged", place)
			f:HookScript("OnShow", place)
			b:SetText(T.btn) -- the standard red button with gold text, like Auctionator's Export
			b:SetScript("OnClick", function() wantWindow = IsShiftKeyDown(); export() end)
			b:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:AddLine("Profitmancer · Auctionator", 0.71, 0.55, 1)
				GameTooltip:AddLine(T.tip, 1, 1, 1, true)
				GameTooltip:Show()
			end)
			b:SetScript("OnLeave", function() GameTooltip:Hide() end)
			made[f] = b
			b:Show()
		end
	end
end
local ev = CreateFrame("Frame")
for _, e in ipairs({ "TRADE_SKILL_SHOW", "CRAFT_SHOW" }) do pcall(ev.RegisterEvent, ev, e) end
local warned
ev:SetScript("OnEvent", function()
	C_Timer.After(0, function()
		local ok, err = pcall(addButton)
		if not ok and not warned then warned = true; print("|cffb48cffProfitmancer|r: Export button error: " .. tostring(err)) end
	end)
end)

ProfitmancerShop = { export = export }
