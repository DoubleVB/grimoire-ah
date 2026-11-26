-- Profitmancer: crafts with a cooldown (transmutes, Mooncloth, Cured Rugged Hide, Salt Shaker...) for every profession.
-- Remembers each character's cooldowns, shows a short notification when one is ready (never in combat or in an instance),
-- a counter on the minimap button and a "Cooldowns" section in its tooltip with every character.
-- Cooldowns are found three ways: a list of the known ones, the profession window (any recipe seen on cooldown is
-- remembered for the whole account) and the game's spell cooldowns (so they stay right while the window is closed).
local FR = GetLocale() == "frFR"
local T = FR and {
	shared = "Cooldown partagé", title = "Cooldown prêt", titleN = "%d cooldowns prêts", more = " · +%d autre(s)", ready = "prêt", head = "Cooldowns",
	click = "Clic : ouvrir le métier · clic droit : fermer", none = "Aucun cooldown connu. Ouvre tes métiers une fois sur chaque personnage.",
	toastOn = "notifications de cooldowns activées.", toastOff = "notifications de cooldowns désactivées (/pfm cd toast pour les remettre).",
	day = "j", help = "/pfm cd : liste des cooldowns · /pfm cd toast : notifications on/off",
} or {
	shared = "Shared cooldown", title = "Cooldown ready", titleN = "%d cooldowns ready", more = " · +%d more", ready = "ready", head = "Cooldowns",
	click = "Click: open the profession · right-click: close", none = "No cooldown known yet. Open your professions once on each character.",
	toastOn = "cooldown notifications on.", toastOff = "cooldown notifications off (/pfm cd toast to turn them back on).",
	day = "d", help = "/pfm cd: list of cooldowns · /pfm cd toast: notifications on/off",
}
local function say(m) print("|cffb48cffProfitmancer|r: " .. m) end

-- Known crafts with a cooldown: spell (or item) id -> item made, and the shared cooldown group
local KNOWN = {
	[17187] = { out = 12360, group = "transmute" }, -- Transmute: Arcanite
	[11479] = { out = 3577, group = "transmute" },  -- Transmute: Iron to Gold
	[11480] = { out = 6037, group = "transmute" },  -- Transmute: Mithril to Truesilver
	[17559] = { out = 7078, group = "transmute" },  -- Air to Fire
	[17560] = { out = 7076, group = "transmute" },  -- Fire to Earth
	[17561] = { out = 7080, group = "transmute" },  -- Earth to Water
	[17562] = { out = 7082, group = "transmute" },  -- Water to Air
	[17563] = { out = 7080, group = "transmute" },  -- Undeath to Water
	[17564] = { out = 12808, group = "transmute" }, -- Water to Undeath
	[17565] = { out = 7076, group = "transmute" },  -- Life to Earth
	[17566] = { out = 12803, group = "transmute" }, -- Earth to Life
	[25146] = { out = 7068, group = "transmute" },  -- Transmute: Elemental Fire
	[18560] = { out = 14342 },                      -- Mooncloth
	[19047] = { out = 15407 },                      -- Cure Rugged Hide
}
local ITEMS = { [15846] = { out = 15409 } } -- Salt Shaker (an item with a cooldown) -> Refined Deeprock Salt

local GetSpellInfo = GetSpellInfo
local function spellName(id)
	if C_Spell and C_Spell.GetSpellName then local ok, n = pcall(C_Spell.GetSpellName, id); if ok and n then return n end end
	if GetSpellInfo then local ok, n = pcall(GetSpellInfo, id); if ok and n then return n end end
	return nil
end
local function itemName(id) local f = (C_Item and C_Item.GetItemInfo) or GetItemInfo; return id and f and f(id) or nil end
local function spellCD(id)
	local s, d
	if C_Spell and C_Spell.GetSpellCooldown then
		local ok, c = pcall(C_Spell.GetSpellCooldown, id)
		if ok and type(c) == "table" then s, d = c.startTime, c.duration end
	elseif GetSpellCooldown then
		local ok, a, b = pcall(GetSpellCooldown, id); if ok then s, d = a, b end
	end
	if not s then return nil end
	if s > 0 and d and d > 2 then return math.max(0, s + d - GetTime()) end
	return 0
end
local function itemCD(id)
	local f = (C_Container and C_Container.GetItemCooldown) or GetItemCooldown
	if not f then return nil end
	local ok, s, d = pcall(f, id)
	if not ok or not s then return nil end
	if s > 0 and d and d > 2 then return math.max(0, s + d - GetTime()) end
	return 0
end
local function known(id)
	if IsPlayerSpell then local ok, k = pcall(IsPlayerSpell, id); if ok and k then return true end end
	if IsSpellKnown then local ok, k = pcall(IsSpellKnown, id); if ok and k then return true end end
	return false
end
local function count(id) local f = (C_Item and C_Item.GetItemCount) or GetItemCount; return f and f(id) or 0 end

-- ——— Saved data ———
local function charKey() return (UnitName("player") or "?") .. "-" .. (GetRealmName and GetRealmName() or "") end
local function db()
	ProfitmancerDB.cds = ProfitmancerDB.cds or {}
	ProfitmancerDB.cdSpells = ProfitmancerDB.cdSpells or {} -- recipes seen on cooldown (account-wide): id -> item made
	return ProfitmancerDB.cds
end
-- Each character's server type (ruleset): cooldowns of characters on another ruleset are not shown
local function rsOf(ck)
	local R = ProfitmancerDB.cdRs or {}
	local C = ProfitmancerDB.chars and ProfitmancerDB.chars[ck]
	return R[ck] or (type(C) == "table" and C.rs) or nil
end
local function sameRs(ck)
	local cur = ProfitmancerRuleset and ProfitmancerRuleset()
	if not cur then return true end
	if ck == charKey() then ProfitmancerDB.cdRs = ProfitmancerDB.cdRs or {}; ProfitmancerDB.cdRs[ck] = cur; return true end
	-- a character not seen since this was added: unknown ruleset, hidden until it logs in again
	return rsOf(ck) == cur
end
local function mine() local D = db(); local k = charKey(); D[k] = D[k] or {}; sameRs(k); return D[k] end

-- Record one cooldown for this character. Spells of a shared group (transmutes) are kept together.
local function put(id, out, left, group, isItem, prof, trusted)
	local C = mine()
	-- one entry per recipe: the game gives each recipe its own time left (recipes sharing a cooldown show the same one)
	local key = (isItem and "i" or "s") .. id
	local e = C[key] or {}
	C[key] = e
	-- keep the same "ready at" while nothing changed (a ready cooldown stays ready since the same moment: announced once)
	local at = time() + math.floor(left or 0)
	local now = time()
	-- a cooldown never ends early: when the spell API says "ready" while the profession window said otherwise, keep the window's time
	if (left or 0) <= 0 and not trusted and e.readyAt and e.readyAt > now + 60 then left = (e.readyAt - now); at = e.readyAt end
	if not e.readyAt or (left or 0) > 0 and math.abs(at - e.readyAt) > 60 or (left or 0) <= 0 and e.readyAt > now then
		-- a new cooldown started: its length (for the progress bar) is the time left right now
		if (left or 0) > 0 and (not e.readyAt or at > e.readyAt + 60) then e.dur = math.floor(left) end
		e.readyAt = at
	end
	if (left or 0) > (e.dur or 0) then e.dur = math.floor(left) end
	e.cat = group or e.cat
	e.group = nil
	e.prof = prof or e.prof
	e.opts = { [id] = out or (e.opts and e.opts[id]) or true }
	e.isItem = isItem
end

-- What the cooldown is worth now: the most profitable recipe of the group, and its name
local function best(e, opts)
	local P = ProfitmancerAPI
	local bid, bout, bp
	for id, out in pairs(opts or e.opts or {}) do
		local p = P and type(out) == "number" and P.profit(out) or nil
		if not bid or (p and (not bp or p > bp)) then bid, bout, bp = id, out, p end
	end
	local name = (e.isItem and itemName(bid)) or (ProfitmancerDB.cdName and ProfitmancerDB.cdName[bid]) or spellName(bid) or (type(bout) == "number" and itemName(bout)) or ("#" .. tostring(bid))
	local icon = type(bout) == "number" and ((C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(bout)) or (GetItemIcon and GetItemIcon(bout))) or nil
	return name, bp, icon, bid
end

-- Shared cooldowns: the transmutes of one category of the profession window share theirs ("Lesser" ones
-- once an hour, "Greater" ones once a day on WoW Forever). The group is learned from the window, by category.
local function groupOf(id) return (ProfitmancerDB.cdGroup and ProfitmancerDB.cdGroup[id]) or (KNOWN[id] and KNOWN[id].group) or nil end
local function isTransmute(name) return type(name) == "string" and name:lower():find("^transmut") ~= nil end

-- ——— Refresh this character's cooldowns ———
-- Recipes that share a cooldown are learned by watching them: two recipes of one character that go on cooldown together,
-- for the same time, share it (Arcanite and Fire to Earth on WoW Forever; Iron to Gold and Mithril to Truesilver).
local function link()
	ProfitmancerDB.cdLink = ProfitmancerDB.cdLink or {}
	local L, now, on = ProfitmancerDB.cdLink, time(), {}
	for key, e in pairs(mine()) do
		local id = tonumber(key:match("^s(%d+)$"))
		if id and (e.readyAt or 0) - now > 60 then on[#on + 1] = { id = id, e = e } end
	end
	for i = 1, #on do
		for j = i + 1, #on do
			local a, b = on[i], on[j]
			if math.abs(a.e.readyAt - b.e.readyAt) <= 60 and math.abs((a.e.dur or 0) - (b.e.dur or 0)) <= 120 then
				local ra, rb = L[a.id] or a.id, L[b.id] or b.id
				local root = math.min(ra, rb)
				for id, r in pairs(L) do if r == ra or r == rb then L[id] = root end end
				L[a.id], L[b.id] = root, root
			end
		end
	end
end

local function refresh()
	if not ProfitmancerDB then return end
	db()
	-- entries of the first versions (one per group) are replaced by one per recipe
	local C = mine()
	for key in pairs(C) do if not key:match("^[si]%d+$") then C[key] = nil end end
	for id, k in pairs(KNOWN) do
		if known(id) then local l = spellCD(id); if l then put(id, k.out, l, groupOf(id)) end end
	end
	for id, out in pairs(ProfitmancerDB.cdSpells) do
		if not KNOWN[id] and known(id) then local l = spellCD(id); if l then put(id, out, l, groupOf(id)) end end
	end
	for id, k in pairs(ITEMS) do
		if count(id) > 0 then local l = itemCD(id); if l then put(id, k.out, l, nil, true, nil, true) end end
	end
	link()
end

-- From the profession window: every learned recipe on cooldown is remembered (any profession, no list needed)
local lastScan = 0
local function scanProfession()
	if GetTime() - lastScan < 2 then return end
	lastScan = GetTime()
	local U = C_TradeSkillUI
	if U and U.GetAllRecipeIDs and U.GetRecipeCooldown then
		local ok, ids = pcall(U.GetAllRecipeIDs)
		ProfitmancerDB.cdGroup = ProfitmancerDB.cdGroup or {}
		local regrouped = false
		for _, id in ipairs(ok and ids or {}) do
			local cdOk, cd = pcall(U.GetRecipeCooldown, id)
			local info = U.GetRecipeInfo and U.GetRecipeInfo(id)
			local trans = info and isTransmute(info.name)
			local isKnown = KNOWN[id] or ProfitmancerDB.cdSpells[id] or trans
			if cdOk and ((cd and cd > 0) or isKnown) then
				if info and info.learned then
					-- transmutes: one shared cooldown per category of the window (Lesser / Greater...)
					if (trans or (KNOWN[id] and KNOWN[id].group)) and info.categoryID then
						ProfitmancerDB.cdGroup[id] = "c" .. info.categoryID; regrouped = true
						-- the category's name ("Lesser Transmutations") labels the shared cooldown
						if U.GetCategoryInfo then
							local okc, ci = pcall(U.GetCategoryInfo, info.categoryID)
							if okc and type(ci) == "table" and ci.name then ProfitmancerDB.cdCat = ProfitmancerDB.cdCat or {}; ProfitmancerDB.cdCat["c" .. info.categoryID] = ci.name end
						end
					end
					if trans and not KNOWN[id] then ProfitmancerDB.cdSpells[id] = ProfitmancerDB.cdSpells[id] or true end
					local out = KNOWN[id] and KNOWN[id].out
					if not out and U.GetRecipeSchematic then local s = U.GetRecipeSchematic(id, false); out = s and s.outputItemID end
					if not out and U.GetRecipeOutputItemData then local o = U.GetRecipeOutputItemData(id); out = o and o.itemID end
					if cd and cd > 0 and not KNOWN[id] then ProfitmancerDB.cdSpells[id] = out or true end
					local prof
					if U.GetProfessionInfoByRecipeID then local p = U.GetProfessionInfoByRecipeID(id); prof = p and (p.parentProfessionID or p.professionID) end
					if trans and not KNOWN[id] and out then ProfitmancerDB.cdSpells[id] = out end
					ProfitmancerDB.cdName = ProfitmancerDB.cdName or {}; ProfitmancerDB.cdName[id] = info.name
					put(id, out, cd or 0, groupOf(id), false, prof, true)
				end
			end
		end
		-- the old single "transmute" line (before the window told us the categories) is replaced by the per-category ones
		if regrouped then local C = mine(); if C.transmute then C.transmute = nil end end
	elseif GetNumTradeSkills and GetTradeSkillCooldown then
		for i = 1, GetNumTradeSkills() do
			local cd = GetTradeSkillCooldown(i)
			local link = GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(i)
			local id = link and tonumber(link:match("enchant:(%d+)"))
			if id and ((cd and cd > 0) or KNOWN[id] or ProfitmancerDB.cdSpells[id]) then
				local il = GetTradeSkillItemLink and GetTradeSkillItemLink(i)
				local out = (KNOWN[id] and KNOWN[id].out) or (il and tonumber(il:match("item:(%d+)")))
				if cd and cd > 0 and not KNOWN[id] then ProfitmancerDB.cdSpells[id] = out or true end
				put(id, out, cd or 0, groupOf(id), false, nil, true)
			end
		end
	end
end

-- ——— Lists ———
local function fmtLeft(s)
	if s <= 0 then return T.ready end
	if s >= 86400 then return math.floor(s / 86400) .. T.day .. " " .. math.floor(s % 86400 / 3600) .. "h" end
	if s >= 3600 then return math.floor(s / 3600) .. "h " .. math.floor(s % 3600 / 60) .. "m" end
	return math.max(1, math.floor(s / 60)) .. "m"
end
-- every character's cooldowns, ready ones first, then the soonest
local function all()
	local out, now, me = {}, time(), charKey()
	local L = ProfitmancerDB.cdLink or {}
	local hidden = ProfitmancerDB.cdHide or {}
	for ck, C in pairs(db()) do if not hidden[ck] and sameRs(ck) then
		local groups, order = {}, {}
		for key, e in pairs(C) do
			local id = tonumber(key:match("^s(%d+)$"))
			local g = (id and L[id]) and ("L" .. L[id]) or key
			if not groups[g] then groups[g] = { members = {} }; order[#order + 1] = g end
			table.insert(groups[g].members, { key = key, id = id, e = e })
		end
		for _, g in ipairs(order) do
			local ms = groups[g].members
			-- linked recipes must still agree (both ready, or the same time left); if not, the link was wrong: undo it
			local a = ms[1].e.readyAt or 0
			for _, m in ipairs(ms) do
				local b = m.e.readyAt or 0
				if math.abs(a - b) > 60 and not (a <= now and b <= now) then
					for _, x in ipairs(ms) do if x.id then L[x.id] = nil end end
					groups[g].split = true
					break
				end
			end
			local sets = groups[g].split and {} or { ms }
			if groups[g].split then for _, m in ipairs(ms) do sets[#sets + 1] = { m } end end
			for _, set in ipairs(sets) do
				table.sort(set, function(x, y) return tostring(x.key) < tostring(y.key) end)
				local rep, opts, cats = set[1].e, {}, {}
				local ready = 0
				for _, m in ipairs(set) do
					for i, o in pairs(m.e.opts or {}) do opts[i] = o end
					cats[m.e.cat or "?"] = true
					ready = math.max(ready, m.e.readyAt or 0)
				end
				local name, profit, icon, id = best(rep, opts)
				local n = 0; for _ in pairs(opts) do n = n + 1 end
				local cat
				if n > 1 then
					local only; for c in pairs(cats) do if only then only = false break end only = c end
					cat = (only and only ~= "?" and ProfitmancerDB.cdCat and ProfitmancerDB.cdCat[only]) or T.shared
				end
				out[#out + 1] = { char = ck:match("^(.-)%-") or ck, me = ck == me, key = set[1].key, e = rep, opts = opts, cat = cat, name = name, profit = profit, icon = icon, id = id, left = ready - now }
			end
		end
	end end
	table.sort(out, function(a, b)
		local ra, rb = a.left <= 0, b.left <= 0
		if ra ~= rb then return ra end
		if ra then return (a.profit or -1e12) > (b.profit or -1e12) end
		return a.left < b.left
	end)
	return out
end
local function money(c) return ProfitmancerAPI and ProfitmancerAPI.money and ProfitmancerAPI.money(c) or tostring(c) end
local function profitText(p) if not p then return "" end return (p >= 0 and "|cff3ec46d+" or "|cffff5a4a-") .. money(math.abs(p)) .. "|r" end

-- ——— Minimap counter + glow ———
local badge, glow, pulse
local function updateBadge()
	local mmb = ProfitmancerMinimapButton
	if not mmb then return end
	if not badge then
		badge = CreateFrame("Frame", nil, mmb); badge:SetSize(11, 11); badge:SetPoint("TOPRIGHT", 2, 1); badge:SetFrameLevel(mmb:GetFrameLevel() + 5)
		local dot = badge:CreateTexture(nil, "ARTWORK"); dot:SetAllPoints(); dot:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask"); dot:SetVertexColor(0.85, 0.13, 0.13)
		badge.fs = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); badge.fs:SetPoint("CENTER", 0, 0)
			do local fp = badge.fs:GetFont(); if fp then badge.fs:SetFont(fp, 8, "OUTLINE") end end
		glow = mmb:CreateTexture(nil, "OVERLAY"); glow:SetPoint("CENTER", mmb.icon or mmb, "CENTER", 0, 0); glow:SetSize(36, 36)
		glow:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"); glow:SetBlendMode("ADD"); glow:SetVertexColor(1, 0.82, 0)
		pulse = glow:CreateAnimationGroup(); pulse:SetLooping("BOUNCE")
		local a = pulse:CreateAnimation("Alpha"); a:SetFromAlpha(0.25); a:SetToAlpha(1); a:SetDuration(1.2); a:SetSmoothing("IN_OUT")
	end
	local n, mineReady = 0, false
	for _, r in ipairs(all()) do if r.left <= 0 then n = n + 1; if r.me then mineReady = true end end end
	if ProfitmancerDB.cdBadgeOff then n, mineReady = 0, false end
	badge:SetShown(n > 0); badge.fs:SetText(n)
	glow:SetShown(mineReady)
	if mineReady then pulse:Play() else pulse:Stop() end
end

-- ——— Notification ("toast"): top of the screen, fades away, never blocks clicks for long ———
local toast, queue = nil, {}
local function openProf(prof)
	if prof and C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill then pcall(C_TradeSkillUI.OpenTradeSkill, prof) end
end
-- The notification frame itself, also used for auction sales (Gains.lua). The caller sets OnClick and OnEnter.
function ProfitmancerMakeToast(frameName, posKey)
	local toast = CreateFrame("Button", frameName, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	toast:SetSize(330, 66); toast:SetFrameStrata("DIALOG"); toast:SetClampedToScreen(true)
	toast:SetMovable(true); toast:RegisterForDrag("LeftButton")
	toast:SetScript("OnDragStart", function(self) if self.unlocked then self:StartMoving() end end)
	toast:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local x, y = self:GetCenter(); local ux, uy = UIParent:GetCenter()
		if x and ux then ProfitmancerDB[posKey] = { math.floor(x - ux + 0.5), math.floor(y - uy + 0.5) } end
	end)
	if toast.SetBackdrop then
		toast:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
		toast:SetBackdropColor(0.07, 0.055, 0.04, 0.95); toast:SetBackdropBorderColor(1, 0.82, 0.2)
	end
	toast.icon = toast:CreateTexture(nil, "ARTWORK"); toast.icon:SetSize(42, 42); toast.icon:SetPoint("LEFT", 12, 0)
	local ig = toast:CreateTexture(nil, "OVERLAY"); ig:SetTexture("Interface\\Buttons\\UI-ActionButton-Border"); ig:SetBlendMode("ADD"); ig:SetVertexColor(1, 0.82, 0)
	ig:SetPoint("CENTER", toast.icon, "CENTER"); ig:SetSize(78, 78)
	toast.title = toast:CreateFontString(nil, "OVERLAY", "GameFontNormal"); toast.title:SetPoint("TOPLEFT", toast.icon, "TOPRIGHT", 10, -2); toast.title:SetPoint("RIGHT", -10, 0); toast.title:SetJustifyH("LEFT")
	toast.text = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); toast.text:SetPoint("TOPLEFT", toast.title, "BOTTOMLEFT", 0, -4); toast.text:SetPoint("RIGHT", -10, 0); toast.text:SetJustifyH("LEFT"); toast.text:SetWordWrap(false)
	toast:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	toast:SetScript("OnLeave", function(self) if not self.unlocked then self.hold = false end; GameTooltip:Hide() end)
	toast:SetScript("OnUpdate", function(self, el)
		if self.hold then return end
		self.t = (self.t or 0) + el
		if self.t < 0.3 then self:SetAlpha(self.t / 0.3)
		elseif self.t > (ProfitmancerDB.cdToastDur or 6) then
			local d = ProfitmancerDB.cdToastDur or 6
			self:SetAlpha(math.max(0, 1 - (self.t - d) / 0.8)); if self.t > d + 0.8 then self:Hide() end
		end
	end)
	toast:Hide()
	return toast
end
local function makeToast()
	if toast then return end
	toast = ProfitmancerMakeToast("ProfitmancerCooldownToast", "cdToastPos")
	toast:SetScript("OnClick", function(self, b)
		if self.unlocked then if b == "RightButton" then self.unlocked = false; self.hold = false; self:Hide() end return end
		if b ~= "RightButton" then openProf(self.prof) end; self:Hide()
	end)
	toast:SetScript("OnEnter", function(self) self.hold = true; self:SetAlpha(1); GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:AddLine(T.click, 1, 1, 1); GameTooltip:Show() end)
end
local function busy()
	if InCombatLockdown and InCombatLockdown() then return true end
	if IsInInstance then local inI, kind = IsInInstance(); if inI and kind ~= "none" then return true end end
	return false
end
local function notify()
	if ProfitmancerDB.cdToast == false or #queue == 0 or busy() or (toast and toast:IsShown()) then return end
	makeToast()
	table.sort(queue, function(a, b) return (a.profit or -1e12) > (b.profit or -1e12) end)
	local r = queue[1]
	toast.icon:SetTexture(r.icon or "Interface\\Icons\\INV_Misc_PocketWatch_01")
	toast.title:SetText(#queue > 1 and T.titleN:format(#queue) or T.title)
	toast.text:SetText(r.name .. "  " .. profitText(r.profit) .. (#queue > 1 and ("|cff9e9e9e" .. T.more:format(#queue - 1) .. "|r") or ""))
	toast.prof = r.e.prof
	toast.unlocked = false
	local pos = ProfitmancerDB.cdToastPos
	toast:ClearAllPoints()
	if pos then toast:SetPoint("CENTER", UIParent, "CENTER", pos[1], pos[2]) else toast:SetPoint("TOP", UIParent, "TOP", 0, -140) end
	toast.t = 0; toast:SetAlpha(0); toast:Show()
	if not ProfitmancerDB.cdSoundOff and PlaySound and SOUNDKIT and SOUNDKIT.UI_PROFESSIONS_WINDOW_OPEN then pcall(PlaySound, SOUNDKIT.UI_PROFESSIONS_WINDOW_OPEN) end
	queue = {}
end
-- Ready cooldowns of this character that weren't announced yet go in the queue (each readiness is announced once)
local function check()
	refresh()
	for _, r in ipairs(all()) do
		if r.me and r.left <= 0 and r.e.told ~= r.e.readyAt then
			r.e.told = r.e.readyAt
			queue[#queue + 1] = r
		end
	end
	notify()
	updateBadge()
end

-- ——— Minimap tooltip section ———
local BAR = "Interface\\Buttons\\WHITE8x8"
local function bar(frac, ready)
	local W = 120
	local f = math.max(0, math.min(1, frac))
	local fill = math.max(1, math.floor(W * f))
	local r, g, b = ready and 255 or 150, ready and 209 or 110, ready and 0 or 230
	local s = "|T" .. BAR .. ":6:" .. fill .. ":0:0:8:8:0:8:0:8:" .. r .. ":" .. g .. ":" .. b .. "|t"
	if fill < W then s = s .. "|T" .. BAR .. ":6:" .. (W - fill) .. ":0:0:8:8:0:8:0:8:50:40:30|t" end
	return s
end
-- every recipe of a cooldown, most profitable first: { {name, profit, icon}, ... }
local function recipes(e, opts)
	local P, out = ProfitmancerAPI, {}
	for id, it in pairs(opts or e.opts or {}) do
		local nm = (e.isItem and itemName(id)) or (ProfitmancerDB.cdName and ProfitmancerDB.cdName[id]) or spellName(id) or (type(it) == "number" and itemName(it)) or ("#" .. id)
		local pr = P and type(it) == "number" and P.profit(it) or nil
		local ic = type(it) == "number" and ((C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(it)) or (GetItemIcon and GetItemIcon(it))) or nil
		out[#out + 1] = { name = nm, profit = pr, icon = ic }
	end
	table.sort(out, function(a, b) return (a.profit or -1e12) > (b.profit or -1e12) end)
	return out
end

local function tooltip(tt)
	local list = all()
	if #list == 0 then return end
	tt:AddLine(" ")
	tt:AddLine(T.head, 0.71, 0.55, 1)
	local shown = 0
	for _, r in ipairs(list) do
		if shown >= 10 then break end
		local ready = r.left <= 0
		local status = ready and ("|cffffd100" .. T.ready .. "|r") or ("|cff9e9e9e" .. fmtLeft(r.left) .. "|r")
		local total = math.max(r.e.dur or 0, r.left, 1)
		local rs = recipes(r.e, r.opts)
		local cat = r.cat
		if #rs > 1 then
			-- a shared cooldown: its category with the status, then each recipe with what it earns
			tt:AddDoubleLine("|cffffd100" .. (cat or r.name) .. "|r |cffb48cff" .. r.char .. "|r", status, 1, 1, 1, 1, 1, 1)
			tt:AddLine("    " .. bar(ready and 1 or (1 - r.left / total), ready), 1, 1, 1)
			for i, x in ipairs(rs) do
				local nm = x.name:gsub("^[^:]*:%s*", "")
				tt:AddDoubleLine("    " .. (x.icon and ("|T" .. x.icon .. ":14:14:0:0|t ") or "") .. nm, profitText(x.profit), i == 1 and 1 or 0.8, i == 1 and 1 or 0.8, i == 1 and 1 or 0.8, 1, 1, 1)
			end
			shown = shown + 2 + #rs
		else
			local icon = r.icon and ("|T" .. r.icon .. ":14:14:0:0|t ") or ""
			tt:AddDoubleLine(icon .. r.name, status .. " " .. profitText(r.profit), 1, 1, 1, 1, 1, 1)
			tt:AddDoubleLine("    " .. bar(ready and 1 or (1 - r.left / total), ready), "|cffb48cff" .. r.char .. "|r", 1, 1, 1, 1, 1, 1)
			shown = shown + 2
		end
	end
end

-- For the profession window: time left on a recipe's cooldown for this character, by the recipe's name (nil = no cooldown)
local nameMap, nameAt = nil, 0
local function leftFor(name)
	if not name or not ProfitmancerDB or not ProfitmancerDB.cds then return nil end
	if not nameMap or GetTime() - nameAt > 5 then
		nameMap, nameAt = {}, GetTime()
		for _, e in pairs(mine()) do
			for id, it in pairs(e.opts or {}) do
				local nm = (e.isItem and itemName(id)) or (ProfitmancerDB.cdName and ProfitmancerDB.cdName[id]) or spellName(id)
				if nm then nameMap[nm] = e end
			end
		end
	end
	local e = nameMap[name]
	return e and ((e.readyAt or 0) - time()) or nil
end

-- ——— Events ———
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_UPDATE", "BAG_UPDATE_COOLDOWN",
	"PLAYER_REGEN_ENABLED", "ZONE_CHANGED_NEW_AREA" }) do pcall(ev.RegisterEvent, ev, e) end
-- a craft with a cooldown was just made (only the player's own spells that are tracked; never every cast in combat)
pcall(ev.RegisterUnitEvent, ev, "UNIT_SPELLCAST_SUCCEEDED", "player")
local pend = false
local lastBagCd = 0
ev:SetScript("OnEvent", function(_, e, _, _, spellID)
	if not ProfitmancerDB then return end
	if e == "UNIT_SPELLCAST_SUCCEEDED" then
		if not (spellID and (KNOWN[spellID] or (ProfitmancerDB.cdSpells and ProfitmancerDB.cdSpells[spellID]))) then return end
	elseif e == "BAG_UPDATE_COOLDOWN" then
		-- fires for every potion or trinket: only matters with a Salt Shaker, and at most every 5 s
		if GetTime() - lastBagCd < 5 or count(15846) == 0 then return end
		lastBagCd = GetTime()
	end
	if e == "PLAYER_LOGIN" then
		db()
		C_Timer.After(10, function() pcall(check) end)
		if C_Timer.NewTicker then C_Timer.NewTicker(30, function() pcall(check) end) end
	elseif e == "TRADE_SKILL_SHOW" or e == "TRADE_SKILL_LIST_UPDATE" or e == "TRADE_SKILL_UPDATE" then
		pcall(scanProfession); pcall(link); pcall(updateBadge)
	elseif e == "PLAYER_REGEN_ENABLED" or e == "ZONE_CHANGED_NEW_AREA" then
		pcall(notify)
	elseif not pend then
		-- a craft was just made: its cooldown starts, read it a moment later
		pend = true
		C_Timer.After(1, function() pend = false; pcall(refresh); pcall(updateBadge) end)
	end
end)

ProfitmancerCooldowns = {
	-- options window: show a sample, let the player drag it, put it back at its default place
	test = function()
		local l = all()
		local r = l[1] or { name = T.title, profit = nil, icon = "Interface\\Icons\\INV_Misc_PocketWatch_01", e = {} }
		local was = ProfitmancerDB.cdToast; ProfitmancerDB.cdToast = nil
		if toast then toast:Hide() end
		queue = { r }; notify()
		ProfitmancerDB.cdToast = was
		return toast
	end,
	unlock = function()
		local t = ProfitmancerCooldowns.test()
		if t then t.unlocked = true; t.hold = true; t:SetAlpha(1); t.title:SetText(FR and "Glisse-moi où tu veux, puis clic droit" or "Drag me anywhere, then right-click") end
	end,
	resetPos = function() ProfitmancerDB.cdToastPos = nil end,
	badge = function() pcall(updateBadge) end,
	-- characters with cooldowns, for the options window: { {key, name, count, hidden}, ... }
	chars = function()
		local out, H = {}, ProfitmancerDB.cdHide or {}
		for ck, C in pairs(db()) do local n = 0; for _ in pairs(C) do n = n + 1 end; out[#out + 1] = { key = ck, name = ck:match("^(.-)%-") or ck, count = n, hidden = H[ck], rs = rsOf(ck), other = not sameRs(ck) } end
		table.sort(out, function(a, b) return a.key < b.key end)
		return out
	end,
	hideChar = function(ck, hide) ProfitmancerDB.cdHide = ProfitmancerDB.cdHide or {}; ProfitmancerDB.cdHide[ck] = hide or nil; pcall(updateBadge) end,
	deleteChar = function(ck) db()[ck] = nil; if ProfitmancerDB.cdHide then ProfitmancerDB.cdHide[ck] = nil end; pcall(updateBadge) end,
	forget = function() ProfitmancerDB.cds = {}; ProfitmancerDB.cdLink = {}; pcall(updateBadge) end,
	tooltip = tooltip,
	leftFor = leftFor,
	fmtLeft = fmtLeft,
	refresh = function() refresh(); updateBadge() end,
	all = all,
	cmd = function(arg)
		arg = arg or ""
		if arg == "toast" or arg == "notif" then
			ProfitmancerDB.cdToast = ProfitmancerDB.cdToast == false and true or false
			say(ProfitmancerDB.cdToast and T.toastOn or T.toastOff)
		elseif arg == "test" then
			local l = all(); if l[1] then queue = { l[1] }; if toast then toast:Hide() end; notify() else say(T.none) end
		else
			refresh(); updateBadge()
			local l = all()
			if #l == 0 then say(T.none) return end
			say(T.head .. " :")
			for _, r in ipairs(l) do print("  " .. (r.icon and ("|T" .. r.icon .. ":14|t ") or "") .. r.name .. " |cffb48cff" .. r.char .. "|r : " .. (r.left <= 0 and ("|cffffd100" .. T.ready .. "|r") or fmtLeft(r.left)) .. " " .. profitText(r.profit)) end
			print("  |cff9e9e9e" .. T.help .. "|r")
		end
	end,
}
