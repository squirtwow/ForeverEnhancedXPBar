-- Forever Enhanced XP Bar, by Squirt: an XP bar with the XP waiting in finished quests and your rested XP, and a hover
-- box with time on this level, this session, XP per hour, when the next level comes and how many kills or quests it
-- takes.
--
-- This file holds the settings (one table of rows; the window and the defaults are built from it), the saved variables
-- and their clean-up, the per-character store (keyed by the character's GUID), the bar's saved spot, Get/Set/Listen,
-- chat output, the secret helpers, number and time formats, one event hub for every file, /xpbar (and /fexb) and the
-- game's AddOns settings entry. Tools/Notes.md has the file map.
local ADDON, F = ...

F.TITLE = "Forever Enhanced XP Bar"
F.SLASH = "/xpbar"
F.SLASH2 = "/fexb"
F.MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
F.ACCENT = { .69, .49, .94 } -- #b07df0, the family purple
F.ACCENT_HEX = "b07df0"

local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
F.VERSION = (GetMeta and GetMeta(ADDON, "Version")) or "0.0.0-dev"

local issecretvalue = issecretvalue or function() return false end

-- Secrets ------------------------------------------------------------------------------------------------------------
-- A secret is never compared, stored, joined or used in sums. nil is never handed to issecretvalue (it takes none).

function F.IsSecret(value)
    if value == nil then return false end
    return issecretvalue(value) == true
end

-- A plain, finite number, or nil for a secret or anything else.
function F.Number(value)
    if value == nil or issecretvalue(value) or type(value) ~= "number" then return nil end
    if value ~= value or value == math.huge or value == -math.huge then return nil end
    return value
end

-- A plain string, or nil for a secret or anything else.
function F.Text(value)
    if value == nil or issecretvalue(value) or type(value) ~= "string" then return nil end
    return value
end

-- A plain true or false, or nil for a secret or anything else.
function F.Bool(value)
    if value == nil or issecretvalue(value) or type(value) ~= "boolean" then return nil end
    return value
end

-- Formats --------------------------------------------------------------------------------------------------------------

-- 12450 -> "12,450" (rounded to a whole number).
function F.Commas(value)
    value = F.Number(value)
    if not value then return "-" end
    local digits = ("%d"):format(math.floor(math.abs(value) + .5))
    local out = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return (value <= -.5 and "-" or "") .. out
end

-- part of whole as "63.2%".
function F.Percent(part, whole)
    part, whole = F.Number(part), F.Number(whole)
    if not part or not whole or whole <= 0 then return "-" end
    return ("%.1f%%"):format(part / whole * 100)
end

-- Seconds as "2h 40m", "14m", "1d 3h" or "under a minute".
function F.Duration(seconds)
    seconds = F.Number(seconds)
    if not seconds or seconds < 0 then return "-" end
    local minutes = math.floor(seconds / 60)
    if minutes < 1 then return "under a minute" end
    local days, hours, mins = math.floor(minutes / 1440), math.floor(minutes % 1440 / 60), minutes % 60
    if days > 0 then return ("%dd %dh"):format(days, hours) end
    if hours > 0 then return ("%dh %dm"):format(hours, mins) end
    return ("%dm"):format(mins)
end

-- Seconds still to go as "~1h 12m", "~14 min" or "a day or more"; "-" when not known.
function F.Eta(seconds)
    seconds = F.Number(seconds)
    if not seconds or seconds < 0 then return "-" end
    local minutes = math.max(1, math.ceil(seconds / 60 - 1e-9))
    if minutes >= 1440 then return "a day or more" end
    if minutes >= 60 then return ("~%dh %dm"):format(math.floor(minutes / 60), minutes % 60) end
    return ("~%d min"):format(minutes)
end

-- Pages and rows ---------------------------------------------------------------------------------------------------------
-- Rows with options are choices, rows with a slider are sliders, rows with buttons are actions (not settings); the rest
-- are ticks. A tag is a quiet word after the label. The descriptions show in the window's footer on hover.

local EXPERIMENTAL = "experimental"
F.EXPERIMENTAL = EXPERIMENTAL
F.SIZES = { thin = 10, normal = 18, thick = 26, large = 34 }
F.WIDTH = { 200, 4000, 10 } -- the width slider: from, to (the screen's width caps it), step
F.MINIMAP_ANGLE = 340

F.PAGES = {
    { key = "bar", label = "The bar", about = "What the bar shows, its size and place, and the text on it." },
    { key = "details", label = "Hover details", about = "What the box shows when you hover the bar." },
    { key = "extras", label = "Extras", about = "The minimap button, played time and this session." },
    { key = "limits", label = "Good to know", about = "How the numbers are worked out, and what to expect." },
}

F.SECTIONS = {
    bar = {
        { title = "Show", rows = {
            { key = "showBar", label = "Show the XP bar",
                desc = "The addon's own XP bar. Your XP is still counted while it's hidden." },
            { key = "questSegment", label = "Show XP waiting in finished quests",
                desc = "An amber part after your XP: what handing in your finished quests will give you. The % in "
                    .. "brackets on the bar is where that takes you." },
            { key = "restedSegment", label = "Show rested XP",
                desc = "A blue part after that: how far your rested XP reaches. Rested only boosts XP from monsters." },
            { key = "lineUnder", label = "Show quests and rested under the bar",
                desc = "A line under the bar: the XP in your completed quests and your rested XP, each as a share of "
                    .. "this level. It shows when the bar's text does." },
            { key = "questStripes", label = "Stripes on finished-quest XP",
                desc = "Amber stripes on the finished-quest part instead of plain amber." },
            { key = "showAtMax", label = "Show the bar at max level",
                desc = "At the level cap the bar turns gold and still shows the XP waiting in finished quests." },
            { key = "border", label = "Border round the bar",
                desc = "A thin dark edge round the bar." },
            { key = "hideGameBar", label = "Hide the game's own XP bar", tag = EXPERIMENTAL,
                desc = "Fades the game's own XP bar out. Its empty slot stays where it was. Untick it to bring the "
                    .. "bar back.",
                blocked = function() return F.GameBar and F.GameBar:Blocked() end },
        } },
        { title = "Size and place", rows = {
            { key = "size", label = "Size", default = "large",
                options = { { key = "thin", label = "Thin" }, { key = "normal", label = "Normal" },
                    { key = "thick", label = "Thick" }, { key = "large", label = "Large" } },
                desc = "10, 18, 26 or 34 pixels tall. Thin has no room for text inside, so its text sits just above "
                    .. "it." },
            { key = "width", label = "Width", default = 800, slider = F.WIDTH,
                desc = "How wide the bar is. Its middle stays where it is." },
            { key = "placeButtons", buttons = {
                { key = "move", label = "Move the bar", desc = "Drag the bar where you want it, then click Done." },
                { key = "putBack", label = "Put the bar back",
                    desc = "Back above your bottom action bars, as wide as them. With EraUI's classic bar, a bar too "
                        .. "tall for the room under the cast bar goes above the cast bar instead." },
            } },
        } },
        { title = "Text on the bar", rows = {
            { key = "textShow", label = "When it shows", default = "always",
                options = { { key = "always", label = "Always" }, { key = "hover", label = "On hover" },
                    { key = "never", label = "Never" } },
                desc = "When the bar's text shows: your level, your XP and the line under the bar." },
            { key = "textFormat", label = "What it shows", default = "both",
                options = { { key = "numbers", label = "Numbers" }, { key = "percent", label = "Percent" },
                    { key = "both", label = "Both" } },
                desc = "Numbers: your XP in the middle. Percent: your % at the right, and in brackets your % once your "
                    .. "finished quests are handed in. Both: the two. Your level shows at the left with either." },
        } },
    },
    details = {
        { title = "When you hover the bar", rows = {
            { key = "dXP", label = "XP this level", desc = "Your XP this level and how far through it you are." },
            { key = "dRested", label = "Rested",
                desc = "Rested XP left, as a share of this level, and whether you're resting now." },
            { key = "dQuests", label = "In finished quests",
                desc = "The XP your finished quests will give when you hand them in." },
            { key = "dDone", label = "Quests done", desc = "Quests handed in this level and this session." },
            { key = "dLevelTime", label = "Time on this level",
                desc = "How long you've played at this level. It says \"at least\" until you level up with the addon "
                    .. "on, or type /played once." },
            { key = "dSession", label = "This session",
                desc = "How long you've been logged in, and the XP you've gained since." },
            { key = "dRate", label = "XP per hour", desc = "Your XP per hour, worked out over the time chosen below." },
            { key = "dEta", label = "Next level in", desc = "How long until your next level at that rate." },
            { key = "dKills", label = "Kills to level", tag = EXPERIMENTAL,
                desc = "From the XP of your last kills. Rested kills give more while your rested XP lasts." },
            { key = "dToQuests", label = "Quests to level", desc = "From the XP of your last hand-ins." },
        } },
        { title = "XP per hour", rows = {
            { key = "rateWindow", label = "Worked out over", default = "1h",
                options = { { key = "15m", label = "Last 15 minutes" }, { key = "1h", label = "Last hour" },
                    { key = "session", label = "This session" } },
                desc = "The last 15 minutes follows changes quickly; the whole session is the steadiest." },
        } },
    },
    extras = {
        { title = "Extras", rows = {
            { key = "minimap", label = "Minimap button",
                desc = "Left-click opens these settings, right-click shows or hides the bar, and you can drag it round "
                    .. "the minimap." },
            { key = "askPlayed", label = "Ask the game for played time at login",
                desc = "Makes Time on this level exact straight away. The game prints two lines in chat when it "
                    .. "answers. Only asked while the time isn't exact yet." },
        } },
        { title = "Session", rows = {
            { key = "sessionButtons", buttons = {
                { key = "newSession", label = "Start a new session", ask = true,
                    desc = "This session, XP per hour and the session's counts start again from now. A new login "
                        .. "starts one anyway." },
            } },
        } },
    },
}

-- The Good to know page.
F.GOOD_TO_KNOW = {
    { title = "How the numbers are worked out", text = "XP per hour counts the XP you've gained over the time chosen on "
        .. "Hover details (the last hour unless you change it). Next level in divides what's left by that rate. Kills "
        .. "and quests to level use the XP of your last kills and hand-ins, so they settle after a few of each." },
    { title = "Rested XP", text = "Rested only boosts XP from monsters, not from quests. That's why the blue part comes "
        .. "after the quest part: once you hand in, your rested XP carries on from there." },
    { title = "Time on this level", text = "The addon counts the time you play. It says \"at least\" until you level up "
        .. "with it on, or until you type /played once. Extras can ask the game at login instead." },
    { title = "Quest XP", text = "The XP waiting in finished quests is what the game says each quest will give. A quest "
        .. "counts once the game says it's ready to hand in." },
    { title = "The game's own XP bar", text = "Hiding it fades it out and leaves an empty slot where it was. With EraUI's "
        .. "classic bar on, the game's bar is part of its stone band, so it stays." },
    { title = "Per character", text = "Your numbers are kept for each character on its own. The settings are shared by "
        .. "all your characters." },
}

-- Every row by its key, the keys in the window's order, and the action rows (buttons) apart.
F.ROWS, F.KEYS, F.ACTIONS = {}, {}, {}
for _, page in ipairs(F.PAGES) do
    for _, section in ipairs(F.SECTIONS[page.key] or {}) do
        for _, row in ipairs(section.rows) do
            row.page = page.key
            if row.buttons then
                F.ACTIONS[row.key] = row
            else
                F.ROWS[row.key] = row
                F.KEYS[#F.KEYS + 1] = row.key
            end
        end
    end
end

-- Settings ---------------------------------------------------------------------------------------------------------------

local OFF_BY_DEFAULT = { questStripes = true, showAtMax = true, askPlayed = true }
F.DEFAULTS = { minimapAngle = F.MINIMAP_ANGLE }
for key, row in pairs(F.ROWS) do
    if row.options or row.slider then
        F.DEFAULTS[key] = row.default
    else
        F.DEFAULTS[key] = not OFF_BY_DEFAULT[key]
    end
end

local function Listed(list, value)
    for _, item in ipairs(list) do
        if item.key == value then return true end
    end
    return false
end

local function Valid(key, value)
    local default = F.DEFAULTS[key]
    if default == nil or value == nil then return false end
    if key == "minimapAngle" then return F.Number(value) ~= nil and value >= 0 and value < 360 end
    local row = F.ROWS[key]
    if row and row.options then return Listed(row.options, value) end
    if row and row.slider then return F.Number(value) ~= nil and value >= row.slider[1] and value <= row.slider[2] end
    return type(value) == type(default)
end
F.Valid = Valid

local db -- ForeverEnhancedXPBarDB
local loaded = false
local DB_VERSION = 1
local CHAR_DAYS = 180 -- a character not seen for this long is forgotten

function F:Get(key)
    local settings = db and db.settings
    local value = settings and settings[key]
    if value == nil then return F.DEFAULTS[key] end
    return value
end

function F:Loaded()
    return loaded
end

-- Chat and errors --------------------------------------------------------------------------------------------------------

function F:Print(text)
    print("|cff" .. F.ACCENT_HEX .. F.TITLE .. "|r: " .. tostring(text))
end

-- Says something once: in the window's footer while it's open, else in chat.
function F:Say(text)
    if F.window and F.window:IsVisible() and F.window.Say then
        F.window:Say(text)
    else
        F:Print(text)
    end
end

local reported = {}
-- A part's error, said once in chat; the others carry on.
local function Report(name, err)
    name = tostring(name or "?")
    if reported[name] then return end
    reported[name] = true
    local text = F.Text(err) and err:match("^[^\n]*") or ""
    if #text > 160 then text = text:sub(1, 160) .. "..." end
    F:Print(("The %s part hit an error and stopped: %s"):format(name, text))
end
F.Report = Report

-- A function that can't break anything else: an error is said once and swallowed. Every C_Timer callback goes through
-- one, as every event handler goes through the event hub's pcall.
function F:Guard(name, fn)
    local function Pass(ok, ...)
        if ok then return ... end
        Report(name, (...))
    end
    return function(...)
        return Pass(pcall(fn, ...))
    end
end

-- Listeners hear about every change: a setting's key, "reset", "spot", "xp", "quests", "kills", "session", "levelup",
-- "played", "band" (EraUI's classic bar came or went) or "dev".
local listeners = {}
function F:Listen(listener)
    listeners[#listeners + 1] = listener
end

function F:Notify(what, ...)
    for _, listener in ipairs(listeners) do
        local ok, err = pcall(listener, what, ...)
        if not ok then Report("display", err) end
    end
end

function F:Set(key, value)
    if not db or not Valid(key, value) then return false end
    if F:Get(key) == value then return false end
    if value == F.DEFAULTS[key] then db.settings[key] = nil else db.settings[key] = value end
    F:Notify(key)
    return true
end

-- Reset all settings (the window, after it asks): every option back to its default, and the bar's spot and the minimap
-- button's angle forgotten (the bar is placed again). Each character's numbers stay: they are counted, not chosen.
function F:Reset()
    if not db then return false end
    db.settings = {}
    db.spot = nil
    F:Notify("reset")
    F:Print("Settings reset.")
    return true
end

-- The bar's spot -------------------------------------------------------------------------------------------------------
-- Its middle from the screen's middle, { x, y }; nil until it has been placed.

local SPOT_LIMIT = 5000

local function ValidSpot(spot)
    if type(spot) ~= "table" then return false end
    local x, y = F.Number(spot.x), F.Number(spot.y)
    return x ~= nil and y ~= nil and math.abs(x) <= SPOT_LIMIT and math.abs(y) <= SPOT_LIMIT
end

function F:Spot()
    if db and ValidSpot(db.spot) then return db.spot end
    return nil
end

function F:SetSpot(x, y)
    if not db then return false end
    local spot = { x = math.floor((F.Number(x) or 0) + .5), y = math.floor((F.Number(y) or 0) + .5) }
    if not ValidSpot(spot) then return false end
    db.spot = spot
    F:Notify("spot")
    return true
end

-- Each character's numbers -----------------------------------------------------------------------------------------------
-- db.chars[UnitGUID("player")]: name ("First Surname"), seen, snap {level, xp, max}, levelSeconds, levelExact, levelAt,
-- session {start, xp, quests, kills, gains}, questsLevel, questSamples, killSamples, played {total, at}.

local CHAR_FIELDS = { name = "string", seen = "number", snap = "table", levelSeconds = "number", levelExact = "boolean",
    levelAt = "number", session = "table", questsLevel = "number", questSamples = "table", killSamples = "table",
    played = "table" }

local function Numbers(t, ...)
    for i = 1, select("#", ...) do
        if F.Number(t[select(i, ...)]) == nil then return false end
    end
    return true
end

local function CleanList(list, ok)
    for i = #list, 1, -1 do
        if not ok(list[i]) then table.remove(list, i) end
    end
end

-- Drops anything in a character's record that isn't what it should be.
local function CleanChar(char)
    for key, value in pairs(char) do
        if CHAR_FIELDS[key] ~= type(value) then char[key] = nil end
    end
    if char.snap and not Numbers(char.snap, "level", "xp", "max") then char.snap = nil end
    if char.played and not Numbers(char.played, "total", "at") then char.played = nil end
    local session = char.session
    if session and (not Numbers(session, "start", "xp", "quests", "kills") or type(session.gains) ~= "table") then
        char.session = nil
    elseif session then
        CleanList(session.gains, function(g) return type(g) == "table" and Numbers(g, "t", "xp") end)
    end
    char.questSamples = char.questSamples or {}
    CleanList(char.questSamples, function(v) return F.Number(v) ~= nil and v > 0 end)
    char.killSamples = char.killSamples or {}
    CleanList(char.killSamples, function(k) return type(k) == "table" and Numbers(k, "level", "base") and k.base > 0 end)
    char.levelSeconds = math.max(0, char.levelSeconds or 0)
    char.levelExact = char.levelExact == true
    char.questsLevel = math.max(0, char.questsLevel or 0)
end
F.CleanChar = CleanChar

-- This character's record (made the first time), or nil before the game says who you are.
function F:Char()
    if not db then return nil end
    local guid = F.Text(UnitGUID and UnitGUID("player"))
    if not guid or guid == "" then return nil end
    local char = db.chars[guid]
    if type(char) ~= "table" then
        char = {}
        CleanChar(char)
        char.seen = time()
        db.chars[guid] = char
    end
    return char
end

-- Notes this character's name and that it was seen now (at login and logout).
function F:TouchChar()
    local char = F:Char()
    if not char then return end
    char.seen = time()
    local first, surname = UnitName("player")
    first, surname = F.Text(first), F.Text(surname)
    if first and first ~= "" then
        char.name = first .. ((surname and surname ~= "") and (" " .. surname) or "")
    end
end

-- Dev mode (/xpbar dev, never announced) ---------------------------------------------------------------------------------

function F:IsDev()
    local dev = db and db.dev
    return type(dev) == "table" and dev.on == true
end

-- A dev record into db.dev[list] (kept to the last 200), read from WTF after /reload.
function F:DevLog(list, entry)
    if not F:IsDev() then return end
    local dev = db.dev
    dev[list] = type(dev[list]) == "table" and dev[list] or {}
    local log = dev[list]
    log[#log + 1] = entry
    while #log > 200 do table.remove(log, 1) end
end

-- /xpbar -------------------------------------------------------------------------------------------------------------------

local HELP = F.SLASH .. " opens the settings. " .. F.SLASH .. " move lets you drag the bar. " .. F.SLASH
    .. " reset puts the bar back. " .. F.SLASH .. " minimap shows or hides the minimap button. " .. F.SLASH
    .. " session starts a new session."
local SESSION_WAIT = 10
local sessionAsked = -math.huge

local function Slash(msg)
    msg = type(msg) == "string" and msg:lower():gsub("^%s+", ""):gsub("%s+$", "") or ""
    if msg == "" or msg == "options" or msg == "settings" or msg == "config" then
        if F.ToggleWindow then F.ToggleWindow() end
    elseif msg == "move" then
        if F.Bar then F.Bar:StartMove() end
    elseif msg == "reset" then
        if F.Bar and F.Bar:PutBack() then F:Print("The bar is back above your action bars.") end
    elseif msg == "minimap" then
        F:Set("minimap", not F:Get("minimap"))
        F:Print(F:Get("minimap") and "The minimap button is back."
            or ("The minimap button is hidden. " .. F.SLASH .. " minimap brings it back."))
    elseif msg == "session" then
        if GetTime() - sessionAsked <= SESSION_WAIT then
            sessionAsked = -math.huge
            if F.Track then F.Track:NewSession() end
            F:Print("A new session has started.")
        else
            sessionAsked = GetTime()
            F:Print("Type " .. F.SLASH .. " session again within 10 seconds to start a new session.")
        end
    elseif msg == "dev" then
        -- Off drops every dev record (send the file after a /reload with it still on).
        if F:IsDev() then
            db.dev = nil
            F:Print("Dev mode off. Its records are cleared.")
        else
            db.dev = { on = true }
            F:Print("Dev mode on: kills, hand-ins, level-ups, played time and the bar's placing are saved for /reload.")
        end
        F:Notify("dev")
    else
        F:Print(HELP)
    end
end

-- Options > AddOns -----------------------------------------------------------------------------------------------------------

local function BuildOptionsEntry()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    local entry = CreateFrame("Frame")
    entry:SetSize(600, 200)
    local title = entry:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(F.TITLE)
    local about = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    about:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    about:SetWidth(560)
    about:SetJustifyH("LEFT")
    about:SetText("An XP bar with the XP waiting in finished quests, your rested XP, XP per hour and how long until your "
        .. "next level. Type " .. F.SLASH .. ", or click below, for the settings.")
    local open = CreateFrame("Button", nil, entry, "UIPanelButtonTemplate")
    open:SetSize(160, 24)
    open:SetPoint("TOPLEFT", about, "BOTTOMLEFT", 0, -14)
    open:SetText("Open settings")
    open:SetScript("OnClick", function() if F.ShowWindow then F.ShowWindow() end end)
    local category = Settings.RegisterCanvasLayoutCategory(entry, F.TITLE)
    Settings.RegisterAddOnCategory(category)
end

-- Events -------------------------------------------------------------------------------------------------------------------
-- One frame for every file. F:On adds a handler (and registers the event). Each handler runs under pcall: an error is
-- said once and the others carry on.

local events = CreateFrame("Frame")
local handlers = {}

function F:On(event, fn)
    local list = handlers[event]
    if not list then
        list = {}
        handlers[event] = list
    end
    for _, have in ipairs(list) do
        if have == fn then return end
    end
    list[#list + 1] = fn
    events:RegisterEvent(event)
end

-- Startup ------------------------------------------------------------------------------------------------------------------

local KEEP = { version = true, settings = true, spot = true, chars = true, dev = true }

local function Load()
    ForeverEnhancedXPBarDB = type(ForeverEnhancedXPBarDB) == "table" and ForeverEnhancedXPBarDB or {}
    db = ForeverEnhancedXPBarDB
    if type(db.version) ~= "number" or db.version > DB_VERSION then
        -- Unknown or newer: start clean rather than misread it.
        for key in pairs(db) do db[key] = nil end
    end
    db.version = DB_VERSION
    if type(db.settings) ~= "table" then db.settings = {} end
    for key, value in pairs(db.settings) do
        if not Valid(key, value) or value == F.DEFAULTS[key] then db.settings[key] = nil end
    end
    if not ValidSpot(db.spot) then db.spot = nil end
    -- Dev records stay only while dev mode is on.
    if type(db.dev) ~= "table" or db.dev.on ~= true then db.dev = nil end
    if type(db.chars) ~= "table" then db.chars = {} end
    local now = time()
    for guid, char in pairs(db.chars) do
        if type(guid) ~= "string" or type(char) ~= "table" or F.Number(char.seen) == nil
            or now - char.seen > CHAR_DAYS * 86400 then
            db.chars[guid] = nil
        else
            CleanChar(char)
        end
    end
    for key in pairs(db) do
        if not KEEP[key] then db[key] = nil end
    end
    loaded = true
    SLASH_FOREVERENHANCEDXPBAR1 = F.SLASH
    SLASH_FOREVERENHANCEDXPBAR2 = F.SLASH2
    SlashCmdList.FOREVERENHANCEDXPBAR = Slash
    BuildOptionsEntry()
    F:Notify("loaded")
end

events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" and ... == ADDON then Load() end
    local list = handlers[event]
    if not list then return end
    local copy = {}
    for i, fn in ipairs(list) do copy[i] = fn end
    for _, fn in ipairs(copy) do
        local ok, err = pcall(fn, event, ...)
        if not ok then Report(event, err) end
    end
end)
events:RegisterEvent("ADDON_LOADED")
