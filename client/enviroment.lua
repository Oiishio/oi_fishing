-- client/environment.lua  
-- Optimized environment system (weather, time, seasons)

local Environment = {}

-- Cache to prevent recalculations
local cache = {
    weather = 'CLEAR',
    season = Config.forcedSeason or 'spring',
    timePeriod = 'day',
    effects = {},
    lastUpdate = 0,
    lastNotification = {}
}

-- Reduce update frequency
local UPDATE_INTERVAL = FishingConstants.INTERVALS.ENVIRONMENT_UPDATE

-- Initialize environment system
function Environment.init()
    -- Single update thread
    CreateThread(function()
        while true do
            Environment.update()
            Wait(UPDATE_INTERVAL)
        end
    end)
    
    -- Listen for server weather changes
    RegisterNetEvent('lunar_fishing:weatherChanged', Environment.onWeatherChanged)
    RegisterNetEvent('lunar_fishing:seasonChanged', Environment.onSeasonChanged)
end

-- Main update function
function Environment.update()
    local now = GetGameTimer()
    if now - cache.lastUpdate < UPDATE_INTERVAL then return end
    
    local newTimePeriod = Environment.getCurrentTimePeriod()
    local oldTimePeriod = cache.timePeriod
    
    -- Only process if something changed
    if newTimePeriod ~= oldTimePeriod then
        cache.timePeriod = newTimePeriod
        Environment.handleTimeChange(oldTimePeriod, newTimePeriod)
    end
    
    -- Recalculate effects
    cache.effects = Environment.calculateEffects()
    cache.lastUpdate = now
end

-- Get current time period (simplified)
function Environment.getCurrentTimePeriod()
    return FishingUtils.getTimePeriod(GetClockHours())
end

-- Get current season
function Environment.getCurrentSeason()
    if Config.forcedSeason then
        return Config.forcedSeason, Config.seasons[Config.forcedSeason]
    end
    return cache.season, Config.seasons[cache.season]
end

-- Get current weather
function Environment.getCurrentWeather()
    return cache.weather
end

-- Calculate environmental effects (cached)
function Environment.calculateEffects()
    local effects = {
        weather = cache.weather,
        time = cache.timePeriod,
        season = cache.season,
        waitMultiplier = 1.0,
        chanceMultiplier = 1.0
    }
    
    -- Apply weather effects
    local weatherData = Config.weatherEffects[cache.weather]
    if weatherData then
        effects.waitMultiplier = effects.waitMultiplier * (weatherData.waitMultiplier or 1.0)
        effects.chanceMultiplier = effects.chanceMultiplier * (1 + (weatherData.chanceBonus or 0) / 100)
    end
    
    -- Apply time effects
    local timeData = Config.timeEffects[cache.timePeriod]
    if timeData then
        effects.waitMultiplier = effects.waitMultiplier * (timeData.waitMultiplier or 1.0)
        effects.chanceMultiplier = effects.chanceMultiplier * (1 + (timeData.chanceBonus or 0) / 100)
    end
    
    return effects
end

-- Handle time period changes (reduced notifications)
function Environment.handleTimeChange(oldPeriod, newPeriod)
    -- Only notify for prime fishing times
    if newPeriod == FishingConstants.TIME_PERIODS.DAWN then
        FishingUI.queueNotification(locale('dawn_arrived') or '🌅 Dawn - prime fishing time!', 'success', FishingConstants.NOTIFICATION_PRIORITY.HIGH)
    elseif newPeriod == FishingConstants.TIME_PERIODS.DUSK then
        FishingUI.queueNotification(locale('dusk_arrived') or '🌆 Dusk - prime fishing time!', 'success', FishingConstants.NOTIFICATION_PRIORITY.HIGH)
    end
end

-- Weather change handler
function Environment.onWeatherChanged(weather)
    local oldWeather = cache.weather
    cache.weather = weather
    
    -- Only notify if significantly different
    if oldWeather ~= weather and Environment.shouldNotifyWeatherChange(weather) then
        local weatherData = Config.weatherEffects[weather]
        if weatherData and weatherData.message then
            local details = Environment.getWeatherDetails(weatherData)
            local message = weatherData.message
            if details then
                message = message .. ' (' .. details .. ')'
            end
            
            local priority = weatherData.chanceBonus >= 10 and FishingConstants.NOTIFICATION_PRIORITY.HIGH or FishingConstants.NOTIFICATION_PRIORITY.NORMAL
            local notifType = weatherData.chanceBonus >= 0 and 'success' or 'warn'
            
            FishingUI.queueNotification(message, notifType, priority)
        end
    end
end

-- Season change handler
function Environment.onSeasonChanged(season)
    local oldSeason = cache.season
    cache.season = season
    
    if oldSeason ~= season then
        local seasonData = Config.seasons[season]
        if seasonData then
            local message = ('🍂 %s: %s'):format(season:upper(), seasonData.message)
            FishingUI.queueNotification(message, 'inform', FishingConstants.NOTIFICATION_PRIORITY.NORMAL)
        end
    end
end

-- Check if weather change should trigger notification
function Environment.shouldNotifyWeatherChange(weather)
    local lastTime = cache.lastNotification[weather] or 0
    local now = GetGameTimer()
    
    -- Don't spam same weather notifications
    if now - lastTime < 300000 then -- 5 minutes
        return false
    end
    
    cache.lastNotification[weather] = now
    return true
end

-- Get weather effect details for notification
function Environment.getWeatherDetails(weatherData)
    local details = {}
    
    if weatherData.chanceBonus and weatherData.chanceBonus ~= 0 then
        local sign = weatherData.chanceBonus > 0 and '+' or ''
        table.insert(details, sign .. weatherData.chanceBonus .. '% catch')
    end
    
    if weatherData.waitMultiplier and weatherData.waitMultiplier ~= 1.0 then
        local speedChange = math.floor((1 - weatherData.waitMultiplier) * 100)
        if speedChange > 0 then
            table.insert(details, '+' .. speedChange .. '% speed')
        elseif speedChange < 0 then
            table.insert(details, speedChange .. '% speed')
        end
    end
    
    return #details > 0 and table.concat(details, ', ') or nil
end

-- Get cached effects (for external use)
function Environment.getEffects()
    return cache.effects
end

-- Force refresh (for commands)
function Environment.forceUpdate()
    cache.lastUpdate = 0
    Environment.update()
end

-- Get environment info for display
function Environment.getInfo()
    return {
        weather = cache.weather,
        timePeriod = cache.timePeriod,
        season = cache.season,
        effects = cache.effects,
        hour = GetClockHours(),
        minute = GetClockMinutes()
    }
end

-- Export
_G.FishingEnvironment = Environment
return Environment