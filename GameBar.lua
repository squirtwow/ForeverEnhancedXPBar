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

local CHECKS = { .5, 1.5, 3.5 } -- seconds after entering the world to look at EraUI again (it applies within 3)
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

-- A container holds XP while its XP bar is shown. (Its shownBarIndex only changes after the bar's OnShow has run.)
local function HoldsXP(container)
    local bar = XPBar(container)
    return bar ~= nil and Bool(bar:IsShown()) == true
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

local function FadeArt(container)
    for _, piece in ipairs(Art(container)) do
        if artAlpha[piece] == nil then
            local alpha = N(piece:GetAlpha())
            if alpha and alpha > 0 then
                artAlpha[piece], artOwner[piece] = alpha, container
                piece:SetAlpha(0)
            end
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
    for _, container in ipairs(Containers()) do
        local bar = XPBar(container)
        if bar then FadeBar(bar) end
        if HoldsXP(container) then FadeArt(container) else RestoreArt(container) end
    end
end

local function Restore()
    for bar, alpha in pairs(barAlpha) do
        bar:SetAlpha(alpha)
        barAlpha[bar] = nil
    end
    RestoreArt(nil)
    active = false
end

-- Post-hooks, once each: an XP bar showing or hiding (XP moving between the containers), and the dividers rebuilt.
local function Hook()
    for _, container in ipairs(Containers()) do
        local bar = XPBar(container)
        if bar and not hooked[bar] then
            hooked[bar] = true
            bar:HookScript("OnShow", Update)
            bar:HookScript("OnHide", Update)
        end
        if not hooked[container] and type(container.UpdateDividers) == "function" then
            hooked[container] = true
            hooksecurefunc(container, "UpdateDividers", Update)
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
    for i, delay in ipairs(CHECKS) do
        C_Timer.After(delay, F:Guard("game bar", function()
            if i == #CHECKS then settled = true end
            G:Apply()
        end))
    end
end

F:On("PLAYER_LOGIN", function() G:Apply() end)
F:On("PLAYER_ENTERING_WORLD", OnEnterWorld)
F:Listen(function(what)
    if what == "hideGameBar" or what == "reset" then G:Apply() end
end)
