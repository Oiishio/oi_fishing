-- shared/utils.lua
-- Optimized shared utility functions

-- Make it global so all files can access it
FishingUtils = {}

-- Cache for frequently accessed data
local cache = {
    itemLabels = {},
    tableSize = {},
    lastUpdate = 0
}

-- Fast table size calculation with caching
function FishingUtils.getTableSize(t)
    if not t then return 0 end
    
    local key = tostring(t)
    if cache.tableSize[key] then
        return cache.tableSize[key]
    end
    
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    
    cache.tableSize[key] = count
    return count
end

-- Optimized random selection from table
function FishingUtils.randomFromTable(t)
    if not t or #t == 0 then return nil, nil end
    local index = math.random(1, #t)
    return t[index], index
end

-- Weighted random selection (for fish catching)
function FishingUtils.weightedRandom(items)
    local totalWeight = 0
    local weights = {}
    
    for item, weight in pairs(items) do
        totalWeight = totalWeight + weight
        weights[item] = totalWeight
    end
    
    if totalWeight == 0 then return nil end
    
    local rand = math.random() * totalWeight
    for item, weight in pairs(weights) do
        if rand <= weight then
            return item
        end
    end
    
    return next(items) -- Fallback
end

-- Efficient distance calculation (no sqrt for comparisons)
function FishingUtils.distanceSquared(pos1, pos2)
    local dx = pos1.x - pos2.x
    local dy = pos1.y - pos2.y
    local dz = pos1.z - pos2.z
    return dx*dx + dy*dy + dz*dz
end

function FishingUtils.distance(pos1, pos2)
    return math.sqrt(FishingUtils.distanceSquared(pos1, pos2))
end

-- Optimized item label lookup with caching
function FishingUtils.getItemLabel(name)
    if not name then return 'Unknown' end
    
    -- Check cache first
    if cache.itemLabels[name] then
        return cache.itemLabels[name]
    end
    
    -- Get from framework and cache result
    local label
    if IsDuplicityVersion() then -- Server side
        label = Framework and Framework.getItemLabel and Framework.getItemLabel(name) or name
    else -- Client side  
        if exports.ox_inventory then
            label = exports.ox_inventory:Items()[name]?.label or name
        else
            label = name
        end
    end
    
    cache.itemLabels[name] = label or name
    return cache.itemLabels[name]
end

-- Format price range consistently
function FishingUtils.formatPrice(price)
    if type(price) == 'number' then
        return ('€%d'):format(price)
    elseif type(price) == 'table' and price.min and price.max then
        return ('€%d - €%d'):format(price.min, price.max)
    end
    return '€0'
end

-- Get average price for calculations
function FishingUtils.getAveragePrice(price)
    if type(price) == 'number' then
        return price
    elseif type(price) == 'table' and price.min and price.max then
        return (price.min + price.max) / 2
    end
    return 0
end

-- Clamp value between min and max
function FishingUtils.clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

-- Round to decimal places
function FishingUtils.round(value, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(value * mult + 0.5) / mult
end

-- Check if table contains value
function FishingUtils.tableContains(t, value)
    if not t then return false end
    for _, v in pairs(t) do
        if v == value then return true end
    end
    return false
end

-- Deep copy table (for config modifications)
function FishingUtils.deepCopy(t)
    if type(t) ~= 'table' then return t end
    
    local result = {}
    for k, v in pairs(t) do
        result[k] = FishingUtils.deepCopy(v)
    end
    return result
end

-- Merge two tables (second overrides first)
function FishingUtils.mergeTables(t1, t2)
    if not t1 then return FishingUtils.deepCopy(t2) end
    if not t2 then return FishingUtils.deepCopy(t1) end
    
    local result = FishingUtils.deepCopy(t1)
    for k, v in pairs(t2) do
        result[k] = v
    end
    return result
end

-- Get time period from hour
function FishingUtils.getTimePeriod(hour)
    if hour >= 5 and hour <= 7 then return FishingConstants.TIME_PERIODS.DAWN
    elseif hour >= 8 and hour <= 11 then return FishingConstants.TIME_PERIODS.MORNING
    elseif hour >= 12 and hour <= 14 then return FishingConstants.TIME_PERIODS.NOON
    elseif hour >= 15 and hour <= 17 then return FishingConstants.TIME_PERIODS.AFTERNOON
    elseif hour >= 18 and hour <= 20 then return FishingConstants.TIME_PERIODS.DUSK
    elseif hour >= 21 or hour <= 4 then return FishingConstants.TIME_PERIODS.NIGHT
    else return FishingConstants.TIME_PERIODS.DAY end
end

-- Get season from month
function FishingUtils.getSeason(month)
    if not month then month = IsDuplicityVersion() and tonumber(os.date('%m')) or GetClockMonth() end
    
    if month >= 3 and month <= 5 then return FishingConstants.SEASONS.SPRING
    elseif month >= 6 and month <= 8 then return FishingConstants.SEASONS.SUMMER
    elseif month >= 9 and month <= 11 then return FishingConstants.SEASONS.AUTUMN
    else return FishingConstants.SEASONS.WINTER end
end

-- Clear cache (call when items are added/removed)
function FishingUtils.clearCache()
    cache.itemLabels = {}
    cache.tableSize = {}
    cache.lastUpdate = GetGameTimer and GetGameTimer() or os.time()
end

-- Batch operation helper
function FishingUtils.batch(items, batchSize, fn)
    batchSize = batchSize or 10
    local batches = {}
    
    for i = 1, #items, batchSize do
        local batch = {}
        for j = i, math.min(i + batchSize - 1, #items) do
            table.insert(batch, items[j])
        end
        table.insert(batches, batch)
    end
    
    for _, batch in ipairs(batches) do
        fn(batch)
    end
end

-- Simple debounce function
function FishingUtils.debounce(fn, delay)
    local timer = nil
    return function(...)
        local args = {...}
        if timer then
            ClearTimeout(timer)
        end
        timer = SetTimeout(function()
            fn(table.unpack(args))
            timer = nil
        end, delay)
    end
end

-- Throttle function calls
function FishingUtils.throttle(fn, delay)
    local last = 0
    return function(...)
        local now = GetGameTimer and GetGameTimer() or os.clock() * 1000
        if now - last >= delay then
            last = now
            return fn(...)
        end
    end
end

-- Also create Utils alias for compatibility
Utils = FishingUtils

return FishingUtils