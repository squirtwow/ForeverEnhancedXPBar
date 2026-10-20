-- The minimap button (MinimapButton.lua): made at login, named, on the minimap in the family's look with the logo's
-- emblem at its default angle in the family's layout (341); left-click opening and closing the settings, right-click
-- showing and hiding the bar, a click just after a drag ignored; dragged round the edge and saved once let go; a saved
-- angle kept over the default (the old default 340 included); its own hover box (level, how far, how long to the next,
-- the clicks); hidden by its tick or /xpbar minimap and back after a reset; and the minimap only read and hooked.
-- Run with fengari: Tools/TestMinimap.lua
local H = assert(loadfile("Tools/Harness.lua"))()
local S, Equal, True, Near = H.S, H.Equal, H.True, H.Near
local F, button

local function Fresh(saved, opts)
    H.Environment()
    rawset(Minimap, "GetCenter", function() return 900, 650 end)
    F = H.Load(saved or { version = 1, spot = { x = 0, y = -300 } }, opts)
    button = F.MinimapButton:Button()
    return F
end

Fresh(nil, { beforeLogin = true })
Equal(F.MinimapButton:Button(), nil, "not made before login")
H.Fire("PLAYER_LOGIN")
button = F.MinimapButton:Button()
True(button, "made at login")
Equal(ForeverEnhancedXPBarMinimapButton, button, "named, so minimap tidiers can find it")
Equal(S[button].width .. "x" .. S[button].height, "32x32", "a 32 px button")
Equal(S[button].parent, Minimap, "on the minimap")
True(S[button.icon].texture:find("MinimapIcon.tga", 1, true), "with the logo's emblem")
local p = S[button].points[1]
local a = math.rad(341)
Near(p[4], math.cos(a) * 74, .01, "at 341 degrees round the edge (x)")
Near(p[5], math.sin(a) * 74, .01, "(y)")
H.Fire("PLAYER_ENTERING_WORLD", true, false)
H.Frame()

-- Clicks.
button:Click("LeftButton")
True(F.window and F.window:IsShown(), "left-click opens the settings")
button:Click("LeftButton")
Equal(F.window:IsShown(), false, "and closes them")
local bar = F.Bar:Frame()
True(bar:IsShown(), "the bar shows")
button:Click("RightButton")
Equal(F:Get("showBar"), false, "right-click hides the bar")
Equal(bar:IsShown(), false, "at once")
button:Click("RightButton")
True(F:Get("showBar") and bar:IsShown(), "and shows it again")

-- Dragging.
H.cursor = { 900 - 100, 650 }
H.Script(button, "OnDragStart")
H.Script(button, "OnUpdate", .01)
p = S[button].points[1]
Near(p[4], -74, .01, "follows the cursor round the edge while dragging")
Equal(F:Get("minimapAngle"), 341, "not saved until let go")
H.Script(button, "OnDragStop")
Equal(F:Get("minimapAngle"), 180, "saved where it was let go")
button:Click("LeftButton")
Equal(F.window and F.window:IsShown() or false, false, "the click that ends a drag is ignored")
H.Advance(.3)

-- The hover box.
H.Script(button, "OnEnter")
local box = F.Tip:Box()
True(box:IsShown(), "hovering shows its own box")
Equal(H.Text(box.title), "Forever Enhanced XP Bar", "titled")
Equal(H.Text(box.labels[1]), "Level 24: 63.2%", "your level and how far through it")
Equal(H.Text(box.labels[2]), "Left-click", "no rate yet: straight to the clicks")
Equal(H.Text(box.values[3]), "hide the bar", "right-click hides the bar")
H.Script(button, "OnLeave")
Equal(box:IsShown(), false, "gone on leave")
H.GainXP(1000)
H.Advance(300)
H.Script(button, "OnEnter")
Equal(H.Text(box.labels[2]), "~32 min to level", "then how long to the next level")
button:Click("RightButton")
Equal(H.Text(box.values[4]), "show the bar", "and the box follows a right-click")
button:Click("RightButton")
H.Script(button, "OnLeave")

-- Hidden and back.
F:Set("minimap", false)
Equal(button:IsShown(), false, "the Extras tick hides it")
F:Reset()
True(button:IsShown(), "a reset brings it back")
Equal(F:Get("minimapAngle"), 341, "at its own spot")
H.printed = {}

-- A saved angle keeps winning over the default (a spot dragged to before the default moved stays put).
for _, saved in ipairs({ 200, 340 }) do
    Fresh({ version = 1, spot = { x = 0, y = -300 }, settings = { minimapAngle = saved } })
    Equal(F:Get("minimapAngle"), saved, "a saved " .. saved .. " kept")
    Equal(ForeverEnhancedXPBarDB.settings.minimapAngle, saved, "and still stored")
    p = S[button].points[1]
    a = math.rad(saved)
    Near(p[4], math.cos(a) * 74, .01, "placed at " .. saved .. " (x)")
    Near(p[5], math.sin(a) * 74, .01, "(y)")
end

-- At max level.
Fresh()
H.p.level, H.p.xp = 30, 0
H.Fire("PLAYER_LEVEL_UP", 30)
H.Frame()
H.Script(button, "OnEnter")
Equal(H.Text(F.Tip:Box().labels[1]), "Level 30, max level", "max level")
H.Script(button, "OnLeave")

-- The minimap is only read and hooked.
local scripts = {}
for key in pairs(S[Minimap].scripts) do scripts[#scripts + 1] = key end
Equal(table.concat(scripts, " "), "OnSizeChanged", "only its size followed, through a hook")
H.printed = {}
Equal(#H.violations, 0, "nothing else done to it")
Equal(H.Problems(), "", "nothing went wrong")
io.stdout:write("TestMinimap: " .. H.checks .. " checks passed\n")
