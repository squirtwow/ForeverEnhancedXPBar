-- Quests.lua: the XP waiting in finished quests (headers, hidden and task quests left out, only quests the game says are
-- complete, their reward XP summed), read once a frame however many events come and never at login before the log
-- says it changed; "levels you up" (exactly the XP left counts); hand-ins counted this level and this session, and a
-- handed-in quest the log still lists left out for 2 seconds; the last 10 rewards kept for the average; quests to
-- level, or "hand in" when the finished quests already cover it.
-- Run with fengari: Tools/TestQuests.lua
local H = assert(loadfile("Tools/Harness.lua"))()
local Equal, True = H.Equal, H.True
local F, QS

local LOG = {
    { questID = 1, title = "Elwynn Forest", isHeader = true },
    { questID = 101, title = "Wolves Across the Border", complete = true, xp = 900 },
    { questID = 102, title = "Kobold Camp Cleanup", complete = false, xp = 1200 },
    { questID = 103, title = "Hidden", complete = true, xp = 500, isHidden = true },
    { questID = 104, title = "A bonus area", complete = true, xp = 700, isTask = true },
    { questID = 105, title = "Report to Goldshire", complete = true, xp = 960 },
    { questID = 106, title = "No XP", complete = true, xp = 0 },
}

local function Fresh(saved)
    H.Environment()
    for i, q in ipairs(LOG) do
        local copy = {}
        for k, v in pairs(q) do copy[k] = v end
        H.quests[i] = copy
    end
    F = H.Load(saved)
    QS = F.Quests
    return F
end

-- The sum -------------------------------------------------------------------------------------------------------------------

Fresh()
Equal(QS.sum, 0, "nothing read at login before the log says it changed")
Equal(H.questReads, 0, "the log not asked yet")
H.Fire("QUEST_LOG_UPDATE")
H.Fire("QUEST_LOG_UPDATE")
H.Fire("QUEST_LOG_UPDATE")
Equal(QS.sum, 0, "read on the next frame, not at once")
H.Frame()
Equal(QS.sum, 900 + 960, "finished quests' XP: headers, hidden, task and unfinished ones left out")
Equal(QS.count, 2, "in two quests (one with no XP doesn't count)")
Equal(H.questReads, 4, "the log read once for three events (four quests asked about)")
H.quests[3].complete = true
H.Fire("QUEST_LOG_UPDATE")
H.Frame()
Equal(QS.sum, 900 + 960 + 1200, "a quest finished")
Equal(QS:LevelsUp(), false, "12,450 + 3,060 doesn't reach 19,700")
H.p.xp = 17000
H.Fire("PLAYER_XP_UPDATE", "player")
H.Frame()
True(QS:LevelsUp(), "17,000 + 3,060 does: it levels you up")
Equal(QS:ToLevel(), "handIn", "quests to level: hand them in")
H.p.xp = 19700 - 3060
H.Fire("PLAYER_XP_UPDATE", "player")
H.Frame()
True(QS:LevelsUp(), "exactly the XP left: that levels you up too")
H.p.xp = 19700 - 3060 - 1
H.Fire("PLAYER_XP_UPDATE", "player")
H.Frame()
Equal(QS:LevelsUp(), false, "one XP short: it doesn't")
H.p.xp = 17000
H.Fire("PLAYER_XP_UPDATE", "player")
H.Frame()
H.quests[2].xp = function() return H.SecretNumber() end
H.Fire("QUEST_LOG_UPDATE")
H.Frame()
Equal(QS.sum, 960 + 1200, "a secret reward is left out")
Equal(#H.violations, 0, "and never touched")
H.quests[2].xp = 900

-- Each trigger reads the log again.
for _, event in ipairs({ "QUEST_REMOVED", "PLAYER_LEVEL_UP" }) do
    H.quests[6].complete = false
    H.Fire(event, 6)
    H.Frame()
    Equal(QS.count, 2, event .. " reads the log again")
    H.quests[6].complete = true
    H.Fire("QUEST_LOG_UPDATE")
    H.Frame()
end
local heard = 0
F:Listen(function(what) if what == "quests" then heard = heard + 1 end end)
H.Fire("QUEST_LOG_UPDATE")
H.Frame()
Equal(heard, 0, "nothing changed: nobody told")

-- Hand-ins -------------------------------------------------------------------------------------------------------------------

Fresh()
H.Fire("QUEST_LOG_UPDATE")
H.Frame()
local char = F:Char()
H.quests[2].complete = nil
table.remove(H.quests, 2)
H.Fire("QUEST_TURNED_IN", 101, 900, 50)
Equal(char.questsLevel .. " " .. char.session.quests, "1 1", "a hand-in counted this level and this session")
H.Frame()
Equal(QS.sum, 960, "and the log read again")
H.Fire("QUEST_TURNED_IN", 200, 0, 0)
Equal(char.questsLevel, 2, "a hand-in with no XP still counts as done")
Equal(#char.questSamples, 1, "but not for the average")
H.Fire("QUEST_TURNED_IN", 201, H.SecretNumber(), 0)
Equal(char.questsLevel .. " " .. #char.questSamples, "3 1", "a secret reward: counted, not kept")
for i = 1, 12 do H.Fire("QUEST_TURNED_IN", 300 + i, 1000 + i * 10, 0) end
Equal(#char.questSamples, 10, "the last 10 rewards kept")
Equal(char.questSamples[1], 1030, "the oldest dropped")
local average = QS:Average()
Equal(average, (1030 + 1120) / 2, "their average")
H.Frame()
local remaining = 19700 - 12450
local count, avg = QS:ToLevel()
Equal(count, math.ceil(remaining / average), "quests to level: what's left over the average")
Equal(avg, average, "with the average")
Equal(char.session.quests, 15, "fifteen this session")

-- The log can still list a quest a moment after its hand-in, its XP already yours: it's left out meanwhile, so it isn't
-- counted twice.
Fresh()
H.Fire("QUEST_LOG_UPDATE")
H.Frame()
Equal(QS.sum, 900 + 960, "two finished quests")
H.Fire("QUEST_TURNED_IN", 101, 900, 0)
H.Frame()
Equal(QS.sum, 960, "one handed in but still listed: left out")
H.Advance(1.5)
H.Fire("QUEST_LOG_UPDATE")
H.Frame()
Equal(QS.sum, 960, "still left out a moment later")
H.Advance(1)
H.Fire("QUEST_LOG_UPDATE")
H.Frame()
Equal(QS.sum, 900 + 960, "only for a moment: still listed 2 seconds on, it counts again")
H.Fire("QUEST_TURNED_IN", H.SecretNumber(), 100, 0)
H.Frame()
Equal(QS.sum, 900 + 960, "a secret quest ID: nothing left out")
Equal(#H.violations, 0, "and never touched")

-- Not known, at max, off.
Fresh()
Equal(QS:ToLevel(), nil, "no hand-ins yet: not known")
H.p.off = true
H.Fire("DISABLE_XP_GAIN")
F:Char().questSamples[1] = 500
H.Frame()
Equal(QS:ToLevel(), nil, "XP off: none")
H.Environment()
H.p.level, H.p.xp = 30, 0
F = H.Load({ version = 1, chars = { [H.guid] = { seen = time(), questSamples = { 500 } } } })
QS = F.Quests
Equal(QS:ToLevel(), nil, "at max level: none")
H.quests = { { questID = 9, title = "Banked", complete = true, xp = 4000 } }
H.Fire("QUEST_LOG_UPDATE")
H.Frame()
Equal(QS.sum, 4000, "but the XP waiting is still read at max level")
Equal(QS:LevelsUp(), false, "and never levels you up there")

H.printed = {}
Equal(#H.violations, 0, "Blizzard's frames only read")
Equal(H.Problems(), "", "nothing went wrong")
io.stdout:write("TestQuests: " .. H.checks .. " checks passed\n")
