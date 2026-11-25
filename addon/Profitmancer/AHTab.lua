-- Profitmancer: shared helpers for the views that live inside the auction house window (Sales, Shopping), like Auctionator's tabs.
-- Our buttons sit after the last tab under the window (Blizzard's and other addons' such as Auctionator), our views cover the
-- window's content area, and clicking any other tab hides them. Blizzard's tab system is never touched (no taint, buying works).
local A = {}
ProfitmancerAH = A

function A.host() return AuctionHouseFrame or AuctionFrame end

-- Icon of an item from its id or its name (the name only works once the game knows the item); also returns the id found
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
function A.icon(id, name)
	if id then
		local tex = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or (GetItemIcon and GetItemIcon(id))
		if not tex and GetItemInfoInstant then tex = select(5, GetItemInfoInstant(id)) end
		if tex then return tex, id end
	end
	if name then
		local ok, _, link, _, _, _, _, _, _, _, tex = pcall(GetItemInfo, name)
		if ok and tex then return tex, link and tonumber(link:match("item:(%d+)")) end
		if GetItemInfoInstant then
			local ok2, iid, _, _, _, t2 = pcall(GetItemInfoInstant, name)
			if ok2 and t2 then return t2, iid end
		end
		-- the name alone isn't known to the game yet: the id from the site's list or what was learned, and its icon
		local nid = ProfitmancerItemID and ProfitmancerItemID(name)
		if nid and nid ~= id then
			local tex = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(nid)) or (GetItemIcon and GetItemIcon(nid))
			if tex then return tex, nid end
		end
	end
	return "Interface\\Icons\\INV_Misc_QuestionMark", nil
end

local mine = {} -- our buttons and views
function A.own(f) mine[f] = true end

-- Tab-like buttons under the window: children of the host whose top is around the window's bottom edge
local function tabs(h)
	local out = {}
	local hb = h:GetBottom()
	if not hb then return out end
	for _, c in ipairs({ h:GetChildren() }) do
		if not mine[c] and c.IsShown and c:IsShown() and c.GetObjectType and c:GetObjectType() == "Button" then
			local top, bottom = c:GetTop(), c:GetBottom()
			if top and bottom and top <= hb + 12 and top >= hb - 30 and bottom < hb then out[#out + 1] = c end
		end
	end
	return out
end

-- Rightmost tab (not ours) and the usual tab height (the selected one is taller)
function A.lastTab(h)
	local best, minH
	for _, t in ipairs(tabs(h)) do
		if not best or (t:GetRight() or 0) > (best:GetRight() or 0) then best = t end
		local th = t:GetHeight()
		if th and th > 16 and (not minH or th < minH) then minH = th end
	end
	return best, minH
end

-- Hide our views when any other tab is clicked (hooked once per button)
local hooked, views = {}, {}
function A.view(panel, onHide) views[#views + 1] = { panel = panel, onHide = onHide } end
function A.hideAll(except)
	for _, v in ipairs(views) do
		if v.panel ~= except and v.panel:IsShown() then v.panel:Hide(); if v.onHide then v.onHide() end end
	end
end
function A.hookTabs()
	local h = A.host()
	if not h then return end
	for _, t in ipairs(tabs(h)) do
		if not hooked[t] then
			hooked[t] = true
			t:HookScript("OnClick", function() A.hideAll() end)
		end
	end
end

-- Put a view inside the auction house window, over its content (title bar and money line stay visible)
function A.dock(panel)
	local h = A.host()
	panel:ClearAllPoints()
	if not rawget(panel, "solid") then -- backing in the auction house's own dark brown, so its content underneath doesn't show through
		panel.solid = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
		panel.solid:SetAllPoints()
	end
	panel:SetScale(ProfitmancerDB.panelScale or 1) -- size chosen in the options (the panel still fills the window)
	if h and h:IsShown() then
		panel:SetParent(h)
		panel:SetFrameStrata(h:GetFrameStrata())
		panel:SetFrameLevel(math.min(h:GetFrameLevel() + 500, 9000)) -- above every part of the window (the Auctions tab has its own sub-tabs on a high layer)
		panel:SetPoint("TOPLEFT", h, "TOPLEFT", 8, -26)
		panel:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", -8, 30)
		panel.solid:SetColorTexture(0.105, 0.085, 0.065, 1)
		if panel.SetBackdrop then panel:SetBackdropColor(0, 0, 0, 0); panel:SetBackdropBorderColor(0.55, 0.44, 0.24, 0.9) end
		-- keep the window's portrait and border art above our view (the character portrait overlaps the top left corner)
		local lvl = panel:GetFrameLevel()
		for _, k in ipairs({ "PortraitContainer", "PortraitFrame", "NineSlice", "TitleContainer", "CloseButton" }) do
			local c = h[k]
			if type(c) == "table" and c.SetFrameLevel and c.GetFrameLevel and (c:GetFrameLevel() or 0) <= lvl + 5 then pcall(c.SetFrameLevel, c, lvl + 10) end
		end
		local hn = h.GetName and h:GetName(); if type(hn) ~= "string" then hn = nil end
		for _, k in ipairs({ "PortraitFrame", "Portrait", "CloseButton" }) do
			local c = hn and _G[hn .. k]
			if type(c) == "table" and c.SetFrameLevel and c.GetFrameLevel and (c:GetFrameLevel() or 0) <= lvl + 5 then pcall(c.SetFrameLevel, c, lvl + 10) end
		end
		-- the window already has its close button and its portrait at the top left: keep clear of both
		if panel.closeB then panel.closeB:Hide() end
		if panel.titleFS then panel.titleFS:ClearAllPoints(); panel.titleFS:SetPoint("TOPLEFT", 74, -12) end
		panel.docked = true
	else
		-- opened with a command away from the auction house: a normal movable window
		panel:SetParent(UIParent)
		panel:SetFrameStrata("HIGH")
		panel:SetSize(560, 480)
		panel:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
		panel.solid:SetColorTexture(0.105, 0.085, 0.065, 0.97)
		if panel.SetBackdrop then panel:SetBackdropColor(0, 0, 0, 0); panel:SetBackdropBorderColor(0.55, 0.44, 0.24, 1) end
		if panel.closeB then panel.closeB:Show() end
		if panel.titleFS then panel.titleFS:ClearAllPoints(); panel.titleFS:SetPoint("TOPLEFT", 14, -12) end
		panel.docked = false
	end
end

-- Tab-styled purple button
function A.button(name, icon, label, tip, extra, onClick)
	local h = A.host()
	local b = CreateFrame("Button", name, h, BackdropTemplateMixin and "BackdropTemplate" or nil)
	b:SetSize(112, 32)
	if b.SetBackdrop then
		b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = false, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
	end
	local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetPoint("TOPLEFT", 3, -3); hl:SetPoint("BOTTOMRIGHT", -3, 3); hl:SetColorTexture(1, 1, 1, 0.12)
	local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal"); fs:SetPoint("CENTER", 0, 0)
	fs:SetText("|T" .. icon .. ":16:16:0:0|t |cffffffff" .. label .. "|r")
	b:SetScript("OnClick", onClick)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("Profitmancer", 0.71, 0.55, 1)
		GameTooltip:AddLine(tip, 1, 1, 1, true)
		if extra then GameTooltip:AddLine(extra, 0.62, 0.62, 0.62, true) end
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	A.own(b)
	A.style(b, false)
	return b
end
function A.style(b, open)
	if not b or not b.SetBackdropBorderColor then return end
	b:SetBackdropBorderColor(1, open and 0.92 or 0.82, open and 0.45 or 0, open and 1 or 0.9)
	b:SetBackdropColor(open and 0.45 or 0.33, open and 0.24 or 0.16, open and 0.75 or 0.58, 0.97)
end

-- Place our buttons in a row after the last tab (called again later: Auctionator adds its tabs after the window opens)
local order = {}
function A.register(b) order[#order + 1] = b end
function A.place()
	local h = A.host()
	if not h then return end
	A.hookTabs()
	local t, th = A.lastTab(h)
	local prev = t
	for _, b in ipairs(order) do
		-- a tab turned off in the options stays hidden, the next one takes its place
		local n = b.GetName and b:GetName()
		local off = (n == "ProfitmancerSalesButton" and ProfitmancerDB.salesTabOff) or (n == "ProfitmancerShoppingButton" and ProfitmancerDB.shopTabOff)
		if off then b:Hide() else
		b:ClearAllPoints()
		if prev then
			b:SetPoint("TOPLEFT", prev, "TOPRIGHT", 3, 0)
		else
			b:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 12, 2)
		end
		if th then b:SetHeight(math.min(th, 36)) end
		if t and t:GetWidth() and t:GetWidth() > 60 then b:SetWidth(math.max(100, math.min(t:GetWidth(), 130))) end
		b:Show()
		prev = b
		end
	end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("AUCTION_HOUSE_SHOW")
ev:SetScript("OnEvent", function()
	for _, d in ipairs({ 0.1, 0.6, 1.5 }) do C_Timer.After(d, function() pcall(A.place) end) end
end)
