--[[
  Widget: Quick Ally Resource Sharer
  Game: Beyond All Reason (BAR)
  Engine: Recoil / Spring RTS
  License: GNU GPL v2 or later
  
  Description:
    Monitors teammates' metal and energy reserves. When an ally is heavily
    stalling resources and the local player has a healthy surplus, displays
    a discreet on-screen prompt with a one-click button to send resources.
    
    100% Fair Play compliant:
    - Only reads visible team data
    - Requires explicit human click to send (no automatic macroing)
    - Public open-source code for Discord #widgets
]]

function widget:GetInfo()
  return {
    name      = "Quick Ally Resource Sharer",
    desc      = "Shows on-screen alerts and 1-click share buttons when allies stall resources.",
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
  checkIntervalFrames   = 30,    -- Run economy check roughly once per second (30 frames)
  energyShareAmount     = 500,   -- Default energy sent on click
  metalShareAmount      = 200,   -- Default metal sent on click
  
  -- Ally stall detection thresholds
  energyStallThreshold  = 100,   -- Energy level under which ally is considered stalling
  energyStallRatio      = 0.05,  -- Or under 5% of their total storage
  metalStallThreshold   = 50,    -- Metal level under which ally is considered stalling
  metalStallRatio       = 0.05,  -- Or under 5% of their total storage
  
  -- Minimum surplus player must hold before offering to donate
  myMinEnergyReserve    = 1000,  -- Don't suggest sharing if we have less than this
  myMinMetalReserve     = 400,   -- Don't suggest sharing if we have less than this
  
  -- UI Layout
  posX                  = 50,    -- Screen X offset (from left)
  posY                  = 500,   -- Screen Y offset (from bottom)
  cardWidth             = 280,
  cardHeight            = 32,
  cardPadding           = 6,
  
  -- Cooldowns
  snoozeDurationSec     = 45,    -- How long to hide an ally if user clicks "Dismiss"
}

-- =========================================================================
-- STATE
-- =========================================================================
local myTeamID        = nil
local myAllyTeamID    = nil
local activeAlerts    = {}
local snoozedTeams    = {} -- [teamID .. "_" .. resType] = timestampSeconds

-- =========================================================================
-- INITIALIZATION / SHUTDOWN
-- =========================================================================
function widget:Initialize()
  myTeamID = Spring.GetMyTeamID()
  myAllyTeamID = Spring.GetMyAllyTeamID()
  Spring.Echo("[Quick Resource Sharer] Initialized successfully.")
end

function widget:Shutdown()
  activeAlerts = {}
  snoozedTeams = {}
end

-- =========================================================================
-- HELPERS
-- =========================================================================
local function GetPlayerDisplayName(teamID, leader)
  if leader and leader >= 0 then
    local name = Spring.GetPlayerInfo(leader)
    if name and name ~= "" then
      return name
    end
  end
  return "Team " .. tostring(teamID)
end

local function IsSnoozed(teamID, resType, now)
  local key = tostring(teamID) .. "_" .. resType
  local expiry = snoozedTeams[key]
  if expiry and expiry > now then
    return true
  end
  return false
end

local function SnoozeAlert(teamID, resType)
  local now = Spring.GetGameSeconds()
  local key = tostring(teamID) .. "_" .. resType
  snoozedTeams[key] = now + CONFIG.snoozeDurationSec
end

-- =========================================================================
-- ECONOMY SCANNER
-- =========================================================================
function widget:GameFrame(frameNum)
  if frameNum % CONFIG.checkIntervalFrames ~= 0 then return end
  
  myTeamID = Spring.GetMyTeamID()
  myAllyTeamID = Spring.GetMyAllyTeamID()
  if not myTeamID or not myAllyTeamID then return end
  
  local now = Spring.GetGameSeconds()
  local myEnergy, myEStorage, _, myEIncome, myEExpense = Spring.GetTeamResources(myTeamID, "energy")
  local myMetal, myMStorage, _, myMIncome, myMExpense    = Spring.GetTeamResources(myTeamID, "metal")
  
  local newAlerts = {}
  local teamList = Spring.GetTeamList(myAllyTeamID) or {}
  
  for _, teamID in ipairs(teamList) do
    if teamID ~= myTeamID then
      local _, leader, isDead, isAi = Spring.GetTeamInfo(teamID)
      if not isDead then
        local allyName = GetPlayerDisplayName(teamID, leader)
        
        -- Check Energy stall
        if not IsSnoozed(teamID, "energy", now) then
          local eCur, eStor, _, eInc, eExp = Spring.GetTeamResources(teamID, "energy")
          if eCur and (eCur < CONFIG.energyStallThreshold or (eStor and eCur < eStor * CONFIG.energyStallRatio)) and (eExp and eInc and eExp > eInc) then
            if myEnergy and myEnergy >= CONFIG.myMinEnergyReserve and (myEnergy >= CONFIG.energyShareAmount * 1.5) then
              table.insert(newAlerts, {
                teamID   = teamID,
                name     = allyName,
                resType  = "energy",
                amount   = CONFIG.energyShareAmount,
                label    = string.format("⚡ %s lacks Energy!", allyName),
                btnLabel = string.format("+%d E", CONFIG.energyShareAmount)
              })
            end
          end
        end
        
        -- Check Metal stall
        if not IsSnoozed(teamID, "metal", now) then
          local mCur, mStor, _, mInc, mExp = Spring.GetTeamResources(teamID, "metal")
          if mCur and (mCur < CONFIG.metalStallThreshold or (mStor and mCur < mStor * CONFIG.metalStallRatio)) and (mExp and mInc and mExp > mInc) then
            if myMetal and myMetal >= CONFIG.myMinMetalReserve and (myMetal >= CONFIG.metalShareAmount * 1.5) then
              table.insert(newAlerts, {
                teamID   = teamID,
                name     = allyName,
                resType  = "metal",
                amount   = CONFIG.metalShareAmount,
                label    = string.format("⚙️ %s lacks Metal!", allyName),
                btnLabel = string.format("+%d M", CONFIG.metalShareAmount)
              })
            end
          end
        end
        
      end
    end
  end
  
  activeAlerts = newAlerts
end

-- =========================================================================
-- RESOURCE TRANSFER ACTION
-- =========================================================================
local function ShareResource(teamID, resType, amount, allyName)
  Spring.ShareResources(teamID, resType, amount)
  Spring.Echo(string.format("[Resource Sharer] Sent %d %s to %s.", amount, resType, allyName))
  -- Temporarily snooze to avoid duplicate rapid clicks on the same alert
  SnoozeAlert(teamID, resType)
end

-- =========================================================================
-- RENDERING (OpenGL DrawScreen)
-- =========================================================================
function widget:DrawScreen()
  if #activeAlerts == 0 then return end
  
  local x = CONFIG.posX
  local baseHeight = CONFIG.cardHeight
  local padding = CONFIG.cardPadding
  
  for i, alert in ipairs(activeAlerts) do
    local y = CONFIG.posY - (i * (baseHeight + padding))
    
    -- Card background (dark semi-transparent slate)
    gl.Color(0.08, 0.10, 0.14, 0.85)
    gl.Rect(x, y, x + CONFIG.cardWidth, y + baseHeight)
    
    -- Subtle border
    if alert.resType == "energy" then
      gl.Color(1.0, 0.85, 0.2, 0.8) -- Energy yellow
    else
      gl.Color(0.8, 0.8, 0.85, 0.8) -- Metal silver
    end
    gl.LineWidth(1.5)
    gl.PolygonMode(GL.FRONT_AND_BACK, GL.LINE)
    gl.Rect(x, y, x + CONFIG.cardWidth, y + baseHeight)
    gl.PolygonMode(GL.FRONT_AND_BACK, GL.FILL)
    
    -- Info Text
    gl.Color(1, 1, 1, 1)
    gl.Text(alert.label, x + 8, y + 10, 11, "o")
    
    -- Share Button background
    local btnW = 65
    local btnH = baseHeight - 8
    local btnX = x + CONFIG.cardWidth - btnW - 28
    local btnY = y + 4
    
    if alert.resType == "energy" then
      gl.Color(0.9, 0.75, 0.1, 0.9)
    else
      gl.Color(0.2, 0.55, 0.85, 0.9)
    end
    gl.Rect(btnX, btnY, btnX + btnW, btnY + btnH)
    
    -- Share Button label
    gl.Color(0, 0, 0, 1)
    gl.Text(alert.btnLabel, btnX + (btnW / 2), btnY + 4, 11, "oc")
    
    -- Dismiss (X) button
    local closeX = x + CONFIG.cardWidth - 22
    local closeY = y + 4
    gl.Color(0.3, 0.3, 0.3, 0.8)
    gl.Rect(closeX, closeY, closeX + 18, closeY + btnH)
    gl.Color(0.8, 0.8, 0.8, 1)
    gl.Text("x", closeX + 9, closeY + 3, 11, "oc")
  end
  
  -- Reset OpenGL color state
  gl.Color(1, 1, 1, 1)
end

-- =========================================================================
-- USER INTERACTION (Mouse Press)
-- =========================================================================
function widget:MousePress(mx, my, button)
  if button ~= 1 or #activeAlerts == 0 then return false end
  
  local x = CONFIG.posX
  local baseHeight = CONFIG.cardHeight
  local padding = CONFIG.cardPadding
  
  for i, alert in ipairs(activeAlerts) do
    local y = CONFIG.posY - (i * (baseHeight + padding))
    
    -- Check if click is inside the card area
    if mx >= x and mx <= (x + CONFIG.cardWidth) and my >= y and my <= (y + baseHeight) then
      local btnW = 65
      local btnH = baseHeight - 8
      local btnX = x + CONFIG.cardWidth - btnW - 28
      local btnY = y + 4
      
      -- Check Share button click
      if mx >= btnX and mx <= (btnX + btnW) and my >= btnY and my <= (btnY + btnH) then
        ShareResource(alert.teamID, alert.resType, alert.amount, alert.name)
        return true
      end
      
      -- Check Dismiss button click
      local closeX = x + CONFIG.cardWidth - 22
      local closeY = y + 4
      if mx >= closeX and mx <= (closeX + 18) and my >= closeY and my <= (closeY + btnH) then
        SnoozeAlert(alert.teamID, alert.resType)
        Spring.Echo(string.format("[Resource Sharer] Snoozed alerts for %s (%s) for %ds.", alert.name, alert.resType, CONFIG.snoozeDurationSec))
        return true
      end
      
      return true
    end
  end
  
  return false
end
