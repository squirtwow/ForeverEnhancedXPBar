-- Kills: the game's kill XP lines (CHAT_MSG_COMBAT_XP_GAIN), read with patterns built from the game's own
-- COMBATLOG_XPGAIN_* strings, so it works in any client language. Only lines with a mob's name are kills; quest and
-- unnamed lines are left alone. Each kill's base XP (without the rested bonus, or with a tired penalty put back) is kept,
-- the last 20 of them, for "kills to level". The line is checked for a secret before anything reads it.
--
-- How the rested pool is used by a rested kill isn't proven on Forever yet (probe P6): MODEL picks the sum. "whole":
-- the pool drops by the whole kill's XP (what the game's own rested marker suggests). "bonus": only by the bonus part.
local _, F = ...

local KL = {}
F.Kills = KL

KL.MODEL = "whole"
local KEEP = 20 -- kills kept
local PER_LEVEL = 3 -- this level's kills are used once there are this many, else all kept
local REST_FACTOR = 2 -- rested gives this many times the XP when the game won't say
local AFTER = .5 -- seconds after a kill its rested pool is read again (dev mode)

local N = F.Number

-- Patterns ---------------------------------------------------------------------------------------------------------------

-- A Lua pattern for one of the game's format strings: %s and %d (also as %1$s) become captures, everything else is
-- matched as it is. The first argument (the mob's name) takes anything; a later %s (the bonus, the rest state) never
-- takes a comma or a bracket, so a tired line with a group bonus can't pass for a rested one. Returns { pattern, args }
-- (args: which of the format's arguments each capture is), or nil.
function KL.Pattern(format)
    if type(format) ~= "string" or format == "" then return nil end
    local out, args, i, n = { "^" }, {}, 1, 0
    while i <= #format do
        local c = format:sub(i, i)
        if c == "%" then
            local position, kind = format:match("^%%(%d+)%$([sd])", i)
            local length = position and #position + 3 or 2
            if not position then kind = format:match("^%%([sd%%])", i) end
            if kind == "%" then
                out[#out + 1] = "%%"
            elseif kind then
                n = n + 1
                local arg = position and tonumber(position) or n
                args[#args + 1] = arg
                out[#out + 1] = kind == "d" and "(%d+)" or (arg == 1 and "(.-)" or "([^,%(%)]-)")
            else
                return nil -- a format this doesn't know: never guess
            end
            i = i + length
        else
            out[#out + 1] = c:find("[%^%$%(%)%%%.%[%]%*%+%-%?]") and ("%" .. c) or c
            i = i + 1
        end
    end
    out[#out + 1] = "$"
    return { pattern = table.concat(out), args = args }
end

-- The kill lines, most particular first: rested (bonus) and tired (penalty) with a group or raid part, then without, then
-- plain kills with a group or raid part, then plain kills.
local function Kinds()
    local list = {}
    for _, part in ipairs({ "_GROUP", "_RAID", "" }) do
        for _, number in ipairs({ "1", "2", "4", "5" }) do
            list[#list + 1] = { name = "COMBATLOG_XPGAIN_EXHAUSTION" .. number .. part,
                kind = (number == "4" or number == "5") and "penalty" or "bonus" }
        end
    end
    for _, part in ipairs({ "_GROUP", "_RAID", "" }) do
        list[#list + 1] = { name = "COMBATLOG_XPGAIN_FIRSTPERSON" .. part, kind = "plain" }
    end
    return list
end

local patterns -- built the first time a line comes (the game's strings are there by then)

local function Build()
    patterns = {}
    for _, entry in ipairs(Kinds()) do
        local built = KL.Pattern(F.Text(_G[entry.name]))
        if built then
            built.name, built.kind = entry.name, entry.kind
            patterns[#patterns + 1] = built
        end
    end
    return patterns
end

-- A kill line read: { name, total, bonus, base, kind }, or nil for anything that isn't a kill (or is secret).
function KL.Parse(text)
    text = F.Text(text)
    if not text or text == "" then return nil end
    for _, entry in ipairs(patterns or Build()) do
        local captures = { text:match(entry.pattern) }
        if captures[1] then
            local values = {}
            for k, arg in ipairs(entry.args) do values[arg] = captures[k] end
            local name, total = values[1], tonumber(values[2])
            if not name or name == "" or not total or total <= 0 then return nil end
            local bonus = 0
            if entry.kind ~= "plain" then bonus = tonumber((values[3] or ""):match("%d+")) or 0 end
            local base = total
            if entry.kind == "bonus" then base = total - bonus elseif entry.kind == "penalty" then base = total + bonus end
            if base <= 0 then return nil end
            return { name = name, total = total, bonus = bonus, base = base, kind = entry.kind }
        end
    end
    return nil
end

-- The sums ------------------------------------------------------------------------------------------------------------------

local function Ceil(value)
    return math.ceil(value - 1e-9)
end

-- Kills for remaining XP at base XP a kill, with pool rested XP giving factor times the XP while it lasts.
function KL.Count(remaining, pool, base, factor, model)
    if remaining <= 0 or base <= 0 then return 0 end
    pool = math.max(0, pool or 0)
    if pool <= 0 or not factor or factor <= 1 then return Ceil(remaining / base) end
    local rich = base * factor
    if (model or KL.MODEL) == "bonus" then
        local rested = pool / (base * (factor - 1)) -- kills the pool covers
        if rested * rich >= remaining then return Ceil(remaining / rich) end
        return Ceil(rested + (remaining - rested * rich) / base)
    end
    if pool >= remaining then return Ceil(remaining / rich) end
    return Ceil(pool / rich + (remaining - pool) / base)
end

-- The average base XP of a kill: this level's last kills once there are 3, else all kept; nil with none.
function KL:Average(level)
    local char = F:Char()
    local samples = char and char.killSamples
    if not samples or #samples == 0 then return nil end
    local sum, n = 0, 0
    for _, kill in ipairs(samples) do
        if kill.level == level then sum, n = sum + kill.base, n + 1 end
    end
    if n >= PER_LEVEL then return sum / n end
    sum = 0
    for _, kill in ipairs(samples) do sum = sum + kill.base end
    return sum / #samples
end

-- The rested factor: the game's own when it says more than 1, else 2.
function KL:Factor()
    local factor = F.Track.now.factor
    if factor and factor > 1 and factor <= 10 then return factor end
    return REST_FACTOR
end

-- Kills to level: the count, the average base XP and (with rested XP) a rested kill's XP; nil when not known.
function KL:ToLevel()
    local TR = F.Track
    if TR:AtMax() or TR:Off() then return nil end
    local remaining = TR:Remaining()
    local base = self:Average(TR.now.level)
    if remaining <= 0 or not base or base <= 0 then return nil end
    local pool = TR.now.rested or 0
    if pool <= 0 then return KL.Count(remaining, 0, base, 1), base end
    local factor = self:Factor()
    return KL.Count(remaining, pool, base, factor), base, base * factor
end

-- The chat line ------------------------------------------------------------------------------------------------------------

local function OnLine(_, text)
    if F.IsSecret(text) then return end
    local kill = KL.Parse(text)
    if not kill then return end
    local char = F:Char()
    local TR = F.Track
    if not char or not TR.now.level then return end
    local samples = char.killSamples
    samples[#samples + 1] = { level = TR.now.level, base = kill.base }
    while #samples > KEEP do table.remove(samples, 1) end
    if char.session then char.session.kills = char.session.kills + 1 end
    if F:IsDev() then
        local entry = { t = GetTime(), line = text, total = kill.total, bonus = kill.bonus, base = kill.base,
            kind = kill.kind, restedBefore = N(GetXPExhaustion and GetXPExhaustion()) }
        F:DevLog("kills", entry)
        C_Timer.After(AFTER, F:Guard("kills", function()
            entry.restedAfter = N(GetXPExhaustion and GetXPExhaustion())
        end))
    end
    F:Notify("kills")
end

F:On("CHAT_MSG_COMBAT_XP_GAIN", OnLine)
