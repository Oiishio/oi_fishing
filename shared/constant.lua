-- shared/constants.lua
-- All constants and enums in one place

local Constants = {}

-- Update intervals (milliseconds)
Constants.INTERVALS = {
    ENVIRONMENT_UPDATE = 30000,  -- 30 seconds
    NOTIFICATION_COOLDOWN = 2000, -- 2 seconds
    WEATHER_CYCLE = 600000,      -- 10 minutes
    CONTRACT_REFRESH = 3600000,  -- 1 hour
    SAVE_INTERVAL = 600000       -- 10 minutes
}

-- Rarity system
Constants.RARITY = {
    COMMON = 1,
    UNCOMMON = 2,
    RARE = 3,
    EPIC = 4,
    LEGENDARY = 5,
    MYTHICAL = 6
}

Constants.RARITY_NAMES = {
    [1] = 'common',
    [2] = 'uncommon', 
    [3] = 'rare',
    [4] = 'epic',
    [5] = 'legendary',
    [6] = 'mythical'
}

Constants.RARITY_EMOJIS = {
    common = '🐟',
    uncommon = '🐠',
    rare = '🌟', 
    epic = '💎',
    legendary = '👑',
    mythical = '🔮'
}

-- Weather types
Constants.WEATHER_TYPES = {
    'CLEAR', 'CLOUDY', 'OVERCAST', 'RAIN', 'THUNDER', 'FOGGY', 'SNOW', 'BLIZZARD'
}

-- Time periods
Constants.TIME_PERIODS = {
    NIGHT = 'night',
    DAWN = 'dawn', 
    MORNING = 'morning',
    NOON = 'noon',
    AFTERNOON = 'afternoon',
    DUSK = 'dusk',
    DAY = 'day'
}

-- Seasons
Constants.SEASONS = {
    SPRING = 'spring',
    SUMMER = 'summer', 
    AUTUMN = 'autumn',
    WINTER = 'winter'
}

-- Notification priorities
Constants.NOTIFICATION_PRIORITY = {
    LOW = 1,
    NORMAL = 2,
    HIGH = 3,
    CRITICAL = 4
}

-- Keybind names
Constants.KEYBINDS = {
    FISHING_INFO = 'fishing_info',
    CONTRACTS = 'fishing_contracts',
    TOURNAMENT = 'tournament_info',
    ANCHOR = 'anchor_toggle',
    RETURN_BOAT = 'fishing_interaction'
}

-- Export
_G.FishingConstants = Constants
return Constants