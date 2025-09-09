-- Get current weather from the global variable set in main.lua
local function getCurrentWeatherType()
    return serverWeather or 'CLEAR'
end

-- Initialize playerContracts if not already defined in main.lua
local playerContracts = playerContracts or {}

local function sell(fishName)
    local fish = Config.fish[fishName]
    local heading = type(fish.price) == 'number' 
                    and locale('sell_fish_heading', Utils.getItemLabel(fishName), fish.price)
                    or locale('sell_fish_heading2', Utils.getItemLabel(fishName), fish.price.min, fish.price.max)
    
    local amount = lib.inputDialog(heading, {
        {
            type = 'number',
            label = locale('amount'),
            min = 1,
            required = true
        }
    })?[1] --[[@as number?]]

    if not amount then
        lib.showContext('sell_fish')
        return
    end

    local success = lib.callback.await('lunar_fishing:sellFish', false, fishName, amount)

    if success then
        ShowProgressBar(locale('selling'), 3000, false, {
            dict = 'misscarsteal4@actor',
            clip = 'actor_berating_loop'
        })
        ShowNotification(locale('sold_fish'), 'success')
    else
        ShowNotification(locale('not_enough_fish'), 'error')
    end
end

local function sellFish()
    local options = {}
    local fishByRarity = {
        mythical = {},
        legendary = {},
        epic = {},
        rare = {},
        uncommon = {},
        common = {}
    }

    -- Organize fish by rarity for better display
    for fishName, fish in pairs(Config.fish) do
        if Framework.hasItem(fishName) then
            local option = {
                title = Utils.getItemLabel(fishName),
                description = type(fish.price) == 'number' and locale('fish_price', fish.price)
                            or locale('fish_price2', fish.price.min, fish.price.max),
                image = GetInventoryIcon(fishName),
                onSelect = sell,
                price = type(fish.price) == 'number' and fish.price or fish.price.min,
                args = fishName,
                metadata = {
                    { label = 'Rarity', value = fish.rarity:upper() },
                    { label = 'Chance', value = fish.chance .. '%' }
                }
            }
            
            table.insert(fishByRarity[fish.rarity], option)
        end
    end

    -- Add fish to options in rarity order
    local rarityOrder = { 'mythical', 'legendary', 'epic', 'rare', 'uncommon', 'common' }
    for _, rarity in ipairs(rarityOrder) do
        for _, option in ipairs(fishByRarity[rarity]) do
            table.insert(options, option)
        end
    end

    if #options == 0 then
        ShowNotification(locale('nothing_to_sell'), 'error')
        return
    end

    lib.registerContext({
        id = 'sell_fish',
        title = locale('sell_fish'),
        menu = 'fisherman',
        options = options
    })

    Wait(60)
    lib.showContext('sell_fish')
end

---@param data { type: string, index: integer }
local function buy(data)
    local itemType, index = data.type, data.index
    local item = Config[itemType][index]
    
    local amount = lib.inputDialog(locale('buy_heading', Utils.getItemLabel(item.name), item.price), {
        {
            type = 'number',
            label = locale('amount'),
            min = 1,
            required = true
        }
    })?[1] --[[@as number?]]

    if not amount then
        lib.showContext(itemType == 'fishingRods' and 'buy_rods' or 'buy_baits')
        return
    end

    local success = lib.callback.await('lunar_fishing:buy', false, data, amount)

    if success then
        ShowProgressBar(locale('buying'), 3000, false, {
            dict = 'misscarsteal4@actor',
            clip = 'actor_berating_loop'
        })
        ShowNotification(locale('bought_item'), 'success')
    else
        ShowNotification(locale('not_enough_' .. Config.ped.buyAccount), 'error')
    end
end

local function buyRods()
    local options = {}

    for index, rod in ipairs(Config.fishingRods) do
        local playerLevel = GetCurrentLevel()
        local isLocked = rod.minLevel > playerLevel
        
        table.insert(options, {
            title = Utils.getItemLabel(rod.name),
            description = locale('rod_price', rod.price),
            image = GetInventoryIcon(rod.name),
            disabled = isLocked,
            onSelect = buy,
            args = { type = 'fishingRods', index = index },
            metadata = {
                { label = 'Reikalingas lygis', value = rod.minLevel },
                { label = 'Sugimo tikimybė', value = rod.breakChance .. '%' },
                { label = 'Būsena', value = isLocked and '🔒 UŽRAKINTA' or '✅ PRIEINAMA' }
            }
        })

    end

    lib.registerContext({
        id = 'buy_rods',
        title = locale('buy_rods'),
        menu = 'fisherman',
        options = options
    })

    Wait(60)
    lib.showContext('buy_rods')
end

local function buyBaits()
    local options = {}

    for index, bait in ipairs(Config.baits) do
        local playerLevel = GetCurrentLevel()
        local isLocked = bait.minLevel > playerLevel
        
        local speedBonus = math.floor((1 - 1/bait.waitDivisor) * 100)
        local effectDesc = speedBonus > 0 and ('Žvejybos greitis: +%d%%'):format(speedBonus) or 'Standartinis masalas'

        
        table.insert(options, {
            title = Utils.getItemLabel(bait.name),
            description = locale('bait_price', bait.price),
            image = GetInventoryIcon(bait.name),
            disabled = isLocked,
            onSelect = buy,
            args = { type = 'baits', index = index },
            metadata = {
                { label = 'Required Level', value = bait.minLevel },
                { label = 'Effect', value = effectDesc },
                { label = 'Status', value = isLocked and '🔒 UŽRAKINTA' or '✅ PRIEINAMA' }
            }
        })
    end

    lib.registerContext({
        id = 'buy_baits',
        title = locale('buy_baits'),
        menu = 'fisherman',
        options = options
    })

    Wait(60)
    lib.showContext('buy_baits')
end

-- Fish encyclopedia
local function showFishEncyclopedia()
    local options = {}
    local fishByRarity = {
        mythical = {},
        legendary = {},
        epic = {},
        rare = {},
        uncommon = {},
        common = {}
    }

    -- Organize fish by rarity
    for fishName, fish in pairs(Config.fish) do
        local hasCaught = Framework.hasItem(fishName) -- Basic check - you might want to improve this
        
        local option = {
            title = (hasCaught and '✅ ' or '❓ ') .. Utils.getItemLabel(fishName),
            description = hasCaught and 
                (type(fish.price) == 'number' and ('Vertė: $%d'):format(fish.price) or 
                ('Vertė: $%d - $%d'):format(fish.price.min, fish.price.max)) or
                'Dar neatrasta',
            image = hasCaught and GetInventoryIcon(fishName) or nil,
            disabled = not hasCaught,
            metadata = hasCaught and {
                { label = 'Retumas', value = fish.rarity:upper() },
                { label = 'Sugavimo tikimybė', value = fish.chance .. '%' },
                { label = 'Įgūdžių patikrinimas', value = table.concat(fish.skillcheck, ', ') }
            } or {
                { label = 'Būsena', value = 'Neatrasta' }
            }
        }
        
        table.insert(fishByRarity[fish.rarity], option)
    end

    -- Add rarity headers and fish
    local rarityOrder = { 'mythical', 'legendary', 'epic', 'rare', 'uncommon', 'common' }
    for _, rarity in ipairs(rarityOrder) do
        if #fishByRarity[rarity] > 0 then
            -- Add rarity header
            local rarityEmojis = {
                mythical = '🔮',
                legendary = '👑',
                epic = '💎',
                rare = '🌟',
                uncommon = '🐠',
                common = '🐟'
            }
            
            table.insert(options, {
                title = ('--- %s ŽUVYS ---'):format(rarity:upper()),
                description = ('Rušys: %d'):format(#fishByRarity[rarity]),
                disabled = true,
                icon = 'fish'
            })
            
            for _, option in ipairs(fishByRarity[rarity]) do
                table.insert(options, option)
            end
        end
    end

    lib.registerContext({
        id = 'fish_encyclopedia',
        title = '📚 Žuvų enciklopedija',
        menu = 'fisherman',
        options = options
    })

    Wait(60)
    lib.showContext('fish_encyclopedia')
end

-- Active contracts display
local function showActiveContracts()
    local contractCount = 0
    for _ in pairs(playerContracts) do
        contractCount = contractCount + 1
    end
    
    if contractCount == 0 then
        ShowNotification('📋 Aktyvių kontraktu nėra', 'inform')
        return
    end
    
    local options = {}
    
    for contractId, contract in pairs(playerContracts) do
        local progress = contract.progress or 0
        local progressText = ''
        
        if contract.type == 'catch_specific' then
            progressText = ('%d/%d %s'):format(progress, contract.target.amount, contract.target.fish)
        elseif contract.type == 'catch_rarity' then
            progressText = ('%d/%d %s fish'):format(progress, contract.target.amount, contract.target.rarity)
        elseif contract.type == 'catch_value' then
            progressText = ('$%d/$%d value'):format(progress, contract.target.value)
        end
        
        local progressPercent = 0
        if contract.type == 'catch_value' then
            progressPercent = math.min((progress / contract.target.value) * 100, 100)
        else
            progressPercent = math.min((progress / (contract.target.amount or 1)) * 100, 100)
        end
        
        table.insert(options, {
            title = contract.title,
            description = contract.description,
            progress = progressPercent,
            colorScheme = progressPercent >= 100 and 'green' or 'blue',
            metadata = {
                { label = 'Progresas', value = progressText },
                { label = 'Premija', value = '$' .. contract.reward.money .. ' + ' .. contract.reward.xp .. ' XP' }
            },
            disabled = true
        })
    end
    
    table.insert(options, {
        title = '📋 Žiurėti kontraktus',
        description = 'Galimi kontraktai',
        icon = 'clipboard-list',
        onSelect = function()
            if contractKeybind then
                contractKeybind.onReleased()
            end
        end
    })

    lib.registerContext({
        id = 'active_contracts',
        title = '📋 Active Contracts',
        menu = 'fisherman',
        options = options
    })

    Wait(60)
    lib.showContext('active_contracts')
end

-- Enhanced main fisherman menu
local function open()
    local level, progress = GetCurrentLevel(), GetCurrentLevelProgress() * 100
    local currentZoneName = currentZone and Config.fishingZones[currentZone.index].blip.name or 'Open Waters'
    local weather = getCurrentWeatherType()
    local weatherEffect = Config.weatherEffects[weather]
    local weatherBonus = weatherEffect and weatherEffect.chanceBonus or 0

    lib.registerContext({
        id = 'fisherman',
        title = '🏢 ' .. locale('fisherman'),
        options = {
            {
                title = ('%d lygio žvejys'):format(level),
                description = ('Progresas: %.1f%% | Zona: %s'):format(progress, currentZoneName),
                icon = 'chart-simple',
                progress = math.max(progress, 0.01),
                colorScheme = 'lime',
                disabled = true
            },
            {
                title = 'Dabartinės sąlygos',
                description = ('Oras: %s | Premija: %s%d%%'):format(
                    weather, 
                    weatherBonus >= 0 and '+' or '', 
                    weatherBonus
                ),
                icon = 'cloud-sun',
                disabled = true
            },
            {
                title =  locale('buy_rods'),
                description = locale('buy_rods_desc'),
                icon = 'dollar-sign',
                arrow = true,
                onSelect = buyRods
            },
            {
                title =  locale('buy_baits'),
                description = locale('buy_baits_desc'),
                icon = 'worm',
                arrow = true,
                onSelect = buyBaits
            },
            {
                title =  locale('sell_fish'),
                description = locale('sell_fish_desc'),
                icon = 'fish',
                arrow = true,
                onSelect = sellFish
            },
            {
                title = 'Žuvų enciklopedija',
                description = 'Peržiūrėkite informaciją apie visas žuvų rūšis',
                icon = 'book',
                arrow = true,
                onSelect = showFishEncyclopedia
            },
            {
                title = 'Aktyvūs kontraktai',
                description = 'Peržiūrėkite savo esamus žvejybos kontraktus',
                icon = 'clipboard-list',
                arrow = true,
                onSelect = showActiveContracts
            }

        }
    })

    lib.showContext('fisherman')
end

-- Create PEDs and blips
for _, coords in ipairs(Config.ped.locations) do
    Utils.createPed(coords, Config.ped.model, {
        {
            label = locale('open_fisherman'),
            icon = 'comment',
            onSelect = open
        }
    })
    Utils.createBlip(coords, Config.ped.blip)
end