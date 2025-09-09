-- Enhanced fishing commands system with configurable season support

-- Get current weather from the global variable set in main.lua
local function getCurrentWeatherType()
    return serverWeather or 'CLEAR'
end

-- Enhanced: Get current season with config support
local function getCurrentSeason()
    -- If season is forced in config, use that
    if Config.forcedSeason then
        return Config.forcedSeason, Config.seasons[Config.forcedSeason]
    end
    
    -- Use server-synced season if available
    if serverSeason and Config.seasons[serverSeason] then
        return serverSeason, Config.seasons[serverSeason]
    end
    
    -- Fallback to automatic detection
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

-- FIXED: Get current time period client-side - CONSISTENT WITH SERVER 
local function getCurrentTimePeriod()
    local hour = GetClockHours()
    
    print('[DEBUG] Commands client hour:', hour)
    
    -- Use the same logic as server and main client
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
        return 'day', { waitMultiplier = 1.0, chanceBonus = 0, message = 'Standard fishing conditions.' }
    end
end

-- NEW: Debug command to help troubleshoot time issues
RegisterCommand('debugtime', function()
    local hour = GetClockHours()
    local minute = GetClockMinutes()
    local timePeriod, timeData = getCurrentTimePeriod()
    
    local info = {}
    table.insert(info, locale('debug_raw_hour'):format(hour))
    table.insert(info, locale('debug_raw_minute'):format(minute))
    table.insert(info, locale('debug_detected_period'):format(timePeriod))
    table.insert(info, locale('debug_config_key'):format(timeData and locale('debug_config_found') or locale('debug_config_missing')))
    
    if timeData then
        table.insert(info, locale('debug_chance_bonus'):format(timeData.chanceBonus or 0))
        table.insert(info, locale('debug_wait_multiplier'):format(timeData.waitMultiplier or 1))
    end
    
    ShowNotification(table.concat(info, '\n'), 'inform')
    
    -- Also print to console for debugging
    print('[DEBUG TIME] Hour:', hour, 'Period:', timePeriod)
    print('[DEBUG TIME] Config check - Dawn:', Config.timeEffects.dawn ~= nil)
    print('[DEBUG TIME] Config check - Dusk:', Config.timeEffects.dusk ~= nil)
    print('[DEBUG TIME] Config check - Night:', Config.timeEffects.night ~= nil)
end, false)

-- Command to show fishing zones and their requirements
RegisterCommand('fishzones', function()
    local playerLevel = GetCurrentLevel()
    local options = {}
    
    for i, zone in ipairs(Config.fishingZones) do
        local isUnlocked = zone.minLevel <= playerLevel
        local distance = currentZone and currentZone.index == i and 0 or 
                        #(GetEntityCoords(cache.ped) - zone.locations[1])
        
        local statusIcon = isUnlocked and '✅' or '🔒'
        local distanceText = distance > 0 and (' (%.0fm away)'):format(distance) or ' (Current Zone)'
        
        table.insert(options, {
            title = statusIcon .. ' ' .. zone.blip.name,
            description = ('Level %d+ | %d fish species%s'):format(
                zone.minLevel, 
                #zone.fishList,
                distanceText
            ),
            disabled = not isUnlocked,
            metadata = isUnlocked and {
                { label = 'Fish Species', value = table.concat(zone.fishList, ', ') },
                { label = 'Wait Time', value = zone.waitTime.min .. '-' .. zone.waitTime.max .. 's' },
                { label = 'Radius', value = zone.radius .. 'm' }
            } or {
                { label = 'Unlock Level', value = zone.minLevel }
            }
        })
    end
    
    lib.registerContext({
        id = 'fishing_zones_info',
        title = '🗺️ Fishing Zones',
        options = options
    })
    
    lib.showContext('fishing_zones_info')
end, false)

-- Command to show current fishing conditions in detail
RegisterCommand('fishconditions', function()
    local weather = getCurrentWeatherType()
    local hour = GetClockHours()
    local minute = GetClockMinutes()
    local currentLevel = GetCurrentLevel()
    local zone = currentZone and Config.fishingZones[currentZone.index]
    
    -- Calculate current time period and season
    local timePeriod, timeData = getCurrentTimePeriod()
    local season, seasonData = getCurrentSeason()
    
    local info = {}
    table.insert(info, locale('environmental_conditions'))
    table.insert(info, locale('time_format'):format(hour, minute, timePeriod:upper()))
    table.insert(info, locale('weather_format'):format(weather))
    table.insert(info, locale('level_format'):format(currentLevel))
    table.insert(info, ('🍂 Season: %s'):format(season:upper()))
    
    if zone then
        table.insert(info, locale('zone_format'):format(zone.blip.name))
    else
        table.insert(info, locale('zone_format'):format(locale('zone_open_waters') or 'Open Waters'))
    end
    
    -- Weather effects
    local weatherEffect = Config.weatherEffects[weather]
    if weatherEffect then
        if weatherEffect.chanceBonus > 0 then
            table.insert(info, locale('weather_effects'):format(weatherEffect.chanceBonus))
        elseif weatherEffect.chanceBonus < 0 then
            table.insert(info, ('⚠️ Weather Penalty: %d%% catch rate'):format(weatherEffect.chanceBonus))
        end
        
        if weatherEffect.waitMultiplier < 1.0 then
            table.insert(info, locale('faster_fishing'):format(math.floor((1 - weatherEffect.waitMultiplier) * 100)))
        elseif weatherEffect.waitMultiplier > 1.0 then
            table.insert(info, locale('slower_fishing'):format(math.floor((weatherEffect.waitMultiplier - 1) * 100)))
        end
    end
    
    -- Time effects
    if timeData.chanceBonus and timeData.chanceBonus ~= 0 then
        if timeData.chanceBonus > 0 then
            table.insert(info, locale('time_effects'):format(timeData.chanceBonus))
        else
            table.insert(info, locale('time_penalty'):format(timeData.chanceBonus))
        end
    end
    
    -- Season effects
    if seasonData.fishBonus and #seasonData.fishBonus > 0 then
        table.insert(info, ('🍂 Season Bonus Fish: %s'):format(table.concat(seasonData.fishBonus, ', ')))
    end
    
    ShowNotification(table.concat(info, '\n'), 'inform')
end, false)

-- Enhanced weather info command - FIXED VERSION (CLIENT-SIDE ONLY)
RegisterCommand('fishweather', function()
    -- Calculate everything CLIENT-SIDE instead of asking server
    local weather = getCurrentWeatherType()
    local hour = GetClockHours()
    local timePeriod, timeData = getCurrentTimePeriod()
    local season, seasonData = getCurrentSeason()
    
    -- Calculate effects client-side
    local effects = {
        weather = weather,
        time = timePeriod,
        season = season,
        waitMultiplier = 1.0,
        chanceMultiplier = 1.0
    }
    
    -- Apply weather effects
    if Config.weatherEffects[weather] then
        local weatherEffect = Config.weatherEffects[weather]
        effects.waitMultiplier = effects.waitMultiplier * weatherEffect.waitMultiplier
        effects.chanceMultiplier = effects.chanceMultiplier * (1 + (weatherEffect.chanceBonus or 0) / 100)
    end
    
    -- Apply time effects  
    if timeData.waitMultiplier then
        effects.waitMultiplier = effects.waitMultiplier * timeData.waitMultiplier
    end
    if timeData.chanceBonus then
        effects.chanceMultiplier = effects.chanceMultiplier * (1 + timeData.chanceBonus / 100)
    end
    
    -- Show the info directly (no server involved)
    local info = {}
    table.insert(info, '🌤️ CLIENT Environmental Conditions:')
    table.insert(info, ('Weather: %s'):format(weather))
    table.insert(info, ('Time: %s (Hour: %d)'):format(timePeriod:upper(), hour))
    table.insert(info, ('Season: %s%s'):format(season:upper(), Config.forcedSeason and ' (FORCED)' or ''))
    
    if effects.chanceMultiplier > 1.0 then
        table.insert(info, ('🌟 Total Bonus: +%d%% catch rate'):format(math.floor((effects.chanceMultiplier - 1) * 100)))
    elseif effects.chanceMultiplier < 1.0 then
        table.insert(info, ('⚠️ Total Penalty: %d%% catch rate'):format(math.floor((1 - effects.chanceMultiplier) * 100)))
    end
    
    if effects.waitMultiplier < 1.0 then
        table.insert(info, ('⚡ Fishing Speed: +%d%%'):format(math.floor((1 - effects.waitMultiplier) * 100)))
    elseif effects.waitMultiplier > 1.0 then
        table.insert(info, ('🐌 Fishing Speed: -%d%%'):format(math.floor((effects.waitMultiplier - 1) * 100)))
    end
    
    ShowNotification(table.concat(info, '\n'), 'inform')
end, false)

-- Command to show fish rarity guide
RegisterCommand('fishrarity', function()
    local rarityInfo = {
        locale('rarity_common_desc') or '🐟 COMMON - Easy to catch, low value (20-120€)',
        locale('rarity_uncommon_desc') or '🐠 UNCOMMON - Moderately rare, decent value (120-250€)', 
        locale('rarity_rare_desc') or '🌟 RARE - Hard to find, good money (280-480€)',
        locale('rarity_epic_desc') or '💎 EPIC - Very rare, high value (450-1500€)',
        locale('rarity_legendary_desc') or '👑 LEGENDARY - Extremely rare, massive value (2000-4000€)',
        locale('rarity_mythical_desc') or '🔮 MYTHICAL - Ultra rare, legendary value (5000-7500€)'
    }
    
    local message = (locale('rarity_guide') or '🎣 Fish Rarity Guide:') .. '\n\n' .. table.concat(rarityInfo, '\n')
    ShowNotification(message, 'inform')
end, false)

-- Command to show current inventory of fish
RegisterCommand('fishstats', function()
    local fishCount = {}
    local totalValue = 0
    local totalFish = 0
    
    for fishName, fish in pairs(Config.fish) do
        if Framework.hasItem(fishName) then
            local count = 1 -- Basic count - you might want to get actual inventory count
            fishCount[fish.rarity] = (fishCount[fish.rarity] or 0) + count
            totalFish = totalFish + count
            
            local fishValue = type(fish.price) == 'number' and fish.price or 
                             math.floor((fish.price.min + fish.price.max) / 2)
            totalValue = totalValue + (fishValue * count)
        end
    end
    
    if totalFish == 0 then
        ShowNotification(locale('stats_no_fish') or '🎣 No fish in your inventory!', 'inform')
        return
    end
    
    local stats = {}
    table.insert(stats, '🎣 Fish Inventory Stats:')
    table.insert(stats, locale('stats_total_fish'):format(totalFish))
    table.insert(stats, locale('stats_estimated_value'):format(totalValue))
    
    local rarityOrder = { 'mythical', 'legendary', 'epic', 'rare', 'uncommon', 'common' }
    for _, rarity in ipairs(rarityOrder) do
        if fishCount[rarity] and fishCount[rarity] > 0 then
            local rarityEmojis = {
                mythical = '🔮',
                legendary = '👑', 
                epic = '💎',
                rare = '🌟',
                uncommon = '🐠',
                common = '🐟'
            }
            table.insert(stats, ('%s %s: %d'):format(rarityEmojis[rarity], rarity:upper(), fishCount[rarity]))
        end
    end
    
    ShowNotification(table.concat(stats, '\n'), 'success')
end, false)

-- Command to get fishing tips based on current conditions
RegisterCommand('fishtips', function()
    local weather = getCurrentWeatherType()
    local hour = GetClockHours()
    local currentLevel = GetCurrentLevel()
    local zone = currentZone and Config.fishingZones[currentZone.index]
    local season, seasonData = getCurrentSeason()
    
    local tips = {}
    
    -- Weather-based tips
    if weather == 'RAIN' or weather == 'THUNDER' then
        table.insert(tips, '🌧️ Great weather for fishing! Fish are more active in the rain.')
    elseif weather == 'FOGGY' then
        table.insert(tips, '🌫️ Foggy conditions make fishing harder. Consider waiting for better weather.')
    elseif weather == 'CLEAR' then
        table.insert(tips, '☀️ Clear weather provides standard fishing conditions.')
    end
    
    -- Time-based tips
    if hour >= 5 and hour <= 7 then
        table.insert(tips, '🌅 Dawn is one of the best times to fish! Fish are very active.')
    elseif hour >= 18 and hour <= 20 then
        table.insert(tips, '🌆 Dusk is another prime fishing time!')
    elseif hour >= 12 and hour <= 14 then
        table.insert(tips, '☀️ Midday heat makes fish less active. Try early morning or evening.')
    elseif hour >= 22 or hour <= 4 then
        table.insert(tips, '🌙 Night fishing is challenging but can yield unique catches.')
    end
    
    -- Season-based tips
    if seasonData.fishBonus and #seasonData.fishBonus > 0 then
        table.insert(tips, ('🍂 %s season is great for: %s'):format(season:upper(), table.concat(seasonData.fishBonus, ', ')))
    end
    
    if Config.forcedSeason then
        table.insert(tips, ('⚙️ Season is currently forced to %s in the server config.'):format(Config.forcedSeason:upper()))
    end
    
    -- Level-based tips
    if currentLevel <= 2 then
        table.insert(tips, '📚 New to fishing? Start in Shallow Waters with basic equipment.')
        table.insert(tips, '💡 Buy better bait to catch fish faster!')
    elseif currentLevel <= 4 then
        table.insert(tips, '🌊 Try the Coral Reef zone for more valuable fish!')
        table.insert(tips, '🎣 Upgrade to a Graphite or Titanium rod for better success.')
    else
        table.insert(tips, '🌊 You can access Deep Waters now - big fish await!')
        table.insert(tips, '🎯 Use Premium or Legendary lures for rare fish.')
    end
    
    -- Zone-specific tips
    if zone then
        if zone.blip.name == 'Coral Reef' then
            table.insert(tips, '🪸 Coral Reefs have tropical fish like Mahi Mahi and Red Snapper.')
        elseif zone.blip.name == 'Deep Waters' then
            table.insert(tips, '🌊 Deep Waters contain the largest and most valuable fish.')
        elseif zone.blip.name == 'Mysterious Swamp' then
            table.insert(tips, '🐊 Swamps are dangerous but contain unique species like Piranha.')
        elseif zone.blip.name == 'Abyssal Depths' then
            table.insert(tips, '🕳️ The Abyss holds mythical creatures - bring your best equipment!')
        end
    else
        table.insert(tips, '🗺️ Explore different fishing zones for unique fish species!')
    end
    
    -- Equipment tips
    table.insert(tips, '🔧 Better rods break less often and have higher success rates.')
    table.insert(tips, '🪱 Different baits affect fishing speed - experiment to find what works!')
    
    if #tips > 0 then
        ShowNotification('💡 Fishing Tips:\n\n' .. table.concat(tips, '\n\n'), 'inform')
    else
        ShowNotification('💡 Keep fishing and experimenting to discover more tips!', 'inform')
    end
end, false)

-- Enhanced fishing season information with config support
RegisterCommand('fishseason', function()
    local season, seasonData = getCurrentSeason()
    
    local seasonInfo = {
        spring = locale('season_spring_desc') or '🌸 Spring: Fish are active after winter. Great for Salmon and Trout.',
        summer = locale('season_summer_desc') or '☀️ Summer: Warm waters bring tropical species. Perfect for Mahi Mahi.',
        autumn = locale('season_autumn_desc') or '🍂 Autumn: Migration season. Many fish are moving to warmer waters.',
        winter = locale('season_winter_desc') or '❄️ Winter: Cold waters. Northern fish like Cod and Haddock are more common.'
    }
    
    local currentSeasonInfo = seasonInfo[season] or 'Standard fishing season.'
    
    local message = ('🗓️ Current Season: %s%s\n\n%s'):format(
        season:upper(), 
        Config.forcedSeason and ' (FORCED IN CONFIG)' or '', 
        currentSeasonInfo
    )
    
    if seasonData.fishBonus and #seasonData.fishBonus > 0 then
        message = message .. ('\n\n🐟 Bonus fish this season: %s'):format(table.concat(seasonData.fishBonus, ', '))
    end
    
    ShowNotification(message, 'inform')
end, false)

-- Quick equipment check command
RegisterCommand('fishgear', function()
    local hasRod = false
    local rodType = locale('gear_none') or 'None'
    local hasBait = false
    local baitType = locale('gear_none') or 'None'
    
    -- Check for rods (from best to worst)
    for i = #Config.fishingRods, 1, -1 do
        local rod = Config.fishingRods[i]
        if Framework.hasItem(rod.name) then
            hasRod = true
            rodType = Utils.getItemLabel(rod.name)
            break
        end
    end
    
    -- Check for bait (from best to worst)
    for i = #Config.baits, 1, -1 do
        local bait = Config.baits[i]
        if Framework.hasItem(bait.name) then
            hasBait = true
            baitType = Utils.getItemLabel(bait.name)
            break
        end
    end
    
    local gearStatus = {}
    table.insert(gearStatus, locale('gear_status') or '🎣 Current Fishing Gear:')
    table.insert(gearStatus, locale('gear_rod'):format(hasRod and '✅' or '❌', rodType))
    table.insert(gearStatus, locale('gear_bait'):format(hasBait and '✅' or '❌', baitType))
    
    if not hasRod then
        table.insert(gearStatus, '\n' .. (locale('gear_need_rod') or '💡 Visit SeaTrade Corp to buy a fishing rod!'))
    end
    
    if not hasBait then
        table.insert(gearStatus, '\n' .. (locale('gear_need_bait') or '💡 You need bait to fish! Buy some worms to get started.'))
    end
    
    if hasRod and hasBait then
        table.insert(gearStatus, '\n' .. (locale('gear_ready') or '🎣 You\'re ready to fish!'))
    end
    
    ShowNotification(table.concat(gearStatus, '\n'), hasRod and hasBait and 'success' or 'warn')
end, false)

-- Enhanced: Detailed fishing information command with season
RegisterCommand('fishinfo', function()
    local currentLevel = GetCurrentLevel()
    local progress = GetCurrentLevelProgress() * 100
    local zone = currentZone and Config.fishingZones[currentZone.index]
    local weather = getCurrentWeatherType()
    local season, seasonData = getCurrentSeason()
    
    -- Calculate current time period
    local timePeriod, timeData = getCurrentTimePeriod()
    
    local info = {}
    table.insert(info, locale('current_level'):format(currentLevel))
    table.insert(info, locale('level_progress'):format(progress))
    
    if zone then
        table.insert(info, ('📍 Zone: %s (Level %d+)'):format(zone.blip.name, zone.minLevel))
        table.insert(info, locale('fish_types'):format(#zone.fishList))
    else
        table.insert(info, locale('current_zone'):format(locale('zone_open_waters') or 'Open Waters'))
    end
    
    -- Weather info
    local weatherEffect = Config.weatherEffects[weather]
    if weatherEffect then
        local bonusText = weatherEffect.chanceBonus > 0 and ('+' .. weatherEffect.chanceBonus .. '%') or 
                         weatherEffect.chanceBonus < 0 and (weatherEffect.chanceBonus .. '%') or 'No effect'
        table.insert(info, locale('current_weather'):format(weather, bonusText))
    end
    
    -- Time info
    if timeData.chanceBonus and timeData.chanceBonus ~= 0 then
        local bonusText = timeData.chanceBonus > 0 and ('+' .. timeData.chanceBonus .. '%') or (timeData.chanceBonus .. '%')
        table.insert(info, locale('current_time'):format(timePeriod:upper(), bonusText))
    else
        table.insert(info, locale('current_time'):format(timePeriod:upper()))
    end
    
    -- Season info
    table.insert(info, ('🍂 Season: %s%s'):format(season:upper(), Config.forcedSeason and ' (FORCED)' or ''))
    
    ShowNotification(table.concat(info, '\n'), 'inform')
end, false)

-- Help command for all fishing commands
RegisterCommand('fishhelp', function()
    local commands = {
        locale('command_fishinfo') or '/fishinfo - Show detailed fishing information',
        locale('command_fishzones') or '/fishzones - View all fishing zones and requirements', 
        locale('command_fishconditions') or '/fishconditions - Check current weather and time effects',
        locale('command_fishweather') or '/fishweather - Get detailed weather impact info',
        locale('command_fishrarity') or '/fishrarity - Learn about fish rarity system',
        locale('command_fishstats') or '/fishstats - View your current fish inventory',
        locale('command_fishtips') or '/fishtips - Get helpful fishing tips',
        locale('command_fishseason') or '/fishseason - Check current fishing season info',
        locale('command_fishgear') or '/fishgear - Check your current equipment',
        locale('command_fishhelp') or '/fishhelp - Show this help menu'
    }
    
    local keybinds = {
        locale('keybind_f6') or 'F6 - Quick fishing info',
        locale('keybind_f7') or 'F7 - Open contracts menu', 
        locale('keybind_f8') or 'F8 - Tournament information',
        locale('keybind_g') or 'G - Anchor/raise anchor (in boats)',
        locale('keybind_e') or 'E - Return boat (near dock)'
    }
    
    local helpText = (locale('help_title') or '🎣 Fishing System Help:') .. '\n\n' ..
                    (locale('help_commands') or '📝 Commands:') .. '\n' .. table.concat(commands, '\n') .. '\n\n' ..
                    (locale('help_keybinds') or '⌨️ Keybinds:') .. '\n' .. table.concat(keybinds, '\n')
    
    ShowNotification(helpText, 'inform')
end, false)

-- Admin command to force weather (if player has permission)
RegisterCommand('setfishweather', function(source, args)
    if not args[1] then
        ShowNotification(locale('usage_setweather') or 'Usage: /setfishweather [CLEAR|RAIN|THUNDER|FOGGY|SNOW]', 'error')
        return
    end
    
    local weather = args[1]:upper()
    local validWeathers = { 'CLEAR', 'RAIN', 'THUNDER', 'FOGGY', 'SNOW', 'CLOUDY', 'OVERCAST' }
    local isValid = false
    
    for _, validWeather in ipairs(validWeathers) do
        if weather == validWeather then
            isValid = true
            break
        end
    end
    
    if not isValid then
        ShowNotification(locale('invalid_weather') or 'Invalid weather type! Valid: CLEAR, RAIN, THUNDER, FOGGY, SNOW, CLOUDY, OVERCAST', 'error')
        return
    end
    
    TriggerServerEvent('lunar_fishing:setWeather', weather)
    ShowNotification(locale('weather_change_requested'):format(weather) or ('Weather change requested: %s'):format(weather), 'inform')
end, false)

-- NEW: Admin command to force season (if player has permission)
RegisterCommand('setfishseason', function(source, args)
    if not args[1] then
        ShowNotification('Usage: /setfishseason [spring|summer|autumn|winter]', 'error')
        return
    end
    
    local season = args[1]:lower()
    local validSeasons = { 'spring', 'summer', 'autumn', 'winter' }
    local isValid = false
    
    for _, validSeason in ipairs(validSeasons) do
        if season == validSeason then
            isValid = true
            break
        end
    end
    
    if not isValid then
        ShowNotification('Invalid season type! Valid: spring, summer, autumn, winter', 'error')
        return
    end
    
    TriggerServerEvent('lunar_fishing:setSeason', season)
    ShowNotification(('Season change requested: %s'):format(season:upper()), 'inform')
end, false)

-- Add the test command for debugging
RegisterCommand('testtime', function()
    local hour = GetClockHours()
    local period, data = getCurrentTimePeriod()
    
    local testInfo = {}
    table.insert(testInfo, ('CLIENT ONLY TEST:'))
    table.insert(testInfo, ('Raw Hour: %d'):format(hour))
    table.insert(testInfo, ('Detected Period: %s'):format(period))
    table.insert(testInfo, ('Should be DUSK if hour 18-20'))
    
    -- Test specific ranges
    if hour >= 18 and hour <= 20 then
        table.insert(testInfo, ('✅ CORRECT: Hour %d should be DUSK'):format(hour))
        if period ~= 'dusk' then
            table.insert(testInfo, ('❌ ERROR: Detected %s instead of dusk'):format(period))
        end
    end
    
    ShowNotification(table.concat(testInfo, '\n'), hour >= 18 and hour <= 20 and period == 'dusk' and 'success' or 'error')
    
    print('[TEST TIME] Hour:', hour, 'Period:', period)
end, false)

-- Register chat suggestions for easier access
TriggerEvent('chat:addSuggestion', '/fishinfo', 'Show detailed fishing information')
TriggerEvent('chat:addSuggestion', '/fishzones', 'View all fishing zones')
TriggerEvent('chat:addSuggestion', '/fishconditions', 'Check current fishing conditions')
TriggerEvent('chat:addSuggestion', '/fishweather', 'Get detailed weather effects on fishing')
TriggerEvent('chat:addSuggestion', '/fishrarity', 'Learn about fish rarity system')
TriggerEvent('chat:addSuggestion', '/fishstats', 'View your fish inventory')
TriggerEvent('chat:addSuggestion', '/fishtips', 'Get helpful fishing tips')
TriggerEvent('chat:addSuggestion', '/fishseason', 'Check current fishing season')
TriggerEvent('chat:addSuggestion', '/fishgear', 'Check your current equipment')
TriggerEvent('chat:addSuggestion', '/fishhelp', 'Show all fishing commands')
TriggerEvent('chat:addSuggestion', '/debugtime', 'Debug time period detection')
TriggerEvent('chat:addSuggestion', '/testtime', 'Test time period calculation')
TriggerEvent('chat:addSuggestion', '/setfishweather', 'Admin: Change fishing weather', {{name = 'weather', help = 'CLEAR|RAIN|THUNDER|FOGGY|SNOW'}})
TriggerEvent('chat:addSuggestion', '/setfishseason', 'Admin: Change fishing season', {{name = 'season', help = 'spring|summer|autumn|winter'}})