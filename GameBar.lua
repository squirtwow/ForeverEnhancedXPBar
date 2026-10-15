-- Hiding the game's own XP bar (hideGameBar, experimental): a cosmetic, reversible fade, and nothing more. The game has
-- an XP bar in each of its two status bar containers (XP moves to the second one while a faction is watched). Both are
-- faded with SetAlpha(0); neither the game nor EraUI ever sets their alpha. The frame art and dividers of whichever
-- container holds XP fade too, and only if they're showing (EraUI may have faded them already). That's re-checked when
-- an XP bar shows or hides and when the game rebuilds the dividers: post-hooks only.
--
-- Never, on these Edit Mode frames: Hide, SetParent, SetPoint, SetScale, events, the containers' alpha, or the game's own
-- methods that change what they show. Never the reputation bar or the vehicle bar's XP bar. Their mouse is left alone, so
-- the empty slot stays where it was. What was changed is kept in weak tables keyed by frame (never a key on the game's
-- frames) and put back exactly when the tick goes off, on a reset, or when EraUI's classic bar takes the game's bar into
-- its stone band (then the tick is greyed and says why).
local _, F = ...

local G = {}
F.GameBar = G

-- Seconds after entering the world to look again: at EraUI (it applies within 3, so from SETTLE on its own answer is
-- trusted) and at the game's bar (which can still be settling its art after that).
local CHECKS = { .5, 1.5, 3.5, 8 }
local SETTLE = 3.5
local BAND_NOTE = "EraUI's classic bar keeps the game's XP bar in its stone band, so it stays while that's on."
local MISSING_NOTE = "The game's XP bar wasn't found."

local function Weak()
    return setmetatable({}, { __mode = "k" })
end
local barAlpha = Weak() -- an XP bar -> its alpha before it was faded
local artAlpha = Weak() -- a piece of frame art or a divider -> its alpha before
local artOwner = Weak() -- that piece -> its container
local hooked = Weak() -- XP bars and containers already hooked
local active = false -- faded now
local settled = false -- EraUI has had its time to apply
local band = false -- EraUI's classic bar holds the game's bar

local N, Bool = F.Number, F.Bool

-- The game's frames (only read) ----------------------------------------------------------------------------------------------

local function Containers()
    local manager = StatusTrackingBarManager
    local list = type(manager) == "table" and manager.barContainers
    local out = {}
    if type(list) ~= "table" then return out end
    for _, container in ipairs(list) do
        if type(container) == "table" then out[#out + 1] = container end
    end
    return out
end

local function XPIndex()
    local info = StatusTrackingBarInfo
    local index = type(info) == "table" and type(info.BarsEnum) == "table" and N(info.BarsEnum.Experience)
    return index or 4
end

local function XPBar(container)
    local bars = container.bars
    local bar = type(bars) == "table" and bars[XPIndex()]
    return type(bar) == "table" and bar or nil
end

-- A container holds XP while its XP bar is shown, or while the game has XP shown or about to show there. (Its
-- shownBarIndex only changes after the bar's OnShow has run; at login the bar can show before the container does.)
local function HoldsXP(container)
    local bar = XPBar(container)
    if bar == nil then return false end
    if Bool(bar:IsShown()) == true then return true end
    local index = XPIndex()
    return N(container.shownBarIndex) == index or N(container.pendingBarToShowIndex) == index
end

-- The container's frame art and its dividers in use.
local function Art(container)
    local list = {}
    local frameArt = container.BarFrameTexture
    if type(frameArt) == "table" then list[#list + 1] = frameArt end
    local pool = container.HorizontalDividersPool
    if type(pool) == "table" and type(pool.EnumerateActive) == "function" then
        for divider in pool:EnumerateActive() do
            if type(divider) == "table" then list[#list + 1] = divider end
        end
    end
    return list
end

-- Fading and putting back ----------------------------------------------------------------------------------------------------

local function FadeBar(bar)
    if barAlpha[bar] == nil then barAlpha[bar] = N(bar:GetAlpha()) or 1 end
    bar:SetAlpha(0)
end

-- A piece already faded that shows again is faded again (seen in game: after a /reload the frame art and all 19
-- dividers were back at full while the XP bar stayed faded); what it had before the first fade is still what goes back.
local function FadeArt(container)
    for _, piece in ipairs(Art(container)) do
        local alpha = N(piece:GetAlpha())
        if alpha and alpha > 0 then
            if artAlpha[piece] == nil then artAlpha[piece], artOwner[piece] = alpha, container end
            piece:SetAlpha(0)
        end
    end
end

-- Puts back the art faded for one container (nil: all). With EraUI's band holding the bar, its art is EraUI's: the record
-- is dropped and the alpha left as it is.
local function RestoreArt(container)
    for piece, alpha in pairs(artAlpha) do
        if container == nil or artOwner[piece] == container then
            if not band then piece:SetAlpha(alpha) end
            artAlpha[piece], artOwner[piece] = nil, nil
        end
    end
end

local function Update()
    if not active then return end
    local seen = F:IsDev() and {} or nil
    for i, container in ipairs(Containers()) do
        local bar = XPBar(container)
        if bar then FadeBar(bar) end
        local holds = HoldsXP(container)
        if seen then
            local art = container.BarFrameTexture
            table.insert(seen, { container = i, holds = holds, shown = bar and Bool(bar:IsShown()),
                index = N(container.shownBarIndex), art = type(art) == "table" and N(art:GetAlpha()) or nil })
        end
        if holds then FadeArt(container) else RestoreArt(container) end
    end
    if seen then F:DevLog("gamebarUpdate", { t = GetTime(), containers = seen }) end
end

-- Whether any piece that should be faded shows again: the XP bars, and the art of a container holding XP.
local function Showing()
    for _, container in ipairs(Containers()) do
        local bar = XPBar(container)
        if bar and (N(bar:GetAlpha()) or 0) > 0 then return true end
        if HoldsXP(container) then
            for _, piece in ipairs(Art(container)) do
                if (N(piece:GetAlpha()) or 0) > 0 then return true end
            end
        end
    end
    return false
end

-- The first seconds after a loading screen: something outside any function we can hook sets the frame art and the
-- dividers back to full, twice (dev log, 2026-10-15). A close look every WATCH_STEP for WATCH_FOR seconds fades them
-- again before they're seen, then stops.
local WATCH_STEP, WATCH_FOR = .05, 10
local watch
local function Watch()
    if watch then watch:Cancel() end
    watch = C_Timer.NewTicker(WATCH_STEP, F:Guard("game bar watch", function()
        if active and Showing() then Update() end
    end), math.floor(WATCH_FOR / WATCH_STEP))
end

local function Restore()
    for bar, alpha in pairs(barAlpha) do
        bar:SetAlpha(alpha)
        barAlpha[bar] = nil
    end
    RestoreArt(nil)
    active = false
end

-- Post-hooks, once each: an XP bar showing or hiding (XP moving between the containers), the dividers rebuilt, a
-- container showing, and a container taking its new bar (at login the game shows the bar, then the container).
local CONTAINER_HOOKS = { "UpdateDividers", "ApplyPendingBarToShow", "UpdateShownState" }
local function Hook()
    for _, container in ipairs(Containers()) do
        local bar = XPBar(container)
        if bar and not hooked[bar] then
            hooked[bar] = true
            bar:HookScript("OnShow", Update)
            bar:HookScript("OnHide", Update)
        end
        if not hooked[container] then
            hooked[container] = true
            for _, name in ipairs(CONTAINER_HOOKS) do
                if type(container[name]) == "function" then hooksecurefunc(container, name, Update) end
            end
            if type(container.HookScript) == "function" then container:HookScript("OnShow", Update) end
        end
    end
end

-- EraUI's classic bar ------------------------------------------------------------------------------------------------------------

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return value end
    return nil
end

-- Whether EraUI's classic bar holds the game's XP bar: what EraUI says, or (before it has had its time to apply) what its
-- settings say it will do.
function G:BandActive()
    local era = _G.EraUI
    if type(era) ~= "table" then return false end
    local classic = era.Classic
    if type(classic) ~= "table" or type(classic.ClassicBarActive) ~= "function" then return false end
    if Bool(Call(classic.ClassicBarActive)) == true then return true end
    if settled then return false end
    return Call(era.GetSetting, era, "enabled") ~= false and Call(era.GetSetting, era, "actionBars") ~= false
end

-- Why the tick can't be used right now, or nil.
function G:Blocked()
    if band then return BAND_NOTE end
    if #Containers() == 0 then return MISSING_NOTE end
    return nil
end

function G:Active()
    return active
end

function G:Apply()
    local was = band
    band = self:BandActive()
    if band ~= was then F:Notify("band") end
    if F:Get("hideGameBar") and not band then
        Hook()
        active = true
        Update()
    elseif active then
        Restore()
    end
    F:DevLog("gamebar", { t = GetTime(), band = band, settled = settled, hiding = active })
end

local function OnEnterWorld()
    G:Apply()
    Watch()
    for _, delay in ipairs(CHECKS) do
        C_Timer.After(delay, F:Guard("game bar", function()
            if delay >= SETTLE then settled = true end
            G:Apply()
        end))
    end
end

F:On("PLAYER_LOGIN", function() G:Apply() end)
F:On("PLAYER_ENTERING_WORLD", OnEnterWorld)
F:Listen(function(what)
    if what == "hideGameBar" or what == "reset" then G:Apply() end
end)
