-- client/commands.lua (Fixed - Lithuanian only, no debug)
-- Lithuanian fishing commands system

-- Get current weather
local function getCurrentWeatherType()
    return serverWeather or 'CLEAR'
end

-- Get current season
local function getCurrentSeason()
    if Config.forcedSeason then
        return Config.forcedSeason, Config.seasons[Config.forcedSeason]
    end
    
    if serverSeason and Config.seasons[serverSeason] then
        return serverSeason, Config.seasons[serverSeason]
    end
    
    local month = GetClockMonth()
    for season, data in pairs(Config.seasons) do
        for _, seasonMonth in ipairs(data.months) do
            if month == seasonMonth then
                return season, data
            end
        end
    end
    return 'spring', Config.seasons.spring
end

-- Get current time period
local function getCurrentTimePeriod()
    local hour = GetClockHours()
    
    if hour >= 5 and hour <= 7 then
        return 'dawn', Config.timeEffects.dawn
    elseif hour >= 8 and hour <= 11 then
        return 'morning', Config.timeEffects.morning
    elseif hour >= 12 and hour <= 14 then
        return 'noon', Config.timeEffects.noon
    elseif hour >= 15 and hour <= 17 then
        return 'afternoon', Config.timeEffects.afternoon
    elseif hour >= 18 and hour <= 20 then
        return 'dusk', Config.timeEffects.dusk
    elseif hour >= 21 or hour <= 4 then
        return 'night', Config.timeEffects.night
    else
        return 'day', { waitMultiplier = 1.0, chanceBonus = 0, message = 'Standartinės žvejybos sąlygos.' }
    end
end

-- Command to show fishing zones
RegisterCommand('zonos', function()
    local playerLevel = GetCurrentLevel()
    local options = {}
    
    for i, zone in ipairs(Config.fishingZones) do
        local isUnlocked = zone.minLevel <= playerLevel
        local distance = currentZone and currentZone.index == i and 0 or 
                        #(GetEntityCoords(cache.ped) - zone.locations[1])
        
        local statusIcon = isUnlocked and '✅' or '🔒'
        local distanceText = distance > 0 and (' (%.0fm atstumas)'):format(distance) or ' (Dabartinė zona)'
        
        table.insert(options, {
            title = statusIcon .. ' ' .. zone.blip.name,
            description = ('Lygis %d+ | %d žuvų rūšys%s'):format(
                zone.minLevel, 
                #zone.fishList,
                distanceText
            ),
            disabled = not isUnlocked,
            metadata = isUnlocked and {
                { label = 'Žuvų rūšys', value = table.concat(zone.fishList, ', ') },
                { label = 'Laukimo laikas', value = zone.waitTime.min .. '-' .. zone.waitTime.max .. 's' },
                { label = 'Spindulys', value = zone.radius .. 'm' }
            } or {
                { label = 'Atrakinti lygį', value = zone.minLevel }
            }
        })
    end
    
    lib.registerContext({
        id = 'fishing_zones_info',
        title = '🗺️ Žvejybos zonos',
        options = options
    })
    
    lib.showContext('fishing_zones_info')
end, false)

-- Command to show current fishing conditions
RegisterCommand('salygos', function()
    local weather = getCurrentWeatherType()
    local hour = GetClockHours()
    local minute = GetClockMinutes()
    local currentLevel = GetCurrentLevel()
    local zone = currentZone and Config.fishingZones[currentZone.index]
    
    local timePeriod, timeData = getCurrentTimePeriod()
    local season, seasonData = getCurrentSeason()
    
    local info = {}
    table.insert(info, '🎣 Dabartinės žvejybos sąlygos:')
    table.insert(info, ('⏰ Laikas: %02d:%02d (%s)'):format(hour, minute, timePeriod:upper()))
    table.insert(info, ('🌤️ Oras: %s'):format(weather))
    table.insert(info, ('⭐ Jūsų lygis: %d'):format(currentLevel))
    table.insert(info, ('🍂 Sezonas: %s'):format(season:upper()))
    
    if zone then
        table.insert(info, ('📍 Zona: %s'):format(zone.blip.name))
    else
        table.insert(info, '📍 Zona: Atviras vandenynas')
    end
    
    -- Weather effects
    local weatherEffect = Config.weatherEffects[weather]
    if weatherEffect and weatherEffect.chanceBonus and weatherEffect.chanceBonus ~= 0 then
        if weatherEffect.chanceBonus > 0 then
            table.insert(info, ('🌟 Oro bonusas: +%d%% gaudymo šansas'):format(weatherEffect.chanceBonus))
        else
            table.insert(info, ('⚠️ Oro nuobauda: %d%% gaudymo šansas'):format(weatherEffect.chanceBonus))
        end
    end
    
    -- Time effects
    if timeData.chanceBonus and timeData.chanceBonus ~= 0 then
        if timeData.chanceBonus > 0 then
            table.insert(info, ('🌅 Laiko bonusas: +%d%% gaudymo šansas'):format(timeData.chanceBonus))
        else
            table.insert(info, ('🌙 Laiko nuobauda: %d%% gaudymo šansas'):format(timeData.chanceBonus))
        end
    end
    
    ShowNotification(table.concat(info, '\n'), 'inform')
end, false)
