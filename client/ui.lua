-- client/ui.lua (Fixed - Safe Constants Access)
-- Optimized UI and notification system with heavy spam prevention

local UI = {}

-- Safe constants with fallbacks
local NOTIFICATION_PRIORITY = {
    LOW = 1,
    NORMAL = 2,
    HIGH = 3,
    CRITICAL = 4
}

local RARITY_EMOJIS = {
    common = '🐟',
    uncommon = '🐠',
    rare = '🌟', 
    epic = '💎',
    legendary = '👑',
    mythical = '🔮'
}

-- Initialize constants once they're available
CreateThread(function()
    Wait(1000) -- Wait for shared scripts to load
    
    if FishingConstants then
        if FishingConstants.NOTIFICATION_PRIORITY then
            NOTIFICATION_PRIORITY = FishingConstants.NOTIFICATION_PRIORITY
        end
        if FishingConstants.RARITY_EMOJIS then
            RARITY_EMOJIS = FishingConstants.RARITY_EMOJIS
        end
    end
end)

-- Notification queue system with aggressive spam protection
local notificationQueue = {}
local lastNotification = 0
local processingQueue = false
local notificationHistory = {} -- Track recent notifications to prevent duplicates

-- UI state
local currentUI = {
    shown = false,
    type = nil,
    data = nil
}

-- Spam prevention settings
local SPAM_PREVENTION = {
    MIN_INTERVAL = 3000,           -- Minimum 3 seconds between notifications
    DUPLICATE_TIMEOUT = 30000,     -- 30 seconds before allowing same message again
    MAX_QUEUE_SIZE = 5,            -- Reduce queue size
    STARTUP_DELAY = 10000          -- 10 second delay before showing any notifications
}

local systemStartTime = GetGameTimer()

-- Initialize UI system
function UI.init()
    -- Process notification queue with spam protection
    CreateThread(function()
        while true do
            UI.processNotificationQueue()
            Wait(500) -- Check every 0.5 seconds
        end
    end)
end

-- Check if we're in startup period (no notifications during startup)
local function isStartupPeriod()
    return (GetGameTimer() - systemStartTime) < SPAM_PREVENTION.STARTUP_DELAY
end

-- Check if notification is duplicate
local function isDuplicateNotification(message)
    local messageHash = tostring(message)
    local now = GetGameTimer()
    
    if notificationHistory[messageHash] then
        if now - notificationHistory[messageHash] < SPAM_PREVENTION.DUPLICATE_TIMEOUT then
            return true -- Too recent, skip
        end
    end
    
    notificationHistory[messageHash] = now
    return false
end

-- Clean old notification history
local function cleanNotificationHistory()
    local now = GetGameTimer()
    for message, timestamp in pairs(notificationHistory) do
        if now - timestamp > SPAM_PREVENTION.DUPLICATE_TIMEOUT then
            notificationHistory[message] = nil
        end
    end
end

-- Queue notification with strict spam prevention
function UI.queueNotification(message, type, priority)
    if not message or message == '' then return end
    
    -- Block all notifications during startup
    if isStartupPeriod() then return end
    
    -- Block duplicate notifications
    if isDuplicateNotification(message) then return end
    
    priority = priority or NOTIFICATION_PRIORITY.NORMAL
    type = type or 'inform'
    
    -- Only allow high priority notifications to interrupt cooldown
    local now = GetGameTimer()
    if priority < NOTIFICATION_PRIORITY.HIGH then
        if now - lastNotification < SPAM_PREVENTION.MIN_INTERVAL then
            return -- Skip low priority notifications during cooldown
        end
    end
    
    -- Check for existing similar messages in queue
    for i, notif in ipairs(notificationQueue) do
        if notif.message == message then
            -- Update priority if higher
            if priority > notif.priority then
                notif.priority = priority
                notif.type = type
            end
            return
        end
    end
    
    -- Add to queue
    table.insert(notificationQueue, {
        message = message,
        type = type,
        priority = priority,
        timestamp = now
    })
    
    -- Sort by priority (higher first)
    table.sort(notificationQueue, function(a, b)
        if a.priority == b.priority then
            return a.timestamp < b.timestamp
        end
        return a.priority > b.priority
    end)
    
    -- Strict queue size limit
    while #notificationQueue > SPAM_PREVENTION.MAX_QUEUE_SIZE do
        table.remove(notificationQueue, #notificationQueue)
    end
    
    -- Clean old history periodically
    if now % 60000 < 500 then -- Approximately once per minute
        cleanNotificationHistory()
    end
end

-- Process notification queue with strict timing
function UI.processNotificationQueue()
    if #notificationQueue == 0 or processingQueue then return end
    
    local now = GetGameTimer()
    local timeSinceLastNotification = now - lastNotification
    
    -- Enforce minimum interval between notifications
    if timeSinceLastNotification < SPAM_PREVENTION.MIN_INTERVAL then return end
    
    -- Block during startup
    if isStartupPeriod() then return end
    
    processingQueue = true
    local notif = table.remove(notificationQueue, 1)
    
    if notif then
        -- Double check for duplicates (safety)
        if not isDuplicateNotification(notif.message) then
            UI.showNotification(notif.message, notif.type)
            lastNotification = now
        end
    end
    
    processingQueue = false
end

-- Show notification (wrapper around framework function)
function UI.showNotification(message, type)
    if ShowNotification then
        ShowNotification(message, type or 'inform')
    else
        -- Fallback
        lib.notify({
            description = message,
            type = type or 'inform',
            position = 'top-right'
        })
    end
end

-- Show UI text with icon
function UI.showText(text, icon)
    if currentUI.shown then return end
    
    currentUI.shown = true
    currentUI.type = 'text'
    currentUI.data = { text = text, icon = icon }
    
    if ShowUI then
        ShowUI(text, icon)
    else
        lib.showTextUI(text, icon and { icon = icon } or nil)
    end
end

-- Hide UI text
function UI.hideText()
    if not currentUI.shown or currentUI.type ~= 'text' then return end
    
    currentUI.shown = false
    currentUI.type = nil
    currentUI.data = nil
    
    if HideUI then
        HideUI()
    else
        lib.hideTextUI()
    end
end

-- Show progress bar
function UI.showProgress(label, duration, canCancel, anim, prop)
    if ShowProgressBar then
        return ShowProgressBar(label, duration, canCancel, anim, prop)
    else
        return lib.progressBar({
            duration = duration,
            label = label,
            useWhileDead = false,
            canCancel = canCancel or false,
            disable = {
                car = true,
                move = true,
                combat = true
            },
            anim = anim,
            prop = prop
        })
    end
end

-- Show context menu (optimized)
function UI.showContext(id, title, options, onBack)
    -- Filter out empty or invalid options
    local validOptions = {}
    for _, option in ipairs(options or {}) do
        if option and option.title then
            table.insert(validOptions, option)
        end
    end
    
    if #validOptions == 0 then
        UI.queueNotification('Nav pieejamas opcijas', 'error')
        return
    end
    
    lib.registerContext({
        id = id,
        title = title,
        menu = onBack,
        options = validOptions
    })
    
    lib.showContext(id)
end

-- Show input dialog
function UI.showInput(title, inputs)
    return lib.inputDialog(title, inputs)
end

-- Show alert dialog
function UI.showAlert(title, content, confirm, cancel)
    return lib.alertDialog({
        header = title,
        content = content,
        centered = true,
        cancel = cancel ~= false
    }) == 'confirm'
end

-- Enhanced fish caught notification (reduced spam)
function UI.notifyFishCaught(fishName, fishData, value)
    if not fishData then return end
    
    local emoji = RARITY_EMOJIS[fishData.rarity] or '🐟'
    local fishLabel = FishingUtils and FishingUtils.getItemLabel and FishingUtils.getItemLabel(fishName) or fishName
    
    -- Different messages based on rarity (only for rare+ fish)
    local message
    local priority = NOTIFICATION_PRIORITY.NORMAL
    local type = 'success'
    
    if fishData.rarity == 'mythical' then
        message = ('🔮 MITINIS LAIMIKIS: %s! Pranoksta legendą!'):format(fishLabel)
        priority = NOTIFICATION_PRIORITY.CRITICAL
        type = 'success'
    elseif fishData.rarity == 'legendary' then
        message = ('👑 LEGENDINIS LAIMIKIS: %s! Meistras žvejas!'):format(fishLabel)
        priority = NOTIFICATION_PRIORITY.HIGH
        type = 'success'
    elseif fishData.rarity == 'epic' then
        message = ('💎 EPIŠKAS LAIMIKIS: %s! Neįtikėtinas sėkmingumas!'):format(fishLabel)
        priority = NOTIFICATION_PRIORITY.HIGH
        type = 'success'
    elseif fishData.rarity == 'rare' then
        message = ('🌟 RETAS LAIMIKIS: %s!'):format(fishLabel)
        priority = NOTIFICATION_PRIORITY.NORMAL
        type = 'success'
    else
        -- Don't show notifications for common/uncommon fish to reduce spam
        return
    end
    
    UI.queueNotification(message, type, priority)
    
    -- Play sound based on rarity
    UI.playFishSound(fishData.rarity)
end

-- Play sound effects (only for rare+ catches)
function UI.playFishSound(rarity)
    local soundData = {
        mythical = { name = 'CHECKPOINT_PERFECT', set = 'HUD_MINI_GAME_SOUNDSET' },
        legendary = { name = 'CHECKPOINT_PERFECT', set = 'HUD_MINI_GAME_SOUNDSET' },
        epic = { name = 'CHECKPOINT_NORMAL', set = 'HUD_MINI_GAME_SOUNDSET' },
        rare = { name = 'WAYPOINT_SET', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' }
    }
    
    local sound = soundData[rarity]
    if sound then
        PlaySoundFrontend(-1, sound.name, sound.set, true)
    end
end

-- Create standardized fishing menu
function UI.createFishingMenu(menuId, title, sections)
    local options = {}
    
    for _, section in ipairs(sections) do
        if section.header then
            table.insert(options, {
                title = section.header,
                description = section.description,
                disabled = true,
                icon = section.icon
            })
        end
        
        for _, item in ipairs(section.items or {}) do
            table.insert(options, item)
        end
    end
    
    UI.showContext(menuId, title, options)
end

-- Standardized equipment display
function UI.formatEquipment(item, playerLevel, isOwned)
    local status = isOwned and '✅ TURIU' or 
                  (item.minLevel > playerLevel and '🔒 UŽRAKINTA' or '✅ PRIEINAMA')
    
    local metadata = {
        { label = 'Reikalingas lygis', value = item.minLevel },
        { label = 'Būsena', value = status }
    }
    
    -- Add specific metadata based on item type
    if item.breakChance then
        table.insert(metadata, { label = 'Lūžimo šansas', value = item.breakChance .. '%' })
    end
    
    if item.waitDivisor then
        local speedBonus = math.floor((1 - 1/item.waitDivisor) * 100)
        table.insert(metadata, { label = 'Greičio bonusas', value = speedBonus .. '%' })
    end
    
    local fishLabel = FishingUtils and FishingUtils.getItemLabel and FishingUtils.getItemLabel(item.name) or item.name
    local priceText = FishingUtils and FishingUtils.formatPrice and FishingUtils.formatPrice(item.price) or ('€%d'):format(item.price)
    
    return {
        title = fishLabel,
        description = 'Kaina: ' .. priceText,
        image = GetInventoryIcon and GetInventoryIcon(item.name) or nil,
        disabled = item.minLevel > playerLevel,
        metadata = metadata
    }
end

-- Show environment status (simplified)
function UI.showEnvironmentStatus()
    if not FishingEnvironment then return end
    
    local env = FishingEnvironment.getInfo()
    local info = {}
    
    table.insert(info, ('🌤️ Oras: %s'):format(env.weather))
    table.insert(info, ('⏰ Laikas: %02d:%02d (%s)'):format(env.hour, env.minute, env.timePeriod:upper()))
    
    -- Only show significant bonuses/penalties
    local effects = env.effects
    if effects.chanceMultiplier > 1.1 then
        table.insert(info, ('📈 Bonusas: +%d%% gaudymo šansas'):format(math.floor((effects.chanceMultiplier - 1) * 100)))
    elseif effects.chanceMultiplier < 0.9 then
        table.insert(info, ('📉 Nuobauda: -%d%% gaudymo šansas'):format(math.floor((1 - effects.chanceMultiplier) * 100)))
    end
    
    UI.queueNotification(table.concat(info, '\n'), 'inform', NOTIFICATION_PRIORITY.NORMAL)
end

-- Clear notification queue
function UI.clearQueue()
    notificationQueue = {}
    notificationHistory = {}
end

-- Get queue status (for debugging)
function UI.getQueueStatus()
    return {
        count = #notificationQueue,
        nextNotification = notificationQueue[1] and notificationQueue[1].message or 'None',
        lastShown = lastNotification,
        startupPeriod = isStartupPeriod()
    }
end

-- Silent notification for level ups only (special case)
function UI.silentLevelNotification(level)
    -- Only show level notifications, nothing else during startup
    if not isStartupPeriod() then
        UI.queueNotification(
            ('🎉 Pasiekėte %d lygį!'):format(level),
            'success',
            NOTIFICATION_PRIORITY.HIGH
        )
    end
end

-- Initialize once the script loads
CreateThread(function()
    Wait(1000)
    UI.init()
end)

-- Export
_G.FishingUI = UI
return UI