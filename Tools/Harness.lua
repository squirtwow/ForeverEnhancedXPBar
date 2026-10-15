-- A mock of the game for the addon's tests, loaded with loadfile. The addon's real files run in it, in the TOC's order.
--
-- Blizzard's objects here are sealed, as the addon must leave them: writing any key on one is a violation, and so is
-- calling any method but a read (Get..., Is..., Has..., Can..., Enumerate..., Num..., Does...), HookScript, or a
-- cosmetic setter (SetText, SetTextColor, SetVertexColor, SetShadowColor). SetAlpha is allowed only on the pieces the
-- addon may fade (the game's two XP bars, their containers' frame art and dividers), and hooksecurefunc only on a
-- container's UpdateDividers, ApplyPendingBarToShow and UpdateShownState. Only Blizzard's own code, run by a test through H.Blizzard, may do more. Violations are
-- recorded even when the addon catches the error. EraUI and its classic band are sealed the same way.
-- Secrets: H.SECRET, and typed ones from H.SecretString() / H.SecretNumber(), which type() reports as "string" /
-- "number" as the game's secrets keep their type (so a type check can't stand in for issecretvalue). Indexing, joining,
-- measuring, iterating, arithmetic, comparing in order, calling or turning one into text is a violation (== with a plain
-- value can't be caught in Lua: the addon must ask issecretvalue first).
--
-- Time: H.clock (GetTime) and H.epoch (time()). H.Advance(seconds) moves both in small steps, running due timers and the
-- OnUpdate of every visible frame, as the game would. Showing or hiding a frame runs OnShow / OnHide on it and on every
-- shown frame under it whose visibility changed.
--
-- Textures take SetGradient (two ColorMixin colours, from H's CreateColor; a vertex colour and a gradient overwrite each
-- other, as in the game) and mask textures (CreateMaskTexture, AddMaskTexture, RemoveMaskTexture, GetNumMaskTextures),
-- at most three a texture as in the game (H.maskCap; H.maskSilent drops one too many without the error; H.maskBudget
-- makes adding fail after that many); H.noMasks makes CreateMaskTexture give nothing, and a test can set CreateColor to
-- nil. SetFont keeps the size and flags, SetShadowOffset the offset. GetStringWidth is 6 px a byte, colour codes left out.
--
-- The player: H.p = { level, xp, max, rested (nil: none), restState { id, name, factor }, resting, off, capExpansion,
-- capPlayer }, H.guid, H.me. The quest log: H.quests = { { questID, title, isHeader, isHidden, isTask, complete, xp } }.
-- The game's XP bars: H.StatusSetup() builds StatusTrackingBarManager with two containers of six bars each; H.ShowXPIn(i)
-- moves XP into a container as the game does; H.RebuildDividers(c, n) runs the game's UpdateDividers. The bottom bars:
-- H.BottomSetup(). EraUI: H.EraSetup(active, settings).
local H = {}

H.ADDON = "ForeverEnhancedXPBar"
-- The addon's files, in the TOC's order (Tools/TestRules.mjs checks they match).
H.FILES = { "Core.lua", "Theme.lua", "Track.lua", "Quests.lua", "Kills.lua", "Tip.lua", "Bar.lua", "GameBar.lua",
    "Window.lua", "MinimapButton.lua" }

local pack = table.pack or function(...) return { n = select("#", ...), ... } end
local unpackAll = table.unpack or unpack
_G.unpack = _G.unpack or table.unpack
local rawSet = rawset

-- Checks --------------------------------------------------------------------------------------------------------------

H.checks = 0
function H.Equal(actual, expected, label)
    H.checks = H.checks + 1
    if actual ~= expected then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

function H.True(value, label)
    H.checks = H.checks + 1
    if not value then error(label .. ": expected true, got " .. tostring(value), 2) end
end

function H.Near(actual, expected, tolerance, label)
    H.checks = H.checks + 1
    if type(actual) ~= "number" or math.abs(actual - expected) > tolerance then
        error(label .. ": expected " .. tostring(expected) .. " (within " .. tolerance .. "), got " .. tostring(actual), 2)
    end
end

-- Secrets --------------------------------------------------------------------------------------------------------------

H.violations = {}
local function Violation(text)
    H.violations[#H.violations + 1] = text
end
H.Violation = Violation

local function Boom(what)
    return function()
        Violation("a secret value was " .. what)
        error("secret value " .. what, 2)
    end
end
local SECRET_META = { __index = Boom("indexed"), __newindex = Boom("written into"), __lt = Boom("compared"),
    __le = Boom("compared"), __add = Boom("used in arithmetic"), __sub = Boom("used in arithmetic"),
    __mul = Boom("used in arithmetic"), __div = Boom("used in arithmetic"), __mod = Boom("used in arithmetic"),
    __pow = Boom("used in arithmetic"), __unm = Boom("used in arithmetic"), __idiv = Boom("used in arithmetic"),
    __concat = Boom("joined"), __len = Boom("measured"), __call = Boom("called"), __tostring = Boom("turned into text"),
    __pairs = Boom("iterated") }
local secrets = setmetatable({}, { __mode = "k" }) -- secret -> the type it reports
local function NewSecret(kind)
    local secret = setmetatable({}, SECRET_META)
    secrets[secret] = kind
    return secret
end
H.SECRET = NewSecret("table")
function H.SecretString() return NewSecret("string") end
function H.SecretNumber() return NewSecret("number") end
function H.SecretBool() return NewSecret("boolean") end
local function IsSecret(v) return v ~= nil and secrets[v] ~= nil end
-- type() as the game has it: a secret keeps the type of the value it hides.
local rawType = type
_G.type = function(v)
    local kind = v ~= nil and secrets[v]
    if kind then return kind end
    return rawType(v)
end

-- Mock objects ----------------------------------------------------------------------------------------------------------

local S = setmetatable({}, { __mode = "k" }) -- each object's state, never on the object
H.S = S
local Proto = {}
H.Proto = Proto
local blizzardCalling = false

local READS = { "Get", "Is", "Has", "Can", "Enumerate", "Num", "Does" }
local COSMETIC = { SetText = true, SetTextColor = true, SetVertexColor = true, SetShadowColor = true }

local function Allowed(key, s)
    if type(key) ~= "string" or not key:match("^[A-Z]") then return true end
    if key == "HookScript" or COSMETIC[key] then return true end
    if key == "SetAlpha" and s.alphaOk then return true end
    for _, prefix in ipairs(READS) do
        if key:sub(1, #prefix) == prefix then return true end
    end
    return false
end

local function Name(obj)
    local s = S[obj]
    return s and (s.name or s.kind) or "?"
end
H.Name = Name

local function Record(obj, key, ...)
    local s = S[obj]
    s.last[key] = pack(...)
    s.calls[key] = (s.calls[key] or 0) + 1
end

local New
New = function(kind, parent)
    local obj = {}
    S[obj] = { kind = kind, parent = parent, shown = true, last = {}, calls = {}, scripts = {}, events = {}, points = {},
        width = 0, height = 0, alpha = 1, scale = 1, children = {}, mouse = false, motion = nil, click = nil }
    H.objects[#H.objects + 1] = obj
    if parent and S[parent] then table.insert(S[parent].children, obj) end
    setmetatable(obj, {
        __index = function(_, key)
            local s = S[obj]
            local field = s.fields and s.fields[key]
            if s.blizzard and not blizzardCalling and not Allowed(key, s) then
                return function()
                    Violation("called " .. key .. " on Blizzard's " .. Name(obj))
                    error("called " .. key .. " on a Blizzard frame", 2)
                end
            end
            if field ~= nil then return field end
            local method = Proto[key]
            if method then return method end
            if type(key) == "string" and key:match("^[A-Z]") then
                return function(self, ...) Record(self, key, ...) end
            end
        end,
        __newindex = function(t, key, value)
            if S[t].sealed and not blizzardCalling then
                Violation("wrote key '" .. tostring(key) .. "' on Blizzard's " .. Name(t))
                error("wrote key '" .. tostring(key) .. "' on a Blizzard frame", 2)
            end
            rawSet(t, key, value)
        end,
    })
    return obj
end
H.New = New

function H.Last(obj, method, i)
    local call = S[obj].last[method]
    return call and call[i or 1]
end

function H.Calls(obj, method)
    return S[obj].calls[method] or 0
end

-- Visibility, as the game has it: shown, and every parent shown.
local function Visible(obj)
    local s = S[obj]
    while s do
        if not s.shown then return false end
        s = s.parent and S[s.parent]
    end
    return true
end

local function Each(obj, fn)
    fn(obj)
    for _, child in ipairs(S[obj].children) do Each(child, fn) end
end

-- Showing or hiding: OnShow / OnHide for this frame and every frame under it whose visibility changed.
local function Toggled(self, v)
    local s = S[self]
    if s.shown == v then return end
    local before = {}
    Each(self, function(o) before[o] = Visible(o) end)
    s.shown = v
    Each(self, function(o)
        local now = Visible(o)
        if now ~= before[o] then
            local script = S[o].scripts[now and "OnShow" or "OnHide"]
            if script then script(o) end
        end
    end)
end
function Proto:Show() Toggled(self, true) end
function Proto:Hide() Toggled(self, false) end
function Proto:SetShown(v) Toggled(self, v and true or false) end
function Proto:IsShown() return S[self].shown end
function Proto:IsVisible() return Visible(self) end
function Proto:SetScript(k, fn) S[self].scripts[k] = fn end
function Proto:GetScript(k) return S[self].scripts[k] end
function Proto:HookScript(k, fn)
    local old = S[self].scripts[k]
    S[self].hooked = S[self].hooked or {}
    S[self].hooked[k] = (S[self].hooked[k] or 0) + 1
    S[self].scripts[k] = function(...)
        if old then old(...) end
        local was = blizzardCalling
        blizzardCalling = false
        local ok, err = pcall(fn, ...)
        blizzardCalling = was
        if not ok then H.hookErrors[#H.hookErrors + 1] = tostring(err) end
    end
end
function Proto:RegisterEvent(e) S[self].events[e] = true end
function Proto:UnregisterEvent(e) S[self].events[e] = nil end
function Proto:UnregisterAllEvents() S[self].events = {} end
function Proto:IsEventRegistered(e) return S[self].events[e] ~= nil end
function Proto:GetObjectType() return S[self].kind end
function Proto:GetParent() return S[self].parent end
function Proto:GetName() return S[self].name end
function Proto:IsForbidden() return false end
function Proto:IsProtected() return false end
local function Child(self, kind, layer, template)
    local o = New(kind, self)
    S[o].layer, S[o].template = layer, template
    if S[self].sealed then S[o].sealed, S[o].blizzard = true, true end
    return o
end
function Proto:CreateTexture(_, layer, _, sublevel)
    local o = Child(self, "Texture", layer)
    S[o].sublevel = sublevel
    return o
end
function Proto:CreateFontString(_, layer, template) return Child(self, "FontString", layer, template) end
function Proto:SetText(t)
    if S[self].kind == "FontString" and not S[self].template and not S[self].fontFile and not S[self].blizzard then
        error("FontString:SetText(): Font not set", 2)
    end
    if t ~= nil and not IsSecret(t) and type(t) ~= "string" and type(t) ~= "number" then error("SetText takes text", 2) end
    S[self].text = (t ~= nil and not IsSecret(t)) and tostring(t) or t
end
function Proto:GetText() return S[self].text end
function Proto:SetTextColor(r, g, b, a) S[self].colour = { r, g, b, a } end
function Proto:GetTextColor()
    local c = S[self].colour or { 1, 1, 1, 1 }
    return c[1], c[2], c[3], c[4] or 1
end
function Proto:SetShadowColor(_, _, _, a) S[self].shadow = a end
function Proto:SetShadowOffset(x, y) S[self].shadowOffset = { x, y } end
function Proto:SetFontObject(font) S[self].fontFile, S[self].fontSize, S[self].fontFlags = font, nil, nil end
function Proto:SetFont(file, size, flags) S[self].fontFile, S[self].fontSize, S[self].fontFlags = file, size, flags end
-- Like the game: a second point of the same name replaces the first.
function Proto:SetPoint(point, ...)
    local s = S[self]
    local entry = pack(point, ...)
    for i, old in ipairs(s.points) do
        if old[1] == point then
            s.points[i] = entry
            return
        end
    end
    s.points[#s.points + 1] = entry
end
function Proto:ClearAllPoints() S[self].points = {} end
function Proto:SetAllPoints(rel) S[self].points = { pack("ALL", rel) } end
function Proto:GetNumPoints() return #S[self].points end
function Proto:GetPoint(i)
    local p = S[self].points[i or 1]
    if p then return unpackAll(p, 1, p.n) end
end
function Proto:SetSize(w, h) S[self].width, S[self].height = w, h end
function Proto:SetWidth(w) S[self].width = w end
function Proto:SetHeight(h) S[self].height = h end
-- A frame made to fill its parent (SetAllPoints) has its parent's size.
function Proto:GetWidth()
    local s = S[self]
    if s.points[1] and s.points[1][1] == "ALL" and s.points[1][2] then return s.points[1][2]:GetWidth() end
    return s.width
end
function Proto:GetHeight()
    local s = S[self]
    if s.points[1] and s.points[1][1] == "ALL" and s.points[1][2] then return s.points[1][2]:GetHeight() end
    return s.height
end
function Proto:GetSize() return self:GetWidth(), self:GetHeight() end
function Proto:GetCenter()
    local s = S[self]
    if s.center then return s.center[1], s.center[2] end
    return 500, 400
end
function Proto:GetLeft() return S[self].left or 100 end
function Proto:GetTop() return S[self].top or 600 end
function Proto:GetRight() return S[self].right or 300 end
function Proto:GetBottom() return S[self].bottom or 100 end
function Proto:GetVerticalScroll() return S[self].scroll or 0 end
function Proto:SetVerticalScroll(v) S[self].scroll = v end
function Proto:SetScrollChild(c) S[self].scrollChild = c end
function Proto:GetEffectiveScale() return S[self].effScale or 1 end
function Proto:SetScale(v) S[self].scale = v end
function Proto:GetScale() return S[self].scale end
function Proto:SetBackdrop(b) S[self].backdropInfo = b end
function Proto:SetBackdropBorderColor(r, g, b, a) S[self].border = { r, g, b, a } end
function Proto:SetBackdropColor(r, g, b, a) S[self].backdrop = { r, g, b, a } end
function Proto:SetAlpha(a)
    if S[self].blizzard then
        H.alphaSets[#H.alphaSets + 1] = { obj = self, alpha = a, combat = H.lockdown }
    end
    S[self].alpha = a
end
function Proto:GetAlpha() return S[self].alpha end
function Proto:GetFrameLevel() return S[self].level or 1 end
function Proto:SetFrameLevel(level) S[self].level = level end
function Proto:SetFrameStrata(strata) S[self].strata = strata end
function Proto:GetFrameStrata() return S[self].strata or "MEDIUM" end
-- 6 px a byte, colour codes left out (as the game measures only what shows).
function Proto:GetStringWidth()
    local text = S[self].text
    if type(text) ~= "string" then return 0 end
    local shown = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return #shown * 6
end
function Proto:GetStringHeight()
    local s = S[self]
    local text = type(s.text) == "string" and s.text or ""
    local width = (s.width and s.width > 0) and s.width or 1000
    return math.max(1, math.ceil(#text * 6 / width)) * 12
end
function Proto:Click(button)
    local script = S[self].scripts.OnClick
    if script then script(self, button or "LeftButton") end
end
-- SetTexture returns true, or false for a file named in H.missingFiles (as the game does for one it can't load).
function Proto:SetTexture(t, h, v)
    S[self].texture, S[self].wrap, S[self].wrapV = t, h, v
    S[self].color = nil
    if H.missingFiles[t] then return false end
    return true
end
function Proto:GetTexture() return S[self].texture end
function Proto:SetTexCoord(...) S[self].texCoord = { ... } end
function Proto:SetColorTexture(r, g, b, a) S[self].color = { r, g, b, a } end
-- As in the game, a vertex colour and a gradient overwrite each other (both set the texture's vertex colours).
function Proto:SetVertexColor(r, g, b, a)
    S[self].tint = { r, g, b, a }
    S[self].gradient = nil
end
-- SetGradient(orientation, minColor, maxColor) with ColorMixin colours, as Forever's modern client has it.
function Proto:SetGradient(orientation, from, to)
    if type(from) ~= "table" or type(to) ~= "table" then error("SetGradient takes two colours", 2) end
    S[self].gradient = { orientation, from, to }
    S[self].tint = nil
end
-- Mask textures: H.noMasks makes CreateMaskTexture give nothing (a game without them). A texture takes at most
-- H.maskCap masks (the game's 3); one more raises the game's error, or with H.maskSilent is dropped without a word.
-- H.maskBudget (nil: no limit) is how many AddMaskTexture calls in all succeed before every later one fails.
function Proto:CreateMaskTexture(_, layer)
    if H.noMasks then return nil end
    return Child(self, "MaskTexture", layer)
end
function Proto:AddMaskTexture(mask)
    local s = S[self]
    s.masks = s.masks or {}
    if H.maskBudget then
        if H.maskBudget <= 0 then error("Texture:AddMaskTexture(): out of mask textures", 2) end
        H.maskBudget = H.maskBudget - 1
    end
    if #s.masks >= H.maskCap then
        if H.maskSilent then return end
        error("Texture:AddMaskTexture(): Texture already has the maximum number of mask textures (" .. H.maskCap .. ")", 2)
    end
    s.masks[#s.masks + 1] = mask
end
function Proto:RemoveMaskTexture(mask)
    local list = S[self].masks or {}
    for i = #list, 1, -1 do
        if list[i] == mask then table.remove(list, i) end
    end
end
function Proto:GetNumMaskTextures() return #(S[self].masks or {}) end
function Proto:GetMaskTexture(i) return (S[self].masks or {})[i] end
function Proto:EnableMouse(v) S[self].mouse = v and true or false end
function Proto:IsMouseEnabled() return S[self].mouse == true end
function Proto:SetMouseClickEnabled(v) S[self].click = v and true or false end
function Proto:SetMouseMotionEnabled(v) S[self].motion = v and true or false end
function Proto:IsMouseClickEnabled() return S[self].click == true or (S[self].click == nil and S[self].mouse == true) end
function Proto:IsMouseMotionEnabled() return S[self].motion == true or (S[self].motion == nil and S[self].mouse == true) end
function Proto:IsMouseOver() return S[self].mouseOver == true end
function Proto:SetEnabled(v) S[self].enabled = v and true or false end
function Proto:StartMoving() S[self].moving = true end
function Proto:StopMovingOrSizing() S[self].moving = false end
function Proto:SetUserPlaced(v) S[self].userPlaced = v end

-- Seals an object and everything in it as Blizzard's (its functions moved apart, so calls go through the check).
local function Seal(obj)
    S[obj].sealed, S[obj].blizzard = true, true
    local functions = {}
    for key, value in next, obj do
        if type(value) == "function" then functions[key] = value end
    end
    for key, value in pairs(functions) do
        S[obj].fields = S[obj].fields or {}
        S[obj].fields[key] = value
        rawSet(obj, key, nil)
    end
    for _, child in ipairs(S[obj].children) do Seal(child) end
end
H.Seal = Seal

-- One of Blizzard's objects: sealed, under its global name if given. fields: keys Blizzard's code would set.
function H.BlizzardFrame(kind, name, parent, fields)
    local obj = New(kind or "Frame", parent)
    S[obj].name = name
    for key, value in pairs(fields or {}) do rawSet(obj, key, value) end
    Seal(obj)
    if name then _G[name] = obj end
    return obj
end

-- A plain table of Blizzard's (or EraUI's): readable, never written.
function H.BlizzardTable(fields, name)
    local t = {}
    for key, value in pairs(fields or {}) do rawSet(t, key, value) end
    return setmetatable(t, { __newindex = function(_, key)
        Violation("wrote key '" .. tostring(key) .. "' on Blizzard's " .. (name or "table"))
        error("wrote a key on a Blizzard table", 2)
    end })
end

function H.Text(region) return S[region].text end
function H.Shown(region) return region ~= nil and region:IsVisible() end

-- Events and time ---------------------------------------------------------------------------------------------------------

function H.Fire(event, ...)
    local list = {}
    for _, frame in ipairs(H.frames) do list[#list + 1] = frame end
    for _, frame in ipairs(list) do
        if S[frame].events[event] and S[frame].scripts.OnEvent then S[frame].scripts.OnEvent(frame, event, ...) end
    end
end

local function RunDue()
    local i = 1
    while i <= #H.timers do
        local timer = H.timers[i]
        if timer.cancelled then
            table.remove(H.timers, i)
        elseif timer.due <= H.clock + 1e-9 then
            if timer.every then
                timer.due = timer.due + timer.every
                timer.left = timer.left and timer.left - 1
                if timer.left and timer.left <= 0 then table.remove(H.timers, i) else i = i + 1 end
                timer.fn(timer)
            else
                table.remove(H.timers, i)
                timer.fn()
            end
        else
            i = i + 1
        end
    end
end

-- Every visible frame's OnUpdate, as a frame of the game would run them.
local function RunUpdates(step)
    local list = {}
    for _, frame in ipairs(H.frames) do
        if S[frame].scripts.OnUpdate and Visible(frame) then list[#list + 1] = frame end
    end
    for _, frame in ipairs(list) do
        local fn = S[frame].scripts.OnUpdate
        if fn and Visible(frame) then fn(frame, step) end
    end
end

-- Moves time on by seconds, in steps (default 0.05), running timers and OnUpdates. Long jumps take bigger steps.
function H.Advance(seconds, step)
    step = step or (seconds > 60 and 1 or .05)
    local target = H.clock + seconds
    RunDue()
    while H.clock < target - 1e-9 do
        local dt = math.min(step, target - H.clock)
        H.clock = H.clock + dt
        H.epoch = H.epoch + dt
        RunDue()
        RunUpdates(dt)
    end
end

-- Runs what's due on the next frame (C_Timer.After(0) and anything else already due).
function H.Frame()
    H.Advance(.01)
end

function H.Blizzard(fn, ...)
    local was = blizzardCalling
    blizzardCalling = true
    local results = pack(pcall(fn, ...))
    blizzardCalling = was
    if not results[1] then error(results[2], 2) end
    return unpackAll(results, 2, results.n)
end

function H.Combat(on)
    H.lockdown = on and true or false
    H.Fire(on and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
end

-- The player, XP and quests ------------------------------------------------------------------------------------------------

local function Value(v)
    if type(v) == "function" then return v() end
    return v
end

local function InstallPlayer()
    _G.UnitName = function(unit)
        if unit ~= "player" then return nil end
        return H.me[1], H.me[2]
    end
    _G.UnitGUID = function(unit) if unit == "player" then return Value(H.guid) end end
    _G.UnitLevel = function(unit) if unit == "player" then return Value(H.p.level) end end
    _G.UnitXP = function(unit) if unit == "player" then return Value(H.p.xp) end end
    _G.UnitXPMax = function(unit) if unit == "player" then return Value(H.p.max) end end
    _G.GetXPExhaustion = function() return Value(H.p.rested) end
    _G.GetRestState = function()
        local r = H.p.restState
        if not r then return end
        return Value(r[1]), Value(r[2]), Value(r[3])
    end
    _G.IsResting = function() return Value(H.p.resting) end
    _G.IsXPUserDisabled = function() return Value(H.p.off) end
    _G.GetMaxPlayerLevel = function() return Value(H.p.capPlayer) end
    _G.GetMaxLevelForPlayerExpansion = function() return Value(H.p.capExpansion) end
    _G.RequestTimePlayed = function() H.playedAsked = H.playedAsked + 1 end
    _G.C_QuestLog = {
        GetNumQuestLogEntries = function()
            local count = 0
            for _, q in ipairs(H.quests) do if not q.isHeader then count = count + 1 end end
            return #H.quests, count
        end,
        GetInfo = function(index)
            local q = H.quests[index]
            if not q then return nil end
            return { questID = q.questID, title = q.title, isHeader = q.isHeader or false, isHidden = q.isHidden or false,
                isTask = q.isTask or false }
        end,
        IsComplete = function(id)
            H.questReads = H.questReads + 1
            for _, q in ipairs(H.quests) do if q.questID == id then return Value(q.complete) == true end end
            return false
        end,
    }
    _G.GetQuestLogRewardXP = function(id)
        for _, q in ipairs(H.quests) do
            if q.questID == id then
                local xp = Value(q.xp)
                return xp, xp
            end
        end
        return 0, 0
    end
end

-- The game's English kill strings (GlobalStrings, Forever 1.60.1.70338).
H.STRINGS = {
    COMBATLOG_XPGAIN_FIRSTPERSON = "%s dies, you gain %d experience.",
    COMBATLOG_XPGAIN_FIRSTPERSON_GROUP = "%s dies, you gain %d experience. (+%d group bonus)",
    COMBATLOG_XPGAIN_FIRSTPERSON_RAID = "%s dies, you gain %d experience. (-%d raid penalty)",
    COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED = "You gain %d experience.",
    COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED_GROUP = "You gain %d experience. (+%d group bonus)",
    COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED_RAID = "You gain %d experience. (-%d raid penalty)",
    COMBATLOG_XPGAIN_QUEST = "You gain %d experience. (%s exp %s bonus)",
    COMBATLOG_XPGAIN_EXHAUSTION1 = "%s dies, you gain %d experience. (%s exp %s bonus)",
    COMBATLOG_XPGAIN_EXHAUSTION2 = "%s dies, you gain %d experience. (%s exp %s bonus)",
    COMBATLOG_XPGAIN_EXHAUSTION4 = "%s dies, you gain %d experience. (%s exp %s penalty)",
    COMBATLOG_XPGAIN_EXHAUSTION5 = "%s dies, you gain %d experience. (%s exp %s penalty)",
    COMBATLOG_XPGAIN_EXHAUSTION1_GROUP = "%s dies, you gain %d experience. (%s exp %s bonus, +%d group bonus)",
    COMBATLOG_XPGAIN_EXHAUSTION2_GROUP = "%s dies, you gain %d experience. (%s exp %s bonus, +%d group bonus)",
    COMBATLOG_XPGAIN_EXHAUSTION4_GROUP = "%s dies, you gain %d experience. (%s exp %s penalty, +%d group bonus)",
    COMBATLOG_XPGAIN_EXHAUSTION5_GROUP = "%s dies, you gain %d experience. (%s exp %s penalty, +%d group bonus)",
    COMBATLOG_XPGAIN_EXHAUSTION1_RAID = "%s dies, you gain %d experience. (%s exp %s bonus, -%d raid penalty)",
    COMBATLOG_XPGAIN_EXHAUSTION2_RAID = "%s dies, you gain %d experience. (%s exp %s bonus, -%d raid penalty)",
    COMBATLOG_XPGAIN_EXHAUSTION4_RAID = "%s dies, you gain %d experience. (%s exp %s penalty, -%d raid penalty)",
    COMBATLOG_XPGAIN_EXHAUSTION5_RAID = "%s dies, you gain %d experience. (%s exp %s penalty, -%d raid penalty)",
}

-- The game's XP bars ------------------------------------------------------------------------------------------------------------

local XP = 4

-- A divider pool as the game's FramePool: Acquire reuses a released frame (keeping its alpha) or makes a new one.
local function Pool(container)
    local active, free, made = {}, {}, {}
    return H.BlizzardTable({
        made = made, -- every divider ever made (for the tests)
        EnumerateActive = function() return pairs(active) end,
        GetNumActive = function()
            local n = 0
            for _ in pairs(active) do n = n + 1 end
            return n
        end,
        Acquire = function()
            local frame = table.remove(free)
            if not frame then
                frame = H.BlizzardFrame("Frame", nil, container)
                S[frame].alphaOk = true
                made[#made + 1] = frame
            end
            active[frame] = true
            S[frame].shown = true
            return frame
        end,
        ReleaseAll = function()
            for frame in pairs(active) do
                S[frame].shown = false
                free[#free + 1] = frame
                active[frame] = nil
            end
        end,
    }, "divider pool")
end

function H.StatusSetup(opts)
    opts = opts or {}
    _G.StatusTrackingBarInfo = H.BlizzardTable({ BarsEnum = H.BlizzardTable({ None = -1, Reputation = 1, Honor = 2,
        Artifact = 3, Experience = 4, Azerite = 5, HouseFavor = 6 }, "BarsEnum") }, "StatusTrackingBarInfo")
    local manager = H.BlizzardFrame("Frame", "StatusTrackingBarManager", UIParent)
    local containers = {}
    for i, name in ipairs({ "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }) do
        local c = H.BlizzardFrame("Frame", name, manager)
        local bars = {}
        for index = 1, 6 do
            local bar = H.BlizzardFrame("Frame", nil, c)
            S[bar].shown = false
            if index == XP then
                S[bar].alphaOk = true
                local tick = H.BlizzardFrame("Button", nil, bar)
                S[bar].mouse, S[tick].mouse = true, true
                H.Blizzard(function() rawset(bar, "ExhaustionTick", tick) rawset(bar, "isExpBar", true) end)
            end
            bars[index] = bar
        end
        local art = H.BlizzardFrame("Texture", nil, c)
        S[art].alphaOk = true
        S[art].alpha = opts.artAlpha or 1
        local pool = Pool(c)
        H.Blizzard(function()
            rawset(c, "bars", H.BlizzardTable(bars, "bars"))
            rawset(c, "BarFrameTexture", art)
            rawset(c, "HorizontalDividersPool", pool)
            rawset(c, "shownBarIndex", -1)
        end)
        S[c].fields = S[c].fields or {}
        S[c].fields.UpdateDividers = function(self, n)
            local p = self.HorizontalDividersPool
            p:ReleaseAll()
            for _ = 1, (n or 20) - 1 do p:Acquire() end
        end
        -- The game's own passes that GameBar post-hooks to look again (their work is done by ShowXPIn and the tests).
        S[c].fields.ApplyPendingBarToShow = function() end
        S[c].fields.UpdateShownState = function() end
        S[c].shown = false
        containers[i] = c
        H.Blizzard(function() c:UpdateDividers(20) end)
    end
    H.Blizzard(function() rawset(manager, "barContainers", H.BlizzardTable(containers, "barContainers")) end)
    H.containers = containers
    return containers
end

-- The game moving XP into container i (nil: none), as ApplyPendingBarToShow does: the old bar hides, the new one shows,
-- and only then shownBarIndex changes.
function H.ShowXPIn(i)
    H.Blizzard(function()
        for index, c in ipairs(H.containers) do
            local bar = c.bars[XP]
            if index ~= i and c.shownBarIndex == XP then
                bar:Hide()
                rawset(c, "shownBarIndex", -1)
                c:Hide()
            end
        end
        local c = H.containers[i]
        if c and c.shownBarIndex ~= XP then
            local other = c.bars[c.shownBarIndex]
            if other then other:Hide() end
            c:Show()
            c.bars[XP]:Show()
            rawset(c, "shownBarIndex", XP)
        end
    end)
end

-- The reputation bar into container i (a watched faction), as the game does.
function H.ShowRepIn(i)
    H.Blizzard(function()
        local c = H.containers[i]
        local old = c.bars[c.shownBarIndex]
        if old then old:Hide() end
        c:Show()
        c.bars[1]:Show()
        rawset(c, "shownBarIndex", 1)
    end)
end

function H.RebuildDividers(c, n)
    H.Blizzard(function() c:UpdateDividers(n) end)
end

-- The bottom bars: name -> { left, right, top } in UIParent's units (shown), as Edit Mode lays them out.
function H.BottomSetup(layout)
    for name, spot in pairs(layout) do
        local frame = _G[name]
        if not frame then frame = H.BlizzardFrame("Frame", name, UIParent) end
        local s = S[frame]
        s.left, s.right, s.top, s.bottom = spot[1], spot[2], spot[3], spot[4] or (spot[3] - 40)
        s.shown = spot.hidden ~= true
        s.alpha = spot.alpha or 1
        s.effScale = spot.scale or 1
    end
end

-- EraUI, as the addon sees it: its classic band and its settings (both only read).
function H.EraSetup(active, settings)
    H.era = { active = active, settings = settings or { enabled = true, actionBars = true } }
    local classic = H.BlizzardTable({ ClassicBarActive = function() return H.era.active end }, "EraUI.Classic")
    _G.EraUI = H.BlizzardTable({ Classic = classic, GetSetting = function(_, key) return H.era.settings[key] end }, "EraUI")
end

-- A fresh game, as after a restart: nothing of the addon's left.
function H.Environment()
    for key in pairs(_G) do
        if type(key) == "string" and (key:find("^ForeverEnhancedXPBar") or key:find("^SLASH_FOREVERENHANCEDXPBAR")) then
            _G[key] = nil
        end
    end
    for _, name in ipairs({ "EraUI", "EraUIClassicBar", "StatusTrackingBarManager", "StatusTrackingBarInfo",
        "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer", "MainActionBar", "MultiBarBottomLeft",
        "MultiBarBottomRight", "StanceBar", "PetActionBar", "PossessActionBar", "PlayerCastingBarFrame" }) do
        _G[name] = nil
    end
    H.objects, H.frames, H.violations, H.hookErrors, H.timers, H.printed = {}, {}, {}, {}, {}, {}
    H.alphaSets, H.hooks, H.missingFiles, H.noMasks = {}, {}, {}, false
    H.maskCap, H.maskSilent, H.maskBudget = 3, false, nil
    -- CreateColor as the game's (a ColorMixin); a test sets it to nil for a game without it.
    _G.CreateColor = function(r, g, b, a)
        return { r = r, g = g, b = b, a = a or 1, GetRGBA = function(c) return c.r, c.g, c.b, c.a end }
    end
    H.lockdown, H.clock, H.epoch = false, 1000, 1800000000
    blizzardCalling = false
    H.me, H.guid = { "Zriel", "Gustbellow" }, "Player-1-0000A1B2"
    H.p = { level = 24, xp = 12450, max = 19700, rested = 4200, restState = { 1, "Rested", 2 }, resting = false,
        off = false, capExpansion = 30, capPlayer = 60 }
    H.quests, H.questReads, H.playedAsked, H.cursor = {}, 0, 0, { 0, 0 }
    _G.C_Timer = {
        After = function(seconds, fn) H.timers[#H.timers + 1] = { due = H.clock + seconds, fn = fn } end,
        NewTicker = function(seconds, fn, iterations)
            local timer = { due = H.clock + seconds, every = seconds, left = iterations }
            timer.fn = function() fn(timer) end
            timer.Cancel = function(self) self.cancelled = true end
            timer.IsCancelled = function(self) return self.cancelled == true end
            H.timers[#H.timers + 1] = timer
            return timer
        end,
    }
    _G.GetTime = function() return H.clock end
    _G.time = function() return math.floor(H.epoch + 1e-6) end
    _G.InCombatLockdown = function() return H.lockdown end
    _G.GetCursorPosition = function() return H.cursor[1], H.cursor[2] end
    _G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    _G.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
        H.printed[#H.printed + 1] = table.concat(parts, " ")
    end
    _G.issecretvalue = function(v)
        if v == nil then
            Violation("asked issecretvalue about nil")
            error("issecretvalue: bad argument (nil)", 2)
        end
        return IsSecret(v)
    end
    _G.UISpecialFrames = {}
    _G.SlashCmdList = {}
    for _, banned in ipairs({ "SetOverrideBinding", "ShowUIPanel", "HideUIPanel", "SetCVar" }) do
        _G[banned] = function() Violation("called " .. banned) end
    end
    _G.CreateFrame = function(kind, name, parent, template)
        local f = New(kind, parent)
        S[f].name, S[f].template = name, template
        H.frames[#H.frames + 1] = f
        if name then _G[name] = f end
        return f
    end
    -- Only a container's UpdateDividers, ApplyPendingBarToShow and UpdateShownState may be hooked (post-hooks: the
    -- game's code runs first).
    local HOOKABLE = { UpdateDividers = true, ApplyPendingBarToShow = true, UpdateShownState = true }
    _G.hooksecurefunc = function(t, method, fn)
        if type(t) ~= "table" or not S[t] or not S[t].blizzard or not HOOKABLE[method] then
            Violation("hooked " .. tostring(type(t) == "string" and t or method))
            return
        end
        H.hooks[#H.hooks + 1] = { obj = t, method = method }
        local old = S[t].fields[method]
        S[t].fields[method] = function(...)
            old(...)
            local was = blizzardCalling
            blizzardCalling = false
            local ok, err = pcall(fn, ...)
            blizzardCalling = was
            if not ok then H.hookErrors[#H.hookErrors + 1] = tostring(err) end
        end
    end
    _G.C_AddOns = {
        IsAddOnLoaded = function() return false, false end,
        GetAddOnMetadata = function(_, field) if field == "Version" then return "0.0.0-dev" end end,
    }
    _G.Settings = {
        RegisterCanvasLayoutCategory = function(canvas, title) return { canvas = canvas, title = title } end,
        RegisterAddOnCategory = function(category) H.category = category end,
    }
    H.pixelFactor = 768 / 1080
    _G.PixelUtil = H.BlizzardTable({ GetPixelToUIUnitFactor = function() return H.pixelFactor end }, "PixelUtil")
    for _, font in ipairs({ "GameFontNormal", "GameFontNormalSmall", "GameFontNormalLarge", "GameFontNormalHuge",
        "GameFontHighlight", "GameFontHighlightSmall" }) do
        _G[font] = { GetFont = function() return "font", 12, "" end }
    end
    for name, text in pairs(H.STRINGS) do _G[name] = text end
    InstallPlayer()
    _G.UIParent = H.BlizzardFrame("Frame", "UIParent")
    S[UIParent].width, S[UIParent].height, S[UIParent].right, S[UIParent].center = 1024, 768, 1024, { 512, 384 }
    _G.Minimap = H.BlizzardFrame("Frame", "Minimap", UIParent)
    S[Minimap].width, S[Minimap].height = 140, 140
    _G.ForeverEnhancedXPBarDB = nil
end

-- Loads the addon's files as the game does, then logs in: ADDON_LOADED, PLAYER_LOGIN and PLAYER_ENTERING_WORLD (a fresh
-- login, or opts.reload for a /reload), then the next frame. opts.beforeLogin stops after ADDON_LOADED. Returns the
-- addon's namespace.
function H.Load(saved, opts)
    opts = opts or {}
    local F = {}
    _G.ForeverEnhancedXPBarDB = saved
    for _, file in ipairs(H.FILES) do assert(loadfile((file:gsub("\\", "/"))))(H.ADDON, F) end
    H.F = F
    H.Fire("ADDON_LOADED", H.ADDON)
    if not opts.beforeLogin then
        H.Fire("PLAYER_LOGIN")
        H.Fire("PLAYER_ENTERING_WORLD", not opts.reload, opts.reload == true)
        H.Frame()
    end
    return F
end

-- A /reload: PLAYER_LOGOUT, then the same saved variables loaded into a fresh copy of the addon.
function H.Reload(opts)
    H.Fire("PLAYER_LOGOUT")
    local saved = _G.ForeverEnhancedXPBarDB
    opts = opts or {}
    opts.reload = true
    return H.Reload2(saved, opts)
end

-- Loads the addon again over the same game (frames of the old copy stay, as after a /reload they would be gone; the old
-- copy's event frame is unregistered so it hears nothing more).
function H.Reload2(saved, opts)
    for _, frame in ipairs(H.frames) do
        S[frame].events = {}
        S[frame].shown = false
    end
    H.frames, H.timers = {}, {}
    for key in pairs(_G) do
        if type(key) == "string" and (key:find("^ForeverEnhancedXPBar") and key ~= "ForeverEnhancedXPBarDB") then
            _G[key] = nil
        end
    end
    _G.UISpecialFrames = {}
    return H.Load(saved, opts)
end

-- A kill line, a level-up and the rest, as the game sends them.
function H.Kill(text) H.Fire("CHAT_MSG_COMBAT_XP_GAIN", text, "", "", "", "", "", 0, 0, "", 0, 0, "") end

-- The player gains xp: the game's numbers change, then PLAYER_XP_UPDATE, then the next frame.
function H.GainXP(amount, opts)
    opts = opts or {}
    local p = H.p
    p.xp = p.xp + amount
    while p.xp >= p.max and p.level < math.min(p.capExpansion, p.capPlayer) do
        p.xp = p.xp - p.max
        p.level = p.level + 1
        p.max = p.max + 1100
        if not opts.quiet then H.Fire("PLAYER_LEVEL_UP", p.level, 10, 10, 0, 0, 1, 1, 1, 1) end
    end
    if p.level >= math.min(p.capExpansion, p.capPlayer) then p.xp = 0 end
    if p.rested and opts.rested then p.rested = math.max(0, p.rested - opts.rested) end
    H.Fire("PLAYER_XP_UPDATE", "player")
    H.Frame()
end

-- The newest region showing this text (or containing it, with part).
function H.Find(text, part)
    for i = #H.objects, 1, -1 do
        local s = S[H.objects[i]]
        if s and (rawequal(s.text, text) or (part and type(s.text) == "string" and s.text:find(text, 1, true))) then
            return H.objects[i]
        end
    end
end

function H.Script(frame, script, ...)
    local fn = S[frame].scripts[script]
    if fn then return fn(frame, ...) end
end

-- Everything that went wrong, as one line: rule violations, hook errors and anything printed.
function H.Problems()
    local list = {}
    for _, v in ipairs(H.violations) do list[#list + 1] = v end
    for _, e in ipairs(H.hookErrors) do list[#list + 1] = "hook error: " .. e end
    for _, p in ipairs(H.printed) do list[#list + 1] = "printed: " .. tostring(p) end
    return table.concat(list, " | ")
end

function H.Clear()
    H.violations, H.hookErrors, H.printed = {}, {}, {}
end

return H
