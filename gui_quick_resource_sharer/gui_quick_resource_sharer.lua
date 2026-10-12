--[[
  =============================================================================
  Widget: Quick Ally Resource Sharer
  Game: Beyond All Reason (BAR)
  Engine: Recoil / Spring RTS
  License: GNU General Public License v2.0 or later
  =============================================================================

  Description:
    Monitors ally team resource levels (Metal and Energy). When a teammate is
    critically stalling and the local player holds a healthy surplus, displays
    an unobtrusive on-screen prompt with a single-click button to send resources.

  Fair Play & Competition Compliance:
    - 100% compliant with BAR Code of Conduct (Section B.5 "Unfair Advantages").
    - Strictly manual: Requires deliberate human click; does NOT auto-macro.
    - Uses only public ally information already exposed to teammates.
    - Completely client-side (LuaUI), zero desync risk.
    - Open source and public.
]]

function widget:GetInfo()
  return {
    name      = "Quick Ally Resource Sharer",
    desc      = "Shows on-screen alerts and single-click share buttons when allies stall resources.",
    author    = "MikiVernox",
    date      = "2026",
    license   = "GNU GPL, v2 or later",
    layer     = 5,
    enabled   = true
  }
end

-- =========================================================================
-- CONFIGURATION
-- =========================================================================
local CONFIG = {
  checkIntervalFrames   = 30,    -- Run scanner every ~1 second (30 sim frames)
  energyShareAmount     = 500,   -- Energy sent per click
  metalShareAmount      = 200,   -- Metal sent per click

  -- Ally stall detection criteria
  energyStallThreshold  = 100,   -- Absolute minimum energy to trigger alert
  energyStallRatio      = 0.05,  -- Or below 5% of their total energy storage
  metalStallThreshold   = 50,    -- Absolute minimum metal to trigger alert
  metalStallRatio       = 0.05,  -- Or below 5% of their total metal storage

  -- Local player minimum safety reserves (do not prompt if player cannot spare)
  myMinEnergyReserve    = 1000,
  myMinMetalReserve     = 400,

  -- Card dimensions & layout
  cardWidth             = 290,
  cardHeight            = 32,
  cardPadding           = 6,
  btnWidth              = 68,
  btnPaddingRight       = 26,
  dismissWidth          = 18,

  -- Cooldown / snooze time (in seconds) when dismiss [x] is clicked
  snoozeDurationSec     = 45,

  -- Default position (pixels from bottom-left corner)
  defaultPosX           = 50,
  defaultPosY           = 520,
}

-- =========================================================================
-- LOCALIZED ENGINE & LUA FUNCTIONS (Performance / Fast JIT dispatch)
-- =========================================================================
local spGetMyTeamID          = Spring.GetMyTeamID
local spGetMyAllyTeamID      = Spring.GetMyAllyTeamID
local spGetTeamResources     = Spring.GetTeamResources
local spGetTeamList          = Spring.GetTeamList
local spGetTeamInfo          = Spring.GetTeamInfo
local spGetPlayerInfo        = Spring.GetPlayerInfo
local spGetAIInfo            = Spring.GetAIInfo
local spShareResources       = Spring.ShareResources
local spGetGameSeconds       = Spring.GetGameSeconds
local spGetSpectatingState   = Spring.GetSpectatingState
local spGetMouseState        = Spring.GetMouseState
local spGetViewGeometry      = Spring.GetViewGeometry
local spEcho                 = Spring.Echo

local glColor                = gl.Color
local glRect                 = gl.Rect
local glText                 = gl.Text
local glLineWidth            = gl.LineWidth
local glPolygonMode          = gl.PolygonMode

local GL_FRONT_AND_BACK      = GL.FRONT_AND_BACK
local GL_LINE                = GL.LINE
local GL_FILL                = GL.FILL

local format                 = string.format
local floor                  = math.floor
local max                    = math.max
local min                    = math.min
local tostring               = tostring
local ipairs                 = ipairs

-- =========================================================================
-- PRE-COMPUTED CONSTANTS & CACHES (Zero runtime allocation)
-- =========================================================================
local LABEL_BTN_ENERGY = format("+%d E", CONFIG.energyShareAmount)
local LABEL_BTN_METAL  = format("+%d M", CONFIG.metalShareAmount)

local myTeamID          = nil
local myAllyTeamID      = nil
local isSpectator       = false

local posX              = CONFIG.defaultPosX
local posY              = CONFIG.defaultPosY
local vsx, vsy          = 1920, 1080

-- Dragging state
local isDragging        = false
local dragOffsetX       = 0
local dragOffsetY       = 0

-- Snooze table: snoozedTeams[teamID][resType] = expireTimestamp
local snoozedTeams      = {}

-- Cached player info records to eliminate runtime string concatenations
-- Schema: playerRecordCache[teamID] = { name = "...", energyLabel = "...", metalLabel = "..." }
local playerRecordCache = {}

-- Pre-allocated alert pool to achieve zero table allocations in GameFrame
local alertPool         = {}
local activeAlertsCount = 0

local function GetPooledAlert(index)
  local alert = alertPool[index]
  if not alert then
    alert = {
      teamID   = 0,
      name     = "",
      resType  = "",
      amount   = 0,
      label    = "",
      btnLabel = ""
    }
    alertPool[index] = alert
  end
  return alert
end

local function RemoveAlertByIndex(index)
  if index < 1 or index > activeAlertsCount then return end
  local target = alertPool[index]
  for i = index, activeAlertsCount - 1 do
    alertPool[i] = alertPool[i + 1]
  end
  alertPool[activeAlertsCount] = target
  activeAlertsCount = activeAlertsCount - 1
end

-- =========================================================================
-- INITIALIZATION / SHUTDOWN / RESIZE
-- =========================================================================
function widget:Initialize()
  myTeamID = spGetMyTeamID()
  myAllyTeamID = spGetMyAllyTeamID()
  isSpectator = spGetSpectatingState()

  local _, _, vx, vy = spGetViewGeometry()
  if vx and vy then
    vsx, vsy = vx, vy
  end

  spEcho("[Quick Ally Resource Sharer] Initialized successfully.")
end

function widget:Shutdown()
  alertPool = {}
  activeAlertsCount = 0
  snoozedTeams = {}
  playerRecordCache = {}
end

function widget:ViewResize(newX, newY)
  vsx, vsy = newX, newY
  -- Clamp positions within visible screen boundaries
  posX = max(10, min(vsx - CONFIG.cardWidth - 10, posX))
  posY = max(50, min(vsy - 100, posY))
end

-- =========================================================================
-- HELPER FUNCTIONS
-- =========================================================================
local function ResolvePlayerRecord(teamID, leader, isAi)
  local cached = playerRecordCache[teamID]
  if cached then return cached end

  local name = nil
  if isAi and spGetAIInfo then
    local _, aiName = spGetAIInfo(teamID)
    if aiName and aiName ~= "" then
      name = "AI: " .. aiName
    end
  elseif leader and leader >= 0 then
    name = spGetPlayerInfo(leader)
  end

  if not name or name == "" then
    name = "Team " .. tostring(teamID)
  end

  cached = {
    name        = name,
    energyLabel = "[E] " .. name .. " lacks Energy!",
    metalLabel  = "[M] " .. name .. " lacks Metal!"
  }
  playerRecordCache[teamID] = cached
  return cached
end

local function IsAlertSnoozed(teamID, resType, now)
  local teamSnooze = snoozedTeams[teamID]
  if not teamSnooze then return false end

  local expiry = teamSnooze[resType]
  return (expiry and expiry > now) or false
end

local function SetAlertSnoozed(teamID, resType, durationSec)
  local now = spGetGameSeconds()
  if not snoozedTeams[teamID] then
    snoozedTeams[teamID] = {}
  end
  snoozedTeams[teamID][resType] = now + durationSec
end

-- =========================================================================
-- RESOURCE TRANSFER ACTION
-- =========================================================================
local function ExecuteResourceShare(teamID, resType, amount, allyName)
  local currentLevel = spGetTeamResources(myTeamID, resType)
  if not currentLevel or currentLevel < amount then
    spEcho(format("[Resource Sharer] Cannot share: insufficient %s reserves.", resType))
    return
  end

  spShareResources(teamID, resType, amount)
  spEcho(format("[Resource Sharer] Sent %d %s to %s.", amount, resType, allyName))

  -- Snooze for 5 seconds to prevent accidental duplicate clicks
  SetAlertSnoozed(teamID, resType, 5)
end

-- =========================================================================
-- SCANNER LOOP (Zero GC allocation)
-- =========================================================================
function widget:GameFrame(frameNum)
  if frameNum % CONFIG.checkIntervalFrames ~= 0 then return end

  isSpectator = spGetSpectatingState()
  if isSpectator then
    activeAlertsCount = 0
    return
  end

  myTeamID = spGetMyTeamID()
  myAllyTeamID = spGetMyAllyTeamID()
  if not myTeamID or not myAllyTeamID then return end

  local _, _, myDead = spGetTeamInfo(myTeamID)
  if myDead then
    activeAlertsCount = 0
    return
  end

  local now = spGetGameSeconds()
  local myEnergy, myEStorage = spGetTeamResources(myTeamID, "energy")
  local myMetal, myMStorage   = spGetTeamResources(myTeamID, "metal")

  local teamList = spGetTeamList(myAllyTeamID)
  if not teamList then return end

  local count = 0

  for _, teamID in ipairs(teamList) do
    if teamID ~= myTeamID then
      local _, leader, isDead, isAi = spGetTeamInfo(teamID)
      if not isDead then
        local record = ResolvePlayerRecord(teamID, leader, isAi)

        -- 1. Evaluate Energy Stall
        if not IsAlertSnoozed(teamID, "energy", now) then
          local eCur, eStor, _, eInc, eExp = spGetTeamResources(teamID, "energy")
          if eCur and eStor and eExp and eInc and (eExp > eInc) and
             (eCur < CONFIG.energyStallThreshold or eCur < eStor * CONFIG.energyStallRatio) then
            if myEnergy and myEnergy >= CONFIG.myMinEnergyReserve and myEnergy >= (CONFIG.energyShareAmount * 1.5) then
              count = count + 1
              local alert = GetPooledAlert(count)
              alert.teamID   = teamID
              alert.name     = record.name
              alert.resType  = "energy"
              alert.amount   = CONFIG.energyShareAmount
              alert.label    = record.energyLabel
              alert.btnLabel = LABEL_BTN_ENERGY
            end
          end
        end

        -- 2. Evaluate Metal Stall
        if not IsAlertSnoozed(teamID, "metal", now) then
          local mCur, mStor, _, mInc, mExp = spGetTeamResources(teamID, "metal")
          if mCur and mStor and mExp and mInc and (mExp > mInc) and
             (mCur < CONFIG.metalStallThreshold or mCur < mStor * CONFIG.metalStallRatio) then
            if myMetal and myMetal >= CONFIG.myMinMetalReserve and myMetal >= (CONFIG.metalShareAmount * 1.5) then
              count = count + 1
              local alert = GetPooledAlert(count)
              alert.teamID   = teamID
              alert.name     = record.name
              alert.resType  = "metal"
              alert.amount   = CONFIG.metalShareAmount
              alert.label    = record.metalLabel
              alert.btnLabel = LABEL_BTN_METAL
            end
          end
        end

      end
    end
  end

  activeAlertsCount = count
end

-- =========================================================================
-- RENDERING (OpenGL Screen Overlay)
-- =========================================================================
function widget:DrawScreen()
  if isSpectator or activeAlertsCount == 0 then return end

  local mx, my = spGetMouseState()
  local baseWidth  = CONFIG.cardWidth
  local baseHeight = CONFIG.cardHeight
  local padding    = CONFIG.cardPadding
  local btnW       = CONFIG.btnWidth
  local btnH       = baseHeight - 8
  local disW       = CONFIG.dismissWidth

  for i = 1, activeAlertsCount do
    local alert = alertPool[i]
    local y = posY - (i * (baseHeight + padding))

    -- Background Card (dark slate semi-transparent)
    glColor(0.06, 0.08, 0.12, 0.88)
    glRect(posX, y, posX + baseWidth, y + baseHeight)

    -- Dynamic Border Accent
    if alert.resType == "energy" then
      glColor(1.0, 0.82, 0.15, 0.85) -- Energy Amber
    else
      glColor(0.35, 0.70, 0.95, 0.85) -- Metal Cyan/Silver
    end
    glLineWidth(1.4)
    glPolygonMode(GL_FRONT_AND_BACK, GL_LINE)
    glRect(posX, y, posX + baseWidth, y + baseHeight)
    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)
    glLineWidth(1.0) -- Restore OpenGL default line width

    -- Information Text (vertically centered using "ov")
    glColor(0.95, 0.95, 0.95, 1.0)
    glText(alert.label, posX + 8, y + (baseHeight * 0.5), 11, "ov")

    -- Share Button coordinates
    local btnX = posX + baseWidth - btnW - CONFIG.btnPaddingRight
    local btnY = y + 4
    local isBtnHovered = (mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH)

    -- Share Button Background with Hover Effect
    if alert.resType == "energy" then
      if isBtnHovered then
        glColor(1.0, 0.90, 0.35, 1.0)
      else
        glColor(0.92, 0.76, 0.12, 0.95)
      end
    else
      if isBtnHovered then
        glColor(0.40, 0.78, 1.0, 1.0)
      else
        glColor(0.25, 0.60, 0.88, 0.95)
      end
    end
    glRect(btnX, btnY, btnX + btnW, btnY + btnH)

    -- Button Label (centered horizontally and vertically using "ocv")
    glColor(0.05, 0.05, 0.05, 1.0)
    glText(alert.btnLabel, btnX + (btnW * 0.5), btnY + (btnH * 0.5), 11, "ocv")

    -- Dismiss [x] Button
    local disX = posX + baseWidth - disW - 4
    local disY = y + 4
    local isDisHovered = (mx >= disX and mx <= disX + disW and my >= disY and my <= disY + btnH)

    if isDisHovered then
      glColor(0.55, 0.20, 0.20, 0.9)
    else
      glColor(0.22, 0.24, 0.28, 0.8)
    end
    glRect(disX, disY, disX + disW, disY + btnH)

    -- Dismiss Label
    glColor(0.85, 0.85, 0.85, 1.0)
    glText("x", disX + (disW * 0.5), disY + (btnH * 0.5), 11, "ocv")
  end

  -- Restore OpenGL state
  glColor(1.0, 1.0, 1.0, 1.0)
end

-- =========================================================================
-- USER INTERACTION (Mouse Events)
-- =========================================================================
function widget:MousePress(mx, my, button)
  if isSpectator or activeAlertsCount == 0 then return false end

  local baseWidth  = CONFIG.cardWidth
  local baseHeight = CONFIG.cardHeight
  local padding    = CONFIG.cardPadding
  local btnW       = CONFIG.btnWidth
  local btnH       = baseHeight - 8
  local disW       = CONFIG.dismissWidth

  -- 1. Left Click: Button Actions
  if button == 1 then
    for i = 1, activeAlertsCount do
      local alert = alertPool[i]
      local y = posY - (i * (baseHeight + padding))

      if mx >= posX and mx <= posX + baseWidth and my >= y and my <= y + baseHeight then
        local btnX = posX + baseWidth - btnW - CONFIG.btnPaddingRight
        local btnY = y + 4

        -- Action: Share Resource Button Clicked
        if mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH then
          ExecuteResourceShare(alert.teamID, alert.resType, alert.amount, alert.name)
          RemoveAlertByIndex(i) -- Immediate UI removal for instant feedback
          return true
        end

        -- Action: Dismiss Snooze Button Clicked
        local disX = posX + baseWidth - disW - 4
        local disY = y + 4
        if mx >= disX and mx <= disX + disW and my >= disY and my <= disY + btnH then
          SetAlertSnoozed(alert.teamID, alert.resType, CONFIG.snoozeDurationSec)
          spEcho(format("[Resource Sharer] Snoozed %s alerts for %s (%ds).", alert.resType, alert.name, CONFIG.snoozeDurationSec))
          RemoveAlertByIndex(i) -- Immediate UI removal for instant feedback
          return true
        end

        return true
      end
    end
  end

  -- 2. Middle Click (Button 2) or Right Click (Button 3): Drag to Reposition
  if button == 2 or button == 3 then
    local totalHeight = activeAlertsCount * (baseHeight + padding)
    local topY = posY
    local bottomY = posY - totalHeight

    if mx >= posX and mx <= posX + baseWidth and my >= bottomY and my <= topY then
      isDragging = true
      dragOffsetX = mx - posX
      dragOffsetY = my - posY
      return true
    end
  end

  return false
end

function widget:MouseMove(mx, my, dx, dy, button)
  if isDragging then
    posX = max(10, min(vsx - CONFIG.cardWidth - 10, mx - dragOffsetX))
    posY = max(50, min(vsy - 50, my - dragOffsetY))
    return true
  end
  return false
end

function widget:MouseRelease(mx, my, button)
  if isDragging and (button == 2 or button == 3) then
    isDragging = false
    return true
  end
  return false
end
