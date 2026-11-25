-- Profitmancer: profit or loss of each recipe, right in the list of the profession window (green = profit, red = loss).
-- The rows are found by their text (the recipe names the game gives), so it works with the window's own layout.
local function api() return ProfitmancerAPI end

local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local function plain(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%s*%[%d+%]$", ""):gsub("^%s+", ""):gsub("%s+$", "")) end

-- recipe name -> product item id: from the profession window's API when there is one, and from the item names of every recipe Profitmancer knows
local staticMap, staticAt = {}, 0
local function addStatic(m)
	local a = ProfitmancerAPI
	if a and a.products and (GetTime() - staticAt > 5 or next(staticMap) == nil) then
		staticAt = GetTime()
		for _, id in ipairs(a.products()) do
			local n = GetItemInfo(id)
			if n then staticMap[n] = id
			elseif C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
		end
	end
	for n, id in pairs(staticMap) do if m[n] == nil then m[n] = id end end
end
local function recipeMap()
	local m = {}
	if GetNumTradeSkills and GetTradeSkillInfo and GetTradeSkillItemLink then
		for i = 1, GetNumTradeSkills() or 0 do
			local name, kind = GetTradeSkillInfo(i)
			if name and kind ~= "header" and kind ~= "subheader" then
				local link = GetTradeSkillItemLink(i)
				local id = link and tonumber(link:match("item:(%d+)"))
				if id then m[name] = id end
			end
		end
	end
	if GetNumCrafts and GetCraftInfo and GetCraftItemLink and CraftFrame and CraftFrame:IsShown() then
		for i = 1, GetNumCrafts() or 0 do
			local name, _, kind = GetCraftInfo(i)
			if name and kind ~= "header" then
				local link = GetCraftItemLink(i)
				local id = link and tonumber(link:match("item:(%d+)"))
				if id then m[name] = id end
			end
		end
	end
	local U = C_TradeSkillUI
	if U and U.GetAllRecipeIDs and U.GetRecipeInfo then
		local ok, ids = pcall(U.GetAllRecipeIDs)
		for _, rid in ipairs(ok and ids or {}) do
			local info = U.GetRecipeInfo(rid)
			if info and info.name and m[info.name] == nil then
				local item
				if U.GetRecipeOutputItemData then local ok2, out = pcall(U.GetRecipeOutputItemData, rid); item = ok2 and out and out.itemID end
				if not item and U.GetRecipeSchematic then local ok3, sch = pcall(U.GetRecipeSchematic, rid, false); item = ok3 and sch and sch.outputItemID end
				if item then m[info.name] = item end
			end
		end
	end
	addStatic(m)
	-- Recipes named differently from what they make (Smelt Copper -> Copper Bar, Transmute: Iron to Gold -> Gold Bar)
	m.__alias = function(name)
		local x = name:match("^Smelt (.+)$")
		if x then return m[x .. " Bar"] or m[x] end
		local b = name:match("^Transmute: .- to (.+)$") or name:match("^Transmute: (.+)$")
		if b then return m[b .. " Bar"] or m["Essence of " .. b] or m[b] end
	end
	return m
end
local function lookup(m, name)
	local id = m[name]
	if id == nil and m.__alias and type(id) ~= "number" then id = m.__alias(name) end
	return type(id) == "number" and id or nil
end

-- every visible frame of the window that shows one of these names
local rowsCache, lastScan = {}, 0
local function scan(root, names)
	local found = {}
	local function walk(f, depth)
		if depth > 9 or not f.IsShown or not f:IsShown() then return end
		local h = f.GetHeight and f:GetHeight() or 0
		if f.GetRegions and h > 8 and h <= 40 then -- list rows only (not the big recipe title in the details panel)
			for _, r in ipairs({ f:GetRegions() }) do
				if r.GetObjectType and r:GetObjectType() == "FontString" and r ~= rawget(f, "pfmProfit") then
					local t = r:GetText()
					if t and lookup(names, plain(t)) then found[#found + 1] = { f, r } break end
				end
			end
		end
		for _, c in ipairs({ f:GetChildren() }) do walk(c, depth + 1) end
	end
	walk(root, 0)
	return found
end

-- Short amount with the game's coin icons, two units at most: +2[g]80[s] / -20[s]50[c] / +150[g]; the exact amount is in the recipe's tooltip
local CG = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:1:0|t"
local CS = "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:1:0|t"
local CC = "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:1:0|t"
local function money(c, col)
	local sign = c < 0 and "-" or "+"
	c = math.floor(math.abs(c) + 0.5)
	local g, s, k = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
	local parts = {}
	local function add(n, icon) parts[#parts + 1] = col .. n .. "|r" .. icon end
	if g >= 100 then add(g, CG)
	elseif g > 0 then add(g, CG); if s > 0 then add(s, CS) end
	elseif s > 0 then add(s, CS); if k > 0 then add(k, CC) end
	else add(k, CC) end
	return col .. sign .. "|r" .. table.concat(parts, " ")
end

-- Caches: the name map is rebuilt when the window's list changes (or every 15 s), profits every 30 s (prices only change on a reload),
-- and the rows are looked for again only inside the list that holds them once it is known.
local mapCache, mapAt, mapDirty = nil, 0, true
local profitCache, profitAt = {}, 0
local listParent
local function names()
	if mapDirty or not mapCache or GetTime() - mapAt > 15 then mapCache, mapAt, mapDirty = recipeMap(), GetTime(), false end
	return mapCache
end
local function profitOf(id)
	if GetTime() - profitAt > 30 then profitCache, profitAt = {}, GetTime() end
	local v = profitCache[id]
	if v == nil then
		local a = api()
		v = (a and a.profit(id)) or false
		profitCache[id] = v
	end
	return v or nil
end

-- The game's "[4]" (how many you can craft) on a recipe row: the Count text of the row, or any small "[n]" text in it
local function countOf(f, label)
	local c = rawget(f, "pfmCount")
	if c then return c end
	if c == false and GetTime() - (rawget(f, "pfmCountT") or 0) < 2 then return nil end -- not found: look again every 2 s only
	f.pfmCountT = GetTime()
	c = rawget(f, "Count")
	if not (type(c) == "table" and c.GetText) then
		c = nil
		for _, r in ipairs({ f:GetRegions() }) do
			if r ~= label and r.GetObjectType and r:GetObjectType() == "FontString" and r ~= rawget(f, "pfmProfit") then
				local tx = r:GetText()
				if type(tx) == "string" and tx:match("^%s*%[%d+%]%s*$") then c = r; break end
			end
		end
	end
	f.pfmCount = c or false
	return c
end

-- Current skill in the open profession (read at most once a second)
local skillV, skillAt = nil, 0
local function skillNow()
	if GetTime() - skillAt < 1 then return skillV end
	skillAt, skillV = GetTime(), nil
	local U = C_TradeSkillUI
	if U and U.GetChildProfessionInfo then
		local ok, i = pcall(U.GetChildProfessionInfo)
		if ok and type(i) == "table" and i.skillLevel and i.skillLevel > 0 then skillV = i.skillLevel end
	end
	if not skillV and U and U.GetBaseProfessionInfo then
		local ok, i = pcall(U.GetBaseProfessionInfo)
		if ok and type(i) == "table" and i.skillLevel and i.skillLevel > 0 then skillV = i.skillLevel end
	end
	if not skillV and GetTradeSkillLine then
		local ok, _, rank = pcall(GetTradeSkillLine)
		if ok and rank and rank > 0 then skillV = rank end
	end
	if not skillV and GetCraftDisplaySkillLine then
		local ok, _, rank = pcall(GetCraftDisplaySkillLine)
		if ok and rank and rank > 0 then skillV = rank end
	end
	return skillV
end
-- Chance (%) that crafting the recipe gives a skill point: 100 while orange, then falls to 0 between yellow and grey
local function upChance(id, skill)
	local lv = ProfitmancerLevels and id and ProfitmancerLevels[id]
	if not (lv and skill) then return nil end
	local y, gr = lv[2], lv[4]
	if skill < y then return 100 end
	if skill >= gr or gr <= y then return 0 end
	return math.floor((gr - skill) / (gr - y) * 100 + 0.5)
end
local function pctColor(p)
	if p >= 100 then return "|cffff8040" elseif p >= 50 then return "|cffffff00" else return "|cff40c040" end
end

local function update(root, rescan)
	if not api() then return end
	local m = names()
	if next(m) == nil then return end
	if rescan and GetTime() - lastScan > 1 then
		lastScan = GetTime()
		local within = (listParent and listParent:IsShown()) and listParent or root
		rowsCache = scan(within, m)
		if #rowsCache == 0 and within ~= root then rowsCache = scan(root, m) end
		local p = rowsCache[1] and rowsCache[1][1]:GetParent()
		if p and p ~= root then listParent = p end
	end
	for _, fr in ipairs(rowsCache) do
		local f, label = fr[1], fr[2]
		local cnt = countOf(f, label)
		local ct = cnt and cnt:IsShown() and cnt:GetText() or ""
		local t = label:GetText()
		local sk = skillNow()
		-- cooldown of the recipe (transmutes, Mooncloth...): looked up again when the row changes or once a second,
		-- and the row is redrawn when its state changes (ready, or one more minute gone)
		local now = GetTime()
		if t ~= rawget(f, "pfmT") or now - (rawget(f, "pfmCdAt") or 0) > 1 then
			f.pfmCdAt = now
			local cdl = t and not ProfitmancerDB.cdRowOff and ProfitmancerCooldowns and ProfitmancerCooldowns.leftFor(plain(t)) or nil
			f.pfmCdl = cdl
			f.pfmCdk = cdl and (cdl <= 0 and -1 or math.floor(cdl / 60)) or false
		end
		local cdl, cdk = rawget(f, "pfmCdl"), rawget(f, "pfmCdk")
		-- redraw only when something shown on the row changed (no strings built every frame)
		if t ~= rawget(f, "pfmT") or ct ~= rawget(f, "pfmCt") or sk ~= rawget(f, "pfmSk") or cdk ~= rawget(f, "pfmK") or ProfitmancerDB.optStamp ~= rawget(f, "pfmStamp") or rawget(f, "pfmText") == nil then
			f.pfmT, f.pfmCt, f.pfmSk, f.pfmK, f.pfmStamp, f.pfmText = t, ct, sk, cdk, ProfitmancerDB.optStamp, true
			local id = t and lookup(m, plain(t))
			local fs = rawget(f, "pfmProfit")
			if not fs then
				fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
				fs:SetPoint("RIGHT", f, "RIGHT", -8, 0)
				fs:SetJustifyH("RIGHT")
				f.pfmProfit = fs
			end
			local pr = id and not ProfitmancerDB.rpOff and profitOf(id)
			if pr and ProfitmancerDB.rpMin and pr < ProfitmancerDB.rpMin then pr = nil end -- below the threshold chosen in the options
			-- the recipe name stops before the profit ("Draught of Greater Water Brea...") so they never overlap
			label:SetWordWrap(false)
			local right = f
			local txt = pr and money(pr, pr >= 0 and "|cff1eff00" or "|cffff5a4a") or nil
			if cdl then
				if cdl <= 0 then
					-- cooldown ready: a green tick before the profit
					txt = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12:0:0|t " .. (txt or "")
				else
					-- on cooldown: an hourglass and the time left instead of the profit
					txt = "|TInterface\\Icons\\INV_Misc_PocketWatch_01:12:12:0:0|t |cff9e9e9e" .. ProfitmancerCooldowns.fmtLeft(cdl) .. "|r"
				end
			end
			if txt then
				fs:SetText(txt)
				fs:Show()
				right = fs
			else
				fs:Hide()
			end
			-- chance of a skill point, right after the game's skill-up arrow: ^ 47% Smelt Copper
			local ch = not ProfitmancerDB.chanceOff and upChance(id, sk) or nil
			local arrow = rawget(f, "SkillUps")
			local pf = rawget(f, "pfmChance")
			if not pf then
				pf = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
				f.pfmChance = pf
				-- remember where the game puts the name, to put it back on recipes without a chance
				for i = 1, (label:GetNumPoints() or 0) do
					local p, rel, rp, x, y = label:GetPoint(i)
					if p == "LEFT" or p == "TOPLEFT" or p == "BOTTOMLEFT" then f.pfmLeft = { p, rel, rp, x, y } break end
				end
			end
			local shown = ch and ch > 0 and type(arrow) == "table" and arrow.IsShown and arrow:IsShown()
			label:ClearAllPoints()
			if shown then
				pf:ClearAllPoints(); pf:SetPoint("LEFT", arrow, "RIGHT", 1, 0)
				pf:SetText(pctColor(ch) .. ch .. "%|r"); pf:Show()
				label:SetPoint("LEFT", pf, "RIGHT", 4, 0)
			else
				pf:Hide()
				local L = rawget(f, "pfmLeft")
				if L then label:SetPoint(L[1], L[2], L[3], L[4], L[5]) end
			end
			-- the game's craftable count "[4]" goes between the name and the profit: name [4] ... +4s
			if cnt and ct ~= "" then
				cnt:ClearAllPoints(); cnt:SetPoint("RIGHT", right, right == f and "RIGHT" or "LEFT", right == f and -6 or -5, 0)
				label:SetPoint("RIGHT", cnt, "LEFT", -4, 0)
			else
				label:SetPoint("RIGHT", right, right == f and "RIGHT" or "LEFT", -6, 0)
			end
		end
	end
end

-- Runs only while a profession window is open
local ticker = CreateFrame("Frame")
ticker:Hide()
local acc = 0
-- Every frame: compare the few visible rows' text (cheap, so scrolling updates at once); look for rows again every second
ticker:SetScript("OnUpdate", function(self, dt)
	acc = acc + dt
	local rescan = acc > 1
	if rescan then acc = 0 end
	local any = false
	for _, n in ipairs({ "ProfessionsFrame", "TradeSkillFrame", "CraftFrame" }) do
		local f = _G[n]
		if f and f:IsShown() then any = true; pcall(update, f, rescan) end
	end
	if not any then self:Hide() end
end)
local ev = CreateFrame("Frame")
for _, e in ipairs({ "TRADE_SKILL_SHOW", "CRAFT_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_UPDATE", "CRAFT_UPDATE" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, e)
	mapDirty = true
	if e == "TRADE_SKILL_SHOW" or e == "CRAFT_SHOW" then lastScan = 0; acc = 2; for _, fr in ipairs(rowsCache) do fr[1].pfmText = nil end end
	ticker:Show()
end)

-- /pfm debug recipes: what Profitmancer sees in the open profession window
function ProfitmancerRecipeProfitDebug()
	local f = TradeSkillFrame or CraftFrame or ProfessionsFrame
	local m = recipeMap()
	local n = 0 for _ in pairs(m) do n = n + 1 end
	local rows = f and f:IsShown() and scan(f, m) or {}
	print("|cffb48cffProfitmancer|r debug: window " .. tostring(f and f:GetName()) .. " shown=" .. tostring(f and f:IsShown())
		.. " · API classic=" .. tostring(GetNumTradeSkills ~= nil) .. " modern=" .. tostring(C_TradeSkillUI ~= nil)
		.. " · names known=" .. n .. " · rows found=" .. #rows .. " · reagents label=" .. tostring(_G.TradeSkillReagentLabel ~= nil))
	for i = 1, math.min(3, #rows) do print("   row: " .. tostring(rows[i][2]:GetText()) .. " h=" .. math.floor(rows[i][1]:GetHeight() or 0)) end
end
