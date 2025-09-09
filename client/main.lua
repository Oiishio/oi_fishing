-- client/main.lua (Optimized)
-- Core fishing mechanics only

lib.locale()

local FishingCore = {}

-- State management
local state = {
    currentZone = nil,
    playerLevel = 1,
    isFishing = false,
    rodObject = nil
}

-- Cache frequently accessed data
local cache = {
    blips = {},
    zones = {},
    lastLevelUpdate = 0
}

-- Initialize core fishing system
function FishingCore.init()
    -- Load initial level
    lib.callback('lunar_fishing:getLevel', false, function(level)
        if level then
            state.playerLevel = math.floor(level)
            FishingCore.updateLevel(level)
        end
    end)
    
    -- Listen for level updates
    RegisterNetEvent('lunar_fishing:updateLevel', FishingCore.updateLevel)
    RegisterNetEvent('esx:playerLoaded', function()
        lib.callback('lunar_fishing:getLevel', 100, FishingCore.updateLevel)
    end)
    RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
        lib.callback('lunar_fishing:getLevel', 100, FishingCore.updateLevel)
    end)
end

-- Update player level and rebuild zones/blips
function FishingCore.updateLevel(level)
    if not level then return end
    
    local now = GetGameTimer()
    if now - cache.lastLevelUpdate < 5000 then return end -- Throttle updates
    
    local newLevel = math.floor(level)
    if newLevel > state.playerLevel then
        FishingUI.queueNotification(
            locale('unlocked_level'):format(newLevel) or ('🎉 Level %d reached!'):format(newLevel),
            'success',
            FishingConstants.NOTIFICATION_PRIORITY.HIGH
        )
    end
    
    state.playerLevel = newLevel
    cache.lastLevelUpdate = now
    
    FishingCore.rebuildBlips()
    FishingCore.rebuildZones()
end

-- Rebuild blips (only when level changes)
function FishingCore.rebuildBlips()
    -- Remove old blips
    for _, blipData in ipairs(cache.blips) do
        RemoveBlip(blipData.normal)
        RemoveBlip(blipData.radius)
    end
    table.wipe(cache.blips)
    
    -- Create new blips for accessible zones
    for _, zone in ipairs(Config.fishingZones) do
        if zone.blip and zone.minLevel <= state.playerLevel then
            for _, coords in ipairs(zone.locations) do
                local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
                SetBlipSprite(blip, zone.blip.sprite)
                SetBlipDisplay(blip, 4)
                SetBlipScale(blip, zone.blip.scale)
                SetBlipColour(blip, zone.blip.color)
                SetBlipAsShortRange(blip, true)
                
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentSubstringPlayerName(zone.blip.name)
                EndTextCommandSetBlipName(blip)
                
                local radiusBlip = AddBlipForRadius(coords.x, coords.y, coords.z, zone.radius)
                SetBlipDisplay(radiusBlip, 4)
                SetBlipColour(radiusBlip, zone.blip.color)
                SetBlipAsShortRange(radiusBlip, true)
                SetBlipAlpha(radiusBlip, 150)
                
                table.insert(cache.blips, { normal = blip, radius = radiusBlip })
            end
        end
    end
end

-- Rebuild zones (only when level changes)
function FishingCore.rebuildZones()
    -- Remove old zones
    for _, zone in ipairs(cache.zones) do
        zone:remove()
    end
    table.wipe(cache.zones)
    
    -- Create new zones for accessible areas
    for index, data in ipairs(Config.fishingZones) do
        if data.minLevel <= state.playerLevel then
            for locationIndex, coords in ipairs(data.locations) do
                local zone = lib.zones.sphere({
                    coords = coords,
                    radius = data.radius,
                    onEnter = function()
                        FishingCore.onZoneEnter(index, locationIndex, data)
                    end,
                    onExit = function()
                        FishingCore.onZoneExit(index, locationIndex, data)
                    end
                })
                
                table.insert(cache.zones, zone)
            end
        end
    end
end

-- Zone enter handler
function FishingCore.onZoneEnter(index, locationIndex, data)
    if state.currentZone?.index == index and state.currentZone?.locationIndex == locationIndex then return end
    
    state.currentZone = { index = index, locationIndex = locationIndex }
    
    if data.message?.enter then
        FishingUI.queueNotification(data.message.enter, 'success')
    end
    
    -- Show zone info (throttled)
    local zoneInfo = ('📍 %s | Level %d+ | %d fish types'):format(
        data.blip.name, data.minLevel, #data.fishList
    )
    FishingUI.queueNotification(zoneInfo, 'inform', FishingConstants.NOTIFICATION_PRIORITY.LOW)
end

-- Zone exit handler  
function FishingCore.onZoneExit(index, locationIndex, data)
    if state.currentZone?.index ~= index or state.currentZone?.locationIndex ~= locationIndex then return end
    
    state.currentZone = nil
    
    if data.message?.exit then
        FishingUI.queueNotification(data.message.exit, 'inform')
    end
end

-- Create fishing rod object
function FishingCore.createRod()
    if state.rodObject then return state.rodObject end
    
    local model = `prop_fishing_rod_01`
    lib.requestModel(model)
    
    local coords = GetEntityCoords(cache.ped)
    local object = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)
    local boneIndex = GetPedBoneIndex(cache.ped, 18905)
    
    AttachEntityToEntity(object, cache.ped, boneIndex, 0.1, 0.05, 0.0, 70.0, 120.0, 160.0, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(model)
    
    state.rodObject = object
    return object
end

-- Remove fishing rod
function FishingCore.removeRod()
    if state.rodObject then
        DeleteEntity(state.rodObject)
        state.rodObject = nil
    end
end

-- Check if player has water in front
function FishingCore.hasWaterInFront()
    if IsPedSwimming(cache.ped) or IsPedInAnyVehicle(cache.ped, true) then
        return false
    end
    
    local headCoords = GetPedBoneCoords(cache.ped, 31086, 0.0, 0.0, 0.0)
    local coords = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 45.0, -27.5)
    local hasWater = TestProbeAgainstWater(headCoords.x, headCoords.y, headCoords.z, coords.x, coords.y, coords.z)
    
    if not hasWater then
        FishingUI.queueNotification(locale('no_water'), 'error')
    end
    
    return hasWater
end

-- Fishing process (simplified)
function FishingCore.startFishing(bait, fish, envEffects)
    if state.isFishing then return false end
    
    state.isFishing = true
    local zone = state.currentZone and Config.fishingZones[state.currentZone.index] or Config.outside
    
    -- Create rod and start animations
    local rodObject = FishingCore.createRod()
    lib.requestAnimDict('mini@tennis')
    lib.requestAnimDict('amb@world_human_stand_fishing@idle_a')
    
    SetPedCanRagdoll(cache.ped, false)
    
    -- Show fishing status
    local statusText = locale('cancel')
    local env = FishingEnvironment.getInfo()
    local bonuses = FishingCore.getEffectSummary(env.effects)
    
    if bonuses then
        statusText = statusText .. ' | ' .. bonuses
    end
    
    FishingUI.showText(statusText, 'ban')
    
    -- Fishing logic
    local success = false
    local cancelled = false
    
    CreateThread(function()
        -- Cast animation
        TaskPlayAnim(cache.ped, 'mini@tennis', 'forehand_ts_md_far', 3.0, 3.0, 1.0, 16, 0, false, false, false)
        Wait(1500)
        
        if cancelled then return end
        
        -- Idle fishing animation
        TaskPlayAnim(cache.ped, 'amb@world_human_stand_fishing@idle_a', 'idle_c', 3.0, 3.0, -1, 11, 0, false, false, false)
        
        -- Wait for bite (with environmental effects)
        local baseWaitTime = math.random(zone.waitTime.min, zone.waitTime.max)
        local waitTime = math.floor(baseWaitTime / bait.waitDivisor * (envEffects.waitMultiplier or 1.0) * 1000)
        
        Wait(waitTime)
        
        if cancelled then return end
        
        -- Fish bite notification
        local biteMessage = FishingCore.getBiteMessage(fish.rarity)
        FishingUI.queueNotification(biteMessage, 'warn', FishingConstants.NOTIFICATION_PRIORITY.HIGH)
        FishingUI.hideText()
        
        Wait(math.random(2000, 4000))
        
        if cancelled then return end
        
        -- Skill check
        local skillcheckKeys = FishingCore.getSkillcheckKeys(fish.rarity)
        success = lib.skillCheck(fish.skillcheck, skillcheckKeys)
        
        if not success then
            local failMessage = FishingCore.getFailMessage(fish.rarity)
            FishingUI.queueNotification(failMessage, 'error')
        end
    end)
    
    -- Cancel check
    local cancelCheck = SetInterval(function()
        if IsControlPressed(0, 38) or 
           (not IsEntityPlayingAnim(cache.ped, 'mini@tennis', 'forehand_ts_md_far', 3) and
            not IsEntityPlayingAnim(cache.ped, 'amb@world_human_stand_fishing@idle_a', 'idle_c', 3)) then
            cancelled = true
            FishingCore.stopFishing()
        end
    end, 100)
    
    -- Wait for completion
    while state.isFishing and not cancelled and success == false do
        Wait(100)
    end
    
    ClearInterval(cancelCheck)
    FishingCore.stopFishing()
    
    return success
end

-- Stop fishing
function FishingCore.stopFishing()
    if not state.isFishing then return end
    
    state.isFishing = false
    
    FishingCore.removeRod()
    FishingUI.hideText()
    ClearPedTasks(cache.ped)
    SetPedCanRagdoll(cache.ped, true)
end

-- Get effect summary for display
function FishingCore.getEffectSummary(effects)
    local bonuses = {}
    
    if effects.chanceMultiplier > 1.05 then
        table.insert(bonuses, ('+%d%%'):format(math.floor((effects.chanceMultiplier - 1) * 100)))
    elseif effects.chanceMultiplier < 0.95 then
        table.insert(bonuses, ('-%d%%'):format(math.floor((1 - effects.chanceMultiplier) * 100)))
    end
    
    return #bonuses > 0 and table.concat(bonuses, ' ') or nil
end

-- Get bite message based on rarity
function FishingCore.getBiteMessage(rarity)
    local messages = {
        common = locale('felt_bite') or 'Something bit the bait!',
        uncommon = locale('felt_strong_bite') or 'Something strong is pulling!',
        rare = locale('felt_powerful_bite') or 'A powerful fish took the bait!',
        epic = locale('felt_epic_bite') or 'An epic fish is fighting!',
        legendary = locale('felt_legendary_bite') or 'Something legendary lurks below!',
        mythical = locale('felt_mythical_bite') or 'A mythical creature stirs!'
    }
    return messages[rarity] or messages.common
end

-- Get fail message based on rarity
function FishingCore.getFailMessage(rarity)
    local messages = {
        common = locale('catch_failed'),
        uncommon = locale('catch_failed_uncommon') or 'The fish escaped!',
        rare = locale('catch_failed_rare') or 'The rare fish was too strong!',
        epic = locale('catch_failed_epic') or 'The epic fish overpowered you!',
        legendary = locale('catch_failed_legendary') or 'The legendary fish proved too mighty!',
        mythical = locale('catch_failed_mythical') or 'The mythical being vanished!'
    }
    return messages[rarity] or messages.common
end

-- Get skillcheck keys based on rarity
function FishingCore.getSkillcheckKeys(rarity)
    if rarity == 'legendary' or rarity == 'mythical' then
        return { 'e', 'q', 'r' }
    elseif rarity == 'epic' then
        return { 'e', 'q' }
    else
        return { 'e' }
    end
end

-- Get current level
function FishingCore.getLevel()
    return state.playerLevel
end

-- Get current zone
function FishingCore.getCurrentZone()
    return state.currentZone
end

-- Callbacks for server
lib.callback.register('lunar_fishing:getCurrentZone', function()
    return FishingCore.hasWaterInFront(), state.currentZone
end)

lib.callback.register('lunar_fishing:getClientHour', function()
    return GetClockHours()
end)

lib.callback.register('lunar_fishing:itemUsed', function(bait, fish, envEffects)
    return FishingCore.startFishing(bait, fish, envEffects)
end)

-- Global functions for compatibility
function GetCurrentLevel()
    return state.playerLevel
end

function GetCurrentLevelProgress()
    -- This would need to be calculated from XP, simplified for now
    return 0
end

function Update(level)
    FishingCore.updateLevel(level)
end

-- Initialize on cache ready
lib.onCache('ped', function(ped)
    if ped then
        FishingCore.init()
    end
end)

-- Export
_G.FishingCore = FishingCore
return FishingCore