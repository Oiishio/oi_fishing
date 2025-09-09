-- server/main.lua (Optimized)
-- Core server fishing logic

lib.locale()
lib.versionCheck('https://github.com/Lunar-Scripts/lunar_fishing')

local FishingServer = {}

-- Server state
local state = {
    players = {}, -- Active fishing players
    weather = 'CLEAR',
    contracts = {},
    tournaments = {}
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

-- Simplified weather system
function FishingServer.initWeatherSystem()
    local weatherCycle = { 'CLEAR', 'CLOUDY', 'OVERCAST', 'RAIN', 'CLEARING', 'CLEAR', 'FOGGY', 'CLEAR' }
    local weatherIndex = 1
    
    CreateThread(function()
        Wait(5000)
        
        while true do
            Wait(FishingConstants.INTERVALS.WEATHER_CYCLE)
            
            weatherIndex = weatherIndex % #weatherCycle + 1
            local newWeather = weatherCycle[weatherIndex]
            
            -- 15% chance for special weather
            if math.random(100) <= 15 then
                local specialWeathers = { 'THUNDER', 'SNOW', 'BLIZZARD' }
                newWeather = FishingUtils.randomFromTable(specialWeathers)
            end
            
            state.weather = newWeather
            TriggerClientEvent('lunar_fishing:weatherChanged', -1, newWeather)
            
            print('[Fishing] Weather changed to:', newWeather)
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

-- Handle fishing rod usage (optimized)
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
        TriggerClientEvent('lunar_fishing:showNotification', source, 'Inventory full!', 'error')
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
        
        -- Calculate value and notify
        local fishValue = FishingUtils.getAveragePrice(fishData.price)
        TriggerClientEvent('lunar_fishing:fishCaught', source, fishName, fishData, fishValue)
        
        -- Log catch
        FishingServer.logCatch(source, player, fishName, fishData, zone.blip?.name or 'Open Waters')
        
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

-- Add player level (optimized)
function FishingServer.addPlayerLevel(player, amount)
    local identifier = player:getIdentifier()
    local currentLevel = math.floor(cache.playerLevels[identifier] or 1.0)
    
    cache.playerLevels[identifier] = (cache.playerLevels[identifier] or 1.0) + amount
    
    local newLevel = math.floor(cache.playerLevels[identifier])
    if newLevel > currentLevel then
        TriggerClientEvent('lunar_fishing:showNotification', player.source, locale('unlocked_level'), 'success')
    end
    
    TriggerClientEvent('lunar_fishing:updateLevel', player.source, cache.playerLevels[identifier])
end

-- Get player level
function FishingServer.getPlayerLevel(player)
    return cache.playerLevels[player:getIdentifier()] or 1.0
end

-- Create new player record
function FishingServer.createPlayer(identifier)
    cache.playerLevels[identifier] = 1.0
    MySQL.insert.await('INSERT INTO lunar_fishing (user_identifier, xp) VALUES(?, ?)', {
        identifier, cache.playerLevels[identifier]
    })
end

-- Log fishing catch (simplified)
function FishingServer.logCatch(source, player, fishName, fishData, zoneName)
    if SvConfig.Webhook == 'WEBHOOK_HERE' then return end
    
    local message = ('Caught %s (%s) in %s'):format(
        FishingUtils.getItemLabel(fishName),
        fishData.rarity,
        zoneName
    )
    
    -- Simple webhook log (you can expand this)
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

-- Simple contract system
function FishingServer.initContracts()
    local function generateContracts()
        state.contracts = {
            {
                id = 'catch_any_5',
                title = 'Catch 5 Fish',
                description = 'Catch any 5 fish for bonus reward.',
                type = 'catch_any',
                target = { amount = 5 },
                reward = { money = 500, xp = 0.1 }
            },
            {
                id = 'catch_value_1000',
                title = 'High Value Catch',
                description = 'Catch fish worth at least €1000 total.',
                type = 'catch_value',
                target = { value = 1000 },
                reward = { money = 800, xp = 0.15 }
            },
            {
                id = 'catch_rare_3',
                title = 'Rare Fish Hunter',
                description = 'Catch 3 rare or better fish.',
                type = 'catch_rarity',
                target = { rarity = 'rare', amount = 3 },
                reward = { money = 1200, xp = 0.2 }
            }
        }
        
        TriggerClientEvent('lunar_fishing:contractsRefreshed', -1, state.contracts)
    end
    
    -- Generate initial contracts
    generateContracts()
    
    -- Refresh every hour
    SetInterval(function()
        generateContracts()
    end, FishingConstants.INTERVALS.CONTRACT_REFRESH)
end

-- Callbacks
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

-- Admin commands
RegisterNetEvent('lunar_fishing:setWeather', function(weather)
    local source = source
    local player = Framework.getPlayerFromId(source)
    
    if not player then return end
    
    -- Add proper permission check here
    local hasPermission = true -- Placeholder
    
    if not hasPermission then
        TriggerClientEvent('lunar_fishing:showNotification', source, 'No permission', 'error')
        return
    end
    
    if not FishingUtils.tableContains(FishingConstants.WEATHER_TYPES, weather) then
        TriggerClientEvent('lunar_fishing:showNotification', source, 'Invalid weather type', 'error')
        return
    end
    
    state.weather = weather
    TriggerClientEvent('lunar_fishing:weatherChanged', -1, weather)
    TriggerClientEvent('lunar_fishing:showNotification', source, ('Weather set to: %s'):format(weather), 'success')
    
    print(('[Fishing] Admin %s changed weather to: %s'):format(GetPlayerName(source), weather))
end)

RegisterNetEvent('lunar_fishing:setSeason', function(season)
    local source = source
    local player = Framework.getPlayerFromId(source)
    
    if not player then return end
    
    -- Add proper permission check here
    local hasPermission = true -- Placeholder
    
    if not hasPermission then
        TriggerClientEvent('lunar_fishing:showNotification', source, 'No permission', 'error')
        return
    end
    
    if not Config.seasons[season] then
        TriggerClientEvent('lunar_fishing:showNotification', source, 'Invalid season', 'error')
        return
    end
    
    Config.forcedSeason = season
    TriggerClientEvent('lunar_fishing:seasonChanged', -1, season)
    TriggerClientEvent('lunar_fishing:showNotification', source, ('Season set to: %s'):format(season:upper()), 'success')
    
    print(('[Fishing] Admin %s changed season to: %s'):format(GetPlayerName(source), season))
end)

-- Export functions for other resources
exports('getCurrentWeather', function()
    return state.weather
end)

exports('setWeather', function(weather)
    if FishingUtils.tableContains(FishingConstants.WEATHER_TYPES, weather) then
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
    return Config.forcedSeason or FishingUtils.getSeason()
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

-- Initialize when resource starts
CreateThread(function()
    Wait(1000)
    FishingServer.init()
end)

-- Export
_G.FishingServer = FishingServer
return FishingServer