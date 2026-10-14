-- The /xpbar settings window (Window.lua): built from Core's rows (four pages, ticks, choices, the width slider and the
-- action buttons), changes applied to the real bar at once, the footer explaining what's hovered (the credit at rest), a
-- blocked row greyed with its reason, Move the bar and Put the bar back, Start a new session and Reset all settings asking
-- first (a double click can't do either), the Escape list, and the status line following your XP.
-- Run with fengari: Tools/TestWindow.lua
local H = assert(loadfile("Tools/Harness.lua"))()
local S, Equal, True = H.S, H.Equal, H.True
local F, window

local function Fresh(saved, setup)
    H.Environment()
    H.StatusSetup()
    H.ShowXPIn(1)
    if setup then setup() end
    F = H.Load(saved or { version = 1, spot = { x = 0, y = -300 } })
    F.ShowWindow()
    window = F.window
    return F
end

local function Note()
    return H.Text(window.note) or ""
end

Fresh()
True(window:IsShown(), "opens")
Equal(ForeverEnhancedXPBarSettings, window, "named ForeverEnhancedXPBarSettings")
Equal(UISpecialFrames[1], "ForeverEnhancedXPBarSettings", "on the game's Escape list")
Equal(S[window].width .. "x" .. S[window].height, "820x560", "its size, set when made")
local pages = {}
for _, page in ipairs(F.PAGES) do pages[#pages + 1] = page.label end
Equal(table.concat(pages, ", "), "The bar, Hover details, Extras, Good to know", "four pages")
Equal(window.selected, "bar", "The bar first")
for key in pairs(F.ROWS) do True(window.controls[key], "a control for " .. key) end
for _, key in ipairs({ "move", "putBack", "newSession" }) do True(window.actions[key], "a button for " .. key) end
Equal(#window.cards, #F.GOOD_TO_KNOW, "Good to know: one card each")
Equal(H.Text(window.status), "Level 24: 63.2%", "your level and how far through it")
True(S[window.controls.hideGameBar.tag] and H.Text(window.controls.hideGameBar.tag) == "experimental",
    "hiding the game's bar: a quiet tag")

-- Ticks, choices and the slider change the real bar at once.
local bar = F.Bar:Frame()
local border = window.controls.border
Equal(border:GetChecked(), true, "Border round the bar ticked")
border:Click()
Equal(F:Get("border"), false, "a click turns it off")
Equal(border:GetChecked(), false, "and the tick follows")
Equal(F.Bar:Parts().edges[1]:IsShown(), false, "the bar's border goes at once")
border:Click()
window.controls.size.options.buttons.thick:Click()
Equal(F:Get("size"), "thick", "a choice")
Equal(window.controls.size.options.selected, "thick", "shows what's chosen")
Equal(S[bar].height, 26, "and the bar is Thick at once")
window.controls.size.options.buttons.large:Click()
Equal(S[bar].height, 34, "and back to Large")
window.controls.lineUnder:Click()
Equal(F:Get("lineUnder"), false, "the line under the bar unticked")
Equal(F.Bar:Parts().line:IsShown(), false, "and gone at once")
window.controls.lineUnder:Click()
window.controls.questStripes:Click()
Equal(S[F.Bar:Parts().quest].texture, "Interface\\AddOns\\ForeverEnhancedXPBar\\Media\\Stripes.tga", "stripes at once")
window.controls.questStripes:Click()
local width = window.controls.width
Equal(width.current, 800, "the width slider shows the width")
Equal(width.limits[2], 1020, "up to the screen's width")
width:Choose(1003)
Equal(F:Get("width"), 1000, "snapped to steps of 10")
Equal(S[bar].width, 1000, "the bar follows at once")
width:Choose(5000)
Equal(F:Get("width"), 1020, "never past the screen")
H.Script(width, "OnMouseWheel", -1)
Equal(F:Get("width"), 1010, "the wheel moves it a step")
width:Choose(50)
Equal(F:Get("width"), 200, "never under 200")
F:Set("width", 800)
Equal(width.current, 800, "and it follows the setting")
window.nav.details:Click()
window.controls.rateWindow.options.buttons["15m"]:Click()
Equal(F:Get("rateWindow"), "15m", "XP per hour over 15 minutes")
window.controls.dKills:Click()
Equal(F:Get("dKills"), false, "a detail unticked")
window.controls.dKills:Click()

-- The footer.
window.nav.bar:Click()
True(Note():find("Made with", 1, true), "at rest: the credit")
H.Script(window.controls.questSegment, "OnEnter")
True(Note():find("An amber part after your XP", 1, true), "hovering a row explains it")
H.Script(window.controls.questSegment, "OnLeave")
True(Note():find("Squirt", 1, true), "and back to the credit")
H.Script(window.controls.hideGameBar, "OnEnter")
True(Note():find("(experimental)", 1, true), "the tag said in words")
H.Script(window.controls.hideGameBar, "OnLeave")
H.Script(window.controls.dKills, "OnEnter")
True(Note():find("Made with", 1, true), "a row on a page not shown explains nothing")

-- The buttons.
window.actions.move:Click()
True(F.Bar:Moving(), "Move the bar")
Equal(window:IsShown(), false, "the window steps aside")
F.Bar:Mover().done:Click()
True(window:IsShown(), "and comes back on Done")
Equal(window.selected, "bar", "on The bar")
F:SetSpot(50, 50)
window.actions.putBack:Click()
Equal(F:Spot().x, 0, "Put the bar back")
True(Note():find("back above your action bars", 1, true), "and it says so")
window.nav.extras:Click()
local ask = window.asks.newSession
local session = F:Char().session
H.Advance(10)
window.actions.newSession:Click()
True(ask.asking and ask.yes:IsShown() and ask.no:IsShown(), "Start a new session asks first")
ask.yes:Click()
Equal(F:Char().session, session, "a click on Start straight away is ignored")
ask.no:Click()
Equal(ask.asking, false, "Cancel puts the button back")
window.actions.newSession:Click()
H.Advance(.6)
ask.yes:Click()
True(F:Char().session ~= session, "a new session")
True(Note():find("A new session has started.", 1, true), "said in the footer")
window.actions.newSession:Click()
window.nav.bar:Click()
Equal(ask.asking, false, "another page puts the question away")

-- Reset all settings asks first and keeps the numbers.
F:Set("size", "thin")
F:Char().questsLevel = 5
local reset = window.reset
reset.button:Click()
True(reset.asking and reset.yes:IsShown(), "Reset all settings asks first")
reset.yes:Click()
Equal(F:Get("size"), "thin", "a click on Reset straight away is ignored")
H.Advance(.6)
reset.yes:Click()
Equal(F:Get("size"), "large", "every setting back to its default")
True(F:Spot() ~= nil, "the bar placed again")
Equal(F:Char().questsLevel, 5, "your numbers kept")
True(H.printed[#H.printed]:find("Settings reset.", 1, true), "and it says so")
H.printed = {}
reset.button:Click()
window:Hide()
Equal(reset.asking, false, "closing the window puts the question away")
F.ShowWindow()

-- The status line follows your XP.
H.GainXP(1000)
Equal(H.Text(window.status), "Level 24: 68.3%", "the status line follows")
window.close:Click()
Equal(window:IsShown(), false, "the x closes it")

-- A blocked row ---------------------------------------------------------------------------------------------------------------------

Fresh(nil, function() H.EraSetup(true) end)
local hide = window.controls.hideGameBar
True(hide.blocked, "with EraUI's band on, hiding the game's bar is greyed")
Equal(S[hide.label].alpha, .4, "faded")
hide:Click()
Equal(F:Get("hideGameBar"), false, "and a click does nothing")
H.Script(hide, "OnEnter")
True(Note():find("stone band", 1, true), "the footer says why")
H.Script(hide, "OnLeave")
H.era.active = false
H.Advance(4)
Equal(hide.blocked, false, "the band gone: usable again")
hide:Click()
Equal(F:Get("hideGameBar"), true, "and it ticks")

-- A small screen: the window shrinks to fit.
Fresh(nil, function() S[UIParent].width, S[UIParent].height = 700, 500 end)
True(S[window].scale < 1, "a small screen: shrunk to fit")

H.printed = {}
Equal(#H.violations, 0, "Blizzard's frames only read")
Equal(H.Problems(), "", "nothing went wrong")
io.stdout:write("TestWindow: " .. H.checks .. " checks passed\n")
