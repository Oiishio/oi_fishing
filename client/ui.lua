-- client/ui.lua
-- Optimized UI and notification system

local UI = {}

-- Notification queue system to prevent spam
local notificationQueue = {}
local lastNotification = 0
local processingQueue = false

-- UI state
local currentUI = {
    shown = false,
    type = nil,
    data = nil
}

-- Initialize UI system
function UI.init()
    -- Process notification queue
    CreateThread(function()
        while true do
            UI.processNotificationQueue()
            Wait(100) -- Check 10 times per second
        end
    end)
end

-- Queue notification with priority and deduplication
function UI.queueNotification(message, type, priority)
    if not message or message == '' then return end
    
    priority = priority or FishingConstants.NOTIFICATION_PRIORITY.NORMAL
    type = type or 'inform'
    
    -- Check for duplicate messages
    for _, notif in ipairs(notificationQueue) do
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
        timestamp = GetGameTimer()
    })
    
    -- Sort by priority (higher first)
    table.sort(notificationQueue, function(a, b)
        if a.priority == b.priority then
            return a.timestamp < b.timestamp
        end
        return a.priority > b.priority
    end)
    
    -- Limit queue size
    while #notificationQueue > 10 do
        table.remove(notificationQueue, #notificationQueue)
    end
end

-- Process notification queue
function UI.processNotificationQueue()
    if #notificationQueue == 0 or processingQueue then return end
    
    local now = GetGameTimer()
    if now - lastNotification < FishingConstants.INTERVALS.NOTIFICATION_COOLDOWN then return end
    
    processingQueue = true
    local notif = table.remove(notificationQueue, 1)
    
    if notif then
        UI.showNotification(notif.message, notif.type)
        lastNotification = now
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
        UI.queueNotification('No options available', 'error')
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

-- Enhanced fish caught notification
function UI.notifyFishCaught(fishName, fishData, value)
    if not fishData then return end
    
    local emoji = FishingConstants.RARITY_EMOJIS[fishData.rarity] or '🐟'
    local fishLabel = FishingUtils.getItemLabel(fishName)
    
    -- Different messages based on rarity
    local message
    local priority = FishingConstants.NOTIFICATION_PRIORITY.NORMAL
    local type = 'success'
    
    if fishData.rarity == 'mythical' then
        message = ('🔮 MYTHICAL CATCH: %s! Beyond legendary!'):format(fishLabel)
        priority = FishingConstants.NOTIFICATION_PRIORITY.CRITICAL
        type = 'success'
    elseif fishData.rarity == 'legendary' then
        message = ('👑 LEGENDARY CATCH: %s! Master angler!'):format(fishLabel)
        priority = FishingConstants.NOTIFICATION_PRIORITY.HIGH
        type = 'success'
    elseif fishData.rarity == 'epic' then
        message = ('💎 EPIC CATCH: %s! Incredible luck!'):format(fishLabel)
        priority = FishingConstants.NOTIFICATION_PRIORITY.HIGH
        type = 'success'
    elseif fishData.rarity == 'rare' then
        message = ('🌟 RARE CATCH: %s! Great find!'):format(fishLabel)
        priority = FishingConstants.NOTIFICATION_PRIORITY.NORMAL
        type = 'success'
    else
        message = ('%s Caught %s (%s)'):format(emoji, fishLabel, FishingUtils.formatPrice(value))
        priority = FishingConstants.NOTIFICATION_PRIORITY.LOW
        type = 'success'
    end
    
    UI.queueNotification(message, type, priority)
    
    -- Play sound based on rarity
    UI.playFishSound(fishData.rarity)
end

-- Play sound effects
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
    local status = isOwned and '✅ OWNED' or 
                  (item.minLevel > playerLevel and '🔒 LOCKED' or '✅ AVAILABLE')
    
    local metadata = {
        { label = 'Required Level', value = item.minLevel },
        { label = 'Status', value = status }
    }
    
    -- Add specific metadata based on item type
    if item.breakChance then
        table.insert(metadata, { label = 'Break Chance', value = item.breakChance .. '%' })
    end
    
    if item.waitDivisor then
        local speedBonus = math.floor((1 - 1/item.waitDivisor) * 100)
        table.insert(metadata, { label = 'Speed Bonus', value = speedBonus .. '%' })
    end
    
    return {
        title = FishingUtils.getItemLabel(item.name),
        description = 'Price: ' .. FishingUtils.formatPrice(item.price),
        image = GetInventoryIcon and GetInventoryIcon(item.name) or nil,
        disabled = item.minLevel > playerLevel,
        metadata = metadata
    }
end

-- Show environment status
function UI.showEnvironmentStatus()
    local env = FishingEnvironment.getInfo()
    local info = {}
    
    table.insert(info, ('🌤️ Weather: %s'):format(env.weather))
    table.insert(info, ('⏰ Time: %02d:%02d (%s)'):format(env.hour, env.minute, env.timePeriod:upper()))
    table.insert(info, ('🍂 Season: %s'):format(env.season:upper()))
    
    -- Add effect summary
    local effects = env.effects
    local bonuses = {}
    
    if effects.chanceMultiplier > 1.1 then
        table.insert(bonuses, ('+%d%% catch'):format(math.floor((effects.chanceMultiplier - 1) * 100)))
    elseif effects.chanceMultiplier < 0.9 then
        table.insert(bonuses, ('-%d%% catch'):format(math.floor((1 - effects.chanceMultiplier) * 100)))
    end
    
    if effects.waitMultiplier < 0.9 then
        table.insert(bonuses, ('+%d%% speed'):format(math.floor((1 - effects.waitMultiplier) * 100)))
    elseif effects.waitMultiplier > 1.1 then
        table.insert(bonuses, ('-%d%% speed'):format(math.floor((effects.waitMultiplier - 1) * 100)))
    end
    
    if #bonuses > 0 then
        table.insert(info, ('📈 Effects: %s'):format(table.concat(bonuses, ', ')))
    end
    
    UI.queueNotification(table.concat(info, '\n'), 'inform', FishingConstants.NOTIFICATION_PRIORITY.NORMAL)
end

-- Batch notification for multiple events
function UI.batchNotify(notifications, delay)
    delay = delay or 1000
    
    for i, notif in ipairs(notifications) do
        SetTimeout(i * delay, function()
            UI.queueNotification(notif.message, notif.type, notif.priority)
        end)
    end
end

-- Clear notification queue
function UI.clearQueue()
    notificationQueue = {}
end

-- Get queue status (for debugging)
function UI.getQueueStatus()
    return {
        count = #notificationQueue,
        nextNotification = notificationQueue[1] and notificationQueue[1].message or 'None',
        lastShown = lastNotification
    }
end

-- Export
_G.FishingUI = UI
return UI