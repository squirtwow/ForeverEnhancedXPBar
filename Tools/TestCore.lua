-- Core.lua: the defaults (the bar Large, both parts, the line under it, the border, text Always and Both, every detail and
-- the minimap button on; stripes, max level, hiding the game's bar and asking for played time off), settings checked as
-- they're set, number and time
-- formats, the secret helpers, the saved variables cleaned at load (a newer version starts clean), each character's
-- record by GUID (cleaned, and forgotten after 180 days unseen), the bar's spot, errors said once, and /xpbar.
-- Run with fengari: Tools/TestCore.lua
local H = assert(loadfile("Tools/Harness.lua"))()
local Equal, True = H.Equal, H.True
local F

local function Fresh(saved, opts)
    H.Environment()
    F = H.Load(saved, opts)
    return F
end

local function Last()
    return H.printed[#H.printed] or ""
end

Fresh()

-- Defaults ------------------------------------------------------------------------------------------------------------------

for _, key in ipairs({ "showBar", "questSegment", "restedSegment", "lineUnder", "border", "dXP", "dRested", "dQuests",
    "dDone", "dLevelTime", "dSession", "dRate", "dEta", "dKills", "dToQuests", "minimap", "hideGameBar" }) do
    Equal(F:Get(key), true, key .. " on by default")
end
for _, key in ipairs({ "questStripes", "showAtMax", "askPlayed" }) do
    Equal(F:Get(key), false, key .. " off by default")
end
Equal(F.ROWS.hideGameBar.tag, "experimental", "hiding the game's bar tagged experimental")
Equal(F.ROWS.dKills.tag, "experimental", "kills to level tagged experimental until the rested sum is proven")
Equal(F:Get("size"), "large", "Large size, as in the mockup")
Equal(F:Get("textShow"), "always", "text always")
Equal(F:Get("textFormat"), "both", "numbers and percent")
Equal(F:Get("rateWindow"), "1h", "XP per hour over the last hour")
Equal(F:Get("width"), 800, "800 wide until placed")
Equal(F:Get("minimapAngle"), 341, "the minimap button's spot in the family's layout")
Equal(#F.KEYS, 25, "25 settings in the window")
True(F.ACTIONS.placeButtons and F.ACTIONS.sessionButtons, "the button rows are actions, not settings")
Equal(F.DEFAULTS.placeButtons, nil, "with no default")
Equal(F.SIZES.thin .. " " .. F.SIZES.normal .. " " .. F.SIZES.thick .. " " .. F.SIZES.large, "10 18 26 34", "the four sizes")
local sizes = {}
for _, option in ipairs(F.ROWS.size.options) do sizes[#sizes + 1] = option.label end
Equal(table.concat(sizes, " "), "Thin Normal Thick Large", "in the window, smallest first")

-- Setting -------------------------------------------------------------------------------------------------------------------

Equal(F:Set("size", "huge"), false, "an unknown choice refused")
Equal(F:Set("width", 100), false, "a width under 200 refused")
Equal(F:Set("width", "wide"), false, "a width that isn't a number refused")
Equal(F:Set("width", H.SecretNumber()), false, "a secret width refused")
Equal(F:Set("width", 4010), false, "a width over 4000 refused")
Equal(F:Set("width", 4000), true, "4000 is the most")
F:Set("width", 800)
Equal(F:Set("border", "yes"), false, "a tick takes true or false only")
Equal(F:Set("width", 1000), true, "a good width")
Equal(F:Get("width"), 1000, "kept")
Equal(F:Set("width", 1000), false, "the same value again changes nothing")
F:Set("width", 800)
Equal(ForeverEnhancedXPBarDB.settings.width, nil, "a default isn't stored")
local heard = {}
F:Listen(function(what) heard[#heard + 1] = what end)
F:Set("border", false)
Equal(heard[#heard], "border", "listeners hear the key")

-- Formats ---------------------------------------------------------------------------------------------------------------------

Equal(F.Commas(12450), "12,450", "thousands")
Equal(F.Commas(123), "123", "hundreds")
Equal(F.Commas(1234567), "1,234,567", "millions")
Equal(F.Commas(0), "0", "nought")
Equal(F.Commas(999.6), "1,000", "rounded")
Equal(F.Commas(-1500), "-1,500", "below nought")
Equal(F.Commas(H.SecretNumber()), "-", "a secret shows as -")
Equal(F.Commas(nil), "-", "nothing shows as -")
Equal(F.Percent(12450, 19700), "63.2%", "a percentage")
Equal(F.Percent(1, 0), "-", "of nothing")
Equal(F.Duration(0), "under a minute", "no time")
Equal(F.Duration(59), "under a minute", "seconds")
Equal(F.Duration(60), "1m", "a minute")
Equal(F.Duration(4320), "1h 12m", "hours and minutes")
Equal(F.Duration(9600), "2h 40m", "the mockup's session")
Equal(F.Duration(90000), "1d 1h", "days")
Equal(F.Eta(nil), "-", "not known")
Equal(F.Eta(30), "~1 min", "under a minute rounds up")
Equal(F.Eta(14 * 60), "~14 min", "minutes")
Equal(F.Eta(72 * 60), "~1h 12m", "hours")
Equal(F.Eta(86400), "a day or more", "a day")

-- Secret helpers ----------------------------------------------------------------------------------------------------------------

Equal(F.Number(H.SecretNumber()), nil, "a secret number is no number")
Equal(F.Number(0 / 0), nil, "nor is NaN")
Equal(F.Number(math.huge), nil, "nor infinity")
Equal(F.Number(5), 5, "a number is")
Equal(F.Text(H.SecretString()), nil, "a secret string is no text")
Equal(F.Bool(H.SecretBool()), nil, "a secret boolean is neither")
Equal(F.Bool(false), false, "false is false")
Equal(F.IsSecret(nil), false, "nil is never handed to issecretvalue")
Equal(F.IsSecret(H.SecretNumber()), true, "a secret is")

-- The saved variables ----------------------------------------------------------------------------------------------------------

local now = 1800000000
Fresh({ version = 1, settings = { size = "huge", width = 50, border = "yes", textShow = "hover", unknown = 1,
    minimapAngle = 999 }, spot = { x = "a", y = 3 }, junk = 5, dev = "on" })
Equal(F:Get("size"), "large", "an unknown choice falls back")
Equal(F:Get("width"), 800, "a width out of range falls back")
Equal(F:Get("border"), true, "a wrong type falls back")
Equal(F:Get("textShow"), "hover", "a good saved value stays")
Equal(F:Get("minimapAngle"), 341, "an angle off the circle falls back")
Equal(ForeverEnhancedXPBarDB.settings.unknown, nil, "unknown settings dropped")
Equal(ForeverEnhancedXPBarDB.junk, nil, "unknown saved tables dropped")
Equal(ForeverEnhancedXPBarDB.dev, nil, "a dev record that isn't a table dropped")
Equal(F:Spot(), nil, "a broken spot dropped")
Fresh({ version = 1, settings = { width = 4010 } })
Equal(F:Get("width"), 800, "a width over 4000 falls back")
Equal(ForeverEnhancedXPBarDB.settings.width, nil, "and is dropped at load")
Fresh({ version = 1, dev = { on = false, kills = { { a = 1 } } } })
Equal(ForeverEnhancedXPBarDB.dev, nil, "dev records left with dev mode off dropped at load")
Fresh({ version = 1, dev = { on = true, kills = { { a = 1 } } } })
Equal(#ForeverEnhancedXPBarDB.dev.kills, 1, "kept while it's on")
Fresh({ version = 99, settings = { border = false } })
Equal(F:Get("border"), true, "a newer saved version: started clean rather than misread")
Fresh({ settings = { border = false } })
Equal(F:Get("border"), true, "no version: started clean")

-- The spot ----------------------------------------------------------------------------------------------------------------------

Fresh()
True(F:SetSpot(10.4, -250.6), "a spot saved")
Equal(F:Spot().x .. "," .. F:Spot().y, "10,-251", "in whole units")
Equal(F:SetSpot(0, 99999), false, "a spot far off the screen refused")
Equal(F:Spot().y, -251, "and the old one kept")

-- Each character -----------------------------------------------------------------------------------------------------------------

Fresh()
local char = F:Char()
True(char, "a record for this character")
Equal(ForeverEnhancedXPBarDB.chars[H.guid], char, "kept under the character's GUID")
Equal(char.name, "Zriel Gustbellow", "with the name and surname")
Equal(char.seen, now, "and when it was seen")
Equal(#char.questSamples .. " " .. #char.killSamples .. " " .. char.levelSeconds, "0 0 0", "empty to start")
H.guid, H.me = "Player-1-0000C3D4", { "Brannoc", "Stonehelm" }
local other = F:Char()
True(other and other ~= char, "another character has its own")
F:TouchChar()
Equal(other.name, "Brannoc Stonehelm", "named")
H.guid = function() return H.SecretString() end
Equal(F:Char(), nil, "a secret GUID: no record, and nothing breaks")
H.guid = nil
Equal(F:Char(), nil, "before the game says who you are: none")
Equal(#H.violations, 0, "the secret GUID never touched")

local day = 86400
Fresh({ version = 1, chars = {
    recent = { seen = now - 179 * day, levelSeconds = 50 },
    old = { seen = now - 181 * day },
    noSeen = { levelSeconds = 5 },
    broken = "x",
    messy = { seen = now, snap = { level = "x", xp = 1, max = 2 }, levelSeconds = -5, levelExact = "yes",
        questSamples = { 100, "a", -3, 50 }, killSamples = { { level = 1, base = 10 }, { level = "a", base = 3 },
        { level = 2, base = 0 } }, session = { start = now, xp = 5, quests = 1, kills = 0, gains = { { t = 1, xp = 2 },
        "bad", { t = "x", xp = 1 } } }, played = { total = 5 }, extra = 1 },
    badSession = { seen = now, session = { start = now, xp = "lots", quests = 0, kills = 0, gains = {} } },
} })
local chars = ForeverEnhancedXPBarDB.chars
True(chars.recent, "a character seen 179 days ago kept")
Equal(chars.old, nil, "one not seen for 181 days forgotten")
Equal(chars.noSeen, nil, "one with no date dropped")
Equal(chars.broken, nil, "one that isn't a record dropped")
local messy = chars.messy
Equal(messy.snap, nil, "a broken snapshot dropped")
Equal(messy.levelSeconds, 0, "negative seconds made nought")
Equal(messy.levelExact, false, "a wrong type made false")
Equal(table.concat(messy.questSamples, ","), "100,50", "only good hand-in samples kept")
Equal(#messy.killSamples, 1, "only good kill samples kept")
Equal(#messy.session.gains, 1, "only good gains kept")
Equal(messy.played, nil, "a played record missing its time dropped")
Equal(messy.extra, nil, "unknown fields dropped")
Equal(chars.badSession.session, nil, "a broken session dropped")

-- Errors said once --------------------------------------------------------------------------------------------------------------

Fresh()
H.printed = {}
local boom = F:Guard("test", function() error("boom\nmore") end)
boom()
boom()
Equal(#H.printed, 1, "an error is said once")
True(H.printed[1]:find("The test part hit an error and stopped: ", 1, true) and not H.printed[1]:find("more", 1, true),
    "its first line only")
H.printed = {}

-- /xpbar ---------------------------------------------------------------------------------------------------------------------------

Fresh()
Equal(H.category and H.category.title, "Forever Enhanced XP Bar", "listed in the game's AddOns settings")
Equal(SLASH_FOREVERENHANCEDXPBAR1 .. " " .. SLASH_FOREVERENHANCEDXPBAR2, "/xpbar /fexb", "/xpbar and /fexb")
SlashCmdList.FOREVERENHANCEDXPBAR("")
True(F.window and F.window:IsShown(), "/xpbar opens the settings")
SlashCmdList.FOREVERENHANCEDXPBAR("  ")
Equal(F.window:IsShown(), false, "and closes them")
SlashCmdList.FOREVERENHANCEDXPBAR("help")
True(Last():find("/xpbar move lets you drag the bar", 1, true), "/xpbar help")
True(not Last():find("dev", 1, true), "never mentions dev mode")
SlashCmdList.FOREVERENHANCEDXPBAR("minimap")
Equal(F:Get("minimap"), false, "/xpbar minimap hides the button")
True(Last():find("/xpbar minimap brings it back", 1, true), "and says how to bring it back")
SlashCmdList.FOREVERENHANCEDXPBAR("MINIMAP")
Equal(F:Get("minimap"), true, "and shows it again (any case)")
SlashCmdList.FOREVERENHANCEDXPBAR("move")
True(F.Bar:Moving(), "/xpbar move shows the mover")
F.Bar:StopMove()
F:SetSpot(0, 200)
SlashCmdList.FOREVERENHANCEDXPBAR("reset")
True(Last():find("back above your action bars", 1, true), "/xpbar reset puts the bar back")
Equal(F:Spot().y, -384 + 148 + 18 + 17, "to its first spot (nothing to go by here: 150 px up, less the border)")
local session = F:Char().session
H.Advance(30)
SlashCmdList.FOREVERENHANCEDXPBAR("session")
Equal(F:Char().session, session, "/xpbar session asks first")
True(Last():find("again within 10 seconds", 1, true), "and says how")
H.Advance(11)
SlashCmdList.FOREVERENHANCEDXPBAR("session")
Equal(F:Char().session, session, "too late: it asks again")
H.Advance(9)
SlashCmdList.FOREVERENHANCEDXPBAR("session")
True(F:Char().session ~= session, "typed twice within 10 seconds: a new session")
Equal(F:Char().session.start, time(), "starting now")
True(Last():find("A new session has started.", 1, true), "said")
SlashCmdList.FOREVERENHANCEDXPBAR("dev")
True(F:IsDev(), "/xpbar dev turns dev mode on")
F:DevLog("kills", { a = 1 })
Equal(#ForeverEnhancedXPBarDB.dev.kills, 1, "and dev records are saved")
for i = 1, 210 do F:DevLog("kills", { i = i }) end
Equal(#ForeverEnhancedXPBarDB.dev.kills, 200, "kept to the last 200")
SlashCmdList.FOREVERENHANCEDXPBAR("dev")
True(not F:IsDev(), "and off")
Equal(ForeverEnhancedXPBarDB.dev, nil, "turning it off clears its records")
F:DevLog("place", { a = 1 })
Equal(ForeverEnhancedXPBarDB.dev, nil, "nothing saved with it off")
SlashCmdList.FOREVERENHANCEDXPBAR("dev")
True(F:IsDev(), "on again")
Equal(ForeverEnhancedXPBarDB.dev.kills, nil, "starting with no old records")
SlashCmdList.FOREVERENHANCEDXPBAR("dev")
H.printed = {}

-- A listener that breaks is said once and the others still hear.
local later = 0
F:Listen(function() error("listener broke") end)
F:Listen(function() later = later + 1 end)
F:Notify("x")
F:Notify("y")
Equal(later, 2, "the others still hear")
Equal(#H.printed, 1, "the broken one said once")
H.printed = {}

Equal(#H.violations, 0, "Blizzard's frames only read")
Equal(H.Problems(), "", "nothing went wrong")
io.stdout:write("TestCore: " .. H.checks .. " checks passed\n")
