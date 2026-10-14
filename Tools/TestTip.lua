-- Tip.lua: the addon's own hover box (named, in the TOOLTIP strata, never taking the mouse, 330 to 400 wide), the bar's ten
-- details in the mockup's order and their formats, rows following the ticks, the reduced boxes at max level and with XP
-- gain off, no box with nothing ticked, the footer, and its place above the bar (below it in the top half), clear of the
-- line under the bar and of Thin's text above it.
-- Run with fengari: Tools/TestTip.lua
local H = assert(loadfile("Tools/Harness.lua"))()
local S, Equal, True = H.S, H.Equal, H.True
local F, TP, box

local function Fresh(saved, setup)
    H.Environment()
    if setup then setup() end
    F = H.Load(saved or { version = 1, spot = { x = 0, y = -300 } })
    TP = F.Tip
    return F
end

-- The rows shown: { label, value } each.
local function Rows()
    local rows = {}
    for i, label in ipairs(box.labels) do
        if label:IsShown() then rows[#rows + 1] = { H.Text(label), H.Text(box.values[i]) } end
    end
    return rows
end

local function Hover()
    H.Script(F.Bar:Frame(), "OnEnter")
    box = TP:Box()
    return Rows()
end

local function Leave()
    H.Script(F.Bar:Frame(), "OnLeave")
end

-- The example character: level 24, 12,450 of 19,700, 4,200 rested in an inn, 1,860 XP in 3 finished quests, 7 quests
-- this level and 12 this session, 1h 12m on this level, 2h 40m of session with 18,400 XP, 9,850 XP in the last hour,
-- 62 XP kills and 1,250 XP quests.
Fresh(nil, function()
    H.p.resting = true
    H.quests = { { questID = 1, title = "A", complete = true, xp = 900 }, { questID = 2, title = "B", complete = true,
        xp = 600 }, { questID = 3, title = "C", complete = true, xp = 360 } }
end)
H.Fire("QUEST_LOG_UPDATE")
H.Fire("TIME_PLAYED_MSG", 90000, 4320)
H.Frame()
local char = F:Char()
local now = time()
char.questsLevel = 7
char.session.quests, char.session.start, char.session.xp = 12, now - 9600, 18400
char.session.gains = { { t = now - 3000, xp = 5000 }, { t = now - 600, xp = 4850 } }
char.killSamples = { { level = 24, base = 62 }, { level = 24, base = 62 }, { level = 24, base = 62 } }
char.questSamples = { 1250 }

local rows = Hover()
True(box:IsShown(), "hovering the bar shows the box")
Equal(ForeverEnhancedXPBarTip, box, "named ForeverEnhancedXPBarTip")
Equal(S[box].strata, "TOOLTIP", "in the TOOLTIP strata")
Equal(S[box].mouse, false, "never takes the mouse")
Equal(S[box].parent, UIParent, "under UIParent")
Equal(H.Text(box.title), "Level 24 to 25", "titled with the level")
local expected = {
    { "XP this level", "12,450 / 19,700 (63.2%)" },
    { "Rested", "4,200 (21.3%), resting" },
    { "In finished quests", "1,860 XP in 3 quests (9.4%)" },
    { "Quests done", "7 this level, 12 this session" },
    { "Time on this level", "1h 12m" },
    { "This session", "2h 40m, 18,400 XP" },
    { "XP per hour", "9,850" },
    { "Next level in", "~45 min" },
    { "Kills to level", "~84 (62 XP each, 124 while rested)" },
    { "Quests to level", "~6 (1,250 XP each)" },
}
Equal(#rows, 10, "all ten details")
for i, row in ipairs(expected) do
    Equal(rows[i][1], row[1], "row " .. i)
    Equal(rows[i][2], row[2], row[1])
end
Equal(H.Text(box.footer), "Right-click the minimap button to show or hide the bar", "the footer")
True(S[box].width >= 330 and S[box].width <= 400, "330 to 400 wide")
Leave()

-- The ticks.
F:Set("dKills", false)
F:Set("dRate", false)
rows = Hover()
Equal(#rows, 8, "unticked details left out")
Equal(rows[7][1], "Next level in", "the rest in order")
Leave()
for _, detail in ipairs(TP.DETAILS) do F:Set(detail[1], false) end
Hover()
Equal(box and box:IsShown() or false, false, "nothing ticked: no box")
for _, detail in ipairs(TP.DETAILS) do F:Set(detail[1], true) end
F:Set("minimap", false)
Hover()
Equal(H.Text(box.footer), "/xpbar opens the settings", "no minimap button: the footer says how to open the settings")
Leave()
F:Set("minimap", true)

-- Other formats.
H.Fire("TIME_PLAYED_MSG", 0, 0)
char.levelExact = false
H.p.resting, H.p.rested = false, nil
H.quests = { { questID = 1, title = "A", complete = true, xp = 9000 } }
H.Fire("QUEST_LOG_UPDATE")
H.Fire("UPDATE_EXHAUSTION")
H.Frame()
char.killSamples, char.questSamples = {}, {}
char.session.gains = {}
rows = Hover()
Equal(rows[2][2], "None", "no rested XP")
Equal(rows[3][2], "9,000 XP in 1 quest (45.7%), levels you up", "one quest, enough to level")
Equal(rows[5][2], "at least under a minute", "\"at least\" until exact")
Equal(rows[7][2], "0", "no XP in the last hour")
Equal(rows[8][2], "-", "so no next level")
Equal(rows[9][2], "-", "no kills yet")
Equal(rows[10][2], "Hand in your finished quests", "the quests already cover it")
Leave()
H.quests = {}
H.Fire("QUEST_LOG_UPDATE")
H.Frame()
rows = Hover()
Equal(rows[3][2], "None waiting", "nothing waiting")
Equal(rows[10][2], "-", "no hand-ins yet")
Leave()

-- XP off.
H.p.off = true
H.Fire("DISABLE_XP_GAIN")
H.Frame()
rows = Hover()
Equal(H.Text(box.title), "Level 24", "XP off: the level only")
Equal(rows[1][1], "XP gain is turned off", "says so")
Equal(rows[2][1] .. ", " .. rows[3][1], "Quests done, This session", "then quests done and this session")
Equal(#rows, 3, "and nothing else")
Leave()

-- Max level.
Fresh(nil, function()
    H.p.level, H.p.xp = 30, 0
    H.quests = { { questID = 1, title = "A", complete = true, xp = 4000 } }
end)
F:Set("showAtMax", true)
H.Fire("QUEST_LOG_UPDATE")
H.Frame()
rows = Hover()
Equal(H.Text(box.title), "Level 30, max level", "max level")
Equal(#rows, 3, "three rows")
Equal(rows[1][1] .. ", " .. rows[2][1] .. ", " .. rows[3][1], "In finished quests, Quests done, This session",
    "the XP waiting, quests done and this session")
Equal(rows[1][2], "4,000 XP in 1 quest", "no share of a level that isn't there")
Leave()

-- Its place.
Fresh()
local bar = F.Bar:Frame()
S[bar].center = { 512, 100 }
Hover()
local point, relative, relativePoint, x, y = box:GetPoint(1)
Equal(point .. " " .. relativePoint, "BOTTOMRIGHT TOPRIGHT", "above the bar, right edges lined up")
Equal(relative, bar, "on the bar")
Equal(y, 6, "just clear of the border")
Leave()
S[bar].center = { 512, 700 }
Hover()
point, relative, relativePoint, x, y = box:GetPoint(1)
Equal(point .. " " .. relativePoint .. " " .. y, "TOPRIGHT BOTTOMRIGHT -22", "below it in the top half of the screen, "
    .. "clear of the line under it (18 px)")
Leave()
F:Set("lineUnder", false)
Hover()
point, relative, relativePoint, x, y = box:GetPoint(1)
Equal(y, -6, "no line: just clear of the border")
Leave()
F:Set("lineUnder", true)
F:Set("size", "thin")
S[bar].center = { 512, 100 }
Hover()
point, relative, relativePoint, x, y = box:GetPoint(1)
Equal(point .. " " .. y, "BOTTOMRIGHT 20", "above a Thin bar: clear of its text (16 px)")
Leave()
F:Set("size", "large")
S[bar].center = { H.SecretNumber(), H.SecretNumber() }
Hover()
point = box:GetPoint(1)
Equal(point, "BOTTOMRIGHT", "a secret position: above, and nothing touched")
Leave()
-- Only the frame that showed it hides it.
Hover()
TP:Hide(UIParent)
True(box:IsShown(), "another frame can't hide it")
TP:Hide()
Equal(box:IsShown(), false, "anyone can clear it")

H.printed = {}
Equal(#H.violations, 0, "Blizzard's frames only read")
Equal(H.Problems(), "", "nothing went wrong")
io.stdout:write("TestTip: " .. H.checks .. " checks passed\n")
