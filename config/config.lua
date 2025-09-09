-- config/config.lua (Optimized)
-- Streamlined configuration with better organization

Config = {}

-- Core Settings
Config.progressPerCatch = 0.05
Config.forcedSeason = "autumn" -- Set to 'spring'/'summer'/'autumn'/'winter' or nil for auto

-- Performance Settings
Config.performance = {
    updateInterval = 30000,      -- Environment updates (30s)
    notificationCooldown = 2000, -- Between notifications (2s)
    maxNotificationQueue = 10,   -- Max queued notifications
    saveInterval = 600000,       -- Database saves (10min)
    weatherCycleDuration = 600000 -- Weather changes (10min)
}

-- Weather Effects (simplified)
Config.weatherEffects = {
    CLEAR = { waitMultiplier = 1.0, chanceBonus = 0 },
    CLOUDY = { waitMultiplier = 0.95, chanceBonus = 2, message = 'Cloudy skies help fishing.' },
    OVERCAST = { waitMultiplier = 0.9, chanceBonus = 5, message = 'Overcast conditions are great!' },
    RAIN = { waitMultiplier = 0.8, chanceBonus = 10, message = 'Rain makes fish active!' },
    THUNDER = { waitMultiplier = 0.7, chanceBonus = 15, message = 'Storms bring out big fish!' },
    FOGGY = { waitMultiplier = 1.3, chanceBonus = -10, message = 'Fog makes fishing harder.' },
    SNOW = { waitMultiplier = 1.4, chanceBonus = -15, message = 'Cold slows fish activity.' },
    BLIZZARD = { waitMultiplier = 1.6, chanceBonus = -20, message = 'Harsh blizzard conditions.' }
}

-- Time Effects (fixed ranges)
Config.timeEffects = {
    dawn = { waitMultiplier = 0.85, chanceBonus = 8, message = 'Prime fishing time!' },
    morning = { waitMultiplier = 1.0, chanceBonus = 0, message = 'Steady fishing.' },
    noon = { waitMultiplier = 1.2, chanceBonus = -5, message = 'Fish avoid the heat.' },
    afternoon = { waitMultiplier = 1.1, chanceBonus = 0, message = 'Decent fishing.' },
    dusk = { waitMultiplier = 0.85, chanceBonus = 8, message = 'Another prime time!' },
    night = { waitMultiplier = 1.3, chanceBonus = -8, message = 'Night fishing is tough.' }
}

-- Seasonal Effects
Config.seasons = {
    spring = { 
        message = 'Spring brings active fish!',
        fishBonus = { 'salmon', 'trout', 'bass' }
    },
    summer = { 
        message = 'Summer heat affects some species.',
        fishBonus = { 'mahi_mahi', 'red_snapper', 'grouper', 'barracuda' }
    },
    autumn = { 
        message = 'Migration season!',
        fishBonus = { 'salmon', 'haddock', 'cod' }
    },
    winter = { 
        message = 'Winter requires patience.',
        fishBonus = { 'haddock', 'cod', 'sea_bass' }
    }
}

-- Fish Data (organized by rarity)
Config.fish = {
    -- Common Fish (easy to catch, low value)
    anchovy = { price = {25, 50}, chance = 35, skillcheck = {'easy', 'medium'}, rarity = 'common' },
    sardine = { price = {20, 40}, chance = 40, skillcheck = {'easy'}, rarity = 'common' },
    mackerel = { price = {30, 60}, chance = 30, skillcheck = {'easy', 'medium'}, rarity = 'common' },
    trout = { price = {50, 100}, chance = 35, skillcheck = {'easy', 'medium'}, rarity = 'common' },
    bass = { price = {60, 120}, chance = 25, skillcheck = {'easy', 'medium'}, rarity = 'common' },
    
    -- Uncommon Fish
    haddock = { price = {150, 200}, chance = 20, skillcheck = {'easy', 'medium'}, rarity = 'uncommon' },
    cod = { price = {120, 180}, chance = 22, skillcheck = {'easy', 'medium'}, rarity = 'uncommon' },
    salmon = { price = {200, 250}, chance = 15, skillcheck = {'easy', 'medium', 'medium'}, rarity = 'uncommon' },
    sea_bass = { price = {180, 240}, chance = 18, skillcheck = {'easy', 'medium', 'medium'}, rarity = 'uncommon' },
    
    -- Rare Fish
    grouper = { price = {300, 350}, chance = 12, skillcheck = {'easy', 'medium', 'medium', 'medium'}, rarity = 'rare' },
    snook = { price = {280, 340}, chance = 14, skillcheck = {'easy', 'medium', 'medium'}, rarity = 'rare' },
    piranha = { price = {350, 450}, chance = 10, skillcheck = {'easy', 'medium', 'hard'}, rarity = 'rare' },
    red_snapper = { price = {400, 450}, chance = 8, skillcheck = {'easy', 'medium', 'medium', 'medium'}, rarity = 'rare' },
    barracuda = { price = {420, 480}, chance = 7, skillcheck = {'easy', 'medium', 'hard'}, rarity = 'rare' },
    
    -- Epic Fish
    mahi_mahi = { price = {450, 500}, chance = 6, skillcheck = {'easy', 'medium', 'medium', 'medium'}, rarity = 'epic' },
    yellowfin_tuna = { price = {800, 1000}, chance = 4, skillcheck = {'easy', 'medium', 'hard', 'hard'}, rarity = 'epic' },
    swordfish = { price = {900, 1200}, chance = 3, skillcheck = {'medium', 'hard', 'hard'}, rarity = 'epic' },
    tuna = { price = {1250, 1500}, chance = 3, skillcheck = {'easy', 'medium', 'hard'}, rarity = 'epic' },
    
    -- Legendary Fish
    blue_marlin = { price = {2000, 2500}, chance = 1, skillcheck = {'medium', 'hard', 'hard', 'hard'}, rarity = 'legendary' },
    shark = { price = {2250, 2750}, chance = 1, skillcheck = {'easy', 'medium', 'hard'}, rarity = 'legendary' },
    giant_squid = { price = {3000, 4000}, chance = 0.5, skillcheck = {'hard', 'hard', 'hard', 'hard'}, rarity = 'legendary' },
    
    -- Mythical Fish
    kraken_tentacle = { price = {5000, 7500}, chance = 0.1, skillcheck = {'hard', 'hard', 'hard', 'hard', 'hard'}, rarity = 'mythical' }
}

-- Equipment (sorted by tier)
Config.fishingRods = {
    { name = 'basic_rod', price = 1000, minLevel = 1, breakChance = 20 },
    { name = 'graphite_rod', price = 2500, minLevel = 2, breakChance = 10 },
    { name = 'titanium_rod', price = 5000, minLevel = 3, breakChance = 1 },
    { name = 'carbon_fiber_rod', price = 10000, minLevel = 4, breakChance = 0.5 },
    { name = 'legendary_rod', price = 25000, minLevel = 5, breakChance = 0.1 }
}

Config.baits = {
    { name = 'worms', price = 5, minLevel = 1, waitDivisor = 1.0 },
    { name = 'artificial_bait', price = 50, minLevel = 2, waitDivisor = 3.0 },
    { name = 'premium_lure', price = 150, minLevel = 3, waitDivisor = 4.0 },
    { name = 'legendary_lure', price = 500, minLevel = 4, waitDivisor = 5.0 },
    { name = 'mythical_bait', price = 2000, minLevel = 5, waitDivisor = 6.0 }
}

-- Fishing Zones (essential data only)
Config.fishingZones = {
    {
        blip = { name = 'Shallow Waters', sprite = 317, color = 42, scale = 0.6 },
        locations = { vector3(-1200.0, -1500.0, 0.0), vector3(1200.0, -2800.0, 0.0) },
        radius = 150.0,
        minLevel = 1,
        waitTime = { min = 3, max = 8 },
        includeOutside = true,
        message = { enter = 'Entered shallow waters - perfect for beginners.', exit = 'Left shallow waters.' },
        fishList = { 'anchovy', 'sardine', 'mackerel', 'trout', 'bass' },
        rarityMultiplier = { common = 1.2, uncommon = 0.8 }
    },
    {
        blip = { name = 'Coral Reef', sprite = 317, color = 24, scale = 0.6 },
        locations = { vector3(-1774.0654, -1796.2740, 0.0), vector3(2482.8589, -2575.6780, 0.0) },
        radius = 250.0,
        minLevel = 2,
        waitTime = { min = 5, max = 10 },
        includeOutside = true,
        message = { enter = 'Entered vibrant coral reef.', exit = 'Left coral reef.' },
        fishList = { 'mahi_mahi', 'red_snapper', 'grouper', 'barracuda', 'snook' },
        rarityMultiplier = { uncommon = 1.2, rare = 1.1 }
    },
    {
        blip = { name = 'Deep Waters', sprite = 317, color = 29, scale = 0.6 },
        locations = { vector3(-4941.7964, -2411.9146, 0.0) },
        radius = 1000.0,
        minLevel = 4,
        waitTime = { min = 20, max = 40 },
        includeOutside = false,
        message = { enter = 'Entered deep waters - danger and treasure await.', exit = 'Left deep waters.' },
        fishList = { 'tuna', 'yellowfin_tuna', 'swordfish', 'shark', 'blue_marlin' },
        rarityMultiplier = { epic = 1.3, legendary = 1.2 }
    },
    {
        blip = { name = 'Abyssal Depths', sprite = 317, color = 1, scale = 0.7 },
        locations = { vector3(-6000.0, -6000.0, 0.0) },
        radius = 500.0,
        minLevel = 6,
        waitTime = { min = 45, max = 90 },
        includeOutside = false,
        message = { enter = 'Entered abyssal depths - ancient creatures dwell here.', exit = 'Left abyssal depths.' },
        fishList = { 'giant_squid', 'kraken_tentacle' },
        rarityMultiplier = { legendary = 1.5, mythical = 2.0 }
    }
}

-- Open water fishing (fallback)
Config.outside = {
    waitTime = { min = 10, max = 25 },
    fishList = { 'trout', 'anchovy', 'haddock', 'salmon', 'sardine', 'mackerel', 'bass', 'cod', 'sea_bass' }
}

-- NPC Locations
Config.ped = {
    model = `s_m_m_cntrybar_01`,
    buyAccount = 'money',
    sellAccount = 'money',
    blip = { name = 'SeaTrade Corporation', sprite = 356, color = 74, scale = 0.75 },
    locations = {
        vector4(-2081.3831, 2614.3223, 3.0840, 112.7910),
        vector4(-1492.3639, -939.2579, 10.2140, 144.0305)
    }
}

-- Boat Rental System
Config.renting = {
    model = `s_m_m_dockwork_01`,
    account = 'money',
    boats = {
        { model = `seashark`, price = 300, image = 'https://i.postimg.cc/mDSqWj4P/164px-Speeder.webp' },
        { model = `speeder`, price = 500, image = 'https://i.postimg.cc/mDSqWj4P/164px-Speeder.webp' },
        { model = `dinghy`, price = 750, image = 'https://i.postimg.cc/ZKzjZgj0/164px-Dinghy2.webp' },
        { model = `tug`, price = 1250, image = 'https://i.postimg.cc/jq7vpKHG/164px-Tug.webp' },
        { model = `marquis`, price = 2000, image = 'https://i.postimg.cc/mDSqWj4P/164px-Speeder.webp' }
    },
    blip = { name = 'Boat Rental', sprite = 410, color = 74, scale = 0.75 },
    returnDivider = 5,
    returnRadius = 30.0,
    locations = {
        { coords = vector4(-1434.4818, -1512.2745, 2.1486, 25.8666), spawn = vector4(-1494.4496, -1537.6943, 2.3942, 115.6015) }
    }
}