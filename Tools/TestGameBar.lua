-- GameBar.lua: hiding the game's own XP bar is off by default and touches nothing; on, it fades both XP bars, and the frame
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

-- Off by default ------------------------------------------------------------------------------------------------------------------

Fresh()
Untouched("off by default")
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
Equal(#H.hooks, 2, "and on each container's UpdateDividers")
F:Set("hideGameBar", false)
F:Set("hideGameBar", true)
Equal(S[c1.bars[XP]].hooked.OnShow, 1, "hooked once only")
Equal(#H.hooks, 2, "both")

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

-- A reset puts it back.
Fresh({ version = 1, settings = { hideGameBar = true } })
True(G:Active(), "on from the saved setting at login")
Equal(Alpha(c1.bars[XP]), 0, "faded at login")
F:Reset()
Equal(Alpha(c1.bars[XP]), 1, "a reset puts it back")
H.printed = {}

-- In a fight.
Fresh()
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
