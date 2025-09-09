-- shared/constants.lua
-- All constants and enums in one place

-- Make it global so all files can access it
FishingConstants = {}

-- Update intervals (milliseconds)
FishingConstants.INTERVALS = {
    ENVIRONMENT_UPDATE = 30000,  -- 30 seconds
    NOTIFICATION_COOLDOWN = 2000, -- 2 seconds
    WEATHER_CYCLE = 600000,      -- 10 minutes
    CONTRACT_REFRESH = 3600000,  -- 1 hour
    SAVE_INTERVAL = 600000       -- 10 minutes
}

-- Rarity system
FishingConstants.RARITY = {
    COMMON = 1,
    UNCOMMON = 2,
    RARE = 3,
    EPIC = 4,
    LEGENDARY = 5,
    MYTHICAL = 6
}

FishingConstants.RARITY_NAMES = {
    [1] = 'common',
    [2] = 'uncommon', 
    [3] = 'rare',
    [4] = 'epic',
    [5] = 'legendary',
    [6] = 'mythical'
}

FishingConstants.RARITY_EMOJIS = {
    common = '🐟',
    uncommon = '🐠',
    rare = '🌟', 
    epic = '💎',
    legendary = '👑',
    mythical = '🔮'
}

-- Weather types
FishingConstants.WEATHER_TYPES = {
    'CLEAR', 'CLOUDY', 'OVERCAST', 'RAIN', 'THUNDER', 'FOGGY', 'SNOW', 'BLIZZARD'
}

-- Time periods
FishingConstants.TIME_PERIODS = {
    NIGHT = 'night',
    DAWN = 'dawn', 
    MORNING = 'morning',
    NOON = 'noon',
    AFTERNOON = 'afternoon',
    DUSK = 'dusk',
    DAY = 'day'
}

-- Seasons
FishingConstants.SEASONS = {
    SPRING = 'spring',
    SUMMER = 'summer', 
    AUTUMN = 'autumn',
    WINTER = 'winter'
}

-- Notification priorities
FishingConstants.NOTIFICATION_PRIORITY = {
    LOW = 1,
    NORMAL = 2,
    HIGH = 3,
    CRITICAL = 4
}

-- Keybind names
FishingConstants.KEYBINDS = {
    FISHING_INFO = 'fishing_info',
    CONTRACTS = 'fishing_contracts',
    TOURNAMENT = 'tournament_info',
    ANCHOR = 'anchor_toggle',
    RETURN_BOAT = 'fishing_interaction'
}

-- Don't need to export since it's already global
return FishingConstants