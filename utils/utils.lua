-- utils/utils.lua
-- Complete client-side utility functions for creating peds, blips, etc.

Utils = Utils or {}

-- Cache for spawned entities
local spawnedPeds = {}
local spawnedBlips = {}
local activeInteractions = {}

-- Create PED with interactions
function Utils.createPed(coords, model, interactions, options)
    options = options or {}
    
    -- Request model
    lib.requestModel(model)
    
    -- Create the ped
    local ped = CreatePed(4, model, coords.x, coords.y, coords.z - 1.0, coords.w or 0.0, false, true)
    
    -- Set ped properties
    SetEntityAsMissionEntity(ped, true, true)
    SetPedFleeAttributes(ped, 0, 0)
    SetPedDiesWhenInjured(ped, false)
    SetPedKeepTask(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    
    -- Make ped look natural
    TaskSetBlockingOfNonTemporaryEvents(ped, true)
    
    -- Add some random animations to make NPCs look more alive
    if options.useRandomAnims then
        CreateThread(function()
            local anims = {
                { dict = 'amb@world_human_smoking@male@male_a@idle_a', clip = 'idle_a' },
                { dict = 'amb@world_human_hang_out_street@female_arms_crossed@idle_a', clip = 'idle_a' },
                { dict = 'amb@world_human_stand_impatient@male@idle_a', clip = 'idle_a' }
            }
            
            while DoesEntityExist(ped) do
                Wait(math.random(30000, 60000)) -- Wait 30-60 seconds
                
                local anim = anims[math.random(#anims)]
                if lib.requestAnimDict(anim.dict) then
                    TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, 8.0, -1, 1, 0, false, false, false)
                end
            end
        end)
    end
    
    -- Set up targeting if interactions are provided
    if interactions and #interactions > 0 then
        -- Check if ox_target is available
        if GetResourceState('ox_target') == 'started' then
            exports.ox_target:addLocalEntity(ped, interactions)
        elseif GetResourceState('qb-target') == 'started' then
            exports['qb-target']:AddTargetEntity(ped, {
                options = interactions,
                distance = 2.5
            })
        elseif GetResourceState('qtarget') == 'started' then
            exports.qtarget:AddTargetEntity(ped, {
                options = interactions,
                distance = 2.5
            })
        else
            -- Fallback: Use built-in interaction system
            local interactionId = #activeInteractions + 1
            activeInteractions[interactionId] = {
                ped = ped,
                interactions = interactions,
                active = false
            }
            
            CreateThread(function()
                local interaction = activeInteractions[interactionId]
                
                while DoesEntityExist(ped) and interaction do
                    -- Check if player exists first
                    if not cache.ped then
                        Wait(100)
                    else
                        local playerCoords = GetEntityCoords(cache.ped)
                        local pedCoords = GetEntityCoords(ped)
                        local distance = #(playerCoords - pedCoords)
                        
                        if distance < 2.5 then
                            if not interaction.active then
                                interaction.active = true
                                
                                -- Show interaction prompt
                                if interactions[1] then
                                    local label = interactions[1].label or 'Interact'
                                    local icon = interactions[1].icon or 'user'
                                    
                                    if ShowUI then
                                        ShowUI('[E] - ' .. label, icon)
                                    else
                                        lib.showTextUI('[E] - ' .. label, { icon = icon })
                                    end
                                end
                            end
                            
                            -- Check for E key press
                            if IsControlJustPressed(0, 38) then -- E key
                                if interaction.active then
                                    interaction.active = false
                                    
                                    if HideUI then
                                        HideUI()
                                    else
                                        lib.hideTextUI()
                                    end
                                    
                                    if interactions[1] and interactions[1].onSelect then
                                        interactions[1].onSelect()
                                    end
                                end
                            end
                        else
                            if interaction.active then
                                interaction.active = false
                                
                                if HideUI then
                                    HideUI()
                                else
                                    lib.hideTextUI()
                                end
                            end
                        end
                    end
                    
                    Wait(0)
                end
                
                -- Clean up interaction when ped is deleted
                activeInteractions[interactionId] = nil
            end)
        end
    end
    
    -- Store reference
    table.insert(spawnedPeds, ped)
    
    -- Set model as no longer needed
    SetModelAsNoLongerNeeded(model)
    
    return ped
end

-- Create blip with enhanced options
function Utils.createBlip(coords, blipData)
    if not blipData then return end
    
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    
    -- Set blip properties
    if blipData.sprite then SetBlipSprite(blip, blipData.sprite) end
    if blipData.color then SetBlipColour(blip, blipData.color) end
    if blipData.scale then SetBlipScale(blip, blipData.scale) end
    
    SetBlipDisplay(blip, 4)
    SetBlipAsShortRange(blip, true)
    
    -- Set blip name
    if blipData.name then
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(blipData.name)
        EndTextCommandSetBlipName(blip)
    end
    
    -- Set additional properties
    if blipData.alpha then SetBlipAlpha(blip, blipData.alpha) end
    if blipData.category then SetBlipCategory(blip, blipData.category) end
    
    -- Store reference
    table.insert(spawnedBlips, blip)
    
    return blip
end

-- Create radius blip (for zones)
function Utils.createRadiusBlip(coords, radius, blipData)
    if not blipData then return end
    
    local blip = AddBlipForRadius(coords.x, coords.y, coords.z, radius)
    
    if blipData.color then SetBlipColour(blip, blipData.color) end
    if blipData.alpha then SetBlipAlpha(blip, blipData.alpha) end
    
    SetBlipDisplay(blip, 4)
    SetBlipAsShortRange(blip, true)
    
    table.insert(spawnedBlips, blip)
    
    return blip
end

-- Draw 3D text (for debugging or special displays)
function Utils.draw3DText(coords, text, scale, font)
    scale = scale or 0.5
    font = font or 4
    
    SetTextFont(font)
    SetTextProportional(1)
    SetTextScale(0.0, scale)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry('STRING')
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

-- Show notification with enhanced options
function Utils.showNotification(message, type, duration)
    type = type or 'inform'
    duration = duration or 5000
    
    if ShowNotification then
        ShowNotification(message, type)
    else
        lib.notify({
            description = message,
            type = type,
            position = 'top-right',
            duration = duration
        })
    end
end

-- Progress bar wrapper
function Utils.progressBar(options)
    options = options or {}
    
    if ShowProgressBar then
        return ShowProgressBar(
            options.label or 'Loading...',
            options.duration or 5000,
            options.canCancel or false,
            options.anim or {},
            options.prop or {}
        )
    else
        return lib.progressBar({
            duration = options.duration or 5000,
            label = options.label or 'Loading...',
            useWhileDead = false,
            canCancel = options.canCancel or false,
            disable = options.disable or {
                car = true,
                move = true,
                combat = true
            },
            anim = options.anim,
            prop = options.prop
        })
    end
end

-- Input dialog wrapper
function Utils.inputDialog(title, inputs)
    return lib.inputDialog(title, inputs)
end

-- Alert dialog wrapper
function Utils.alertDialog(options)
    return lib.alertDialog({
        header = options.title or options.header,
        content = options.content or options.description,
        centered = options.centered or true,
        cancel = options.cancel ~= false
    }) == 'confirm'
end

-- Clean up spawned entities
function Utils.cleanup()
    -- Clean up active interactions first
    for _, interaction in pairs(activeInteractions) do
        if interaction.active then
            if HideUI then
                HideUI()
            else
                lib.hideTextUI()
            end
        end
    end
    activeInteractions = {}
    
    -- Remove peds
    for _, ped in ipairs(spawnedPeds) do
        if DoesEntityExist(ped) then
            -- Remove targeting if it exists
            if GetResourceState('ox_target') == 'started' then
                exports.ox_target:removeLocalEntity(ped)
            elseif GetResourceState('qb-target') == 'started' then
                exports['qb-target']:RemoveTargetEntity(ped)
            elseif GetResourceState('qtarget') == 'started' then
                exports.qtarget:RemoveTargetEntity(ped)
            end
            
            DeleteEntity(ped)
        end
    end
    spawnedPeds = {}
    
    -- Remove blips
    for _, blip in ipairs(spawnedBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    spawnedBlips = {}
end

-- Get item label (compatibility function)
function Utils.getItemLabel(itemName)
    if not itemName then return 'Unknown' end
    
    -- First try FishingUtils
    if FishingUtils and FishingUtils.getItemLabel then
        return FishingUtils.getItemLabel(itemName)
    end
    
    -- Framework-specific methods
    if Framework then
        if Framework.name == 'es_extended' then
            if exports.ox_inventory then
                local items = exports.ox_inventory:Items()
                return items[itemName]?.label or itemName
            elseif exports['qs-inventory'] then
                local items = exports['qs-inventory']:GetItemList()
                return items[itemName]?.label or itemName
            else
                return itemName
            end
        elseif Framework.name == 'qb-core' then
            if exports.ox_inventory then
                local items = exports.ox_inventory:Items()
                return items[itemName]?.label or itemName
            elseif exports['qb-inventory'] then
                return exports['qb-inventory']:GetItemLabel(itemName) or itemName
            elseif exports['ps-inventory'] then
                return exports['ps-inventory']:GetItemLabel(itemName) or itemName
            elseif exports['qs-inventory'] then
                local items = exports['qs-inventory']:GetItemList()
                return items[itemName]?.label or itemName
            else
                return itemName
            end
        end
    end
    
    return itemName
end

-- Format price (compatibility function)
function Utils.formatPrice(price)
    if FishingUtils and FishingUtils.formatPrice then
        return FishingUtils.formatPrice(price)
    end
    
    if type(price) == 'number' then
        return ('€%d'):format(price)
    elseif type(price) == 'table' and price.min and price.max then
        return ('€%d - €%d'):format(price.min, price.max)
    end
    return '€0'
end

-- Get average price (for calculations)
function Utils.getAveragePrice(price)
    if FishingUtils and FishingUtils.getAveragePrice then
        return FishingUtils.getAveragePrice(price)
    end
    
    if type(price) == 'number' then
        return price
    elseif type(price) == 'table' and price.min and price.max then
        return (price.min + price.max) / 2
    end
    return 0
end

-- Distance calculation
function Utils.distance(pos1, pos2)
    if FishingUtils and FishingUtils.distance then
        return FishingUtils.distance(pos1, pos2)
    end
    
    return #(pos1 - pos2)
end

-- Round number to decimal places
function Utils.round(value, decimals)
    if FishingUtils and FishingUtils.round then
        return FishingUtils.round(value, decimals)
    end
    
    local mult = 10 ^ (decimals or 0)
    return math.floor(value * mult + 0.5) / mult
end

-- Check if table contains value
function Utils.tableContains(t, value)
    if FishingUtils and FishingUtils.tableContains then
        return FishingUtils.tableContains(t, value)
    end
    
    if not t then return false end
    for _, v in pairs(t) do
        if v == value then return true end
    end
    return false
end

-- Get current time period
function Utils.getTimePeriod(hour)
    if FishingUtils and FishingUtils.getTimePeriod then
        return FishingUtils.getTimePeriod(hour)
    end
    
    -- Fallback time period calculation
    hour = hour or GetClockHours()
    if hour >= 5 and hour <= 7 then return 'dawn'
    elseif hour >= 8 and hour <= 11 then return 'morning'
    elseif hour >= 12 and hour <= 14 then return 'noon'
    elseif hour >= 15 and hour <= 17 then return 'afternoon'
    elseif hour >= 18 and hour <= 20 then return 'dusk'
    elseif hour >= 21 or hour <= 4 then return 'night'
    else return 'day' end
end

-- Format time display
function Utils.formatTime(hour, minute)
    return ('%02d:%02d'):format(hour or GetClockHours(), minute or GetClockMinutes())
end

-- Get entity from network ID safely
function Utils.getEntityFromNetworkId(netId)
    if not netId then return 0 end
    local entity = NetworkGetEntityFromNetworkId(netId)
    return DoesEntityExist(entity) and entity or 0
end

-- Spawn vehicle wrapper (for boat rentals, etc.)
function Utils.spawnVehicle(model, coords, heading, callback)
    if Framework and Framework.spawnVehicle then
        Framework.spawnVehicle(model, coords, heading, callback)
    else
        -- Fallback vehicle spawning
        lib.requestModel(model)
        local vehicle = CreateVehicle(model, coords.x, coords.y, coords.z, heading, true, false)
        SetModelAsNoLongerNeeded(model)
        if callback then callback(vehicle) end
        return vehicle
    end
end

-- Delete vehicle safely
function Utils.deleteVehicle(vehicle)
    if Framework and Framework.deleteVehicle then
        Framework.deleteVehicle(vehicle)
    else
        if DoesEntityExist(vehicle) then
            DeleteEntity(vehicle)
        end
    end
end

-- Get players in area (for multiplayer features)
function Utils.getPlayersInArea(coords, radius)
    if Framework and Framework.getPlayersInArea then
        return Framework.getPlayersInArea(coords, radius)
    else
        local players = {}
        local allPlayers = GetActivePlayers()
        
        for _, playerId in ipairs(allPlayers) do
            local ped = GetPlayerPed(playerId)
            local playerCoords = GetEntityCoords(ped)
            local distance = #(coords - playerCoords)
            
            if distance <= radius then
                table.insert(players, playerId)
            end
        end
        
        return players
    end
end

-- Resource cleanup on stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Utils.cleanup()
    end
end)

-- Debug function (only works in development)
function Utils.debug(...)
    if GetConvar('fishing_debug', '0') == '1' then
        print('[Fishing Debug]', ...)
    end
end

-- Export Utils globally
_G.Utils = Utils

return UtilsPrice(price)
    end
    
    if type(price) == 'number' then
        return price
    elseif type(price) == 'table' and price.min and price.max then
        return (price.min + price.max) / 2
    end
    return 0
end

-- Distance calculation
function Utils.distance(pos1, pos2)
    if FishingUtils and FishingUtils.distance then
        return FishingUtils.distance(pos1, pos2)
    end
    
    return #(pos1 - pos2)
end

-- Round number to decimal places
function Utils.round(value, decimals)
    if FishingUtils and FishingUtils.round then
        return FishingUtils.round(value, decimals)
    end
    
    local mult = 10 ^ (decimals or 0)
    return math.floor(value * mult + 0.5) / mult
end

-- Check if table contains value
function Utils.tableContains(t, value)
    if FishingUtils and FishingUtils.tableContains then
        return FishingUtils.tableContains(t, value)
    end
    
    if not t then return false end
    for _, v in pairs(t) do
        if v == value then return true end
    end
    return false
end

-- Get current time period
function Utils.getTimePeriod(hour)
    if FishingUtils and FishingUtils.getTimePeriod then
        return FishingUtils.getTimePeriod(hour)
    end
    
    -- Fallback time period calculation
    hour = hour or GetClockHours()
    if hour >= 5 and hour <= 7 then return 'dawn'
    elseif hour >= 8 and hour <= 11 then return 'morning'
    elseif hour >= 12 and hour <= 14 then return 'noon'
    elseif hour >= 15 and hour <= 17 then return 'afternoon'
    elseif hour >= 18 and hour <= 20 then return 'dusk'
    elseif hour >= 21 or hour <= 4 then return 'night'
    else return 'day' end
end

-- Format time display
function Utils.formatTime(hour, minute)
    return ('%02d:%02d'):format(hour or GetClockHours(), minute or GetClockMinutes())
end

-- Get entity from network ID safely
function Utils.getEntityFromNetworkId(netId)
    if not netId then return 0 end
    local entity = NetworkGetEntityFromNetworkId(netId)
    return DoesEntityExist(entity) and entity or 0
end

-- Spawn vehicle wrapper (for boat rentals, etc.)
function Utils.spawnVehicle(model, coords, heading, callback)
    if Framework and Framework.spawnVehicle then
        Framework.spawnVehicle(model, coords, heading, callback)
    else
        -- Fallback vehicle spawning
        lib.requestModel(model)
        local vehicle = CreateVehicle(model, coords.x, coords.y, coords.z, heading, true, false)
        SetModelAsNoLongerNeeded(model)
        if callback then callback(vehicle) end
        return vehicle
    end
end

-- Delete vehicle safely
function Utils.deleteVehicle(vehicle)
    if Framework and Framework.deleteVehicle then
        Framework.deleteVehicle(vehicle)
    else
        if DoesEntityExist(vehicle) then
            DeleteEntity(vehicle)
        end
    end
end

-- Get players in area (for multiplayer features)
function Utils.getPlayersInArea(coords, radius)
    if Framework and Framework.getPlayersInArea then
        return Framework.getPlayersInArea(coords, radius)
    else
        local players = {}
        local allPlayers = GetActivePlayers()
        
        for _, playerId in ipairs(allPlayers) do
            local ped = GetPlayerPed(playerId)
            local playerCoords = GetEntityCoords(ped)
            local distance = #(coords - playerCoords)
            
            if distance <= radius then
                table.insert(players, playerId)
            end
        end
        
        return players
    end
end

-- Resource cleanup on stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Utils.cleanup()
    end
end)

-- Debug function (only works in development)
function Utils.debug(...)
    if GetConvar('fishing_debug', '0') == '1' then
        print('[Fishing Debug]', ...)
    end
end

-- Export Utils globally
_G.Utils = Utils

return Utils