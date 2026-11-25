-- Profitmancer: remembers each character's level, professions and known recipes, and exports them for the website (Character tab).
-- The recipes are read when a profession window is open. /pfm export shows a code to paste on the site.
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local FR = GetLocale() == "frFR"
local T = FR and {
	title = "Profitmancer · export des personnages",
	help = "Ctrl+C pour copier, puis colle le code sur le site, onglet Character.",
	none = "aucun personnage enregistré pour l'instant : ouvre une fenêtre de métier.",
	saved = "%d recettes enregistrées (%s).",
	close = "Fermer",
	btn = "Exporter les recettes",
	btnTip = "Copie le code de ce personnage (niveau, métiers et recettes connues) pour l'onglet Character du site Profitmancer. Ouvre chaque métier une fois pour que toutes ses recettes soient dedans.",
} or {
	title = "Profitmancer · character export",
	help = "Ctrl+C to copy, then paste the code on the website, Character tab.",
	none = "no character saved yet: open a profession window.",
	saved = "%d recipes saved (%s).",
	close = "Close",
	btn = "Export recipes",
	btnTip = "Copies this character's code (level, professions and known recipes) for the Character tab of the Profitmancer website. Open each profession once so all its recipes are included.",
}

-- Profession names in the client languages (the skill list also holds weapons, armor, languages...)
local PROF_NAMES = {}
for _, n in ipairs({
	"Alchemy", "Blacksmithing", "Cooking", "Enchanting", "Engineering", "First Aid", "Fishing", "Herbalism", "Leatherworking", "Mining", "Skinning", "Tailoring", "Jewelcrafting", "Inscription",
	"Alchimie", "Forge", "Cuisine", "Enchantement", "Ingénierie", "Secourisme", "Pêche", "Herboristerie", "Travail du cuir", "Minage", "Dépeçage", "Couture", "Joaillerie", "Calligraphie",
	"Alchemie", "Schmiedekunst", "Kochkunst", "Verzauberkunst", "Ingenieurskunst", "Erste Hilfe", "Angeln", "Kräuterkunde", "Lederverarbeitung", "Bergbau", "Kürschnerei", "Schneiderei",
	"Alquimia", "Herrería", "Cocina", "Encantamiento", "Ingeniería", "Primeros auxilios", "Pesca", "Herboristería", "Peletería", "Minería", "Desuello", "Sastrería",
}) do PROF_NAMES[n] = true end

local function db()
	ProfitmancerDB = ProfitmancerDB or {}
	ProfitmancerDB.chars = ProfitmancerDB.chars or {}
	return ProfitmancerDB.chars
end

local function clean(s) return (tostring(s or ""):gsub("[~%^,|\"\\]", "")) end
local DIG = "0123456789abcdefghijklmnopqrstuvwxyz"
local function b36(n)
	n = math.floor(tonumber(n) or 0)
	local s = ""
	repeat
		local r = n % 36
		s = DIG:sub(r + 1, r + 1) .. s
		n = (n - r) / 36
	until n == 0
	return s
end

local function me()
	local name, realm = UnitName("player"), GetRealmName and GetRealmName() or ""
	local key = clean(name) .. "-" .. clean(realm)
	local C = db()
	local c = C[key] or { p = {} }
	C[key] = c
	c.n, c.r = clean(name), clean(realm)
	c.c = select(2, UnitClass("player")) or ""
	local f = UnitFactionGroup("player")
	c.f = f == "Alliance" and "A" or f == "Horde" and "H" or "N"
	c.l = UnitLevel("player") or c.l or 1
	c.rs = ProfitmancerRuleset and ProfitmancerRuleset() or c.rs
	c.p = c.p or {}
	return c, key
end

local function prof(c, name, rank, max)
	name = clean(name)
	if name == "" then return nil end
	local p = c.p[name] or {}
	c.p[name] = p
	if rank then p.k = rank end
	if max then p.m = max end
	return p
end

-- The export code: PFM1~name~realm~class~faction~level~time~profession^rank^max^itemIds^spellIds~...
local function code(c)
	local parts = { "PFM1", c.n, c.r, c.c or "", c.f or "N", tostring(c.l or 1), tostring(c.t or 0) }
	local names = {}
	for n in pairs(c.p) do names[#names + 1] = n end
	table.sort(names)
	for _, n in ipairs(names) do
		local p, ids, sps = c.p[n], {}, {}
		for id in pairs(p.i or {}) do ids[#ids + 1] = id end
		for id in pairs(p.s or {}) do sps[#sps + 1] = id end
		table.sort(ids); table.sort(sps)
		for i, v in ipairs(ids) do ids[i] = b36(v) end
		for i, v in ipairs(sps) do sps[i] = b36(v) end
		parts[#parts + 1] = table.concat({ n, tostring(p.k or 0), tostring(p.m or 0), table.concat(ids, ","), table.concat(sps, ",") }, "^")
	end
	return table.concat(parts, "~")
end

local function finish(c)
	c.t = time()
	c.code = code(c) -- also kept in the saved file, so the site can read every character from SavedVariables\Profitmancer.lua
end

-- ——— Level and profession ranks (no window needed) ———
local function scanSkills()
	local c = me()
	if GetProfessions and GetProfessionInfo then
		for _, i in pairs({ GetProfessions() }) do
			if i then
				local ok, name, _, rank, max = pcall(GetProfessionInfo, i)
				if ok and name then prof(c, name, rank, max) end
			end
		end
	end
	if GetNumSkillLines and GetSkillLineInfo then
		local ok, n = pcall(GetNumSkillLines)
		for i = 1, (ok and n or 0) do
			local name, header, _, rank, _, _, max = GetSkillLineInfo(i)
			if not header and name and PROF_NAMES[name] then prof(c, name, rank, max) end
		end
	end
	finish(c)
end

-- ——— Known recipes of the open profession window ———
local function linked()
	if C_TradeSkillUI and C_TradeSkillUI.IsTradeSkillLinked then
		local ok, v = pcall(C_TradeSkillUI.IsTradeSkillLinked); if ok and v then return true end
	end
	if C_TradeSkillUI and C_TradeSkillUI.IsTradeSkillGuild then
		local ok, v = pcall(C_TradeSkillUI.IsTradeSkillGuild); if ok and v then return true end
	end
	if IsTradeSkillLinked then
		local ok, v = pcall(IsTradeSkillLinked); if ok and v then return true end
	end
	return false
end

local function addLink(p, link)
	if not link then return false end
	local item = link:match("item:(%d+)")
	if item then p.i = p.i or {}; p.i[tonumber(item)] = true; return true end
	local sp = link:match("enchant:(%d+)") or link:match("spell:(%d+)")
	if sp then p.s = p.s or {}; p.s[tonumber(sp)] = true; return true end
	return false
end

local function count(p)
	local n = 0
	for _ in pairs(p.i or {}) do n = n + 1 end
	for _ in pairs(p.s or {}) do n = n + 1 end
	return n
end

local lastMsg = {}
local function report(p, name)
	local n = count(p)
	if lastMsg[name] ~= n then
		lastMsg[name] = n
		print("|cffb48cffProfitmancer|r: " .. T.saved:format(n, name))
	end
end

-- Classic profession window (every profession but Enchanting)
local function scanTradeClassic()
	if not (GetTradeSkillLine and GetNumTradeSkills and GetTradeSkillInfo) then return false end
	local name, rank, max = GetTradeSkillLine()
	if not name or name == "UNKNOWN" or linked() then return false end
	local c = me()
	local p = prof(c, name, rank, max)
	if not p then return false end
	for i = 1, GetNumTradeSkills() or 0 do
		local _, kind = GetTradeSkillInfo(i)
		if kind and kind ~= "header" and kind ~= "subheader" then
			local ok = GetTradeSkillItemLink and addLink(p, GetTradeSkillItemLink(i))
			if not ok and GetTradeSkillRecipeLink then addLink(p, GetTradeSkillRecipeLink(i)) end
		end
	end
	finish(c); report(p, name)
	return true
end

-- Classic Enchanting window ("craft" frame)
local function scanCraftClassic()
	if not (GetNumCrafts and GetCraftInfo) then return false end
	local name, rank, max
	if GetCraftDisplaySkillLine then name, rank, max = GetCraftDisplaySkillLine() end
	if not name and GetCraftSkillLine then name, rank, max = GetCraftSkillLine(1) end
	if not name or name == "UNKNOWN" then return false end
	local c = me()
	local p = prof(c, name, rank, max)
	if not p then return false end
	for i = 1, GetNumCrafts() or 0 do
		local _, _, kind = GetCraftInfo(i)
		if kind ~= "header" then
			local ok = GetCraftItemLink and addLink(p, GetCraftItemLink(i))
			if not ok and GetCraftRecipeLink then addLink(p, GetCraftRecipeLink(i)) end
		end
	end
	finish(c); report(p, name)
	return true
end

-- Modern profession window (C_TradeSkillUI)
local function scanTradeModern()
	local U = C_TradeSkillUI
	if not (U and U.GetAllRecipeIDs and U.GetRecipeInfo) or linked() then return false end
	local name, rank, max
	if U.GetBaseProfessionInfo then
		local ok, info = pcall(U.GetBaseProfessionInfo)
		if ok and info then name, rank, max = info.professionName, info.skillLevel, info.maxSkillLevel end
	end
	if not name and U.GetTradeSkillLine then
		local ok, _, n, r, m = pcall(U.GetTradeSkillLine)
		if ok then name, rank, max = n, r, m end
	end
	if not name then return false end
	local c = me()
	local p = prof(c, name, rank, max)
	if not p then return false end
	for _, rid in ipairs(U.GetAllRecipeIDs() or {}) do
		local info = U.GetRecipeInfo(rid)
		if info and info.learned then
			local item
			if U.GetRecipeOutputItemData then
				local ok, out = pcall(U.GetRecipeOutputItemData, rid)
				item = ok and out and out.itemID
			end
			if not item and U.GetRecipeItemLink then
				local ok, link = pcall(U.GetRecipeItemLink, rid)
				item = ok and link and tonumber(link:match("item:(%d+)"))
			end
			if item then p.i = p.i or {}; p.i[item] = true end
			p.s = p.s or {}; p.s[rid] = true
		end
	end
	finish(c); report(p, name)
	return true
end

local pending = false
local function scanWindow(kind)
	if pending then return end
	pending = true
	C_Timer.After(2, function() -- the list updates often while crafting: read it at most every 2 s
		pending = false
		if kind == "craft" then pcall(scanCraftClassic)
		else
			local ok, done = pcall(scanTradeClassic)
			if not (ok and done) then pcall(scanTradeModern) end
		end
	end)
end

-- ——— Export window ———
local win
local function export(onlyMe)
	scanSkills()
	local codes = {}
	if onlyMe then local c = me(); finish(c); codes[1] = c.code
	else for _, c in pairs(db()) do if c.code then codes[#codes + 1] = c.code end end end
	if #codes == 0 then print("|cffb48cffProfitmancer|r: " .. T.none) return end
	if not win then
		win = CreateFrame("Frame", "ProfitmancerExport", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
		win:SetSize(520, 130); win:SetPoint("CENTER"); win:SetFrameStrata("DIALOG")
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
		e:SetScript("OnTextChanged", function(self, user) if user then self:SetText(win.code or ""); self:HighlightText() end end)
		e:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
		win.edit = e
		local b = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
		b:SetSize(100, 22); b:SetPoint("BOTTOM", 0, 16); b:SetText(T.close); b:SetScript("OnClick", function() win:Hide() end)
		tinsert(UISpecialFrames, "ProfitmancerExport")
	end
	win.code = table.concat(codes, " ")
	win:Show()
	win.edit:SetText(win.code); win.edit:SetFocus(); win.edit:HighlightText(); win.edit:SetCursorPosition(0); win.edit:HighlightText()
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_LEVEL_UP", "SKILL_LINES_CHANGED", "TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE", "TRADE_SKILL_LIST_UPDATE", "NEW_RECIPE_LEARNED", "CRAFT_SHOW", "CRAFT_UPDATE" }) do
	pcall(ev.RegisterEvent, ev, e)
end
local skillTimer = false
ev:SetScript("OnEvent", function(_, e)
	if e == "CRAFT_SHOW" or e == "CRAFT_UPDATE" then scanWindow("craft")
	elseif e:find("^TRADE_SKILL") or e == "NEW_RECIPE_LEARNED" then scanWindow("trade")
	elseif not skillTimer then
		skillTimer = true
		C_Timer.After(e == "PLAYER_LOGIN" and 3 or 1, function() skillTimer = false; pcall(scanSkills) end)
	end
end)

-- ——— "Export" button on the profession window: read its recipes now, then show this character's code ———
local profBtn = {}
local function scanNow()
	pcall(scanCraftClassic)
	local ok, done = pcall(scanTradeClassic)
	if not (ok and done) then pcall(scanTradeModern) end
end
local function addProfButton()
	for _, name in ipairs({ "ProfessionsFrame", "TradeSkillFrame", "CraftFrame" }) do
		local f = _G[name]
		if f and not profBtn[f] then
			local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
			b:SetSize(170, 22); b:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", -4, -2)
			b:SetText("|cffb48cffProfitmancer|r · " .. T.btn)
			b:SetScript("OnClick", function() scanNow(); export(true) end)
			b:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:AddLine("Profitmancer", 0.71, 0.55, 1)
				GameTooltip:AddLine(T.btnTip, 1, 1, 1, true)
				GameTooltip:Show()
			end)
			b:SetScript("OnLeave", function() GameTooltip:Hide() end)
			profBtn[f] = b
		end
	end
	for _, b in pairs(profBtn) do b:SetShown(not ProfitmancerDB.charBtnOff) end
end
local evb = CreateFrame("Frame")
for _, e in ipairs({ "TRADE_SKILL_SHOW", "CRAFT_SHOW" }) do pcall(evb.RegisterEvent, evb, e) end
evb:SetScript("OnEvent", function() C_Timer.After(0, function() pcall(addProfButton) end) end)

ProfitmancerChar = { refreshButtons = function() pcall(addProfButton) end, export = export, scan = scanSkills, code = function() local c = me(); return code(c) end }
