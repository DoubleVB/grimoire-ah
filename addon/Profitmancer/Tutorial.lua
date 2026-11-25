-- Profitmancer: a short guide in a few steps, shown once to new users (and again with /pfm guide).
local FR = GetLocale() == "frFR"
local URL = "https://doublevb.github.io/grimoire-ah/"
local G = "|cffffd100" -- gold for the names of things
local P = "|cffb48cff" -- Profitmancer purple
local E = "|r"

local STEPS = FR and {
	{ "Bienvenue dans Profitmancer", "Profitmancer t'aide à gagner de l'or avec tes métiers et l'hôtel des ventes : prix, profit des crafts, cooldowns, historique de tes ventes et listes de courses.\n\nCe guide prend une minute. Utilise les flèches pour avancer." },
	{ "Les infobulles", "Survole n'importe quel objet : trois lignes s'ajoutent.\n\n" .. G .. "Vendor" .. E .. " : le prix chez un PNJ (en vert s'il est moins cher qu'à l'HV), sinon ce qu'un PNJ t'en donne.\n" .. G .. "AH" .. E .. " : le prix du marché et combien s'en vendent par jour.\n" .. G .. "Craft" .. E .. " : le coût des composants et le profit si tu le fabriques.\n\nMaintiens " .. G .. "Maj" .. E .. " pour le détail." },
	{ "D'où viennent les prix", "Deux sources, au choix :\n\n" .. G .. "Auctionator" .. E .. " : fais un scan complet à l'hôtel des ventes, les prix s'affichent tout de suite.\n" .. G .. "Les prix automatiques" .. E .. " (Windows, gratuit) : tous les hôtels des ventes de WoW Forever, avec les ventes 24 h. Blizzard publie les prix une fois par heure, le programme les récupère tout seul en moins de 15 minutes. L'installation se fait depuis le site :", URL .. "#updater" },
	{ "Le bouton de la minicarte", P .. "Clic gauche" .. E .. " : charger les derniers prix.\n" .. P .. "Clic droit" .. E .. " : les options de l'addon.\n" .. P .. "Maj+clic" .. E .. " : exporter tes personnages pour le site.\n" .. P .. "Glisser" .. E .. " : le déplacer.\n\nSurvole-le pour voir l'âge des prix, tes gains de la session et tes cooldowns. Une " .. G .. "pastille rouge" .. E .. " indique combien de cooldowns sont prêts.", nil, "minimap" },
	{ "À l'hôtel des ventes", "Deux onglets violets s'ajoutent sous la fenêtre :\n\n" .. G .. "Sales" .. E .. " : ton historique de ventes, tes totaux par objet, les ventes en attente de courrier et tes enchères en cours comparées au prix du marché. Clique sur une colonne pour trier.\n" .. G .. "Shop lists" .. E .. " : tes listes de courses. Règle le nombre de " .. G .. "Crafts" .. E .. " en haut de la liste et toutes les quantités suivent (chaque quantité reste modifiable). Clique sur un objet : la recherche se lance et l'achat s'ouvre avec la bonne quantité. Import et export au format Auctionator." },
	{ "Dans tes fenêtres de métier", "À côté de chaque recette :\n• le " .. G .. "profit" .. E .. " (|cff1eff00vert|r) ou la " .. G .. "perte" .. E .. " (|cffff5a4arouge|r) du craft ;\n• après la flèche verte, le " .. G .. "% de chance" .. E .. " de gagner un point de métier ;\n• pour les recettes à cooldown, une coche quand c'est prêt ou le temps restant.\n\n" .. G .. "Export" .. E .. " (en bas, à côté de « Suivre la recette ») : les composants de la recette en liste de courses, pour Auctionator ou Profitmancer.\n" .. G .. "Export recipes" .. E .. " (sous la fenêtre) : ton personnage et ses recettes pour le site." },
	{ "Les cooldowns de craft", "Transmutations, Étoffe lunaire, Salière... pour tous les métiers et tous tes personnages.\n\nQuand un cooldown est prêt, une " .. G .. "notification" .. E .. " apparaît en haut de l'écran (jamais en combat ni en donjon). Clique dessus pour ouvrir le métier.\n\nOuvre une fois chaque métier sur chaque personnage pour que Profitmancer connaisse ses cooldowns. " .. P .. "/pfm cd" .. E .. " les liste dans le chat." },
	{ "Les options", "Clic droit sur le bouton de la minicarte (ou " .. P .. "/pfm options" .. E .. ") :\n\n• les lignes des infobulles et ce qui s'affiche dans la fenêtre de métier ;\n• la notification des cooldowns : son, durée, " .. G .. "position" .. E .. " (bouton Déplacer) ;\n• les onglets de l'HV, la taille des fenêtres, la durée de l'historique ;\n• les personnages suivis, les rappels de prix, les liens du site.", nil, "minimap" },
	{ "Tes gains", "Profitmancer compte ce que tu gagnes et dépenses à l'hôtel des ventes pendant chaque session de jeu.\n\n" .. P .. "/pfm gains" .. E .. " : le bilan de la session.\n" .. P .. "/pfm gains history" .. E .. " : les sessions précédentes." },
	{ "Le site", "Le site Profitmancer classe les crafts les plus rentables, donne des guides pour monter tes métiers et liste tous les objets de l'hôtel des ventes :", URL },
	{ "C'est parti !", "Tape " .. P .. "/pfm" .. E .. " pour voir toutes les commandes, et " .. P .. "/pfm guide" .. E .. " pour revoir ce guide.\n\nBonnes ventes !" },
} or {
	{ "Welcome to Profitmancer", "Profitmancer helps you make gold with your professions and the auction house: prices, crafting profit, cooldowns, the history of your sales and shopping lists.\n\nThis guide takes a minute. Use the arrows to move on." },
	{ "Tooltips", "Hover any item: three lines are added.\n\n" .. G .. "Vendor" .. E .. ": what an NPC sells it for (green when cheaper than the AH), otherwise what an NPC pays you.\n" .. G .. "AH" .. E .. ": the market price and how many sell per day.\n" .. G .. "Craft" .. E .. ": the cost of the reagents and the profit if you make it.\n\nHold " .. G .. "Shift" .. E .. " for the details." },
	{ "Where the prices come from", "Two sources, your choice:\n\n" .. G .. "Auctionator" .. E .. ": do a full scan at the auction house, prices show right away.\n" .. G .. "Automatic prices" .. E .. " (Windows, free): every WoW Forever auction house, with 24 h sales. Blizzard publishes prices once an hour, the updater picks them up by itself within 15 minutes. Install it from the website:", URL .. "#updater" },
	{ "The minimap button", P .. "Left click" .. E .. ": load the latest prices.\n" .. P .. "Right click" .. E .. ": the addon's options.\n" .. P .. "Shift+click" .. E .. ": export your characters for the website.\n" .. P .. "Drag" .. E .. ": move it.\n\nHover it to see the age of the prices, your earnings this session and your cooldowns. A " .. G .. "red badge" .. E .. " shows how many cooldowns are ready.", nil, "minimap" },
	{ "At the auction house", "Two purple tabs are added under the window:\n\n" .. G .. "Sales" .. E .. ": your sales history, totals per item, sales awaiting mail and your current auctions compared to the market price. Click a column to sort.\n" .. G .. "Shop lists" .. E .. ": your shopping lists. Set the number of " .. G .. "Crafts" .. E .. " at the top of a list and every quantity follows (each one can still be changed). Click an item: the search runs and the purchase opens with the right quantity. Import and export in Auctionator's format." },
	{ "In your profession windows", "Next to each recipe:\n• the " .. G .. "profit" .. E .. " (|cff1eff00green|r) or " .. G .. "loss" .. E .. " (|cffff5a4ared|r) of the craft;\n• after the green arrow, the " .. G .. "% chance" .. E .. " of a skill point;\n• for recipes with a cooldown, a tick when ready or the time left.\n\n" .. G .. "Export" .. E .. " (at the bottom, next to \"Track Recipe\"): the recipe's reagents as a shopping list, for Auctionator or Profitmancer.\n" .. G .. "Export recipes" .. E .. " (under the window): your character and its recipes for the website." },
	{ "Craft cooldowns", "Transmutes, Mooncloth, Salt Shaker... for every profession and all your characters.\n\nWhen a cooldown is ready, a " .. G .. "notification" .. E .. " shows at the top of the screen (never in combat or in a dungeon). Click it to open the profession.\n\nOpen each profession once on each character so Profitmancer knows its cooldowns. " .. P .. "/pfm cd" .. E .. " lists them in the chat." },
	{ "Options", "Right-click the minimap button (or " .. P .. "/pfm options" .. E .. "):\n\n• the tooltip lines and what shows in the profession window;\n• the cooldown notification: sound, duration, " .. G .. "position" .. E .. " (Move button);\n• the AH tabs, the window size, how long sales are kept;\n• the characters followed, price reminders, the website links.", nil, "minimap" },
	{ "Your earnings", "Profitmancer counts what you earn and spend at the auction house during each play session.\n\n" .. P .. "/pfm gains" .. E .. ": this session's report.\n" .. P .. "/pfm gains history" .. E .. ": previous sessions." },
	{ "The website", "The Profitmancer website ranks the most profitable crafts, has leveling guides for your professions and lists every item at the auction house:", URL },
	{ "You're all set!", "Type " .. P .. "/pfm" .. E .. " to see every command, and " .. P .. "/pfm guide" .. E .. " to see this guide again.\n\nHappy selling!" },
}
local B = FR and { prev = "Précédent", next = "Suivant", done = "Terminer", skip = "Passer le guide", copy = "Ctrl+C pour copier" }
	or { prev = "Previous", next = "Next", done = "Done", skip = "Skip the guide", copy = "Ctrl+C to copy" }

local win, step = nil, 1
local glow

local function showGlow(on)
	local mm = ProfitmancerMinimapButton
	if on and mm then
		if not glow then
			glow = mm:CreateTexture(nil, "OVERLAY")
			glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border"); glow:SetBlendMode("ADD")
			glow:SetVertexColor(0.71, 0.55, 1); glow:SetSize(70, 70); glow:SetPoint("CENTER", mm, "CENTER", 0, 0)
			local ag = glow:CreateAnimationGroup(); ag:SetLooping("BOUNCE")
			local a = ag:CreateAnimation("Alpha"); a:SetFromAlpha(0.2); a:SetToAlpha(1); a:SetDuration(0.7)
			glow.ag = ag
		end
		glow:Show(); glow.ag:Play()
	elseif glow then
		glow.ag:Stop(); glow:Hide()
	end
end

local function render()
	local s = STEPS[step]
	win.title:SetText(s[1])
	win.body:SetText(s[2])
	win.count:SetText(step .. " / " .. #STEPS)
	if s[3] then
		win.link:SetText(s[3]); win.link:Show(); win.copy:Show()
	else
		win.link:Hide(); win.copy:Hide()
	end
	win.prev:SetEnabled(step > 1)
	win.next:SetText(step < #STEPS and (B.next .. " >") or B.done)
	for i, d in ipairs(win.dots) do d:SetVertexColor(i == step and 0.71 or 0.35, i == step and 0.55 or 0.3, i == step and 1 or 0.25) end
	showGlow(s[4] == "minimap")
	-- fit the window to the text
	local h = 76 + (win.body:GetStringHeight() or 80) + (s[3] and 40 or 0) + 84
	win:SetHeight(math.max(220, math.min(520, h)))
end

local function close(done)
	if win then win:Hide() end
	showGlow(false)
	ProfitmancerDB.tutoDone = true
end

local function build()
	if win then return end
	win = CreateFrame("Frame", "ProfitmancerGuide", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	win:SetSize(480, 260); win:SetPoint("TOP", UIParent, "TOP", 0, -140); win:SetFrameStrata("DIALOG")
	win:EnableMouse(true); win:SetMovable(true); win:RegisterForDrag("LeftButton"); win:SetClampedToScreen(true)
	win:SetScript("OnDragStart", win.StartMoving); win:SetScript("OnDragStop", win.StopMovingOrSizing)
	win:SetScript("OnHide", function() showGlow(false); ProfitmancerDB.tutoDone = true end)
	if win.SetBackdrop then
		win:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } })
	end
	local icon = win:CreateTexture(nil, "ARTWORK"); icon:SetSize(40, 40); icon:SetPoint("TOPLEFT", 22, -22); icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")
	local brand = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); brand:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -2); brand:SetText(P .. "Profitmancer" .. E)
	win.title = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); win.title:SetPoint("TOPLEFT", brand, "BOTTOMLEFT", 0, -4); win.title:SetPoint("RIGHT", -24, 0); win.title:SetJustifyH("LEFT")
	local x = CreateFrame("Button", nil, win, "UIPanelCloseButton"); x:SetPoint("TOPRIGHT", -6, -6); x:SetScript("OnClick", function() close() end)
	win.body = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); win.body:SetPoint("TOPLEFT", 24, -76); win.body:SetPoint("RIGHT", -24, 0)
	win.body:SetJustifyH("LEFT"); win.body:SetJustifyV("TOP"); win.body:SetSpacing(3)
	win.link = CreateFrame("EditBox", nil, win, "InputBoxTemplate"); win.link:SetSize(300, 22); win.link:SetPoint("TOPLEFT", win.body, "BOTTOMLEFT", 6, -10); win.link:SetAutoFocus(false)
	win.link:SetScript("OnTextChanged", function(self, user) if user then self:SetText(STEPS[step][3] or ""); self:HighlightText() end end)
	win.link:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
	win.link:SetScript("OnMouseUp", function(self) self:SetFocus(); self:HighlightText() end)
	win.link:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	win.copy = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); win.copy:SetPoint("LEFT", win.link, "RIGHT", 10, 0); win.copy:SetText(B.copy)
	-- footer: skip, progress dots, previous / next
	local skip = CreateFrame("Button", nil, win); skip:SetSize(120, 20); skip:SetPoint("BOTTOMLEFT", 22, 18)
	local st = skip:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); st:SetPoint("LEFT"); st:SetText(B.skip)
	skip:SetScript("OnClick", function() close() end)
	skip:SetScript("OnEnter", function() st:SetTextColor(1, 1, 1) end); skip:SetScript("OnLeave", function() st:SetTextColor(0.5, 0.5, 0.5) end)
	win.next = CreateFrame("Button", nil, win, "UIPanelButtonTemplate"); win.next:SetSize(110, 24); win.next:SetPoint("BOTTOMRIGHT", -22, 16)
	win.next:SetScript("OnClick", function() if step < #STEPS then step = step + 1; render() else close() end end)
	win.prev = CreateFrame("Button", nil, win, "UIPanelButtonTemplate"); win.prev:SetSize(110, 24); win.prev:SetPoint("RIGHT", win.next, "LEFT", -8, 0); win.prev:SetText("< " .. B.prev)
	win.prev:SetScript("OnClick", function() if step > 1 then step = step - 1; render() end end)
	-- progress: one dot per step, centered above the buttons, then "3 / 9"
	win.dots = {}
	local n = #STEPS
	for i = 1, n do
		local d = win:CreateTexture(nil, "ARTWORK"); d:SetSize(8, 8); d:SetTexture("Interface\\Buttons\\WHITE8x8")
		d:SetPoint("BOTTOM", win, "BOTTOM", (i - (n + 1) / 2) * 14 - 20, 50)
		win.dots[i] = d
	end
	win.count = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); win.count:SetPoint("LEFT", win.dots[n], "RIGHT", 10, 0)
	tinsert(UISpecialFrames, "ProfitmancerGuide") -- Escape closes it
end

local function open(from)
	build()
	step = from or 1
	win:Show()
	render()
end

-- First login with Profitmancer: show the guide (the "automatic prices" window waits, the guide talks about it)
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
	ProfitmancerDB = ProfitmancerDB or {}
	local VER = 2 -- guide version: players who saw an older guide see the new parts once (from the minimap button step)
	if not ProfitmancerDB.tutoDone then
		ProfitmancerDB.setupT = time()
		ProfitmancerDB.tutoVer = VER
		C_Timer.After(5, function() if not InCombatLockdown() then open(1) end end)
	elseif (ProfitmancerDB.tutoVer or 1) < VER then
		ProfitmancerDB.tutoVer = VER
		C_Timer.After(8, function() if not InCombatLockdown() then open(4) end end)
	end
end)

ProfitmancerGuide_Open = open
