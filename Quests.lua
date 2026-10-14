-- Quests: the XP waiting in finished quests (the quest log's ready-to-hand-in quests, each one's reward XP as the game
-- gives it), the hand-ins (counted this level and this session; the last 10 rewards that gave XP kept for the average),
-- and quests to level. The log is read at most once a frame, after the game says it changed, never at login before it
-- has.
local _, F = ...

local QS = {}
F.Quests = QS

local SAMPLES = 10 -- hand-ins kept for the average
local SCAN_EVENTS = { "QUEST_LOG_UPDATE", "QUEST_REMOVED", "PLAYER_LEVEL_UP" } -- and QUEST_TURNED_IN, below
local HANDED_IN = 2 -- seconds a handed-in quest is left out, should the log still list it (its XP is already yours)

QS.sum, QS.count = 0, 0 -- XP waiting, and in how many finished quests
local pending = false
local handedIn = {} -- questID -> GetTime() of its hand-in

local N, Bool = F.Number, F.Bool

-- One quest log entry: its reward XP if it's a real quest that's ready to hand in (and not just handed in), else nil.
local function Waiting(log, index)
    local info = log.GetInfo(index)
    if type(info) ~= "table" or F.IsSecret(info) then return nil end
    if Bool(info.isHeader) or Bool(info.isHidden) or Bool(info.isTask) then return nil end
    local id = N(info.questID)
    if not id or id <= 0 or handedIn[id] or Bool(log.IsComplete(id)) ~= true then return nil end
    local xp = GetQuestLogRewardXP and N((GetQuestLogRewardXP(id)))
    if not xp or xp <= 0 then return nil end
    return xp
end

function QS:Scan()
    pending = false
    local t = GetTime()
    for id, at in pairs(handedIn) do
        if t - at >= HANDED_IN then handedIn[id] = nil end
    end
    local log = C_QuestLog
    if not (log and log.GetNumQuestLogEntries and log.GetInfo and log.IsComplete) then return end
    local entries = N((log.GetNumQuestLogEntries())) or 0
    local sum, count = 0, 0
    for index = 1, entries do
        local xp = Waiting(log, index)
        if xp then sum, count = sum + xp, count + 1 end
    end
    if sum ~= self.sum or count ~= self.count then
        self.sum, self.count = sum, count
        F:Notify("quests")
    end
end

local GuardedScan = F:Guard("quests", function() QS:Scan() end)

function QS:Request()
    if pending then return end
    pending = true
    C_Timer.After(0, GuardedScan)
end

-- Whether handing in the finished quests would level you up.
function QS:LevelsUp()
    local TR = F.Track
    local remaining = TR:Remaining()
    return self.sum > 0 and remaining > 0 and self.sum >= remaining
end

-- The average XP of the last hand-ins that gave XP, or nil.
function QS:Average()
    local char = F:Char()
    local samples = char and char.questSamples
    if not samples or #samples == 0 then return nil end
    local sum = 0
    for _, xp in ipairs(samples) do sum = sum + xp end
    return sum / #samples
end

-- Quests to level: "handIn" when the finished quests already cover it, else the count and the average; nil when not known.
function QS:ToLevel()
    local TR = F.Track
    if TR:AtMax() or TR:Off() then return nil end
    local remaining = TR:Remaining()
    if remaining <= 0 then return nil end
    if self:LevelsUp() then return "handIn" end
    local average = self:Average()
    if not average or average <= 0 then return nil end
    return math.ceil(remaining / average - 1e-9), average
end

-- A hand-in: counted for this level and this session, and its XP kept for the average. The quest is left out of the sum
-- for a moment, should the log still list it after its XP has come.
local function OnTurnedIn(_, questID, xpReward)
    local id = N(questID)
    if id and id > 0 then handedIn[id] = GetTime() end
    local char = F:Char()
    if char then
        char.questsLevel = (char.questsLevel or 0) + 1
        if char.session then char.session.quests = char.session.quests + 1 end
        local xp = N(xpReward)
        if xp and xp > 0 then
            local samples = char.questSamples
            samples[#samples + 1] = xp
            while #samples > SAMPLES do table.remove(samples, 1) end
        end
        F:DevLog("quests", { t = GetTime(), id = N(questID), xpReward = xp, xp = N(UnitXP("player")),
            level = N(UnitLevel("player")) })
    end
    QS:Request()
    F:Notify("quests")
end

for _, event in ipairs(SCAN_EVENTS) do F:On(event, function() QS:Request() end) end
F:On("QUEST_TURNED_IN", OnTurnedIn)
