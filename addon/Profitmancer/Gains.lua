-- Profitmancer: auction house earnings per play session.
-- Sales: money taken from "Auction successful" mails (seller invoices). Spending: gold that leaves the bags while the auction
-- house is open (buyouts, bids, deposits). A /reload keeps the session; logging back in after 20 minutes starts a new one.
local FR = GetLocale() == "frFR"
local T = FR and {
	title = "Session", sales = "Ventes HV", spent = "Achats et dépôts HV", net = "Bilan HV", gold = "Or du personnage",
	nSales = "%d vente(s)", pending = "%d en attente au courrier", last = "Dernières ventes", none = "aucune vente encore",
	hist = "Sessions précédentes", noHist = "aucune session précédente avec des ventes ou des achats.",
	reset = "nouvelle session démarrée.", help = "/pfm gains : bilan de la session · /pfm gains history : sessions précédentes · /pfm gains reset : nouvelle session",
	sold = "vendu", tip = "Session HV",
	testSale = "Vente de test : [Fiole de Potion] ×5 · ≈ %s", tabName = "Profitmancer",
	soldNow = "Vendu : %s ×%d · ≈ %s (prix de dépôt, avant commission)", soldNoPrice = "Vendu : %s (prix de dépôt inconnu)",
} or {
	title = "Session", sales = "AH sales", spent = "AH purchases and deposits", net = "AH balance", gold = "Character gold",
	nSales = "%d sale(s)", pending = "%d waiting in the mailbox", last = "Latest sales", none = "no sale yet",
	hist = "Previous sessions", noHist = "no previous session with sales or purchases.",
	reset = "new session started.", help = "/pfm gains: session report · /pfm gains history: previous sessions · /pfm gains reset: new session",
	sold = "sold", tip = "AH session",
	testSale = "Test sale: [Potion Vial] ×5 · ≈ %s", tabName = "Profitmancer",
	soldNow = "Sold: %s ×%d · ≈ %s (listed price, before AH cut)", soldNoPrice = "Sold: %s (listed price unknown)",
}
local G, SI, CO = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:1:0|t", "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:1:0|t", "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:1:0|t"
local function money(c, signed)
	c = c or 0
	local sign = ""
	if signed then sign = c < 0 and "-" or "+" end
	c = math.floor(math.abs(c) + 0.5)
	local g, s, cp = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
	if g > 0 then return sign .. g .. G .. (s > 0 and (" " .. s .. SI) or "") end
	if s > 0 then return sign .. s .. SI .. (cp > 0 and (" " .. cp .. CO) or "") end
	return sign .. cp .. CO
end
-- Sale notices: money the way the base game writes it (coin icons sized 14 px, like GetCoinTextureString)
local function coins(c)
	c = math.floor(math.abs(c or 0) + 0.5)
	if GetCoinTextureString then
		local ok, t = pcall(GetCoinTextureString, c)
		if ok and t then return t end
	end
	local g, s, cp = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
	local t = {}
	if g > 0 then t[#t + 1] = g .. "|TInterface\\MoneyFrame\\UI-GoldIcon:14:14:2:0|t" end
	if s > 0 then t[#t + 1] = s .. "|TInterface\\MoneyFrame\\UI-SilverIcon:14:14:2:0|t" end
	if cp > 0 or #t == 0 then t[#t + 1] = cp .. "|TInterface\\MoneyFrame\\UI-CopperIcon:14:14:2:0|t" end
	return table.concat(t, " ")
end
local function dur(sec)
	sec = math.max(0, sec or 0)
	local h, m = math.floor(sec / 3600), math.floor(sec / 60) % 60
	return h > 0 and (h .. " h " .. string.format("%02d", m)) or (m .. " min")
end
local function say(s) print("|cffb48cffProfitmancer|r: " .. s) end

local GAP = 20 * 60 -- away longer than this = new session
local G0 -- this character's record: { cur = session, hist = { older sessions } }
local function key() return (UnitName("player") or "?") .. "-" .. (GetRealmName and GetRealmName() or "") end
local function newSession()
	return { start = time(), last = time(), m0 = GetMoney(), sold = 0, n = 0, spent = 0, pend = 0, sales = {} }
end
local function archive()
	local c = G0.cur
	if c and (c.sold > 0 or c.spent > 0) then
		c.m1 = GetMoney()
		table.insert(G0.hist, 1, { start = c.start, last = c.last, sold = c.sold, n = c.n, spent = c.spent, gold = (c.m1 or 0) - (c.m0 or 0) })
		while #G0.hist > 30 do table.remove(G0.hist) end
	end
	G0.cur = newSession()
end
local function cur() return G0 and G0.cur end

-- ——— Sales: money from auction house mails ———
local recent = {}
-- Item id from its name (sale mails only give the name): ids learned from your bags, your auctions and what you post,
-- then the site's list of item names, then the game's own cache
function ProfitmancerLearnItem(name, id)
	if type(name) ~= "string" or not id or not ProfitmancerDB then return end
	ProfitmancerDB.ids = ProfitmancerDB.ids or {}
	ProfitmancerDB.ids[name:lower()] = id
end
function ProfitmancerItemID(name)
	if type(name) ~= "string" or name == "" then return nil end
	local k = name:lower()
	local id = (ProfitmancerDB and ProfitmancerDB.ids and ProfitmancerDB.ids[k]) or (ProfitmancerNames and ProfitmancerNames[k])
	if id then return id end
	local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
	if f then local ok, v = pcall(f, name); if ok and v then return v end end
	return nil
end
-- Learn the ids of everything in the bags (when the auction house or the mailbox opens)
local function learnBags()
	local C = C_Container
	local nSlots = (C and C.GetContainerNumSlots) or GetContainerNumSlots
	if not nSlots then return end
	for bag = 0, 4 do
		local ok, n = pcall(nSlots, bag)
		for slot = 1, (ok and n or 0) do
			local id, link
			if C and C.GetContainerItemInfo then
				local ok2, info = pcall(C.GetContainerItemInfo, bag, slot)
				if ok2 and type(info) == "table" then id, link = info.itemID, info.hyperlink end
			elseif GetContainerItemLink then
				link = GetContainerItemLink(bag, slot); id = link and tonumber(link:match("item:(%d+)"))
			end
			local name = link and link:match("%[(.-)%]")
			if id and name then ProfitmancerLearnItem(name, id) end
		end
	end
end
local lb = CreateFrame("Frame")
for _, e in ipairs({ "AUCTION_HOUSE_SHOW", "MAIL_SHOW" }) do pcall(lb.RegisterEvent, lb, e) end
lb:SetScript("OnEvent", function() pcall(learnBags) end)

local function onTake(i)
	local c = cur()
	if not c or not GetInboxInvoiceInfo or not GetInboxHeaderInfo then return end
	local ok, kind, item, _, bid, buyout, _, _, _, _, count = pcall(GetInboxInvoiceInfo, i)
	if not ok or kind ~= "seller" then return end
	local _, _, sender, subject, cash = GetInboxHeaderInfo(i)
	if not cash or cash <= 0 then return end
	-- Quantity sold: from the invoice when the game gives it, else "(20)" in the subject, else the price you posted it at
	count = tonumber(count)
	if not count or count < 1 then count = tonumber(tostring(subject or ""):match("%((%d+)%)%s*$") or tostring(item or ""):match("%((%d+)%)%s*$")) end
	if not count or count < 1 then
		local p = ProfitmancerDB.posted and item and ProfitmancerDB.posted[item:lower()]
		if p and p.u and p.u > 0 then
			local gross = (buyout and buyout > 0 and buyout) or (bid and bid > 0 and bid) or cash / 0.95
			count = math.max(1, math.floor(gross / p.u + 0.5))
		end
	end
	local id = tostring(subject) .. "|" .. cash .. "|" .. tostring(sender)
	if recent[id] and GetTime() - recent[id] < 15 then return end -- the same mail opened twice (auto loot then take money)
	recent[id] = GetTime()
	c.sold, c.n, c.last = c.sold + cash, c.n + 1, time()
	if c.pend > 0 then c.pend = c.pend - 1 end
	table.insert(c.sales, 1, { item or subject or "?", cash, count or 0, time() })
	while #c.sales > 50 do table.remove(c.sales) end
	-- Lasting sales log for the auction house panel (Sales.lua)
	local iid = item and ProfitmancerItemID(item)
	table.insert(G0.log, 1, { item or subject or "?", cash, count or 0, time(), iid })
	while #G0.log > 3000 do table.remove(G0.log) end
	if ProfitmancerSales and ProfitmancerSales.refresh then pcall(ProfitmancerSales.refresh) end
end
if hooksecurefunc then
	if TakeInboxMoney then hooksecurefunc("TakeInboxMoney", onTake) end
	if AutoLootMailItem then hooksecurefunc("AutoLootMailItem", onTake) end
end

-- Remember the unit price of what you post, to know how many were sold when the sale mail doesn't say
local function posted(name, unit, qty)
	if not name or not unit or unit <= 0 then return end
	ProfitmancerDB = ProfitmancerDB or {}
	ProfitmancerDB.posted = ProfitmancerDB.posted or {}
	ProfitmancerDB.posted[name:lower()] = { u = unit, q = math.max(1, qty or 1), t = time() }
end
local function learnLocation(loc, name)
	if C_Item and C_Item.GetItemID then local ok, id = pcall(C_Item.GetItemID, loc); if ok and id then ProfitmancerLearnItem(name, id) end end
end
local function nameOfLocation(loc)
	if C_Item and C_Item.GetItemName then local ok, n = pcall(C_Item.GetItemName, loc); if ok and n then return n end end
	if C_Item and C_Item.GetItemID then local ok, id = pcall(C_Item.GetItemID, loc); if ok and id then return (GetItemInfo and GetItemInfo(id)) or (C_Item.GetItemInfo and C_Item.GetItemInfo(id)) end end
end
if hooksecurefunc and C_AuctionHouse then
	if C_AuctionHouse.PostCommodity then
		hooksecurefunc(C_AuctionHouse, "PostCommodity", function(loc, _, qty, unit) pcall(function() local n = nameOfLocation(loc); posted(n, unit, qty); learnLocation(loc, n) end) end)
	end
	if C_AuctionHouse.PostItem then
		hooksecurefunc(C_AuctionHouse, "PostItem", function(loc, _, qty, bid, buyout) pcall(function() local n = nameOfLocation(loc); posted(n, (buyout or bid or 0) / math.max(1, qty or 1), qty); learnLocation(loc, n) end) end)
	end
end
if hooksecurefunc and PostAuction and GetAuctionSellItemInfo then
	hooksecurefunc("PostAuction", function(minBid, buyout, _, stack) pcall(function() local n = GetAuctionSellItemInfo(); posted(n, (buyout and buyout > 0 and buyout or minBid or 0) / math.max(1, stack or 1), stack) end) end)
end

-- ——— Spending and "a buyer has been found" messages ———
-- Sale notices: in a chat tab of their own when ticked in the options (ProfitmancerDB.saleTab), else in the main chat
local function saleFrame(create)
	for i = 1, (NUM_CHAT_WINDOWS or 10) do
		local n = GetChatWindowInfo and GetChatWindowInfo(i)
		if n == T.tabName then return _G["ChatFrame" .. i] end
	end
	if create and FCF_OpenNewWindow then
		local ok, f = pcall(FCF_OpenNewWindow, T.tabName)
		if ok and f then
			-- a new tab must show nothing but our own lines
			if ChatFrame_RemoveAllMessageGroups then pcall(ChatFrame_RemoveAllMessageGroups, f) end
			if ChatFrame_RemoveAllChannels then pcall(ChatFrame_RemoveAllChannels, f) end
			return f
		end
	end
end
local function notify(msg)
	if ProfitmancerDB and ProfitmancerDB.saleTab then
		local f = saleFrame(true)
		if f and f.AddMessage then f:AddMessage("|cffb48cffProfitmancer|r: " .. msg); return end
	end
	say(msg)
end
-- Used by the options window
function ProfitmancerSaleTab(on) if on then pcall(saleFrame, true) end end
function ProfitmancerSaleTest() notify(T.testSale:format(coins(125000))) end

local ahOpen, lastMoney = false, nil
local soldPat
local function buildPat()
	local f = ERR_AUCTION_SOLD_S
	if not f then return nil end
	return "^" .. f:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", "(.+)") .. "$"
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_LOGOUT", "PLAYER_MONEY", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "CHAT_MSG_SYSTEM" }) do
	pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, e, msg)
	if e == "PLAYER_LOGIN" then
		ProfitmancerDB = ProfitmancerDB or {}
		ProfitmancerDB.gains = ProfitmancerDB.gains or {}
		local k = key()
		G0 = ProfitmancerDB.gains[k] or { hist = {} }
		ProfitmancerDB.gains[k] = G0
		G0.hist = G0.hist or {}
		if not G0.log then -- first run of the sales log: start from this session's sales
			G0.log = {}
			for _, x in ipairs(G0.cur and G0.cur.sales or {}) do G0.log[#G0.log + 1] = { x[1], x[2], x[3], x[4] } end
		end
		if ProfitmancerGains and ProfitmancerGains.prune then pcall(ProfitmancerGains.prune) end
		if not G0.cur or time() - (G0.cur.last or 0) > GAP then archive() end
		lastMoney = GetMoney()
		soldPat = buildPat()
		C_Timer.NewTicker(60, function() if G0 and G0.cur then G0.cur.last = time() end end)
	elseif not G0 then return
	elseif e == "PLAYER_LOGOUT" then
		G0.cur.last = time(); G0.cur.m1 = GetMoney()
	elseif e == "AUCTION_HOUSE_SHOW" then ahOpen = true
	elseif e == "AUCTION_HOUSE_CLOSED" then ahOpen = false
	elseif e == "PLAYER_MONEY" then
		local m = GetMoney()
		if lastMoney and ahOpen and m < lastMoney then
			G0.cur.spent = G0.cur.spent + (lastMoney - m)
			G0.cur.last = time()
		end
		lastMoney = m
	elseif e == "CHAT_MSG_SYSTEM" and soldPat and type(msg) == "string" then
		-- the game can hand addons a protected ("secret") chat text that can't be read: skip it, the sale still counts when its mail arrives
		if issecretvalue and issecretvalue(msg) then return end
		local ok, hit = pcall(string.match, msg, soldPat)
		if ok and hit then
			G0.cur.pend = G0.cur.pend + 1
			G0.cur.last = time()
			-- Tell the player right away what sold, using the price and quantity recorded when it was posted
			pcall(function()
				local nm = tostring(hit):match("%[(.-)%]") or tostring(hit)
				local p = ProfitmancerDB and ProfitmancerDB.posted and ProfitmancerDB.posted[nm:lower()]
				if p and p.u and p.u > 0 then
					local q = p.q or 1
					notify(T.soldNow:format(tostring(hit), q, coins(p.u * q)))
				else
					notify(T.soldNoPrice:format(tostring(hit)))
				end
			end)
		end
	end
end)

-- ——— Report ———
local function report()
	local c = cur()
	if not c then return end
	say(T.title .. " · " .. dur(time() - c.start))
	print("   " .. T.sales .. " : |cff3ec46d" .. money(c.sold, true) .. "|r  (" .. T.nSales:format(c.n) .. (c.pend > 0 and (", " .. T.pending:format(c.pend)) or "") .. ")")
	print("   " .. T.spent .. " : |cffe06c5a" .. money(-c.spent, true) .. "|r")
	local net = c.sold - c.spent
	print("   " .. T.net .. " : " .. (net >= 0 and "|cff3ec46d" or "|cffe06c5a") .. money(net, true) .. "|r")
	print("   " .. T.gold .. " : " .. money(GetMoney() - (c.m0 or GetMoney()), true))
	if #c.sales > 0 then
		local parts = {}
		for i = 1, math.min(5, #c.sales) do
			local s = c.sales[i]
			parts[#parts + 1] = s[1] .. ((s[3] or 0) > 1 and (" x" .. s[3]) or "") .. " " .. money(s[2])
		end
		print("   " .. T.last .. " : " .. table.concat(parts, " · "))
	end
end
local function history()
	if not G0 or #G0.hist == 0 then say(T.noHist) return end
	say(T.hist)
	for i = 1, math.min(10, #G0.hist) do
		local h = G0.hist[i]
		local net = h.sold - h.spent
		print("   " .. date(FR and "%d/%m %H:%M" or "%m/%d %H:%M", h.start) .. " · " .. dur(h.last - h.start) .. " · " .. T.sales .. " " .. money(h.sold, true)
			.. " · " .. T.net .. " " .. (net >= 0 and "|cff3ec46d" or "|cffe06c5a") .. money(net, true) .. "|r")
	end
end

ProfitmancerGains = {
	log = function() return G0 and G0.log or {} end,
	-- sales older than the history length chosen in the options are dropped (every character)
	prune = function()
		local days = ProfitmancerDB.salesKeep
		if not days then return end
		local min = time() - days * 86400
		for _, G in pairs(ProfitmancerDB.gains or {}) do
			if type(G) == "table" and G.log then
				for i = #G.log, 1, -1 do if (G.log[i][4] or 0) < min then table.remove(G.log, i) end end
			end
		end
	end,
	cmd = function(arg)
		arg = arg or ""
		if arg == "reset" or arg == "new" then if G0 then archive(); say(T.reset) end
		elseif arg == "history" or arg == "hist" or arg == "h" then history()
		elseif arg == "help" then say(T.help)
		else report() end
	end,
	-- Lines for the minimap button tooltip
	tooltip = function(tt)
		local c = cur()
		if not c or (c.sold == 0 and c.spent == 0 and c.pend == 0) then return end
		local net = c.sold - c.spent
		tt:AddLine(" ")
		tt:AddDoubleLine(T.tip .. " · " .. dur(time() - c.start), money(net, true), 0.71, 0.55, 1, net >= 0 and 0.24 or 0.88, net >= 0 and 0.77 or 0.42, net >= 0 and 0.43 or 0.35)
		-- one line: sales (count) and purchases, plus mail waiting
		local l = "|cff3ec46d+" .. money(c.sold, true) .. "|r |cff9e9e9e(" .. c.n .. ")|r"
		if c.spent > 0 then l = l .. "  |cffe06c5a-" .. money(c.spent, true) .. "|r" end
		if c.pend > 0 then l = l .. "  |cff9e9e9e✉ " .. c.pend .. "|r" end
		tt:AddLine("  " .. l)
	end,
}
