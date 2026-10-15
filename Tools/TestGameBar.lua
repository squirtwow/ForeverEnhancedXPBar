-- GameBar.lua: hiding the game's own XP bar is on by default; off, it touches nothing; on, it fades both XP bars, and the frame
-- art and dividers of the container holding XP only (and only pieces still showing); follows XP between the containers
-- and rebuilt dividers through post-hooks; puts back exactly what it changed; steps aside for EraUI's classic band (now,
-- predicted from its settings before it applies, or arriving later) and says why; never hides, moves or writes keys on the
-- game's frames, never their containers' alpha; and works in a fight.
-- Run with fengari: Tools/TestGameBar.lua
local H = assert(loadfile("Tools/Harness.lua"))()
local S, Equal, True = H.S, H.Equal, H.True
local F, G, c1, c2

local XP = 4

local function Fresh(saved, setup, opts)
    H.Environment()
    H.StatusSetup(opts)
    H.ShowXPIn(1)
    if setup then setup() end
    F = H.Load(saved)
    G = F.GameBar
    c1, c2 = H.containers[1], H.containers[2]
    return F
end

local function Alpha(obj) return S[obj].alpha end

local function Dividers(c, alpha)
    local n, all = 0, true
    for divider in c.HorizontalDividersPool:EnumerateActive() do
        n = n + 1
        if S[divider].alpha ~= alpha then all = false end
    end
    return all and n > 0, n
end

local function Untouched(label)
    Equal(#H.alphaSets, 0, label .. ": no alpha set")
    Equal(#H.hooks, 0, label .. ": no function hooked")
    Equal(S[c1.bars[XP]].hooked, nil, label .. ": no script hooked")
end

-- On by default (the user, 2026-10-14) ---------------------------------------------------------------------------------------

Fresh()
True(G:Active(), "a fresh install hides the game's bar")
Equal(Alpha(c1.bars[XP]) .. " " .. Alpha(c2.bars[XP]), "0 0", "both XP bars faded at login")

-- Off -------------------------------------------------------------------------------------------------------------------------------

Fresh({ version = 1, settings = { hideGameBar = false } })
Untouched("off")
Equal(G:Blocked(), nil, "nothing in the way")

-- On --------------------------------------------------------------------------------------------------------------------------------

F:Set("hideGameBar", true)
True(G:Active(), "on")
Equal(Alpha(c1.bars[XP]) .. " " .. Alpha(c2.bars[XP]), "0 0", "both XP bars faded")
Equal(Alpha(c1.BarFrameTexture), 0, "the frame art of the container holding XP faded")
True(Dividers(c1, 0), "and its dividers")
Equal(Alpha(c2.BarFrameTexture), 1, "the other container's art left alone")
True(Dividers(c2, 1), "and its dividers")
Equal(Alpha(c1) .. " " .. Alpha(c2), "1 1", "the containers' own alpha never touched")
Equal(Alpha(c1.bars[1]), 1, "nor the reputation bar")
Equal(S[c1.bars[XP]].hooked.OnShow .. " " .. S[c1.bars[XP]].hooked.OnHide, "1 1", "post-hooks on the XP bars' show and hide")
Equal(#H.hooks, 6, "and on each container's UpdateDividers, ApplyPendingBarToShow and UpdateShownState")
Equal(S[c1].hooked and S[c1].hooked.OnShow, 1, "and each container's show")
F:Set("hideGameBar", false)
F:Set("hideGameBar", true)
Equal(S[c1.bars[XP]].hooked.OnShow, 1, "hooked once only")
Equal(#H.hooks, 6, "all of them")

-- Seen in game (2026-10-15, after a /reload): the frame art and all 19 dividers back at full while the XP bar stayed
-- faded. Whatever puts them back, the next pass of the game's looks fades them again, and off still gives back what
-- they had before the first fade.
H.Blizzard(function()
    c1.BarFrameTexture:SetAlpha(1)
    for divider in c1.HorizontalDividersPool:EnumerateActive() do divider:SetAlpha(1) end
end)
Equal(Alpha(c1.BarFrameTexture), 1, "the art back at full (as in game)")
H.Blizzard(function() c1:UpdateShownState() end)
Equal(Alpha(c1.BarFrameTexture), 0, "the container's next pass fades it again")
True(Dividers(c1, 0), "and its dividers")
H.Blizzard(function() c1.BarFrameTexture:SetAlpha(1) end)
H.Blizzard(function() c1:ApplyPendingBarToShow() end)
Equal(Alpha(c1.BarFrameTexture), 0, "so does the container taking its bar")
-- The game showing XP in a container before the bar itself shows (at login): its art fades already.
F:Set("hideGameBar", false)
H.Blizzard(function() rawset(c2, "pendingBarToShowIndex", XP) end)
F:Set("hideGameBar", true)
Equal(Alpha(c2.BarFrameTexture), 0, "XP about to show in the second container: its art faded too")
H.Blizzard(function() rawset(c2, "pendingBarToShowIndex", nil) end)
F:Set("hideGameBar", false)
Equal(Alpha(c1.BarFrameTexture) .. " " .. Alpha(c2.BarFrameTexture), "1 1", "off: both back as they were")
F:Set("hideGameBar", true)

-- The close watch after a loading screen (dev log, 2026-10-15: the art and dividers set back to full twice in the first
-- seconds, outside any hooked function): faded again within a step, and the watch stops after its seconds.
Fresh()
H.Advance(1)
H.Blizzard(function()
    c1.BarFrameTexture:SetAlpha(1)
    for divider in c1.HorizontalDividersPool:EnumerateActive() do divider:SetAlpha(1) end
end)
H.Advance(.06)
Equal(Alpha(c1.BarFrameTexture), 0, "art set back at full a second in: faded again within a step")
True(Dividers(c1, 0), "and the dividers")
H.Advance(10, .05)
local watching = 0
for _, timer in ipairs(H.timers) do if timer.every == .05 and not timer.cancelled then watching = watching + 1 end end
Equal(watching, 0, "the watch stops after its seconds")
H.Blizzard(function() c1.BarFrameTexture:SetAlpha(1) end)
H.Advance(1)
Equal(Alpha(c1.BarFrameTexture), 1, "after it, nothing looks every step (a later reset waits for the game's own passes)")
H.Blizzard(function() c1:UpdateShownState() end)
Equal(Alpha(c1.BarFrameTexture), 0, "which still fade it")
F:Set("hideGameBar", false)
F:Set("hideGameBar", true)

-- XP moving to the second container (a faction watched).
H.ShowXPIn(2)
H.ShowRepIn(1)
Equal(Alpha(c1.BarFrameTexture), 1, "XP left the first container: its art back")
True(Dividers(c1, 1), "and its dividers")
Equal(Alpha(c2.BarFrameTexture), 0, "the second container's art faded")
True(Dividers(c2, 0), "and its dividers")
Equal(Alpha(c2.bars[XP]), 0, "its XP bar still faded")
Equal(Alpha(c1.bars[1]), 1, "the reputation bar shown as ever")
-- Dividers rebuilt: new ones come in showing.
H.RebuildDividers(c2, 30)
local all, n = Dividers(c2, 0)
True(all, "rebuilt dividers faded too")
Equal(n, 29, "all 29 of them")
-- And back.
H.ShowXPIn(1)
Equal(Alpha(c2.BarFrameTexture), 1, "XP back in the first container: the second's art back")
True(Dividers(c2, 1), "and its dividers")
Equal(Alpha(c1.BarFrameTexture), 0, "the first's faded again")

-- Putting back exactly.
F:Set("hideGameBar", false)
Equal(G:Active(), false, "off")
Equal(Alpha(c1.bars[XP]) .. " " .. Alpha(c2.bars[XP]), "1 1", "the XP bars back")
Equal(Alpha(c1.BarFrameTexture) .. " " .. Alpha(c2.BarFrameTexture), "1 1", "the art back")
True(Dividers(c1, 1) and Dividers(c2, 1), "the dividers back")
local sets = #H.alphaSets
H.ShowXPIn(2)
H.RebuildDividers(c1, 20)
Equal(#H.alphaSets, sets, "off: the hooks do nothing")
H.ShowXPIn(1)

-- What was faded already stays as it was; an XP bar's own alpha comes back as it was.
Fresh({ version = 1, settings = { hideGameBar = true } }, function() S[H.containers[2].bars[XP]].alpha = .7 end,
    { artAlpha = 0 })
Equal(Alpha(c1.BarFrameTexture), 0, "art already faded")
for _, set in ipairs(H.alphaSets) do
    True(set.obj ~= c1.BarFrameTexture, "and never set")
end
F:Set("hideGameBar", false)
Equal(Alpha(c1.BarFrameTexture), 0, "nor 'put back' to showing")
Equal(Alpha(c2.bars[XP]), .7, "an XP bar's own alpha put back exactly")

-- A reset brings back the default: hidden (on by default since 2026-10-14).
Fresh({ version = 1, settings = { hideGameBar = false } })
Equal(Alpha(c1.bars[XP]), 1, "off from the saved setting at login")
F:Reset()
True(G:Active(), "a reset switches it back on")
Equal(Alpha(c1.bars[XP]), 0, "and the bar fades")
H.printed = {}

-- In a fight.
Fresh({ version = 1, settings = { hideGameBar = false } })
H.Combat(true)
F:Set("hideGameBar", true)
Equal(Alpha(c1.bars[XP]), 0, "faded in a fight")
True(H.alphaSets[1].combat, "(it was in one)")
F:Set("hideGameBar", false)
Equal(Alpha(c1.bars[XP]), 1, "and back in one")
H.Combat(false)

-- EraUI's classic band ----------------------------------------------------------------------------------------------------------------

-- Active now.
Fresh({ version = 1, settings = { hideGameBar = true } }, function() H.EraSetup(true) end)
H.Advance(4)
Untouched("EraUI's band active")
Equal(G:Blocked(), "EraUI's classic bar keeps the game's XP bar in its stone band, so it stays while that's on.",
    "and it says why")
Equal(G:Active(), false, "not hiding")

-- Predicted from its settings before it applies, then not applied after all.
Fresh({ version = 1, settings = { hideGameBar = true } }, function() H.EraSetup(false) end)
Untouched("before EraUI applies, its settings say the band will")
True(G:Blocked(), "blocked meanwhile")
H.Advance(1)
Untouched("still waiting")
H.Advance(3)
True(G:Active(), "EraUI had its time and the band isn't there: hidden")
Equal(Alpha(c1.bars[XP]), 0, "faded")
Equal(G:Blocked(), nil, "no longer blocked")

-- EraUI with its classic bar off, or turned off: hidden at once.
Fresh({ version = 1, settings = { hideGameBar = true } }, function() H.EraSetup(false, { enabled = true, actionBars = false }) end)
True(G:Active(), "EraUI's classic bar off: hidden at once")
Fresh({ version = 1, settings = { hideGameBar = true } }, function() H.EraSetup(false, { enabled = false }) end)
True(G:Active(), "EraUI off: hidden at once")

-- The band arriving later: everything put back, the art left to EraUI.
Fresh({ version = 1, settings = { hideGameBar = true } })
True(G:Active(), "no EraUI: hidden")
local heard = false
F:Listen(function(what) if what == "band" then heard = true end end)
H.EraSetup(false)
H.era.active = true
H.Blizzard(function() c1.BarFrameTexture:SetAlpha(0) end) -- EraUI fades the art itself
H.Fire("PLAYER_ENTERING_WORLD", false, false)
H.Advance(.6)
Equal(G:Active(), false, "EraUI took the band: not hiding")
True(heard, "and the window told")
Equal(Alpha(c1.bars[XP]) .. " " .. Alpha(c2.bars[XP]), "1 1", "the XP bars back for EraUI's band")
Equal(Alpha(c1.BarFrameTexture), 0, "the art left as EraUI has it")
True(Dividers(c1, 0), "its dividers too")

-- No game bar at all.
H.Environment()
F = H.Load({ version = 1, settings = { hideGameBar = true } })
Equal(F.GameBar:Blocked(), "The game's XP bar wasn't found.", "no XP bar found: says so")

H.printed = {}
Equal(#H.violations, 0, "nothing hidden, moved or written on the game's frames, no container alpha")
Equal(H.Problems(), "", "nothing went wrong")
io.stdout:write("TestGameBar: " .. H.checks .. " checks passed\n")
