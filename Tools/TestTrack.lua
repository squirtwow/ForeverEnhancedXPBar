-- Track.lua: reading the game (level, XP, rested, the cap, XP off; a secret or missing value keeps the last good one),
-- the gains (the difference, across a level-up, a drop, the first read, a level-up seen before its numbers or its
-- numbers before the level, and the 5-second limit on that wait either way; a timer's error said once), the session
-- (a login starts one, a /reload keeps it and its snapshot, a relog starts another), XP per hour over 15 minutes, an
-- hour or the session with its 5-minute floor, next level in, time on this level (folded at logout, exact after a
-- level-up or the game's played time, "at least" before), and askPlayed asking only when ticked, at login, while not
-- exact.
-- Run with fengari: Tools/TestTrack.lua
local H = assert(loadfile("Tools/Harness.lua"))()
local Equal, True, Near = H.Equal, H.True, H.Near
local F, TR

local function Fresh(saved, opts)
    H.Environment()
    F = H.Load(saved, opts)
    TR = F.Track
    return F
end

local function Session() return F:Char().session end

-- Reading ---------------------------------------------------------------------------------------------------------------------

Fresh()
local st = TR.now
Equal(st.level .. " " .. st.xp .. " " .. st.max .. " " .. st.rested, "24 12450 19700 4200", "read at login")
Equal(st.cap, 30, "the cap: the lower of the expansion's and the player's")
Equal(st.restId .. " " .. st.restName .. " " .. st.factor, "1 Rested 2", "the rest state")
Equal(TR:AtMax(), false, "not at max")
Equal(TR:Remaining(), 7250, "XP still to go")
H.p.rested = nil
H.Fire("UPDATE_EXHAUSTION")
H.Frame()
Equal(st.rested, 0, "no rested XP (nil) counts as none")
H.p.rested = 900
H.p.capExpansion = nil
H.Fire("PLAYER_MAX_LEVEL_UPDATE", "player")
H.Frame()
Equal(st.cap, 60, "one cap missing: the other")
Equal(st.rested, 900, "rested back")

-- Secrets and missing values keep the last good one.
H.p.xp = function() return H.SecretNumber() end
H.p.rested = function() return H.SecretNumber() end
H.p.level = function() return H.SecretNumber() end
H.p.off = function() return H.SecretBool() end
H.p.restState = { function() return H.SecretNumber() end, function() return H.SecretString() end, 2 }
H.Fire("PLAYER_XP_UPDATE", "player")
H.Frame()
Equal(st.xp .. " " .. st.rested .. " " .. st.level .. " " .. tostring(st.off), "12450 900 24 false", "secrets ignored")
Equal(st.restId, nil, "a secret rest state isn't kept")
Equal(Session().xp, 0, "and no gain made up")
Equal(#H.violations, 0, "no secret touched")
H.p.xp, H.p.level, H.p.off, H.p.rested, H.p.restState = 12450, 24, false, 900, { 1, "Rested", 2 }

-- Gains -------------------------------------------------------------------------------------------------------------------------

Fresh()
Equal(Session().xp, 0, "the first read is a snapshot, not a gain")
H.GainXP(100)
Equal(Session().xp, 100, "same level: the difference")
Equal(#Session().gains, 1, "noted for the rate")
H.GainXP(7250 - 100 + 150)
Equal(H.p.level .. " " .. H.p.xp, "25 150", "levelled up")
Equal(Session().xp, 100 + 7150 + 150, "across a level-up: the rest of the old level plus the new XP")
local snap = F:Char().snap
Equal(snap.level .. " " .. snap.xp .. " " .. snap.max, "25 150 20800", "the snapshot moved on")
-- A level-up whose numbers come a moment later.
local before = Session().xp
H.Fire("PLAYER_LEVEL_UP", 26)
H.Frame()
Equal(Session().xp, before, "the new level with the old numbers: nothing yet")
Equal(F:Char().snap.level, 25, "and the snapshot kept")
H.p.level, H.p.xp, H.p.max = 26, 50, 21900
H.Fire("PLAYER_XP_UPDATE", "player")
H.Frame()
Equal(Session().xp, before + (20800 - 150) + 50, "then counted once the numbers come")
-- UnitLevel lagging the event.
H.p.level = 26
H.p.xp, H.p.max = 21800, 21900
H.Fire("PLAYER_XP_UPDATE", "player")
H.Frame()
before = Session().xp
H.p.xp, H.p.max = 40, 23000
H.Fire("PLAYER_LEVEL_UP", 27)
H.Fire("PLAYER_XP_UPDATE", "player")
H.Frame()
Equal(TR.now.level, 27, "the level from the event when UnitLevel lags")
Equal(Session().xp, before + 100 + 40, "and the gain across it")
H.p.level = 27
-- A drop is no gain.
before = Session().xp
H.p.xp = 10
H.Fire("PLAYER_XP_UPDATE", "player")
H.Frame()
Equal(Session().xp, before, "XP down: no gain")
Equal(F:Char().snap.xp, 10, "a new snapshot")
H.GainXP(5)
Equal(Session().xp, before + 5, "and counting goes on from it")
-- Several events in one frame make one refresh.
before = Session().xp
H.p.xp = H.p.xp + 30
H.Fire("PLAYER_XP_UPDATE", "player")
H.Fire("UPDATE_EXHAUSTION")
H.Fire("PLAYER_UPDATE_RESTING")
H.Frame()
Equal(Session().xp, before + 30, "counted once")

-- XP off.
H.p.off = true
H.Fire("DISABLE_XP_GAIN")
H.Frame()
True(TR:Off(), "XP gain off")
before = Session().xp
H.GainXP(50)
Equal(Session().xp, before, "no gains counted while it's off")
Equal(TR:EtaSeconds(), nil, "and no next level")
H.p.off = false
H.Fire("ENABLE_XP_GAIN")
H.Frame()
Equal(TR:Off(), false, "back on")

-- Max level.
H.Environment()
H.p.level, H.p.xp, H.p.max = 29, 21000, 21100
F = H.Load()
TR = F.Track
H.GainXP(500)
Equal(H.p.level, 30, "at the cap")
True(TR:AtMax(), "at max level")
Equal(TR:Remaining(), 0, "nothing to go")
Equal(Session().xp, 100, "the last bit counted")
before = Session().xp
H.GainXP(500)
Equal(Session().xp, before, "then gains stop")
Equal(TR:EtaSeconds(), nil, "no next level")

-- A level-up whose numbers come before the level (the other order).
Fresh()
H.p.xp, H.p.max = 150, 20800
H.Fire("PLAYER_XP_UPDATE", "player")
H.Frame()
Equal(Session().xp, 0, "the next level's numbers with the old level: nothing yet")
snap = F:Char().snap
Equal(snap.level .. " " .. snap.xp .. " " .. snap.max, "24 12450 19700", "and the snapshot kept")
H.p.level = 25
H.Fire("PLAYER_LEVEL_UP", 25)
H.Frame()
Equal(Session().xp, 7250 + 150, "then counted once the level comes")
for _ = 1, 5 do H.GainXP(100) end
Equal(Session().xp, 7250 + 150 + 500, "and counting goes on at the new level")
H.GainXP(5000)
Equal(Session().xp, 7250 + 150 + 500 + 5000, "a big hand-in too")
snap = F:Char().snap
Equal(snap.level .. " " .. snap.xp .. " " .. snap.max, "25 5650 20800", "the snapshot at the new level")
-- Half a level-up whose other half never comes: the wait ends after 5 seconds.
Fresh()
H.p.max = 19800
H.Fire("PLAYER_XP_UPDATE", "player")
H.Frame()
H.GainXP(100)
Equal(Session().xp, 0, "a new max at the same level: waiting")
H.Advance(4.5)
Equal(Session().xp, 0, "still waiting after 4.5 seconds")
H.Advance(1)
Equal(Session().xp, 100, "after 5: the numbers taken as they are (the same level: the difference)")
Equal(F:Char().snap.max, 19800, "with the new max")
H.GainXP(50)
Equal(Session().xp, 150, "and counting goes on")
Fresh()
H.Fire("PLAYER_LEVEL_UP", 25)
H.Frame()
H.Advance(4.5)
Equal(Session().xp, 0, "a level-up whose numbers never come: waiting")
H.Advance(1)
Equal(Session().xp, 0, "after 5: a new snapshot at the new level, no gain made up")
Equal(F:Char().snap.level, 25, "at the new level")
H.GainXP(100)
Equal(Session().xp, 100, "and counting goes on")

-- The session --------------------------------------------------------------------------------------------------------------------

Fresh()
local first = Session()
Equal(first.start, time(), "a login starts a session")
H.GainXP(200)
H.Advance(120)
F = H.Reload()
TR = F.Track
Equal(Session(), first, "a /reload keeps it")
H.GainXP(50)
Equal(Session().xp, 250, "and its count")
-- XP gained during the reload itself (between logout and the new copy's first read) still counts.
H.Fire("PLAYER_LOGOUT")
H.p.xp = H.p.xp + 70
F = H.Reload2(ForeverEnhancedXPBarDB, { reload = true })
TR = F.Track
Equal(Session().xp, 320, "the snapshot is kept through a /reload")
-- A relog starts again, and XP from elsewhere isn't counted.
H.Fire("PLAYER_LOGOUT")
H.p.xp = H.p.xp + 1000
F = H.Reload2(ForeverEnhancedXPBarDB, {})
TR = F.Track
True(Session() ~= first, "a new login: a new session")
Equal(Session().xp, 0, "starting at nought: XP from elsewhere not counted")
H.Advance(5)
TR:NewSession()
Equal(Session().start, time(), "a new session on asking")

-- XP per hour ----------------------------------------------------------------------------------------------------------------------

Fresh()
Equal(TR:Rate(), nil, "no gain yet: no rate")
H.GainXP(1000)
H.Advance(30)
Equal(TR:Rate(), nil, "not before a minute of session")
H.Advance(30)
Near(TR:Rate(), 1000 / 300 * 3600, .01, "never over less than 5 minutes")
H.Advance(540)
H.GainXP(1000)
Near(TR:Rate(), 2000 / 600 * 3600, .01, "the last hour, from the session's start")
F:Set("rateWindow", "15m")
Near(TR:Rate(), 2000 / 600 * 3600, .01, "15 minutes: the same while the session is younger")
H.Advance(1200)
Equal(TR:Rate(), 0, "15 minutes with no gains: nought")
F:Set("rateWindow", "1h")
Near(TR:Rate(), 2000 / 1800 * 3600, .01, "the last hour over 30 minutes")
F:Set("rateWindow", "session")
Near(TR:Rate(), 2000 / 1800 * 3600, .01, "the whole session")
F:Set("rateWindow", "1h")
H.Advance(3600)
H.GainXP(500)
Equal(#Session().gains, 1, "gains older than an hour dropped")
Near(TR:Rate(), 500 / 3600 * 3600, .01, "and the hour only counts the new one")
H.GainXP(20)
Equal(#Session().gains, 1, "gains within 5 seconds share an entry")
H.Advance(6)
H.GainXP(20)
Equal(#Session().gains, 2, "later ones don't")
for _ = 1, 800 do
    H.Advance(5, 5)
    H.GainXP(1)
end
True(#Session().gains <= 721, "an hour is at most 720 entries")

-- Next level in.
Fresh()
H.GainXP(1000)
H.Advance(300)
local rate = TR:Rate()
Near(rate, 12000, .01, "12,000 XP an hour")
Near(TR:EtaSeconds(), (19700 - 13450) / 12000 * 3600, .01, "what's left at that rate")
Equal(F.Eta(TR:EtaSeconds()), "~32 min", "about half an hour")

-- Time on this level --------------------------------------------------------------------------------------------------------------

Fresh()
local char = F:Char()
local seconds, exact = TR:LevelSeconds()
Equal(math.floor(seconds) .. " " .. tostring(exact), "0 false", "a first run: counting from now, not exact")
Equal(char.levelAt, 24, "for this level")
H.Advance(3600)
seconds, exact = TR:LevelSeconds()
Near(seconds, 3600, .1, "an hour counted")
H.Fire("PLAYER_LOGOUT")
Near(char.levelSeconds, 3600, .1, "folded at logout (a /reload sends it too)")
F = H.Reload2(ForeverEnhancedXPBarDB, { reload = true })
TR = F.Track
H.Advance(600)
Near(TR:LevelSeconds(), 4200, .2, "and carried on after the /reload")
H.Fire("TIME_PLAYED_MSG", 100000, 5000)
seconds, exact = TR:LevelSeconds()
Equal(math.floor(seconds) .. " " .. tostring(exact), "5000 true", "the game's played time: exact")
Equal(F:Char().played.total, 100000, "total played kept")
H.Advance(60)
Near(TR:LevelSeconds(), 5060, .1, "counting on from it")
H.Fire("TIME_PLAYED_MSG", H.SecretNumber(), H.SecretNumber())
Near(TR:LevelSeconds(), 5060, .1, "a secret answer ignored")
F:Char().questsLevel = 4
H.GainXP(7300)
seconds, exact = TR:LevelSeconds()
Equal(math.floor(seconds) .. " " .. tostring(exact), "0 true", "a level-up seen: nought, exact")
Equal(F:Char().questsLevel, 0, "and quests this level start again")
Equal(F:Char().levelAt, 25, "for the new level")
H.Advance(120)
-- Levelled while the addon wasn't watching.
H.Fire("PLAYER_LOGOUT")
H.p.level, H.p.xp, H.p.max = 26, 10, 21900
F = H.Reload2(ForeverEnhancedXPBarDB, {})
TR = F.Track
seconds, exact = TR:LevelSeconds()
Equal(math.floor(seconds) .. " " .. tostring(exact), "0 false", "a level changed elsewhere: not exact again")

-- Asking for played time ------------------------------------------------------------------------------------------------------------

Fresh()
H.Advance(10)
Equal(H.playedAsked, 0, "never asked with the tick off")
H.Environment()
F = H.Load({ version = 1, settings = { askPlayed = true } })
H.Advance(4)
Equal(H.playedAsked, 0, "with it on: not at once")
H.Advance(2)
Equal(H.playedAsked, 1, "but a few seconds after login")
H.Fire("TIME_PLAYED_MSG", 9000, 300)
H.Fire("PLAYER_LOGOUT")
F = H.Reload2(ForeverEnhancedXPBarDB, {})
H.Advance(10)
Equal(H.playedAsked, 1, "not again once exact")
F:Char().levelExact = false
H.Fire("PLAYER_LOGOUT")
F = H.Reload2(ForeverEnhancedXPBarDB, { reload = true })
H.Advance(10)
Equal(H.playedAsked, 1, "never on a /reload")

-- A timer's error is said once in chat, as an event's is, and counting goes on once it clears.
Fresh()
H.printed = {}
H.p.level = function() error("level broke") end
H.Fire("PLAYER_XP_UPDATE", "player")
H.Frame()
H.Fire("PLAYER_XP_UPDATE", "player")
H.Frame()
Equal(#H.printed, 1, "a refresh's error said once")
True(H.printed[1]:find("The numbers part hit an error and stopped: ", 1, true), "as Core's one line")
H.p.level = 24
H.GainXP(100)
Equal(Session().xp, 100, "then counting goes on")

H.printed = {}
Equal(#H.violations, 0, "Blizzard's frames only read")
Equal(H.Problems(), "", "nothing went wrong")
io.stdout:write("TestTrack: " .. H.checks .. " checks passed\n")
