-- Your XP, read from the game: level, XP, rested, the level cap and whether XP gain is turned off. From them: the gains
-- (UnitXP differences, across a level-up too), the session (login to logout, kept through /reload), time on this level,
-- XP per hour over the chosen window (rateWindow) and when the next level comes. Asks the game for played time at login
-- only with askPlayed on, and only while the level timer isn't exact yet; otherwise it only listens for the answer to
-- the player's own /played.
--
-- Every XP event is folded into one refresh on the next frame. A level-up read in halves (the new level first, or the
-- new level's numbers first: the game's order isn't known) waits for the other half, for 5 seconds at most. Every value
-- read goes through F.Number / F.Bool / F.Text: a secret or a missing one keeps the last good one.
local _, F = ...

local TR = {}
F.Track = TR

local RATE_KEEP = 3600 -- seconds of gains kept for the rate
local RATE_BUCKET = 5 -- gains this close together share an entry (so an hour is at most 720 of them)
local RATE_FLOOR = 300 -- the rate is never worked out over less than this many seconds
local RATE_START = 60 -- nor before the session is this old
local WINDOWS = { ["15m"] = 900, ["1h"] = 3600 }
local ASK_DELAY = 5 -- seconds after login before askPlayed asks
local LEVEL_LOG = 5 -- seconds of XP events logged after a level-up in dev mode
local HALF_WAIT = 5 -- seconds the snapshot waits for the rest of a level-up before taking the numbers as they are
local XP_EVENTS = { "PLAYER_XP_UPDATE", "PLAYER_LEVEL_CHANGED", "PLAYER_MAX_LEVEL_UPDATE", "UPDATE_EXHAUSTION",
    "PLAYER_UPDATE_RESTING", "ENABLE_XP_GAIN", "DISABLE_XP_GAIN" }

-- The last good reading. level is nil until the game has said; cap is nil if the game won't say.
local now = { level = nil, xp = 0, max = 0, rested = 0, cap = nil, off = false, resting = false, restId = nil,
    restName = nil, factor = nil }
TR.now = now

local eventLevel -- the last PLAYER_LEVEL_UP level: UnitLevel can lag it
local entered = false -- this UI load's first PLAYER_ENTERING_WORLD has run
local foldedAt -- GetTime() when levelSeconds was last brought up to date
local pending = false
local logUntil = -math.huge
local waitFrom -- GetTime() when the snapshot began waiting for the rest of a level-up
local rechecking = false -- a look after HALF_WAIT is due

local N = F.Number

-- Reading the game ----------------------------------------------------------------------------------------------------------

local function ReadCap()
    local expansion = GetMaxLevelForPlayerExpansion and N(GetMaxLevelForPlayerExpansion())
    local player = GetMaxPlayerLevel and N(GetMaxPlayerLevel())
    if expansion and expansion <= 0 then expansion = nil end
    if player and player <= 0 then player = nil end
    if expansion and player then return math.min(expansion, player) end
    return expansion or player
end

function TR:Read()
    local level = N(UnitLevel("player"))
    if eventLevel and (not level or eventLevel > level) then level = eventLevel end
    if level and level > 0 then now.level = level end
    local xp, max = N(UnitXP("player")), N(UnitXPMax("player"))
    if xp and xp >= 0 then now.xp = xp end
    if max and max >= 0 then now.max = max end
    if GetXPExhaustion then
        local rested = GetXPExhaustion()
        if rested == nil then
            now.rested = 0
        elseif N(rested) and rested >= 0 then
            now.rested = rested
        end
    end
    local cap = ReadCap()
    if cap then now.cap = cap end
    local off = IsXPUserDisabled and F.Bool(IsXPUserDisabled())
    if off ~= nil then now.off = off end
    local resting = IsResting and F.Bool(IsResting())
    if resting ~= nil then now.resting = resting end
    if GetRestState then
        local id, name, factor = GetRestState()
        now.restId, now.restName, now.factor = N(id), F.Text(name), N(factor)
    end
    return now
end

function TR:AtMax()
    return now.cap ~= nil and now.level ~= nil and now.level >= now.cap
end

function TR:Off()
    return now.off == true
end

-- XP still to go this level (0 at max level or with no reading).
function TR:Remaining()
    if self:AtMax() or now.max <= 0 then return 0 end
    return math.max(0, now.max - now.xp)
end

-- Gains --------------------------------------------------------------------------------------------------------------------

-- Half a level-up, in either order: the new level with the old level's numbers still, or the new level's numbers (a new
-- max) with the old level still.
local function HalfLevelUp(snap, level, xp, max)
    if level > snap.level then return max == snap.max and xp >= snap.xp end
    return level == snap.level and max ~= snap.max and snap.max > 0
end

-- The XP gained since the snapshot, and the snapshot moved on. Same level: the difference. A higher level: the rest of the
-- old level plus the new XP. Anything else: nothing, and a new snapshot. Half a level-up keeps the snapshot and returns
-- 0, true (waiting) for up to HALF_WAIT seconds; after that the numbers are taken as they are (the difference at the
-- same level, else nothing), so a level-up whose other half never comes can't stop the counting.
function TR.Gain(char, level, xp, max)
    local snap = char.snap
    if not snap then
        char.snap = { level = level, xp = xp, max = max }
        waitFrom = nil
        return 0
    end
    local gain = 0
    if HalfLevelUp(snap, level, xp, max) then
        local t = GetTime()
        waitFrom = waitFrom or t
        if t - waitFrom < HALF_WAIT then return 0, true end
        if level == snap.level and xp > snap.xp then gain = xp - snap.xp end
    elseif level == snap.level then
        if xp > snap.xp then gain = xp - snap.xp end
    elseif level > snap.level then
        gain = math.max(0, snap.max - snap.xp) + xp
    end
    waitFrom = nil
    snap.level, snap.xp, snap.max = level, xp, max
    return gain
end

local function AddGain(session, gain, t)
    session.xp = session.xp + gain
    local gains = session.gains
    local last = gains[#gains]
    if last and t - last.t < RATE_BUCKET then
        last.xp = last.xp + gain
    else
        gains[#gains + 1] = { t = t, xp = gain }
    end
    while gains[1] and gains[1].t < t - RATE_KEEP do table.remove(gains, 1) end
end

-- The session -----------------------------------------------------------------------------------------------------------------

function TR:NewSession(char)
    char = char or F:Char()
    if not char then return end
    char.session = { start = time(), xp = 0, quests = 0, kills = 0, gains = {} }
    F:Notify("session")
end

function TR:Session()
    local char = F:Char()
    return char and char.session
end

-- Seconds since the session started.
function TR:SessionSeconds()
    local session = self:Session()
    if not session then return 0 end
    return math.max(0, time() - session.start)
end

-- XP per hour over the chosen window, or nil until there's a gain and a minute of session.
function TR:Rate()
    local session = self:Session()
    if not session or session.xp <= 0 then return nil end
    local t = time()
    if t - session.start < RATE_START then return nil end
    local window = WINDOWS[F:Get("rateWindow")]
    if not window then return session.xp / math.max(t - session.start, RATE_FLOOR) * 3600 end
    local from = math.max(t - window, session.start)
    local sum = 0
    for _, gain in ipairs(session.gains) do
        if gain.t >= from then sum = sum + gain.xp end
    end
    return sum / math.max(t - from, RATE_FLOOR) * 3600
end

-- Seconds until the next level at that rate, or nil.
function TR:EtaSeconds()
    if self:AtMax() or self:Off() then return nil end
    local rate, remaining = self:Rate(), self:Remaining()
    if not rate or rate <= 0 or remaining <= 0 then return nil end
    return remaining / rate * 3600
end

-- Time on this level ------------------------------------------------------------------------------------------------------------

-- Seconds played at this level, and whether that's exact (else it's "at least").
function TR:LevelSeconds()
    local char = F:Char()
    if not char then return 0, false end
    local seconds = char.levelSeconds or 0
    if foldedAt then seconds = seconds + math.max(0, GetTime() - foldedAt) end
    return seconds, char.levelExact == true
end

-- Brings the saved seconds up to date (at logout, which /reload sends too).
local function Fold()
    local char = F:Char()
    if not char or not foldedAt then return end
    char.levelSeconds = TR:LevelSeconds()
    foldedAt = GetTime()
    F:TouchChar()
end

local function StartLevel(char, level, exact)
    char.levelSeconds, char.levelExact, char.levelAt = 0, exact, level
    char.questsLevel = 0
    foldedAt = GetTime()
end

-- The refresh ---------------------------------------------------------------------------------------------------------------------

-- A look once a half level-up has waited its time (timer callbacks are guarded: an error is said once, like an event's).
local Recheck = F:Guard("numbers", function()
    rechecking = false
    TR:Request()
end)
local Request = F:Guard("numbers", function() TR:Request() end)

local function Refresh()
    pending = false
    if not entered then return end
    TR:Read()
    local char = F:Char()
    if not char or not now.level then return end
    if now.level > (char.levelAt or now.level) then
        StartLevel(char, now.level, true)
        F:DevLog("levelups", { what = "seen", t = GetTime(), level = now.level, xp = now.xp, max = now.max })
        F:Notify("levelup")
    elseif now.level < (char.levelAt or now.level) then
        StartLevel(char, now.level, false)
    end
    local gain, waiting = TR.Gain(char, now.level, now.xp, now.max)
    if waiting and not rechecking then
        rechecking = true
        C_Timer.After(HALF_WAIT + .1, Recheck)
        -- Which half came first (dev mode): settles the game's order.
        F:DevLog("levelups", { what = "half", t = GetTime(), level = now.level, xp = now.xp, max = now.max,
            snapLevel = char.snap.level, snapMax = char.snap.max })
    end
    if gain > 0 and char.session and not now.off then
        AddGain(char.session, gain, time())
        F:DevLog("gains", { t = GetTime(), gain = gain, xp = now.xp, rested = now.rested })
    end
    F:Notify("xp")
end
local GuardedRefresh = F:Guard("numbers", Refresh)

function TR:Request()
    if pending then return end
    pending = true
    C_Timer.After(0, GuardedRefresh)
end

local function OnXPEvent(event, ...)
    if GetTime() <= logUntil then
        F:DevLog("levelups", { what = event, t = GetTime(), level = N(UnitLevel("player")), xp = N(UnitXP("player")),
            max = N(UnitXPMax("player")), arg = N((...)) })
    end
    TR:Request()
end

local function OnLevelUp(event, level)
    level = N(level)
    if level and (not eventLevel or level > eventLevel) then eventLevel = level end
    logUntil = GetTime() + LEVEL_LOG
    OnXPEvent(event, level)
    -- The new level's numbers can come a moment later: look again then too.
    C_Timer.After(1, Request)
end

-- A login starts a new session and a new snapshot (XP gained elsewhere isn't this session's); a /reload keeps both. A level
-- other than the one the saved seconds belong to means it changed while the addon wasn't watching: "at least" again.
local function OnEnter(_, isInitialLogin, isReloadingUi)
    if entered then
        TR:Request()
        return
    end
    entered = true
    TR:Read()
    local char = F:Char()
    if not char then return end
    F:TouchChar()
    local login = F.Bool(isInitialLogin) == true
    if login or not char.session then
        TR:NewSession(char)
        char.snap = nil
    end
    foldedAt = GetTime()
    if now.level and char.levelAt ~= now.level then StartLevel(char, now.level, false) end
    F:DevLog("enter", { t = GetTime(), login = login, reload = F.Bool(isReloadingUi), level = now.level, cap = now.cap,
        restId = now.restId, factor = now.factor })
    if login and F:Get("askPlayed") and not char.levelExact then
        C_Timer.After(ASK_DELAY, F:Guard("played time", function()
            local c = F:Char()
            if F:Get("askPlayed") and c and not c.levelExact and RequestTimePlayed then RequestTimePlayed() end
        end))
    end
    Refresh()
end

-- The game's played time: whoever asked (the player's /played, or the askPlayed tick), it sets the level timer exactly.
local function OnPlayed(_, total, thisLevel)
    total, thisLevel = N(total), N(thisLevel)
    local char = F:Char()
    if not char then return end
    TR:Read()
    if thisLevel and thisLevel >= 0 then
        char.levelSeconds, char.levelExact, char.levelAt = thisLevel, true, now.level or char.levelAt
        foldedAt = GetTime()
    end
    if total and total >= 0 then char.played = { total = total, at = time() } end
    F:DevLog("played", { t = GetTime(), total = total, thisLevel = thisLevel, restId = now.restId,
        restName = now.restName, factor = now.factor })
    F:Notify("played")
end

for _, event in ipairs(XP_EVENTS) do F:On(event, OnXPEvent) end
F:On("PLAYER_LEVEL_UP", OnLevelUp)
F:On("PLAYER_ENTERING_WORLD", OnEnter)
F:On("PLAYER_LOGOUT", Fold)
F:On("TIME_PLAYED_MSG", OnPlayed)
