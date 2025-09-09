-- client/environment.lua (Fixed typo and constants access)
-- Optimized environment system - only essential notifications

local Environment = {}

-- Cache to prevent recalculations
local cache = {
    weather = 'CLEAR',
    season = 'spring', -- Default fallback
    timePeriod = 'day',
    effects = {},
    lastUpdate = 0,
    lastNotification = {},
    initialized = false
}

-- Reduce update frequency - use fallback if constants not loaded
local UPDATE_INTERVAL = 30000 -- 30 seconds fallback

-- Initialize environment system
function Environment.init()
    -- Set proper interval once constants are loaded
    if FishingConstants and FishingConstants.INTERVALS then
        UPDATE_INTERVAL = FishingConstants.INTERVALS.ENVIRONMENT_UPDATE
    end
    
    -- Set forced season if configured
    if Config and Config.forcedSeason then
        cache.season = Config.forcedSeason
    end
    
    -- Single update thread
    CreateThread(function()
        Wait(5000) -- Initial delay to prevent spam on join
        cache.initialized = true
        
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
    
    -- Only process if something changed AND system is initialized
    if newTimePeriod ~= oldTimePeriod and cache.initialized then
        cache.timePeriod = newTimePeriod
        Environment.handleTimeChange(oldTimePeriod, newTimePeriod)
    else
        cache.timePeriod = newTimePeriod
    end
    
    -- Recalculate effects
    cache.effects = Environment.calculateEffects()
    cache.lastUpdate = now
end

-- Get current time period (simplified)
function Environment.getCurrentTimePeriod()
    if FishingUtils and FishingUtils.getTimePeriod then
        return FishingUtils.getTimePeriod(GetClockHours())
    else
        -- Fallback if utils not loaded yet
        local hour = GetClockHours()
        if hour >= 5 and hour <= 7 then return 'dawn'
        elseif hour >= 8 and hour <= 11 then return 'morning'
        elseif hour >= 12 and hour <= 14 then return 'noon'
        elseif hour >= 15 and hour <= 17 then return 'afternoon'
        elseif hour >= 18 and hour <= 20 then return 'dusk'
        elseif hour >= 21 or hour <= 4 then return 'night'
        else return 'day' end
    end
end

-- Get current season
function Environment.getCurrentSeason()
    if Config and Config.forcedSeason then
        return Config.forcedSeason, Config.seasons and Config.seasons[Config.forcedSeason] or {}
    end
    return cache.season, Config and Config.seasons and Config.seasons[cache.season] or {}
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
    
    -- Apply weather effects if config is loaded
    if Config and Config.weatherEffects then
        local weatherData = Config.weatherEffects[cache.weather]
        if weatherData then
            effects.waitMultiplier = effects.waitMultiplier * (weatherData.waitMultiplier or 1.0)
            effects.chanceMultiplier = effects.chanceMultiplier * (1 + (weatherData.chanceBonus or 0) / 100)
        end
    end
    
    -- Apply time effects if config is loaded
    if Config and Config.timeEffects then
        local timeData = Config.timeEffects[cache.timePeriod]
        if timeData then
            effects.waitMultiplier = effects.waitMultiplier * (timeData.waitMultiplier or 1.0)
            effects.chanceMultiplier = effects.chanceMultiplier * (1 + (timeData.chanceBonus or 0) / 100)
        end
    end
    
    return effects
end

-- Handle time period changes (only prime times)
function Environment.handleTimeChange(oldPeriod, newPeriod)
    if not cache.initialized then return end
    
    -- Only notify for prime fishing times and with cooldown
    local now = GetGameTimer()
    local cooldownKey = 'time_' .. newPeriod
    
    if now - (cache.lastNotification[cooldownKey] or 0) < 1800000 then -- 30 minutes cooldown
        return
    end
    
    -- Use constants if available, otherwise fallback
    local DAWN = (FishingConstants and FishingConstants.TIME_PERIODS and FishingConstants.TIME_PERIODS.DAWN) or 'dawn'
    local DUSK = (FishingConstants and FishingConstants.TIME_PERIODS and FishingConstants.TIME_PERIODS.DUSK) or 'dusk'
    
    if newPeriod == DAWN then
        if FishingUI and FishingUI.queueNotification then
            FishingUI.queueNotification('🌅 Aušra - puikus žvejybos laikas!', 'success', 
                (FishingConstants and FishingConstants.NOTIFICATION_PRIORITY and FishingConstants.NOTIFICATION_PRIORITY.NORMAL) or 2)
        end
        cache.lastNotification[cooldownKey] = now
    elseif newPeriod == DUSK then
        if FishingUI and FishingUI.queueNotification then
            FishingUI.queueNotification('🌆 Sutemose - puikus žvejybos laikas!', 'success', 
                (FishingConstants and FishingConstants.NOTIFICATION_PRIORITY and FishingConstants.NOTIFICATION_PRIORITY.NORMAL) or 2)
        end
        cache.lastNotification[cooldownKey] = now
    end
end

-- Weather change handler (minimal notifications)
function Environment.onWeatherChanged(weather)
    local oldWeather = cache.weather
    cache.weather = weather
    
    -- Only notify if significantly different and system is initialized
    if cache.initialized and oldWeather ~= weather and Environment.shouldNotifyWeatherChange(weather) then
        local weatherData = Config and Config.weatherEffects and Config.weatherEffects[weather]
        
        -- Only notify for significant weather changes
        if weatherData and weatherData.chanceBonus and math.abs(weatherData.chanceBonus) >= 10 then
            local message = weatherData.message
            if weatherData.chanceBonus > 0 then
                message = '🌟 ' .. (message or 'Geras oras žvejybai!')
            else
                message = '⚠️ ' .. (message or 'Blogas oras žvejybai.')
            end
            
            local notifType = weatherData.chanceBonus >= 0 and 'success' or 'warn'
            if FishingUI and FishingUI.queueNotification then
                FishingUI.queueNotification(message, notifType, 
                    (FishingConstants and FishingConstants.NOTIFICATION_PRIORITY and FishingConstants.NOTIFICATION_PRIORITY.NORMAL) or 2)
            end
        end
    end
end

-- Season change handler (silent - no notifications)
function Environment.onSeasonChanged(season)
    cache.season = season
    -- No notifications for season changes to reduce spam
end

-- Check if weather change should trigger notification
function Environment.shouldNotifyWeatherChange(weather)
    local lastTime = cache.lastNotification[weather] or 0
    local now = GetGameTimer()
    
    -- Don't spam same weather notifications - 1 hour cooldown
    if now - lastTime < 3600000 then
        return false
    end
    
    cache.lastNotification[weather] = now
    return true
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

-- Initialize when script loads
CreateThread(function()
    Wait(1000) -- Wait for other scripts to load
    Environment.init()
end)

-- Export
_G.FishingEnvironment = Environment
return Environment