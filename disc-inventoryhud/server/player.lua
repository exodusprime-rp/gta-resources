local impendingRemovals = {}
local impendingAdditions = {}

ESX.RegisterServerCallback('disc-inventoryhud:getPlayerInventory', function(source, cb)
    getPlayerDisplayInventory(ESX.GetPlayerFromId(source).identifier, cb)
end)

Citizen.CreateThread(function()
    --Player
    TriggerEvent('disc-inventoryhud:RegisterInventory', {
        name = 'player',
        label = 'Player',
        slots = 20,
        getInventory = function(identifier, cb)
            getInventory(identifier, 'player', cb)
        end,
        saveInventory = function(identifier, inventory)
            saveInventory(identifier, 'player', inventory)
        end
    })
end)

function getPlayerDisplayInventory(identifier, cb)
    local player = ESX.GetPlayerFromIdentifier(identifier)
    getInventory(identifier, 'player', function(inventory)
        local itemsObject = {}

        for k, v in pairs(inventory) do
            local esxItem = player.getInventoryItem(v.name)
            local item = createDisplayItem(v, esxItem, tonumber(k))
            table.insert(itemsObject, item)
        end

        local inv = {
            invId = identifier,
            invTier = InvType['player'],
            inventory = itemsObject,
            cash = player.getMoney(),
            bank = player.getAccount('bank').money,
            black_money = player.getAccount('black_money').money,
        }
        cb(inv)
    end)
end

function ensurePlayerInventory(player)
    getInventory(player.identifier, 'player', function(result)
        local inventory = {}
        for _, esxItem in pairs(player.getInventory()) do
            print('Adding ' .. esxItem.name .. ' ' .. esxItem.count)
            local item = createItem(esxItem.name, esxItem.count)
            addToInventory(item, 'player', inventory, esxItem.limit)
        end

        if result == nil then
            createInventory(player.identifier, 'player', inventory)
        else
            saveInventory(player.identifier, 'player', inventory)
        end
    end)
end

RegisterServerEvent('disc-inventoryhud:notifyImpendingRemoval')
AddEventHandler('disc-inventoryhud:notifyImpendingRemoval', function(item, count, playerSource)
    local _source = playerSource or source
    if impendingRemovals[_source] == nil then
        impendingRemovals[_source] = {}
    end
    item.count = count
    print(_source)
    table.insert(impendingRemovals[_source], item)
end)

RegisterServerEvent('disc-inventoryhud:notifyImpendingAddition')
AddEventHandler('disc-inventoryhud:notifyImpendingAddition', function(item, count, playerSource)
    local _source = playerSource or source
    if impendingAdditions[_source] == nil then
        impendingAdditions[_source] = {}
    end
    item.count = count
    table.insert(impendingAdditions[_source], item)
end)

AddEventHandler('esx:onRemoveInventoryItem', function(source, item, count)
    TriggerClientEvent('disc-inventoryhud:showItemUse', source, {
        { id = item.name, label = item.label, qty = count, msg = 'Item Removed' , action = 'removed', data = item }
    })
end)

AddEventHandler('esx:onAddInventoryItem', function(source, esxItem, count)
    TriggerClientEvent('disc-inventoryhud:showItemUse', source, {
        { id = esxItem.name, label = esxItem.label, qty = count, msg = 'Item Added' , action = 'added' , data = esxItem }
    })
end)


RegisterServerEvent('disc-inventoryhud:RemovedItem')
AddEventHandler('disc-inventoryhud:RemovedItem', function(data)
    local source = source
    local item = data.item
    local count = data.count
    local player = ESX.GetPlayerFromId(source)
    getInventory(player.identifier, 'player', function(inventory)
        if impendingRemovals[source] then
            print('Looking at source ' .. source)
            local extImp = json.encode(impendingRemovals[source])
            print(extImp)
            for k, removingItem in pairs(impendingRemovals[source]) do
                print('Looking at ' .. removingItem.id)
                if removingItem.id == item.name and removingItem.count == count then
                    print('Found')
                    if removingItem.block then
                        print('Blocked Removal')
                        impendingRemovals[source][k] = nil
                    else
                        print('Non Blocked Removal')
                        removeItemFromSlot(inventory, removingItem.slot, count)
                        impendingRemovals[source][k] = nil
                        saveInventory(player.identifier, 'player', inventory)
                        TriggerClientEvent('disc-inventoryhud:refreshInventory', source)
                    end
                    return
                end
            end
        end
        removeItemFromInventory(item, count, inventory)
        saveInventory(player.identifier, 'player', inventory)
        TriggerClientEvent('disc-inventoryhud:refreshInventory', source)
    end)

end)

RegisterServerEvent('disc-inventoryhud:AddingItem')
AddEventHandler('disc-inventoryhud:AddingItem', function(data)
    local source = source
    local esxItem = data.item
    local count = data.count
    local player = ESX.GetPlayerFromId(source)
    getInventory(player.identifier, 'player', function(inventory)
        if impendingAdditions[source] then
            for k, addingItem in pairs(impendingAdditions[source]) do
                if addingItem.id == esxItem.name and addingItem.count == count then
                    print('Found')
                    if addingItem.block then
                        print('Blocked Addition')
                        impendingAdditions[source][k] = nil
                        return
                    end
                end
            end
        end
        print('Running Default')
        local item = createItem(esxItem.name, count)
        addToInventory(item, 'player', inventory, esxItem.limit)
        saveInventory(player.identifier, 'player', inventory)
        TriggerClientEvent('disc-inventoryhud:refreshInventory', source)
    end)

end)