-- Kills.lua: patterns built from the game's own kill strings (every rested, tired, group and raid variant, the game's
-- magic characters escaped, positional %1$s, an unknown format refused), unnamed and quest lines left alone, a secret
-- line never read, each kill's base XP (the rested bonus taken off, a tired penalty put back), the last 20 kept, the
-- average from this level's kills once there are 3, and kills to level with both rested sums.
-- Run with fengari: Tools/TestKills.lua
local H = assert(loadfile("Tools/Harness.lua"))()
local Equal, True = H.Equal, H.True
local F, KL

local function Fresh(saved, before)
    H.Environment()
    if before then before() end
    F = H.Load(saved)
    KL = F.Kills
    return F
end

local function Line(name, ...)
    return H.STRINGS["COMBATLOG_XPGAIN_" .. name]:format(...)
end

-- Every kind of line -----------------------------------------------------------------------------------------------------------

Fresh()
local cases = {
    { Line("FIRSTPERSON", "Kobold Vermin", 62), "Kobold Vermin", 62, 0, 62, "plain" },
    { Line("FIRSTPERSON_GROUP", "Kobold Vermin", 74, 12), "Kobold Vermin", 74, 0, 74, "plain" },
    { Line("FIRSTPERSON_RAID", "Hogger", 40, 10), "Hogger", 40, 0, 40, "plain" },
    { Line("EXHAUSTION1", "Murloc Forager", 124, "+62", "Rested"), "Murloc Forager", 124, 62, 62, "bonus" },
    { Line("EXHAUSTION2", "Murloc Forager", 124, "+62", "Rested"), "Murloc Forager", 124, 62, 62, "bonus" },
    { Line("EXHAUSTION4", "Defias Thug", 31, "-31", "Tired"), "Defias Thug", 31, 31, 62, "penalty" },
    { Line("EXHAUSTION5", "Defias Thug", 16, "-46", "Exhausted"), "Defias Thug", 16, 46, 62, "penalty" },
    { Line("EXHAUSTION1_GROUP", "Young Wolf", 136, "+62", "Rested", 12), "Young Wolf", 136, 62, 74, "bonus" },
    { Line("EXHAUSTION2_GROUP", "Young Wolf", 136, "+62", "Rested", 12), "Young Wolf", 136, 62, 74, "bonus" },
    { Line("EXHAUSTION4_GROUP", "Young Wolf", 43, "-31", "Tired", 12), "Young Wolf", 43, 31, 74, "penalty" },
    { Line("EXHAUSTION5_GROUP", "Young Wolf", 28, "-46", "Exhausted", 12), "Young Wolf", 28, 46, 74, "penalty" },
    { Line("EXHAUSTION1_RAID", "Mr. Smite (Elite)", 100, "+50", "Rested", 10), "Mr. Smite (Elite)", 100, 50, 50, "bonus" },
    { Line("EXHAUSTION2_RAID", "Mr. Smite (Elite)", 100, "+50", "Rested", 10), "Mr. Smite (Elite)", 100, 50, 50, "bonus" },
    { Line("EXHAUSTION4_RAID", "Mr. Smite (Elite)", 25, "-25", "Tired", 10), "Mr. Smite (Elite)", 25, 25, 50, "penalty" },
    { Line("EXHAUSTION5_RAID", "Mr. Smite (Elite)", 12, "-38", "Exhausted", 10), "Mr. Smite (Elite)", 12, 38, 50, "penalty" },
}
for _, case in ipairs(cases) do
    local kill = KL.Parse(case[1])
    True(kill, "read: " .. case[1])
    Equal(kill.name, case[2], case[1] .. ": the name")
    Equal(kill.total, case[3], case[1] .. ": the XP")
    Equal(kill.bonus, case[4], case[1] .. ": the bonus or penalty")
    Equal(kill.base, case[5], case[1] .. ": the base XP")
    Equal(kill.kind, case[6], case[1] .. ": the kind")
end
for _, line in ipairs({ Line("FIRSTPERSON_UNNAMED", 50), Line("FIRSTPERSON_UNNAMED_GROUP", 60, 10),
    Line("FIRSTPERSON_UNNAMED_RAID", 40, 10), Line("QUEST", 50, "+25", "Rested"), "Experience gained: 450.",
    "Discovered Goldshire: 120 experience gained", "", "Kobold Vermin dies." }) do
    Equal(KL.Parse(line), nil, "not a kill: " .. line)
end
Equal(KL.Parse(" dies, you gain 62 experience."), nil, "a kill with no name isn't one")
Equal(KL.Parse(H.SecretString()), nil, "a secret line is never read")
Equal(KL.Parse(nil), nil, "nor nothing")
Equal(KL.Parse(Line("EXHAUSTION4", "Odd", 10, "-0", "Tired") .. "x"), nil, "anything after the line: not this kind")
Equal(#H.violations, 0, "no secret touched")

-- Patterns -----------------------------------------------------------------------------------------------------------------------

local built = KL.Pattern("%2$d XP from %1$s (100%%).")
Equal(built.pattern, "^(%d+) XP from (.-) %(100%%%)%.$", "positional, escaped, a literal percent")
Equal(table.concat(built.args, ","), "2,1", "which argument each capture is")
Equal(KL.Pattern("%s gains %.1f"), nil, "a format it doesn't know: no pattern")
Equal(KL.Pattern(""), nil, "an empty string: none")
Equal(KL.Pattern(nil), nil, "a missing string: none")
-- A client language with the name after the number.
Fresh(nil, function()
    H.STRINGS.COMBATLOG_XPGAIN_FIRSTPERSON = "Du erhältst %2$d Erfahrung, weil %1$s stirbt."
    _G.COMBATLOG_XPGAIN_FIRSTPERSON = H.STRINGS.COMBATLOG_XPGAIN_FIRSTPERSON
end)
local kill = KL.Parse("Du erhältst 58 Erfahrung, weil Kobold stirbt.")
Equal(kill and (kill.name .. " " .. kill.total), "Kobold 58", "positional arguments read in their own order")
H.STRINGS.COMBATLOG_XPGAIN_FIRSTPERSON = "%s dies, you gain %d experience."

-- Kills kept ---------------------------------------------------------------------------------------------------------------------

Fresh()
local char = F:Char()
H.Kill(Line("FIRSTPERSON_UNNAMED", 50))
Equal(#char.killSamples, 0, "an unnamed line isn't kept")
H.Kill(H.SecretString())
Equal(#char.killSamples, 0, "nor a secret one")
H.Kill(Line("EXHAUSTION1", "Murloc Forager", 124, "+62", "Rested"))
Equal(#char.killSamples, 1, "a kill kept")
Equal(char.killSamples[1].level .. " " .. char.killSamples[1].base, "24 62", "its level and base XP")
Equal(char.session.kills, 1, "counted this session")
for i = 1, 25 do H.Kill(Line("FIRSTPERSON", "Kobold", 60 + i)) end
Equal(#char.killSamples, 20, "the last 20 kept")
Equal(char.killSamples[1].base, 66, "the oldest dropped")

-- The average: this level's kills once there are 3.
Fresh({ version = 1, chars = { [H.guid] = { seen = time(), killSamples = {
    { level = 23, base = 40 }, { level = 23, base = 40 }, { level = 24, base = 60 }, { level = 24, base = 62 } } } } })
Equal(KL:Average(24), (40 + 40 + 60 + 62) / 4, "two at this level: all of them")
H.Kill(Line("FIRSTPERSON", "Kobold", 64))
Equal(KL:Average(24), (60 + 62 + 64) / 3, "three at this level: only those")
Equal(KL:Average(25), (40 + 40 + 60 + 62 + 64) / 5, "a new level: all again")

-- The sums ---------------------------------------------------------------------------------------------------------------------------

Equal(KL.MODEL, "whole", "the rested pool is used by the whole kill until probe P6 says otherwise")
Equal(KL.Count(1000, 0, 50, 2), 20, "no rested XP: what's left over a kill's XP")
Equal(KL.Count(1000, 2000, 50, 2), 10, "rested covers it all: double XP each")
Equal(KL.Count(1000, 400, 50, 2, "whole"), 16, "whole: 4 rested kills use the pool, 12 plain ones after")
Equal(KL.Count(1000, 400, 50, 2, "bonus"), 12, "bonus only: 8 rested kills, then 4 plain ones")
Equal(KL.Count(1000, 600, 50, 2, "bonus"), 10, "bonus only: the pool covers it all")
Equal(KL.Count(1000, 400, 50, 1.5, "whole"), math.ceil(400 / 75 + 600 / 50), "the game's own factor")
Equal(KL.Count(1000, 400, 50, 1), 20, "a factor of 1: no rested boost")
Equal(KL.Count(0, 400, 50, 2), 0, "nothing left: none")
Equal(KL.Count(300, 0, 100, 2), 3, "exactly three")

-- Kills to level, from the game's numbers.
Fresh({ version = 1, chars = { [H.guid] = { seen = time(), killSamples = {
    { level = 24, base = 62 }, { level = 24, base = 62 }, { level = 24, base = 62 } } } } })
local count, base, rich = KL:ToLevel()
Equal(count, math.ceil(4200 / 124 + (7250 - 4200) / 62), "7,250 to go with 4,200 rested")
Equal(base, 62, "62 XP a kill")
Equal(rich, 124, "124 while rested")
H.p.rested = nil
H.Fire("UPDATE_EXHAUSTION")
H.Frame()
count, base, rich = KL:ToLevel()
Equal(count, math.ceil(7250 / 62), "no rested XP: what's left over a kill's XP")
Equal(rich, nil, "and no rested kill")
H.p.rested, H.p.restState = 1000, { 1, "Rested", 1.5 }
H.Fire("UPDATE_EXHAUSTION")
H.Frame()
count, base, rich = KL:ToLevel()
Equal(rich, 93, "the game's own factor")
H.p.restState = { 2, "Normal", 1 }
H.Fire("UPDATE_EXHAUSTION")
H.Frame()
count, base, rich = KL:ToLevel()
Equal(rich, 124, "a factor of 1 with rested XP left: taken as double")
H.p.off = true
H.Fire("DISABLE_XP_GAIN")
H.Frame()
Equal(KL:ToLevel(), nil, "XP off: none")
Fresh()
Equal(KL:ToLevel(), nil, "no kills yet: not known")

-- Dev mode: the rested pool before and after a kill.
Fresh()
SlashCmdList.FOREVERENHANCEDXPBAR("dev")
H.Kill(Line("EXHAUSTION1", "Murloc Forager", 124, "+62", "Rested"))
H.p.rested = 4200 - 124
H.Advance(.6)
local entry = ForeverEnhancedXPBarDB.dev.kills[1]
Equal(entry.restedBefore .. " " .. entry.restedAfter, "4200 4076", "saved for /reload")
H.printed = {}

Equal(#H.violations, 0, "Blizzard's frames only read")
Equal(H.Problems(), "", "nothing went wrong")
io.stdout:write("TestKills: " .. H.checks .. " checks passed\n")
