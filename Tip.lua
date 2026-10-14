-- The addon's own hover box, for the bar and the minimap button. The game's tooltip is never touched. It sits in the
-- TOOLTIP strata under UIParent, never takes the mouse and grows to fit: a title with a line under it, rows of a label on
-- the left and a value on the right (or one line of text), and a quiet footer.
--
-- The bar's box lists the details ticked on the Hover details page (dXP, dRested, dQuests, dDone, dLevelTime, dSession,
-- dRate, dEta, dKills, dToQuests), in that order. At max level it keeps In finished quests, Quests done and This session;
-- with XP gain turned off it says so, then Quests done and This session.
local _, F = ...

local T = F.Theme
local P = T.TIP

local TP = {}
F.Tip = TP

local MIN_W, MAX_W, PAD, LINE_H, GAP = 330, 400, 12, 16, 16
local BAR_GAP, BAR_ROOM = 4, 2 -- clear of the bar's outer edge; how far that is past its track if not said (the border)
local box, owner

local function Build()
    box = CreateFrame("Frame", "ForeverEnhancedXPBarTip", UIParent, "BackdropTemplate")
    box:SetSize(MIN_W, 60)
    box:SetFrameStrata("TOOLTIP")
    box:SetClampedToScreen(true)
    box:EnableMouse(false)
    T:Flat(box, P.back, P.edge)
    box.title = T:Text(box, "GameFontNormalLarge", P.title)
    box.title:SetPoint("TOPLEFT", PAD, -PAD)
    box.rule = T:Block(box, P.line, "ARTWORK")
    box.rule:SetHeight(1)
    box.footer = T:Text(box, "GameFontHighlightSmall", P.footer)
    box.labels, box.values = {}, {}
    box:Hide()
end

local function Line(i)
    local label, value = box.labels[i], box.values[i]
    if not label then
        label = T:Text(box, "GameFontHighlight", P.label)
        value = T:Text(box, "GameFontHighlight", P.value)
        value:SetJustifyH("RIGHT")
        box.labels[i], box.values[i] = label, value
    end
    return label, value
end

-- content: { title, rows = { { label, value } or { text = "..." } }, footer, minWidth }.
local function Fill(content)
    local rows = content.rows or {}
    box.title:SetText(content.title or "")
    local widest = box.title:GetStringWidth() or 0
    local y = -PAD - 22
    box.rule:ClearAllPoints()
    box.rule:SetPoint("TOPLEFT", PAD, y + 4)
    box.rule:SetPoint("TOPRIGHT", -PAD, y + 4)
    y = y - 4
    for i, row in ipairs(rows) do
        local label, value = Line(i)
        label:ClearAllPoints()
        label:SetPoint("TOPLEFT", PAD, y)
        value:ClearAllPoints()
        value:SetPoint("TOPRIGHT", -PAD, y)
        if row.text then
            label:SetText(row.text)
            label:SetTextColor(P.value[1], P.value[2], P.value[3])
            value:SetText("")
            widest = math.max(widest, label:GetStringWidth() or 0)
        else
            label:SetText(row[1])
            label:SetTextColor(P.label[1], P.label[2], P.label[3])
            value:SetText(row[2])
            widest = math.max(widest, (label:GetStringWidth() or 0) + GAP + (value:GetStringWidth() or 0))
        end
        label:Show()
        value:Show()
        y = y - LINE_H
    end
    for i = #rows + 1, #box.labels do
        box.labels[i]:Hide()
        box.values[i]:Hide()
    end
    if content.footer then
        box.footer:ClearAllPoints()
        box.footer:SetPoint("TOPLEFT", PAD, y - 6)
        box.footer:SetText(content.footer)
        box.footer:Show()
        widest = math.max(widest, box.footer:GetStringWidth() or 0)
        y = y - 6 - 14
    else
        box.footer:SetText("")
        box.footer:Hide()
    end
    local width = math.max(content.minWidth or MIN_W, math.min(MAX_W, math.floor(widest + PAD * 2 + .5)))
    box:SetSize(width, math.floor(-y + PAD - 2 + .5))
end

-- Above the bar, its right edge on the bar's; below it when the bar is in the top half of the screen. above and below:
-- how far the bar reaches past its track (its border, Thin's text above, the line under it), so the box clears them.
local function PlaceByBar(frame, above, below)
    local _, y = frame:GetCenter()
    local _, middle = UIParent:GetCenter()
    local scale = (frame:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
    local under = F.Number(y) ~= nil and F.Number(middle) ~= nil and y * scale > middle
    box:ClearAllPoints()
    if under then
        box:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -((F.Number(below) or BAR_ROOM) + BAR_GAP))
    else
        box:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, (F.Number(above) or BAR_ROOM) + BAR_GAP)
    end
    return under
end

-- Toward the middle of the screen from the frame, so it's never cut off (the minimap button).
local function PlaceByMiddle(frame)
    local right, top = true, true
    local x, y = frame:GetCenter()
    local midX, midY = UIParent:GetCenter()
    if F.Number(x) and F.Number(y) and F.Number(midX) and F.Number(midY) then
        local scale = (frame:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
        right, top = x * scale > midX, y * scale > midY
    end
    box:ClearAllPoints()
    box:SetPoint((top and "TOP" or "BOTTOM") .. (right and "RIGHT" or "LEFT"), frame,
        (top and "BOTTOM" or "TOP") .. (right and "LEFT" or "RIGHT"), 0, 0)
end

-- Shows the box for a frame. how: "bar" (above or below it, right-aligned, clear of the room above and below given) or
-- nil (toward the screen's middle).
function TP:Show(frame, content, how, above, below)
    if not content then return self:Hide(frame) end
    if not box then Build() end
    owner = frame
    Fill(content)
    if how == "bar" then PlaceByBar(frame, above, below) else PlaceByMiddle(frame) end
    box:Show()
end

-- Only the frame that showed it can take it down.
function TP:Hide(frame)
    if box and (frame == nil or frame == owner) then
        box:Hide()
        owner = nil
    end
end

-- Refreshes the content while it's up for this frame (the times ticking).
function TP:Update(frame, content)
    if not (box and box:IsShown() and owner == frame) then return end
    if not content then return self:Hide(frame) end
    Fill(content)
end

function TP:Owner()
    return box and box:IsShown() and owner or nil
end

function TP:Box()
    return box
end

-- The bar's details ---------------------------------------------------------------------------------------------------------

local Commas, Percent = F.Commas, F.Percent

local function Plural(n, one, many)
    return F.Commas(n) .. " " .. (n == 1 and one or many)
end

local function RestedValue(st)
    local text = st.rested > 0 and (Commas(st.rested) .. " (" .. Percent(st.rested, st.max) .. ")") or "None"
    if st.resting then text = text .. ", resting" end
    return text
end

local function QuestsValue(st)
    local QS = F.Quests
    if QS.sum <= 0 then return "None waiting" end
    local text = Commas(QS.sum) .. " XP in " .. Plural(QS.count, "quest", "quests")
    if not F.Track:AtMax() and st.max > 0 then text = text .. " (" .. Percent(QS.sum, st.max) .. ")" end
    if QS:LevelsUp() then text = text .. ", levels you up" end
    return text
end

local function DoneValue()
    local char = F:Char()
    local session = char and char.session
    return Commas(char and char.questsLevel or 0) .. " this level, " .. Commas(session and session.quests or 0)
        .. " this session"
end

local function LevelTimeValue()
    local seconds, exact = F.Track:LevelSeconds()
    return (exact and "" or "at least ") .. F.Duration(seconds)
end

local function SessionValue()
    local session = F.Track:Session()
    return F.Duration(F.Track:SessionSeconds()) .. ", " .. Commas(session and session.xp or 0) .. " XP"
end

local function RateValue()
    local rate = F.Track:Rate()
    return rate and Commas(rate) or "-"
end

local function KillsValue()
    local count, base, rested = F.Kills:ToLevel()
    if not count then return "-" end
    local each = Commas(base) .. " XP each"
    if rested then each = each .. ", " .. Commas(rested) .. " while rested" end
    return "~" .. Commas(count) .. " (" .. each .. ")"
end

local function ToQuestsValue()
    local count, average = F.Quests:ToLevel()
    if count == "handIn" then return "Hand in your finished quests" end
    if not count then return "-" end
    return "~" .. Commas(count) .. " (" .. Commas(average) .. " XP each)"
end

local function XPValue(st)
    return Commas(st.xp) .. " / " .. Commas(st.max) .. " (" .. Percent(st.xp, st.max) .. ")"
end

-- The ten details in the mockup's order: key, label, value.
TP.DETAILS = {
    { "dXP", "XP this level", XPValue },
    { "dRested", "Rested", RestedValue },
    { "dQuests", "In finished quests", QuestsValue },
    { "dDone", "Quests done", DoneValue },
    { "dLevelTime", "Time on this level", LevelTimeValue },
    { "dSession", "This session", SessionValue },
    { "dRate", "XP per hour", RateValue },
    { "dEta", "Next level in", function() return F.Eta(F.Track:EtaSeconds()) end },
    { "dKills", "Kills to level", KillsValue },
    { "dToQuests", "Quests to level", ToQuestsValue },
}
-- What stays at max level, and with XP gain turned off.
local AT_MAX = { dQuests = true, dDone = true, dSession = true }
local WHEN_OFF = { dDone = true, dSession = true }

-- The bar's box: nil when nothing is ticked (or nothing has been read yet).
function TP:BarContent()
    local TR = F.Track
    local st = TR.now
    if not st.level then return nil end
    local atMax, off = TR:AtMax(), TR:Off()
    local rows = {}
    local title
    if atMax then
        title = "Level " .. Commas(st.level) .. ", max level"
    elseif off then
        title = "Level " .. Commas(st.level)
        rows[1] = { text = "XP gain is turned off" }
    else
        title = "Level " .. Commas(st.level) .. " to " .. Commas(st.level + 1)
    end
    for _, detail in ipairs(self.DETAILS) do
        local key = detail[1]
        local wanted = F:Get(key) and (not atMax or AT_MAX[key]) and (not off or WHEN_OFF[key])
        if wanted then rows[#rows + 1] = { detail[2], detail[3](st) } end
    end
    if #rows == 0 then return nil end
    local footer = F:Get("minimap") and "Right-click the minimap button to show or hide the bar"
        or (F.SLASH .. " opens the settings")
    return { title = title, rows = rows, footer = footer }
end
