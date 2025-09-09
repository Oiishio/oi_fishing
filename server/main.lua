local currentMonth = tonumber(os.date-- server/main.lua (Fixed - Database and Constants Issues)
-- Core server fishing logic with proper database handling

lib.locale()
lib.versionCheck('https://github.com/Lunar-Scripts/lunar_fishing')

-- Safe constants access with fallbacks
local WEATHER_CYCLE_INTERVAL = 600000 -- 10 minutes fallback
local CONTRACT_REFRESH_INTERVAL = 3600000 -- 1 hour fallback

-- Initialize constants with fallbacks once they're available
CreateThread(function()
    Wait(1000) -- Wait for shared scripts to load
    
    if FishingConstants and FishingConstants.INTERVALS then
        WEATHER_CYCLE_INTERVAL = FishingConstants.INTERVALS.WEATHER_CYCLE
        CONTRACT_REFRESH_INTERVAL = FishingConstants.INTERVALS.CONTRACT_REFRESH
    end
end)

local FishingServer = {}

-- Server state
local state = {
    players = {}, -- Active fishing players
    weather = 'CLEAR',
    contracts = {},
    tournaments = {},
    playerJoinTimes = {}, -- Track when players join to prevent spam
    currentSeason = nil
}

-- Cache for performance
local cache = {
    playerLevels = {},
    itemLabels = {},
    lastSave = 0
}

-- Initialize server
function FishingServer.init()
    -- Load player levels from database
    MySQL.ready(function()
        local data = MySQL.query.await('SELECT * FROM lunar_fishing')
        for _, entry in ipairs(data) do
            cache.playerLevels[entry.user_identifier] = entry.xp
        end
        print('[Fishing] Loaded', #data, 'player records')
    end)
    
    -- Setup save intervals
    FishingServer.setupSaveSystem()
    
    -- Initialize weather system
    FishingServer.initWeatherSystem()
    
    -- Setup item usage handlers
    FishingServer.setupItemHandlers()
    
    -- Initialize contracts (simplified)
    FishingServer.initContracts()
    
    -- Track player joins to prevent startup spam
    AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
        state.playerJoinTimes[playerId] = GetGameTimer()
    end)
    
    AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
        state.playerJoinTimes[Player.PlayerData.source] = GetGameTimer()
    end)
end

-- Check if player recently joined (prevent spam)
local function isRecentlyJoined(source)
    local joinTime = state.playerJoinTimes[source]
    if not joinTime then return false end
    
    return (GetGameTimer() - joinTime) < 30000 -- 30 seconds
end

-- Setup save system with batching
function FishingServer.setupSaveSystem()
    local function batchSave()
        local query = 'UPDATE lunar_fishing SET xp = ? WHERE user_identifier = ?'
        local parameters = {}
        local count = 0
        
        for identifier, xp in pairs(cache.playerLevels) do
            count = count + 1
            parameters[count] = { xp, identifier }
        end
        
        if count > 0 then
            print('[Fishing] Saving', count, 'player records')
            MySQL.prepare.await(query, parameters)
            cache.lastSave = os.time()
        end
    end
    
    -- Save every 10 minutes
    lib.cron.new('*/10 * * * *', batchSave)
    
    -- Save on shutdown events
    AddEventHandler('txAdmin:events:serverShuttingDown', batchSave)
    AddEventHandler('txAdmin:events:scheduledRestart', function(eventData)
        if eventData.secondsRemaining == 60 then
            batchSave()
        end
    end)
    AddEventHandler('onResourceStop', function(resource)
        if resource == cache.resource then
            batchSave()
        end
    end)
end

-- Simplified weather system (less frequent changes)
function FishingServer.initWeatherSystem()
    local weatherCycle = { 'CLEAR', 'CLOUDY', 'OVERCAST', 'RAIN', 'CLEARING', 'CLEAR' }
    local weatherIndex = 1
    
    CreateThread(function()
        Wait(10000) -- Initial delay to prevent startup spam
        
        while true do
            Wait(WEATHER_CYCLE_INTERVAL * 2) -- Double interval to reduce spam
            
            weatherIndex = weatherIndex % #weatherCycle + 1
            local newWeather = weatherCycle[weatherIndex]
            
            -- 10% chance for special weather (reduced from 15%)
            if math.random(100) <= 10 then
                local specialWeathers = { 'THUNDER', 'FOGGY' }
                newWeather = FishingUtils.randomFromTable(specialWeathers)
            end
            
            local oldWeather = state.weather
            state.weather = newWeather
            
            -- Only send weather change if significantly different
            if oldWeather ~= newWeather then
                TriggerClientEvent('lunar_fishing:weatherChanged', -1, newWeather)
                print('[Fishing] Weather changed to:', newWeather)
            end
        end
    end)
end

-- Setup item usage handlers (simplified)
function FishingServer.setupItemHandlers()
    -- Sort rods by price for consistent processing
    table.sort(Config.fishingRods, function(a, b) return a.price < b.price end)
    table.sort(Config.baits, function(a, b) return a.price < b.price end)
    
    -- Merge zone fish lists
    for _, zone in ipairs(Config.fishingZones) do
        if zone.includeOutside then
            for _, fishName in ipairs(Config.outside.fishList) do
                if not FishingUtils.tableContains(zone.fishList, fishName) then
                    table.insert(zone.fishList, fishName)
                end
            end
        end
    end
    
    -- Register rod usage
    for _, rod in ipairs(Config.fishingRods) do
        Framework.registerUsableItem(rod.name, function(source)
            FishingServer.handleRodUse(source, rod)
        end)
    end
end

-- Handle fishing rod usage (optimized with spam prevention)
function FishingServer.handleRodUse(source, rod)
    local player = Framework.getPlayerFromId(source)
    if not player or player:getItemCount(rod.name) == 0 or state.players[source] then
        return
    end
    
    state.players[source] = true -- Mark as busy
    
    local hasWater, currentZone = lib.callback.await('lunar_fishing:getCurrentZone', source)
    if not hasWater then
        state.players[source] = nil
        return
    end
    
    -- Get best bait
    local bait = FishingServer.getBestBait(player)
    if not bait then
        TriggerClientEvent('lunar_fishing:showNotification', source, locale('no_bait'), 'error')
        state.players[source] = nil
        return
    end
    
    -- Get environmental effects
    local clientHour = lib.callback.await('lunar_fishing:getClientHour', source)
    local envEffects = FishingServer.calculateEnvironmentalEffects(currentZone, clientHour)
    
    -- Select fish
    local zone = currentZone and Config.fishingZones[currentZone.index] or Config.outside
    local fishName = FishingServer.selectFish(zone, envEffects)
    local fishData = Config.fish[fishName]
    
    if not fishData or not player:canCarryItem(fishName, 1) then
        TriggerClientEvent('lunar_fishing:showNotification', source, 'Inventorius pilnas!', 'error')
        state.players[source] = nil
        return
    end
    
    -- Remove bait
    player:removeItem(bait.name, 1)
    
    -- Start fishing process
    local success = lib.callback.await('lunar_fishing:itemUsed', source, bait, fishData, envEffects)
    
    if success then
        -- Add fish and XP
        player:addItem(fishName, 1)
        FishingServer.addPlayerLevel(player, Config.progressPerCatch)
        
        -- Calculate value and notify (only for rare+ fish to reduce spam)
        local fishValue = FishingUtils.getAveragePrice(fishData.price)
        
        -- Only send catch notification for rare+ fish
        if fishData.rarity ~= 'common' and fishData.rarity ~= 'uncommon' then
            TriggerClientEvent('lunar_fishing:fishCaught', source, fishName, fishData, fishValue)
        end
        
        -- Log catch (silent for common fish)
        FishingServer.logCatch(source, player, fishName, fishData, zone.blip?.name or 'Atviras vandenynas')
        
    elseif math.random(100) <= rod.breakChance then
        -- Rod breaks
        player:removeItem(rod.name, 1)
        TriggerClientEvent('lunar_fishing:showNotification', source, locale('rod_broke'), 'error')
    end
    
    state.players[source] = nil
end

-- Get best bait (cached lookup)
function FishingServer.getBestBait(player)
    for i = #Config.baits, 1, -1 do
        local bait = Config.baits[i]
        if player:getItemCount(bait.name) > 0 then
            return bait
        end
    end
    return nil
end

-- Calculate environmental effects (optimized)
function FishingServer.calculateEnvironmentalEffects(currentZone, clientHour)
    local hour = clientHour or 12
    local timePeriod = FishingUtils.getTimePeriod(hour)
    local season = Config.forcedSeason or FishingUtils.getSeason()
    
    local effects = {
        weather = state.weather,
        time = timePeriod,
        season = season,
        waitMultiplier = 1.0,
        chanceMultiplier = 1.0
    }
    
    -- Apply weather effects
    local weatherData = Config.weatherEffects[state.weather]
    if weatherData then
        effects.waitMultiplier = effects.waitMultiplier * (weatherData.waitMultiplier or 1.0)
        effects.chanceMultiplier = effects.chanceMultiplier * (1 + (weatherData.chanceBonus or 0) / 100)
    end
    
    -- Apply time effects
    local timeData = Config.timeEffects[timePeriod]
    if timeData then
        effects.waitMultiplier = effects.waitMultiplier * (timeData.waitMultiplier or 1.0)
        effects.chanceMultiplier = effects.chanceMultiplier * (1 + (timeData.chanceBonus or 0) / 100)
    end
    
    return effects
end

-- Select fish using weighted random (optimized)
function FishingServer.selectFish(zone, effects)
    local fishList = zone.fishList or Config.outside.fishList
    local weights = {}
    
    for _, fishName in ipairs(fishList) do
        local fish = Config.fish[fishName]
        if fish then
            local weight = fish.chance * (effects.chanceMultiplier or 1.0)
            
            -- Apply zone rarity multipliers
            if zone.rarityMultiplier and zone.rarityMultiplier[fish.rarity] then
                weight = weight * zone.rarityMultiplier[fish.rarity]
            end
            
            -- Weather bonuses
            if (state.weather == 'RAIN' or state.weather == 'THUNDER') and 
               (fish.rarity == 'rare' or fish.rarity == 'epic') then
                weight = weight * 1.2
            elseif state.weather == 'CLEAR' and fish.rarity == 'common' then
                weight = weight * 1.1
            end
            
            -- Seasonal bonuses
            local seasonData = Config.seasons[effects.season]
            if seasonData and seasonData.fishBonus then
                for _, bonusFish in ipairs(seasonData.fishBonus) do
                    if fishName == bonusFish then
                        weight = weight * 1.3
                        break
                    end
                end
            end
            
            weights[fishName] = math.max(weight, 0.1)
        end
    end
    
    return FishingUtils.weightedRandom(weights) or 'anchovy'
end

-- Add player level (silent on join, notifications only for active players)
function FishingServer.addPlayerLevel(player, amount)
    local identifier = player:getIdentifier()
    local currentLevel = math.floor(cache.playerLevels[identifier] or 1.0)
    
    cache.playerLevels[identifier] = (cache.playerLevels[identifier] or 1.0) + amount
    
    local newLevel = math.floor(cache.playerLevels[identifier])
    
    -- Only show level up notification if not recently joined and actually leveled up
    if newLevel > currentLevel and not isRecentlyJoined(player.source) then
        TriggerClientEvent('lunar_fishing:showNotification', player.source, 
            ('🎉 Pasiekėte %d lygį!'):format(newLevel), 'success')
    end
    
    -- Always send level update (for UI purposes)
    TriggerClientEvent('lunar_fishing:updateLevel', player.source, cache.playerLevels[identifier])
end

-- Get player level
function FishingServer.getPlayerLevel(player)
    return cache.playerLevels[player:getIdentifier()] or 1.0
end

-- Create new player record (fixed - use INSERT IGNORE to prevent duplicates)
function FishingServer.createPlayer(identifier)
    cache.playerLevels[identifier] = 1.0
    
    -- Use INSERT IGNORE to prevent duplicate key errors
    local success = MySQL.insert.await('INSERT IGNORE INTO lunar_fishing (user_identifier, xp) VALUES(?, ?)', {
        identifier, cache.playerLevels[identifier]
    })
    
    -- If INSERT IGNORE failed (record already exists), just load the existing value
    if not success then
        local existing = MySQL.scalar.await('SELECT xp FROM lunar_fishing WHERE user_identifier = ?', {identifier})
        if existing then
            cache.playerLevels[identifier] = existing
        end
    end
end

-- Log fishing catch (only for rare+ catches to reduce spam)
function FishingServer.logCatch(source, player, fishName, fishData, zoneName)
    if SvConfig.Webhook == 'WEBHOOK_HERE' then return end
    
    -- Only log rare+ catches to reduce webhook spam
    if fishData.rarity == 'common' or fishData.rarity == 'uncommon' then
        return
    end
    
    local message = ('Pagavo %s (%s) zonoje %s'):format(
        FishingUtils.getItemLabel(fishName),
        fishData.rarity,
        zoneName
    )
    
    -- Simple webhook log
    local embed = {
        title = GetPlayerName(source) .. ' (' .. player:getIdentifier() .. ')',
        description = message,
        color = 16768885,
        timestamp = os.date('%Y-%m-%dT%H:%M:%SZ')
    }
    
    PerformHttpRequest(SvConfig.Webhook, function() end, 'POST', 
        json.encode({ embeds = { embed } }), 
        { ['Content-Type'] = 'application/json' }
    )
end

-- Simple contract system (no spam notifications)
function FishingServer.initContracts()
    local function generateContracts()
        state.contracts = {
            {
                id = 'catch_any_5',
                title = 'Pagauti 5 žuvis',
                description = 'Pagaukite bet kokias 5 žuvis bonuso atlygiui.',
                type = 'catch_any',
                target = { amount = 5 },
                reward = { money = 500, xp = 0.1 }
            },
            {
                id = 'catch_value_1000',
                title = 'Aukštos vertės laimikis',
                description = 'Pagaukite žuvų už bent 1000€ iš viso.',
                type = 'catch_value',
                target = { value = 1000 },
                reward = { money = 800, xp = 0.15 }
            },
            {
                id = 'catch_rare_3',
                title = 'Retų žuvų medžiotojas',
                description = 'Pagaukite 3 retas ar geresnes žuvis.',
                type = 'catch_rarity',
                target = { rarity = 'rare', amount = 3 },
                reward = { money = 1200, xp = 0.2 }
            }
        }
        
        -- Send contracts update silently (no notifications)
        TriggerClientEvent('lunar_fishing:contractsRefreshed', -1, state.contracts)
    end
    
    -- Generate initial contracts
    generateContracts()
    
    -- Refresh every hour using safe interval
    SetInterval(function()
        generateContracts()
    end, CONTRACT_REFRESH_INTERVAL)
end

-- Callbacks (all silent data transfers)
lib.callback.register('lunar_fishing:getLevel', function(source)
    local player = Framework.getPlayerFromId(source)
    if not player then return 1.0 end
    
    local identifier = player:getIdentifier()
    if not cache.playerLevels[identifier] then
        FishingServer.createPlayer(identifier)
    end
    
    return cache.playerLevels[identifier]
end)

lib.callback.register('lunar_fishing:getCurrentWeather', function(source)
    return state.weather
end)

lib.callback.register('lunar_fishing:getCurrentSeason', function(source)
    local season = Config.forcedSeason or FishingUtils.getSeason()
    return season, Config.seasons[season]
end)

lib.callback.register('lunar_fishing:getActiveContracts', function(source)
    return state.contracts
end)

lib.callback.register('lunar_fishing:getTournamentInfo', function(source)
    return nil -- No tournaments for now
end)

lib.callback.register('lunar_fishing:getEnvironmentalEffects', function(source)
    local clientHour = lib.callback.await('lunar_fishing:getClientHour', source)
    return FishingServer.calculateEnvironmentalEffects(nil, clientHour)
end)

-- Admin commands (Lithuanian messages)
RegisterNetEvent('lunar_fishing:setWeather', function(weather)
    local source = source
    local player = Framework.getPlayerFromId(source)
    
    if not player then return end
    
    -- Add proper permission check here
    local hasPermission = true -- Placeholder - implement your permission system
    
    if not hasPermission then
        TriggerClientEvent('lunar_fishing:showNotification', source, 'Neturite leidimo', 'error')
        return
    end
    
    -- Safe weather types check with fallback
    local weatherTypes = { 'CLEAR', 'CLOUDY', 'OVERCAST', 'RAIN', 'THUNDER', 'FOGGY', 'SNOW', 'BLIZZARD' }
    if not FishingUtils.tableContains(weatherTypes, weather) then
        TriggerClientEvent('lunar_fishing:showNotification', source, 'Neteisingas oro tipas', 'error')
        return
    end
    
    state.weather = weather
    TriggerClientEvent('lunar_fishing:weatherChanged', -1, weather)
    TriggerClientEvent('lunar_fishing:showNotification', source, ('Oras nustatytas į: %s'):format(weather), 'success')
    
    print(('[Fishing] Admin %s pakeite orą į: %s'):format(GetPlayerName(source), weather))
end)

RegisterNetEvent('lunar_fishing:setSeason', function(season)
    local source = source
    local player = Framework.getPlayerFromId(source)
    
    if not player then return end
    
    -- Add proper permission check here
    local hasPermission = true -- Placeholder
    
    if not hasPermission then
        TriggerClientEvent('lunar_fishing:showNotification', source, 'Neturite leidimo', 'error')
        return
    end
    
    if not Config.seasons[season] then
        TriggerClientEvent('lunar_fishing:showNotification', source, 'Neteisingas sezonas', 'error')
        return
    end
    
    Config.forcedSeason = season
    TriggerClientEvent('lunar_fishing:seasonChanged', -1, season)
    TriggerClientEvent('lunar_fishing:showNotification', source, ('Sezonas nustatytas į: %s'):format(season:upper()), 'success')
    
    print(('[Fishing] Admin %s pakeite sezoną į: %s'):format(GetPlayerName(source), season))
end)

-- Clean up player data on disconnect
AddEventHandler('esx:playerDropped', function(playerId)
    state.players[playerId] = nil
    state.playerJoinTimes[playerId] = nil
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(playerId)
    state.players[playerId] = nil
    state.playerJoinTimes[playerId] = nil
end)

AddEventHandler('playerDropped', function(reason)
    local source = source
    state.players[source] = nil
    state.playerJoinTimes[source] = nil
end)

-- Performance monitoring and cleanup
CreateThread(function()
    local startTime = GetGameTimer()
    
    while true do
        Wait(300000) -- Every 5 minutes
        
        local memoryUsage = collectgarbage('count')
        local uptime = math.floor((GetGameTimer() - startTime) / 1000 / 60) -- Minutes
        
        -- Clean up old player join times (older than 1 hour)
        local now = GetGameTimer()
        for playerId, joinTime in pairs(state.playerJoinTimes) do
            if now - joinTime > 3600000 then -- 1 hour
                state.playerJoinTimes[playerId] = nil
            end
        end
        
        -- Periodic garbage collection
        if memoryUsage > 50000 then -- 50MB
            collectgarbage('collect')
        end
        
        -- Debug info (only in development)
        if GetConvar('fishing_debug', '0') == '1' then
            print(('[Fishing] Uptime: %dm, Memory: %.2fMB, Active Players: %d'):format(
                uptime, memoryUsage / 1024, #GetPlayers()
            ))
        end
    end
end)

-- Season auto-detection if not forced
CreateThread(function()
    if Config.forcedSeason then return end -- Skip if forced season is set
    
    while true do
        Wait(3600000) -- Check every hour
        
        local currentMonth = tonumber(os.date('%m'))
        local newSeason = FishingUtils.getSeason(currentMonth)
        
        if newSeason ~= (state.currentSeason or 'spring') then
            state.currentSeason = newSeason
            -- Silent season change - no notifications to prevent spam
            TriggerClientEvent('lunar_fishing:seasonChanged', -1, newSeason)
        end
    end
end)

-- Resource health check and emergency save
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Emergency save before shutdown
        local query = 'UPDATE lunar_fishing SET xp = ? WHERE user_identifier = ?'
        local parameters = {}
        local count = 0
        
        for identifier, xp in pairs(cache.playerLevels) do
            count = count + 1
            parameters[count] = { xp, identifier }
        end
        
        if count > 0 then
            print('[Fishing] Emergency save: ' .. count .. ' records')
            MySQL.prepare.await(query, parameters)
        end
        
        print('[Fishing] Resource stopped cleanly')
    end
end)

-- Export functions for other resources
exports('getCurrentWeather', function()
    return state.weather
end)

exports('setWeather', function(weather)
    local weatherTypes = { 'CLEAR', 'CLOUDY', 'OVERCAST', 'RAIN', 'THUNDER', 'FOGGY', 'SNOW', 'BLIZZARD' }
    if FishingUtils.tableContains(weatherTypes, weather) then
        state.weather = weather
        TriggerClientEvent('lunar_fishing:weatherChanged', -1, weather)
        return true
    end
    return false
end)

exports('getWeatherEffects', function()
    return Config.weatherEffects[state.weather]
end)

exports('getCurrentSeason', function()
    return Config.forcedSeason or (FishingUtils and FishingUtils.getSeason and FishingUtils.getSeason() or 'spring')
end)

exports('setSeason', function(season)
    if Config.seasons[season] then
        Config.forcedSeason = season
        TriggerClientEvent('lunar_fishing:seasonChanged', -1, season)
        return true
    end
    return false
end)

exports('getPlayerLevel', function(source)
    local player = Framework.getPlayerFromId(source)
    return player and FishingServer.getPlayerLevel(player) or 1.0
end)

exports('addPlayerXP', function(source, amount)
    local player = Framework.getPlayerFromId(source)
    if player then
        FishingServer.addPlayerLevel(player, amount)
        return true
    end
    return false
end)

-- Global functions for compatibility
AddPlayerLevel = FishingServer.addPlayerLevel
GetPlayerLevel = FishingServer.getPlayerLevel

-- Version check and startup info
CreateThread(function()
    Wait(5000)
    
    local playerCount = 0
    for _ in pairs(cache.playerLevels) do
        playerCount = playerCount + 1
    end
    
    print('==================================================')
    print('  🎣 Lunar Fishing Script')
    print('  Version: 2.0.0 ')
    print('  Features: Enhanced with proper error handling')
    print('  Weather System: ' .. (state.weather or 'CLEAR'))
    print('  Forced Season: ' .. (Config.forcedSeason or 'Auto'))
    print('  Database Records: ' .. playerCount)
    print('==================================================')
end)

-- Initialize when resource starts
CreateThread(function()
    Wait(1000)
    FishingServer.init()
end)

-- Export
_G.FishingServer = FishingServer
return FishingServer