-- Made by GCodeman --
-- Configurations
startingcash = 100000
bailoutcost = 60000 -- Not used unless bailout feature is turned on
hospitalbill = 1000
recoverycostpercent = 0.10
maxloan = 200000000
maxdebt = 25000000
debtcap = 300000
fuelcostperliter = 2
debtperday = 0.025
incometax = 20000 -- Can be positive or negative
islandclaiming = true -- Set to false to disable claiming of islands and teleport/spawn/bench permissions
negativetaxdebt = true -- Set to false to disable negative tax adding debt. If player cannot pay, it'll just set them to $0 bank

--[[
g_savedata = {}
playertable = {
    {player name, bank, debt, lastvehicle, lastdebtdate, lasttaxdate},
    {player name, bank, debt, lastvehicle, lastdebtdate, lasttaxdate},
    ...
}
vehicletable = {
    [group_id] = {owner_name, cost, vehicle_ids},
    ...
}
islandtable = {island tile name, owner, {co-owners}, {allowed to teleport}, {allowed to spawn vehicles}, {allowed to bench}, {spawncoords}}
datatable = {incometax}
]] --

-- Initialize g_savedata if not already initialized
if not g_savedata then
    g_savedata = {}
end

-- Initialize other tables if not already initialized
playertable = g_savedata.playertable or {}
vehicletable = g_savedata.vehicletable or {}
islandtable = g_savedata.islandtable or {}
datatable = g_savedata.datatable or {incometax}

function saveGame()
    saveTables()
    server.save("serveroof")
end

function saveTables()
    g_savedata.playertable = playertable
    g_savedata.vehicletable = vehicletable
    g_savedata.islandtable = islandtable
    g_savedata.datatable = datatable
    -- shared_bank is already in g_savedata
end

function ownsVehicle(target_id, group_id)
    local player_name = server.getPlayerName(target_id)
    if vehicletable[group_id] and vehicletable[group_id].owner_name == player_name then
        return true
    end
    return false
end

function isPlayerOnline(target_name)
    for k, v in pairs(server.getPlayers()) do
        if (v["name"] == target_name) then
            return true
        end
    end
    return false
end

function getPlayerID(target_name)
    for k, v in pairs(server.getPlayers()) do
        if (v["name"] == target_name) then
            return v["id"]
        end
    end
    return -1
end

function nearestVehicleGroup(target_id)
    local playerloc = server.getPlayerPos(target_id)
    local nearest_group = -1
    local nearest_distance = math.huge

    for group_id, group_info in pairs(vehicletable) do
        for _, vehicle_id in ipairs(group_info.vehicle_ids) do
            local vehicle_pos = server.getVehiclePos(vehicle_id)
            local dist = matrix.distance(playerloc, vehicle_pos)
            if dist < nearest_distance then
                nearest_distance = dist
                nearest_group = group_id
            end
        end
    end

    return nearest_group, nearest_distance
end

function isInPurchasedArea(target_id)
    local playerloc = server.getPlayerPos(target_id)
    return server.getTilePurchased(playerloc)
end

function isInMainland(target_id)
    local playerloc = server.getPlayerPos(target_id)
    local x, y, z = matrix.position(playerloc)
    if (z < 0 and z > -14000) then
        return true
    else
        return false
    end
end

function isHomeIsland(island_tile_name)
    local hometile = server.getStartTile()
    local hometilename = hometile["name"]
    if (island_tile_name == hometilename) then
        return true
    else
        return false
    end
end

function getIslandOwner(island_tile_name)
    for k, v in pairs(islandtable) do
        if v[1] == island_tile_name then
            return v[2]
        end
    end
    return "Unowned"
end

function getIslandKeyFromID(island_tile_name)
    for k, v in pairs(islandtable) do
        if v[1] == island_tile_name then
            return k
        end
    end
    return -1 -- if not found
end

function getIslandCoOwners(island_tile_name)
    for k, v in pairs(islandtable) do
        if v[1] == island_tile_name then
            return v[3]
        end
    end
    return {} -- if not found
end

function getIslandTeleportAccess(island_tile_name)
    for k, v in pairs(islandtable) do
        if v[1] == island_tile_name then
            return v[4]
        end
    end
    return {} -- if not found
end

function getIslandSpawnAccess(island_tile_name)
    for k, v in pairs(islandtable) do
        if v[1] == island_tile_name then
            return v[5]
        end
    end
    return {} -- if not found
end

function getIslandBenchAccess(island_tile_name)
    for k, v in pairs(islandtable) do
        if v[1] == island_tile_name then
            return v[6]
        end
    end
    return {} -- if not found
end

function isCoOwner(player_name, island_tile_name)
    local coowners = getIslandCoOwners(island_tile_name)
    for k, v in pairs(coowners) do
        if v == player_name then
            return true
        end
    end
    return false
end

function hasTeleportAccess(player_name, island_name)
    local island_data = islandtable[island_name]
    if not island_data then
        return false
    end

    if island_data.owner == player_name then
        return true  -- Owners have teleport access
    end

    if isCoOwner(player_name, island_name) then
        return true  -- Co-owners have teleport access
    end

    for _, name in ipairs(island_data.teleport_access) do
        if name == player_name then
            return true
        end
    end

    return false
end


function hasSpawnAccess(player_name, island_tile_name)
    if isHomeIsland(island_tile_name) then
        return true
    end
    local access = getIslandSpawnAccess(island_tile_name)
    for k, v in pairs(access) do
        if v == player_name then
            return true
        end
    end
    return false
end

function hasBenchAccess(player_name, island_tile_name)
    if isHomeIsland(island_tile_name) then
        return true
    end
    local access = getIslandBenchAccess(island_tile_name)
    for k, v in pairs(access) do
        if v == player_name then
            return true
        end
    end
    return false
end

function tableToFormattedString(tbl)
    local str = ""
    for k, v in pairs(tbl) do
        str = str .. v .. "\n"
    end
    return str
end

function getBank(target_id)
    for k, v in pairs(playertable) do
        if (v[1] == server.getPlayerName(target_id)) then
            return playertable[k][2] -- Returns bank amount
        end
    end
    return 0
end

function getDebt(target_id)
    for k, v in pairs(playertable) do
        if (v[1] == server.getPlayerName(target_id)) then
            return playertable[k][3] -- Returns debt amount
        end
    end
    return 0
end

function teleportHome(target_id)
    local hometile = server.getStartTile()
    local x = hometile["x"]
    local y = hometile["y"]
    local z = hometile["z"]
    local pos = matrix.translation(x, y, z)
    server.setPlayerPos(target_id, pos)
end

function accrueDebt()
    for k, v in pairs(playertable) do
        if (v[3] > 0) and (v[5] < server.getDateValue()) then
            if (isPlayerOnline(v[1])) then
                local currentdebt = v[3]
                local debtadded = math.ceil(currentdebt * debtperday)
                local newdebt = math.ceil(currentdebt + debtadded)
                if (newdebt > debtcap) then
                    newdebt = debtcap
                end
                playertable[k][3] = newdebt
                playertable[k][5] = server.getDateValue()
                server.notify(getPlayerID(v[1]), "Debt Accrued",
                    "Debt: $" .. currentdebt .. "\n(" .. debtperday * 100 .. "%) = $" .. debtadded .. "\nNew Debt: $" ..
                        newdebt, 8)
            end
        end
    end
end

function incomeTax()
    for k, v in pairs(playertable) do
        if (v[6] < server.getDateValue()) then
            if (isPlayerOnline(v[1])) then
                local amount = datatable[1]
                playertable[k][6] = server.getDateValue()
                if (amount == 0) then
                    return
                end
                local target_id = getPlayerID(v[1])
                addBank(target_id, amount)
                if (amount > 0) then
                    server.notify(target_id, "Tax Return", "$" .. amount .. " has been added to your account", 8)
                else
                    server.notify(target_id, "Taxes Due", "$" .. amount .. " has been deducted from your account", 8)
                    if (getBank(target_id) < 0) then
                        local deficit = getBank(target_id)
                        setBank(target_id, 0)
                        if (negativetaxdebt) then
                            addDebt(target_id, -deficit)
                            if (getDebt(target_id) > debtcap) then
                                setDebt(target_id, debtcap)
                            end
                        end
                    end
                end
            end
        end
    end
end

function displayUI()
    if (playertable ~= nil) then
        for k, v in pairs(playertable) do
            if (isPlayerOnline(v[1])) then
                local target_id = getPlayerID(v[1])
                server.setPopupScreen(target_id, 47, "Bank", true,
                    "Bank:\n$" .. string.format('%.0f', getBank(target_id)), 0.885, 0.75)
                if (getDebt(target_id) > 0) then
                    server.setPopupScreen(target_id, 48, "Debt", true,
                        "Debt:\n$" .. string.format('%.0f', getDebt(target_id)), 0.885, 0.62)
                    server.setPopupScreen(target_id, 49, "Shared Bank", true, "Shared Bank:\n$" .. getSharedBank(),
                        0.885, 0.49)
                else
                    server.setPopupScreen(target_id, 48, "Debt", false, "", 0.885, 0.62)
                    server.setPopupScreen(target_id, 49, "Shared Bank", true, "Shared Bank:\n$" .. getSharedBank(),
                        0.885, 0.62)
                end
            end
        end
    end
end

function searchTable(tbl, searchedvalue)
    for k, v in pairs(tbl) do
        if v == searchedvalue then
            return k
        end
    end
    return -1
end

function getVehicleCost(group_id)
    if vehicletable[group_id] then
        return vehicletable[group_id].cost
    end
    return 0
end

function deleteVehicleFromTable(group_id)
    vehicletable[group_id] = nil
end

function getLastVehicle(target_id)
    for k, v in pairs(playertable) do
        if (v[1] == server.getPlayerName(target_id)) then
            return playertable[k][4] -- Returns last group they were in
        end
    end
    return -1
end

function setLastVehicle(target_id, group_id)
    for k, v in pairs(playertable) do
        if (v[1] == server.getPlayerName(target_id)) then
            playertable[k][4] = group_id
        end
    end
end

function clearVehicles(target_id)
    for group_id, group_info in pairs(vehicletable) do
        if (group_info.owner_name == server.getPlayerName(target_id)) then
            server.despawnVehicleGroup(group_id, true)
        end
    end
end

function getSharedBank()
    local shared_bank = server.getCurrency() - 1000000
    if shared_bank < 0 then
        return 0
    else
        return shared_bank
    end
end

function addSharedBank(amount)
    local current_currency = server.getCurrency()
    local shared_bank = current_currency - 1000000
    local new_shared_bank = shared_bank + amount

    if new_shared_bank < 0 then
        new_shared_bank = 0
    end

    server.setCurrency(1000000 + new_shared_bank, server.getResearchPoints())
end

function addBank(target_id, amount)
    for k, v in pairs(playertable) do
        if (v[1] == server.getPlayerName(target_id)) then
            playertable[k][2] = playertable[k][2] + amount
        end
    end
end

function setBank(target_id, amount)
    for k, v in pairs(playertable) do
        if (v[1] == server.getPlayerName(target_id)) then
            playertable[k][2] = amount
        end
    end
end

-- Used for loans and fines
function addDebt(target_id, amount)
    for k, v in pairs(playertable) do
        if (v[1] == server.getPlayerName(target_id)) then
            if playertable[k][3] == 0 then
                playertable[k][5] = server.getDateValue() -- Makes it so you don't get interest immediately
            end
            playertable[k][3] = playertable[k][3] + amount
        end
    end
end

-- Used for loans and fines
function setDebt(target_id, amount)
    for k, v in pairs(playertable) do
        if (v[1] == server.getPlayerName(target_id)) then
            if playertable[k][3] == 0 then
                playertable[k][5] = server.getDateValue() -- Makes it so you don't get interest immediately
            end
            playertable[k][3] = amount
        end
    end
end

function InitializePlayer(target_player)
    local playerfound = false
    for k, v in pairs(playertable) do
        if (v[1] == server.getPlayerName(target_player)) then
            playerfound = true
        end
    end

    if (playerfound == false) then
        table.insert(playertable, {server.getPlayerName(target_player), startingcash, 0, -1, -1, -1})
        server.notify(target_player, "Welcome " .. server.getPlayerName(target_player),
            "$" .. startingcash .. " has been deposited into your account. Type '?help' to get started!", 8)
    else
        server.notify(target_player, "Welcome back " .. server.getPlayerName(target_player), "", 8)
    end
end

function getCurrentTileName(peer_id)
    local pos = server.getPlayerPos(peer_id)
    local tile = server.getTile(pos[13], pos[14], pos[15])
    if tile then
        return tile.name
    else
        return "NotFound"
    end
end


function onCreate(is_world_create)
    server.setGameSetting("infinite_resources", false)
    if islandclaiming then
        server.setGameSetting("map_teleport", false)
        server.setGameSetting("fast_travel", false)
    end

    if is_world_create then
        playertable = {}
        vehicletable = {}
        islandtable = {}
        datatable = {incometax}
        server.setCurrency(1000000, server.getResearchPoints()) -- Set server currency to 1,000,000
        saveGame()
    else
        playertable = g_savedata.playertable or {}
        vehicletable = g_savedata.vehicletable or {}
        islandtable = g_savedata.islandtable or {}
        datatable = g_savedata.datatable or {incometax}
        -- Do not reset server currency in existing worlds
    end
end

function onTick(game_ticks)
    incomeTax()
    accrueDebt()
    displayUI()
end

function onPlayerJoin(steam_id, name, peer_id, admin, auth)
    server.announce("[Server]", name .. " joined the game")
    InitializePlayer(peer_id)
    if getLastVehicle(peer_id) > -1 then
        -- There is no direct way to press a vehicle button in a group, so you may need to adjust this logic
        server.notify(peer_id, "Possible Crash/Disconnect",
            "If your last occupied vehicle has a button labelled 'Killswitch' it has been pressed", 8)
    end
end

function onPlayerLeave(steam_id, name, peer_id, admin, auth)
    server.announce("[Server]", name .. " left the game")
    saveGame()
end

function onCustomCommand(full_message, user_peer_id, is_admin, is_auth, command, ...)
    local args = {...}

    -- ?help
    if command == "?help" then
        server.announce("Commands",
            "?bank\n?deposit (amount)\n?claim (amount)\n?pay (player id) (amount)\n?loan (amount)\n?payloan (amount)\n?bench\n?recover [" ..
                string.format('%.0f', recoverycostpercent * 100) ..
                "% vehicle cost fee]\n?buyfuel (diesel/jetfuel) (amount) [$" .. fuelcostperliter ..
                "/L, non-dynamic tanks only]\n?savegame", user_peer_id)
        if islandclaiming then
            server.announce("Island Commands",
                "?access\n?islandaccess (island name)\n?claimisland\n?unclaimisland\n?setcoowner (player id) (island name)\n?setteleport (player id) (island name)\n?setspawn (player id) (island name)\n?setbench (player id) (island name)",
                user_peer_id)
        end
        if is_admin then
            server.announce("Admin Commands",
                "?addbank (player id) (amount)\n?setbank (player id) (amount)\n?addsharedbank (amount)\n?adddebt (player id) (amount)\n?setdebt (player id) (amount)\n?addresearch (amount)\n?setresearch (amount)\n?settax (amount)\n?bring (player id)\n?lock\n?unlock\n?resetisland",
                user_peer_id)
            server.announce("Debug Commands",
                "?init\n?playertable\n?vehicletable\n?islandtable\n?accruedebt\n?tilename", user_peer_id)
        end
    end

    -- ?addbank (admin only)
    if command == "?addbank" and is_admin then
        local target_id = tonumber(args[1])
        local amount = tonumber(args[2])
        if target_id and amount then
            addBank(target_id, amount)
            server.notify(user_peer_id, "Account Updated",
                server.getPlayerName(target_id) .. "'s bank has increased by $" .. amount, 8)
            server.notify(target_id, "Account Updated", "Your bank has been increased by $" .. amount, 8)
        else
            server.notify(user_peer_id, "Command Failed", "Invalid arguments", 8)
        end
    end

    -- ?adddebt (admin only)
    if command == "?adddebt" and is_admin then
        local target_id = tonumber(args[1])
        local amount = tonumber(args[2])
        if target_id and amount then
            addDebt(target_id, amount)
            server.notify(user_peer_id, "Account Updated",
                server.getPlayerName(target_id) .. "'s debt has increased by $" .. amount, 8)
            server.notify(target_id, "Account Updated", "Your debt has been increased by $" .. amount, 8)
        else
            server.notify(user_peer_id, "Command Failed", "Invalid arguments", 8)
        end
    end

    -- ?setbank (admin only)
    if command == "?setbank" and is_admin then
        local target_id = tonumber(args[1])
        local amount = tonumber(args[2])
        if target_id and amount then
            setBank(target_id, amount)
            server.notify(user_peer_id, "Account Updated",
                server.getPlayerName(target_id) .. "'s bank has been set to $" .. amount, 8)
            server.notify(target_id, "Account Updated", "Your bank has been set to $" .. amount, 8)
        else
            server.notify(user_peer_id, "Command Failed", "Invalid arguments", 8)
        end
    end

    -- ?setdebt (admin only)
    if command == "?setdebt" and is_admin then
        local target_id = tonumber(args[1])
        local amount = tonumber(args[2])
        if target_id and amount then
            setDebt(target_id, amount)
            server.notify(user_peer_id, "Account Updated",
                server.getPlayerName(target_id) .. "'s debt has been set to $" .. amount, 8)
            server.notify(target_id, "Account Updated", "Your debt has been set to $" .. amount, 8)
        else
            server.notify(user_peer_id, "Command Failed", "Invalid arguments", 8)
        end
    end

    -- ?resetisland (admin only)
    if command == "?resetisland" and is_admin then
        local islandname = getCurrentTileName(user_peer_id)
        local formattedname = getFormattedTileName(islandname)
        if formattedname ~= "NotFound" then
            server.notify(user_peer_id, "Island Reset", formattedname .. " is no longer owned by anybody", 8)
            local islandkey = getIslandKeyFromID(islandname)
            if islandkey ~= -1 then
                islandtable[islandkey] = nil
            end
        else
            server.notify(user_peer_id, "Reset Failed", "This area is not ownable", 8)
        end
    end

    -- ?pay
    if command == "?pay" then
        local target_id = tonumber(args[1])
        local amount = tonumber(args[2])
        if target_id and amount and amount > 0 then
            if getBank(user_peer_id) >= amount then
                addBank(user_peer_id, -amount)
                addBank(target_id, amount)
                server.notify(user_peer_id, "Payment Success",
                    "You paid " .. server.getPlayerName(target_id) .. " $" .. amount, 8)
                server.notify(target_id, "Payment Received",
                    "You were paid $" .. amount .. " by " .. server.getPlayerName(user_peer_id), 8)
            else
                server.notify(user_peer_id, "Payment Failed", "You only have $" .. getBank(user_peer_id), 8)
            end
        else
            server.notify(user_peer_id, "Command Failed", "Invalid arguments", 8)
        end
    end

    -- ?init
    if command == "?init" then
        InitializePlayer(user_peer_id)
    end

    -- ?loan
    if command == "?loan" then
        local amount = tonumber(args[1])
        local currentdebt = getDebt(user_peer_id)
        if amount and amount + currentdebt <= maxloan then
            addBank(user_peer_id, amount)
            addDebt(user_peer_id, amount)
            server.notify(user_peer_id, "Loan Successful",
                "Current Debt: $" .. (currentdebt + amount) .. "\nYour debt will increase by " .. (debtperday * 100) ..
                    "%" .. " at the beginning of each day", 8)
        else
            server.notify(user_peer_id, "Loan Failed",
                "Loan exceeds available amount\nMax: $" .. (maxloan - currentdebt), 8)
        end
    end

    -- ?payloan
    if command == "?payloan" then
        local amount = tonumber(args[1])
        local currentdebt = getDebt(user_peer_id)
        if amount and amount > 0 then
            if getBank(user_peer_id) >= amount then
                if currentdebt >= amount then
                    addBank(user_peer_id, -amount)
                    addDebt(user_peer_id, -amount)
                    server.notify(user_peer_id, "Payment Successful", "Remaining Debt: $" .. (currentdebt - amount), 8)
                else
                    server.notify(user_peer_id, "Payment Failed", "Amount larger than current debt", 8)
                end
            else
                server.notify(user_peer_id, "Payment Failed", "You do not have enough money", 8)
            end
        else
            server.notify(user_peer_id, "Payment Failed", "Please enter a valid number", 8)
        end
    end

    -- ?accruedebt (admin only)
    if command == "?accruedebt" and is_admin then
        accrueDebt()
        server.notify(user_peer_id, "Debt Accrual", "Debt has been accrued for all players.", 8)
    end

    -- ?bank
    if command == "?bank" then
        local bank = getBank(user_peer_id)
        local debt = getDebt(user_peer_id)
        local sharedbank = getSharedBank()
        server.notify(user_peer_id, "Account",
            "Personal Bank: $" .. bank .. "\nShared Bank: $" .. sharedbank .. "\nDebt: $" .. debt, 8)
    end

    -- ?addsharedbank (admin only)
    if command == "?addsharedbank" and is_admin then
        local amount = tonumber(args[1])
        if amount then
            addSharedBank(amount)
            server.notify(user_peer_id, "Shared Account Updated", "Balance: $" .. getSharedBank(), 8)
        else
            server.notify(user_peer_id, "Command Failed", "Invalid amount", 8)
        end
    end

    -- ?addresearch (admin only)
    if command == "?addresearch" and is_admin then
        local amount = tonumber(args[1])
        if amount then
            server.setCurrency(server.getCurrency(), server.getResearchPoints() + amount)
            server.notify(user_peer_id, "Research Updated", "Total Research: " .. server.getResearchPoints(), 8)
        else
            server.notify(user_peer_id, "Command Failed", "Invalid amount", 8)
        end
    end

    -- ?setresearch (admin only)
    if command == "?setresearch" and is_admin then
        local amount = tonumber(args[1])
        if amount then
            server.setCurrency(server.getCurrency(), amount)
            server.notify(user_peer_id, "Research Updated", "Total Research: " .. server.getResearchPoints(), 8)
        else
            server.notify(user_peer_id, "Command Failed", "Invalid amount", 8)
        end
    end

    -- ?savegame
    if command == "?savegame" then
        saveGame()
        server.notify(user_peer_id, "Game Saved", "", 8)
    end

    -- ?playertable (admin only)
    if command == "?playertable" and is_admin then
        for k, v in pairs(playertable) do
            server.announce("Player Table",
                "Key ID " .. k .. "\nPlayer Name: " .. v[1] .. "\nBank: $" .. v[2] .. "\nDebt: $" .. v[3] ..
                    "\nLast Group ID: " .. v[4] .. "\nLast Debt Date: " .. v[5], user_peer_id)
        end
    end

    -- ?vehicletable (admin only)
    if command == "?vehicletable" and is_admin then
        for group_id, group_info in pairs(vehicletable) do
            server.announce("Vehicle Table", "Group ID: " .. group_id .. "\nOwner Name: " .. group_info.owner_name ..
                "\nCost: $" .. group_info.cost, user_peer_id)
        end
    end

    -- ?islandtable (admin only)
    if command == "?islandtable" and is_admin then
        for k, v in pairs(islandtable) do
            local coowners = table.concat(v[3] or {}, ", ")
            local tp_access = table.concat(v[4] or {}, ", ")
            local spawn_access = table.concat(v[5] or {}, ", ")
            local bench_access = table.concat(v[6] or {}, ", ")
            server.announce("Island Table",
                "Key ID " .. k .. "\nTile: " .. v[1] .. "\nOwner Name: " .. v[2] .. "\nCo-Owner Names: " .. coowners ..
                    "\nTP Access: " .. tp_access .. "\nSpawn Access: " .. spawn_access .. "\nBench Access: " ..
                    bench_access, user_peer_id)
        end
    end

    -- ?bring (admin only)
    if command == "?bring" and is_admin then
        local target_id = tonumber(args[1])
        if target_id then
            server.setPlayerPos(target_id, server.getPlayerPos(user_peer_id))
            server.notify(user_peer_id, "Teleport",
                server.getPlayerName(target_id) .. " has been teleported to your position.", 8)
            server.notify(target_id, "Teleport",
                server.getPlayerName(user_peer_id) .. " has teleported you to their position.", 8)
        else
            server.notify(user_peer_id, "Command Failed", "Invalid player ID", 8)
        end
    end

    -- ?goto (admin only)
    if command == "?goto" and is_admin then
        local target_id = tonumber(args[1])
        if target_id then
            server.setPlayerPos(user_peer_id, server.getPlayerPos(target_id))
            server.notify(user_peer_id, "Teleport",
                "You have teleported to " .. server.getPlayerName(target_id) .. "'s position", 8)
            server.notify(target_id, "Teleport",
                server.getPlayerName(user_peer_id) .. " has teleported to your position", 8)
        else
            server.notify(user_peer_id, "Command Failed", "Invalid player ID", 8)
        end
    end

    -- ?settax (admin only)
    if command == "?settax" and is_admin then
        local amount = tonumber(args[1])
        if amount then
            datatable[1] = amount
            server.notify(user_peer_id, "Taxes Updated", "Each player gets $" .. amount .. " per day", 8)
        else
            server.notify(user_peer_id, "Command Failed", "Invalid amount", 8)
        end
    end

    if command == "?bench" or command == "?c" then
        local islandname = getCurrentTileName(user_peer_id)
        local formattedname = getFormattedTileName(islandname)
        if isInPurchasedArea(user_peer_id) or string.find(formattedname, "Deposit") then
            local playername = server.getPlayerName(user_peer_id)
            if (not islandclaiming) or hasBenchAccess(playername, islandname) or getIslandOwner(islandname) == playername or isCoOwner(playername, islandname) or isHomeIsland(islandname) then
                local nearest_group, nearest_dist = nearestVehicleGroup(user_peer_id)
                if nearest_dist <= 25 and nearest_group ~= -1 then
                    if ownsVehicle(user_peer_id, nearest_group) then
                        local vehiclecost = getVehicleCost(nearest_group)
                        if getSharedBank() >= vehiclecost then
                            addBank(user_peer_id, vehiclecost)
                            addSharedBank(-vehiclecost)
                            setLastVehicle(user_peer_id, -1)
                            -- Despawn all vehicles in the group
                            local vehicle_ids = vehicletable[nearest_group].vehicle_ids
                            for _, vehicle_id in ipairs(vehicle_ids) do
                                server.despawnVehicle(vehicle_id, true)
                            end
                            -- Remove the group from vehicletable
                            vehicletable[nearest_group] = nil
                            server.notify(user_peer_id, "Vehicle Returned", "$" .. string.format('%.0f', vehiclecost) .. " was refunded to your account", 8)
                        else
                            server.notify(user_peer_id, "Return Failed", "The shared bank does not have enough funds to refund you.", 8)
                        end
                    else
                        server.notify(user_peer_id, "Return Failed", "This vehicle does not belong to you", 8)
                    end
                else
                    server.notify(user_peer_id, "Return Failed", "No vehicle within 25m found", 8)
                end
            else
                server.notify(user_peer_id, "Bench Failed", "You do not have clearance to bench here", 8)
            end
        else
            server.notify(user_peer_id, "Return Failed", "You must be near a workbench you own", 8)
        end
    end
    

    -- ?lock (admin only)
    if command == "?lock" and is_admin then
        local nearest_group, nearest_dist = nearestVehicleGroup(user_peer_id)
        if nearest_dist <= 25 and nearest_group ~= -1 then
            local vehicle_ids = vehicletable[nearest_group].vehicle_ids
            for _, vehicle_id in ipairs(vehicle_ids) do
                server.setVehicleEditable(vehicle_id, false)
            end
            server.notify(user_peer_id, "Vehicle Locked", "", 8)
        else
            server.notify(user_peer_id, "Lock Failed", "No vehicle within 25m found", 8)
        end
    end

    -- ?unlock (admin only)
    if command == "?unlock" and is_admin then
        local nearest_group, nearest_dist = nearestVehicleGroup(user_peer_id)
        if nearest_dist <= 25 and nearest_group ~= -1 then
            local vehicle_ids = vehicletable[nearest_group].vehicle_ids
            for _, vehicle_id in ipairs(vehicle_ids) do
                server.setVehicleEditable(vehicle_id, true)
            end
            server.notify(user_peer_id, "Vehicle Unlocked", "", 8)
        else
            server.notify(user_peer_id, "Unlock Failed", "No vehicle within 25m found", 8)
        end
    end

    -- ?recover
    if command == "?recover" then
        local islandname = getCurrentTileName(user_peer_id)
        local formattedname = getFormattedTileName(islandname)
        if isInPurchasedArea(user_peer_id) or string.find(formattedname, "Deposit") then
            local playername = server.getPlayerName(user_peer_id)
            if (not islandclaiming) or hasBenchAccess(playername, islandname) or getIslandOwner(islandname) == playername or isCoOwner(playername, islandname) or isHomeIsland(islandname) then
                local nearest_group, nearest_dist = nearestVehicleGroup(user_peer_id)
                if nearest_dist <= 10000 and nearest_group ~= -1 then
                    if ownsVehicle(user_peer_id, nearest_group) then
                        local vehiclecost = getVehicleCost(nearest_group)
                        local recovery_fee = math.floor(vehiclecost * recoverycostpercent)
                        local refund = vehiclecost - recovery_fee
                        if getSharedBank() >= refund then
                            addBank(user_peer_id, refund)
                            addSharedBank(-refund)
                            setLastVehicle(user_peer_id, -1)
                            -- Despawn all vehicles in the group
                            local vehicle_ids = vehicletable[nearest_group].vehicle_ids
                            for _, vehicle_id in ipairs(vehicle_ids) do
                                server.despawnVehicle(vehicle_id, true)
                            end
                            -- Remove the group from vehicletable
                            vehicletable[nearest_group] = nil
                            server.notify(user_peer_id, "Vehicle Recovered", "$" .. string.format('%.0f', refund) .. " was refunded to your account after a " .. (recoverycostpercent * 100) .. "% ($" .. recovery_fee .. ") recovery fee", 8)
                        else
                            server.notify(user_peer_id, "Recovery Failed", "The shared bank does not have enough funds to refund you.", 8)
                        end
                    else
                        server.notify(user_peer_id, "Return Failed", "This vehicle does not belong to you", 8)
                    end
                else
                    server.notify(user_peer_id, "Return Failed", "No vehicle within 10km found", 8)
                end
            else
                server.notify(user_peer_id, "Recover Failed", "You do not have clearance to recover here", 8)
            end
        else
            server.notify(user_peer_id, "Return Failed", "You must be near a workbench you own", 8)
        end
    end
    

    -- ?tilename (admin only)
    if command == "?tilename" and is_admin then
        local tilename = getCurrentTileName(user_peer_id)
        server.notify(user_peer_id, "Tile Name", tilename, 8)
    end

    if command == "?deposit" then
        local amount = tonumber(args[1])
        if amount and amount > 0 then
            if getBank(user_peer_id) >= amount then
                addBank(user_peer_id, -amount)
                addSharedBank(amount)
                server.notify(-1, server.getPlayerName(user_peer_id) .. " has deposited $" .. amount,
                    "Shared Bank: $" .. getSharedBank(), 8)
            else
                server.notify(user_peer_id, "Deposit Failed", "You only have $" .. getBank(user_peer_id), 8)
            end
        else
            server.notify(user_peer_id, "Invalid number", "Please enter a valid number", 8)
        end
    end

    -- ?claim
    if command == "?claim" then
        local amount = tonumber(args[1])
        if amount and amount > 0 then
            if getSharedBank() >= amount then
                addBank(user_peer_id, amount)
                addSharedBank(-amount)
                server.notify(-1, server.getPlayerName(user_peer_id) .. " has claimed $" .. amount,
                    "Shared Bank: $" .. getSharedBank(), 8)
            else
                server.notify(user_peer_id, "Claim Failed", "The shared bank only has $" .. getSharedBank(), 8)
            end
        else
            server.notify(user_peer_id, "Invalid number", "Please enter a valid number", 8)
        end
    end

    -- ?buyfuel
    if command == "?buyfuel" then
        local fuel_type = args[1]
        local amount = tonumber(args[2])
        if getLastVehicle(user_peer_id) ~= -1 and fuel_type and amount then
            if isInMainland(user_peer_id) then
                if isInPurchasedArea(user_peer_id) then
                    if fuel_type == "diesel" or fuel_type == "jetfuel" then
                        local total_cost = amount * fuelcostperliter
                        if getBank(user_peer_id) >= total_cost then
                            addBank(user_peer_id, -total_cost)
                            local tank_type = (fuel_type == "diesel") and 1 or 2
                            local last_group = getLastVehicle(user_peer_id)
                            local vehicle_ids = vehicletable[last_group].vehicle_ids
                            for _, vehicle_id in ipairs(vehicle_ids) do
                                server.setVehicleTank(vehicle_id, "", amount, tank_type)
                            end
                            server.notify(user_peer_id, "Fueling Successful",
                                amount .. "L " .. fuel_type .. " purchased for $" .. total_cost, 8)
                        else
                            server.notify(user_peer_id, "Fueling Failed", "You do not have enough cash", 8)
                        end
                    else
                        server.notify(user_peer_id, "Fueling Failed", "You must enter diesel or jetfuel", 8)
                    end
                else
                    server.notify(user_peer_id, "Fueling Failed", "You must be near a workbench you own", 8)
                end
            else
                server.notify(user_peer_id, "Fueling Failed",
                    "You can only purchase fuel on the mainland and main islands", 8)
            end
        else
            server.notify(user_peer_id, "Fueling Failed", "You must be in a vehicle to do this", 8)
        end
    end
    -- Island Management Commands
    -- Island Management Commands

    -- ?access
    if command == "?access" then
        if islandclaiming then
            local hometile = server.getStartTile()
            local hometilename = hometile["name"]
            local hometileformattedname = getFormattedTileName(hometilename)
            local accessstring = hometileformattedname .. ": Home"

            for k, v in pairs(islandtable) do
                local island_tile_name = v[1]
                local islandformattedname = getFormattedTileName(island_tile_name)

                if getIslandOwner(island_tile_name) == playername then
                    accessstring = accessstring .. "\n" .. islandformattedname .. ": Owner"
                elseif isCoOwner(playername, island_tile_name) then
                    accessstring = accessstring .. "\n" .. islandformattedname .. ": Co-Owner"
                else
                    local permissions = {}
                    if hasTeleportAccess(playername, island_tile_name) then
                        table.insert(permissions, "Teleport")
                    end
                    if hasSpawnAccess(playername, island_tile_name) then
                        table.insert(permissions, "Spawn")
                    end
                    if hasBenchAccess(playername, island_tile_name) then
                        table.insert(permissions, "Bench")
                    end
                    if #permissions > 0 then
                        accessstring = accessstring .. "\n" .. islandformattedname .. ": " ..
                                           table.concat(permissions, ", ")
                    end
                end
            end
            server.announce("Access", accessstring, user_peer_id)
        else
            server.notify(user_peer_id, "Island Claiming Disabled", "This command has been disabled by server settings",
                8)
        end
    end

    -- ?islandaccess (island name)
    if command == "?islandaccess" then
        if islandclaiming then
            local islandformattedname = args[1]
            local islandtilename = getTileIDFromName(islandformattedname)
            if islandtilename ~= "NotFound" then
                if getIslandOwner(islandtilename) == playername or isCoOwner(playername, islandtilename) then
                    -- Owner
                    server.announce("Owner", getIslandOwner(islandtilename), user_peer_id)
                    -- Co-Owners
                    local coowners = getIslandCoOwners(islandtilename)
                    local coownersstring = tableToFormattedString(coowners)
                    if coownersstring ~= "" then
                        server.announce("Co-Owners", coownersstring, user_peer_id)
                    end
                    -- Teleport Access
                    local teleportaccess = getIslandTeleportAccess(islandtilename)
                    local teleportaccessstring = tableToFormattedString(teleportaccess)
                    if teleportaccessstring ~= "" then
                        server.announce("Teleport Access", teleportaccessstring, user_peer_id)
                    end
                    -- Spawn Access
                    local spawnaccess = getIslandSpawnAccess(islandtilename)
                    local spawnaccessstring = tableToFormattedString(spawnaccess)
                    if spawnaccessstring ~= "" then
                        server.announce("Spawn Access", spawnaccessstring, user_peer_id)
                    end
                    -- Bench Access
                    local benchaccess = getIslandBenchAccess(islandtilename)
                    local benchaccessstring = tableToFormattedString(benchaccess)
                    if benchaccessstring ~= "" then
                        server.announce("Bench Access", benchaccessstring, user_peer_id)
                    end
                else
                    server.notify(user_peer_id, "Request Failed", "You do not have clearance to see this", 8)
                end
            else
                server.notify(user_peer_id, "Request Failed", "Island not found", 8)
            end
        else
            server.notify(user_peer_id, "Island Claiming Disabled", "This command has been disabled by server settings",
                8)
        end
    end

 -- ?claimisland
if command == "?claimisland" then
    if islandclaiming then
        local islandname = getCurrentTileName(user_peer_id)
        local formattedname = getFormattedTileName(islandname)
        local islandowner = getIslandOwner(islandname)
        local is_purchased = isInPurchasedArea(user_peer_id)
        if is_purchased or string.find(formattedname, "Deposit") then
            if not isHomeIsland(islandname) then
                if formattedname ~= "NotFound" then
                    if islandowner == "Unowned" then
                        if getBank(user_peer_id) >= 50000 then
                            -- Deduct $50,000 from player's bank
                            addBank(user_peer_id, -50000)
                            server.notify(user_peer_id, "Claim Successful", "You now own " .. formattedname .. ". $50,000 has been deducted from your account.", 8)
                            table.insert(islandtable, {islandname, playername, {}, {}, {}, {}, server.getPlayerPos(user_peer_id)})
                        else
                            server.notify(user_peer_id, "Claim Failed", "You need $50,000 to claim this island.", 8)
                        end
                    else
                        server.notify(user_peer_id, "Claim Failed", formattedname .. " is already owned by " .. islandowner, 8)
                    end
                else
                    server.notify(user_peer_id, "Claim Failed", "This area is not ownable", 8)
                end
            else
                server.notify(user_peer_id, "Claim Failed", "The starting area is not ownable", 8)
            end
        else
            server.notify(user_peer_id, "Claim Failed", "This island is not purchased", 8)
        end
    else
        server.notify(user_peer_id, "Island Claiming Disabled", "This command has been disabled by server settings", 8)
    end
end

-- ?unclaimisland
if command == "?unclaimisland" then
    if islandclaiming then
        local islandname = getCurrentTileName(user_peer_id)
        local formattedname = getFormattedTileName(islandname)
        local islandowner = getIslandOwner(islandname)
        if formattedname ~= "NotFound" then
            if islandowner == playername then
                local islandkey = getIslandKeyFromID(islandname)
                if islandkey ~= -1 then
                    islandtable[islandkey] = nil
                    -- Add $20,000 to player's bank
                    addBank(user_peer_id, 20000)
                    server.notify(user_peer_id, "Unclaim Successful", "You no longer own " .. formattedname .. ". $20,000 has been refunded to your account.", 8)
                else
                    server.notify(user_peer_id, "Unclaim Failed", "Island not found in islandtable.", 8)
                end
            else
                server.notify(user_peer_id, "Unclaim Failed", "You do not own " .. formattedname, 8)
            end
        else
            server.notify(user_peer_id, "Unclaim Failed", "This area is not ownable", 8)
        end
    else
        server.notify(user_peer_id, "Island Claiming Disabled", "This command has been disabled by server settings", 8)
    end
end



    -- ?setcoowner (player id) (island name)
    if command == "?setcoowner" then
        if islandclaiming then
            local target_id = tonumber(args[1])
            local islandformattedname = args[2]
            if target_id and islandformattedname then
                local targetname = server.getPlayerName(target_id)
                local islandtilename = getTileIDFromName(islandformattedname)
                if islandtilename ~= "NotFound" then
                    if target_id ~= user_peer_id then
                        if getIslandOwner(islandtilename) == playername or isCoOwner(playername, islandtilename) then
                            if getIslandOwner(islandtilename) ~= targetname then
                                local islandkey = getIslandKeyFromID(islandtilename)
                                if islandkey ~= -1 then
                                    if isCoOwner(targetname, islandtilename) then
                                        server.notify(user_peer_id, "Permission Removed", targetname ..
                                            " is no longer a co-owner of " .. islandformattedname, 8)
                                        local playerkey = searchTable(islandtable[islandkey][3], targetname)
                                        if playerkey ~= -1 then
                                            table.remove(islandtable[islandkey][3], playerkey)
                                        end
                                    else
                                        table.insert(islandtable[islandkey][3], targetname)
                                        server.notify(user_peer_id, "Permission Added",
                                            targetname .. " is now a co-owner of " .. islandformattedname, 8)
                                    end
                                else
                                    server.notify(user_peer_id, "Permission Failed", "Island not found in islandtable",
                                        8)
                                end
                            else
                                server.notify(user_peer_id, "Permission Failed",
                                    "That player is the owner of the island", 8)
                            end
                        else
                            server.notify(user_peer_id, "Permission Failed", "You do not own this island", 8)
                        end
                    else
                        server.notify(user_peer_id, "Permission Failed", "You cannot edit your own permissions", 8)
                    end
                else
                    server.notify(user_peer_id, "Permission Failed", "Island not found", 8)
                end
            else
                server.notify(user_peer_id, "Command Failed", "Invalid arguments", 8)
            end
        else
            server.notify(user_peer_id, "Island Claiming Disabled", "This command has been disabled by server settings",
                8)
        end
    end

    -- ?setteleport (player id) (island name)
    if command == "?setteleport" then
        if islandclaiming then
            -- Rest of the command code here
        else
            server.notify(user_peer_id, "Island Claiming Disabled", "This command has been disabled by server settings",
                8)
        end
    end

    -- ?setspawn (player id) (island name)
    if command == "?setspawn" then
        if islandclaiming then
            -- Rest of the command code here
        else
            server.notify(user_peer_id, "Island Claiming Disabled", "This command has been disabled by server settings",
                8)
        end
    end

    -- ?setbench (player id) (island name)
    if command == "?setbench" then
        if islandclaiming then
            -- Rest of the command code here
        else
            server.notify(user_peer_id, "Island Claiming Disabled", "This command has been disabled by server settings",
                8)
        end
    end

    if command == "?teleport" or command == "?tp" then
        if islandclaiming then
            local island_formatted_name = args[1]
            local island_name = getTileIDFromName(island_formatted_name)
            if island_name ~= "NotFound" then
                local playername = server.getPlayerName(user_peer_id)
                if getIslandOwner(island_name) == playername or isCoOwner(playername, island_name) or hasTeleportAccess(playername, island_name) or isHomeIsland(island_name) then
                    if isHomeIsland(island_name) then
                        local hometile = server.getStartTile()
                        local x = hometile["x"]
                        local y = hometile["y"]
                        local z = hometile["z"]
                        local loc = matrix.translation(x, y, z)
                        server.setPlayerPos(user_peer_id, loc)
                    else
                        local island_data = islandtable[island_name]
                        if island_data then
                            local loc = island_data.location
                            server.setPlayerPos(user_peer_id, loc)
                        else
                            server.notify(user_peer_id, "Teleport Failed", "Island not found in islandtable", 8)
                        end
                    end
                else
                    server.notify(user_peer_id, "Teleport Failed", "You do not have clearance to teleport to " .. island_formatted_name, 8)
                end
            else
                server.notify(user_peer_id, "Teleport Failed", "Island not found", 8)
            end
        else
            server.notify(user_peer_id, "Island Claiming Disabled", "This command has been disabled by server settings", 8)
        end
    end
    
end

function onGroupSpawn(group_id, peer_id, x, y, z, cost)
    if (peer_id > -1) then
        local playername = server.getPlayerName(peer_id)
        local islandname = getCurrentTileName(peer_id)
        if (not islandclaiming) or hasSpawnAccess(playername, islandname) or isHomeIsland(islandname) then
            if (cost ~= 2) then
                if (getDebt(peer_id) <= maxdebt) then
                    if (getBank(peer_id) >= cost) then
                        addBank(peer_id, -cost)
                        addSharedBank(cost)
                        -- Get all vehicle IDs in the group
                        local vehicle_ids, is_success = server.getVehicleGroup(group_id)
                        if is_success then
                            -- Store group info including vehicle IDs
                            vehicletable[group_id] = {
                                owner_name = playername,
                                cost = cost,
                                vehicle_ids = vehicle_ids
                            }
                            -- Set all vehicles in the group to editable
                            for _, vehicle_id in ipairs(vehicle_ids) do
                                server.setVehicleEditable(vehicle_id, false)
                            end
                            server.notify(peer_id, "Vehicle Purchased", "$" .. string.format('%.0f', getBank(peer_id)) .. " remains", 8)
                        else
                            server.despawnVehicleGroup(group_id, true)
                            server.notify(peer_id, "Spawn Failed", "Could not retrieve vehicle group information.", 8)
                        end
                    else
                        server.despawnVehicleGroup(group_id, true)
                        server.notify(peer_id, "Not enough money", "You need $" .. (cost - getBank(peer_id)) .. " more.", 8)
                    end
                else
                    server.despawnVehicleGroup(group_id, true)
                    server.notify(peer_id, "Debt too high", "You must get your debt below $" .. maxdebt .. " to spawn a vehicle", 8)
                end
            else
                server.despawnVehicleGroup(group_id, true)
                server.notify(-1, playername .. " accidentally spawned the Cube of Shame", "Everybody point and laugh", 8)
            end
        else
            server.despawnVehicleGroup(group_id, true)
            server.notify(peer_id, "Purchase Failed", "You do not have clearance to spawn here", 8)
        end
    end
end

-- Adjusted onVehicleDespawn function
function onVehicleDespawn(vehicle_id, peer_id)
    -- Find the group this vehicle belongs to
    local group_id = getGroupIDFromVehicleID(vehicle_id)
    if group_id ~= -1 then
        local group_info = vehicletable[group_id]
        if group_info then
            -- Remove the vehicle from the group's vehicle_ids list
            for i, v_id in ipairs(group_info.vehicle_ids) do
                if v_id == vehicle_id then
                    table.remove(group_info.vehicle_ids, i)
                    break
                end
            end

            -- If all vehicles in the group have been despawned, remove the group from vehicletable
            if #group_info.vehicle_ids == 0 then
                vehicletable[group_id] = nil
            end
        end
    end
end

-- Helper function to get group_id from vehicle_id
function getGroupIDFromVehicleID(vehicle_id)
    for group_id, group_info in pairs(vehicletable) do
        for _, v_id in ipairs(group_info.vehicle_ids) do
            if v_id == vehicle_id then
                return group_id
            end
        end
    end
    return -1
end

function onPlayerSit(peer_id, vehicle_id, seat_name)
    local group_id = getGroupIDFromVehicleID(vehicle_id)
    setLastVehicle(peer_id, group_id)
end

function onPlayerUnsit(peer_id, vehicle_id, seat_name)
    setLastVehicle(peer_id, -1)
end

function onPlayerRespawn(peer_id)
    setLastVehicle(peer_id, -1)
    teleportHome(peer_id)
    if (getBank(peer_id) >= hospitalbill) then
        addBank(peer_id, -hospitalbill)
        server.notify(peer_id, "Hospital Bills", "$" .. hospitalbill .. " was deducted from your account", 8)
    else
        server.notify(peer_id, "Hospital Bills", "$" .. getBank(peer_id) .. " was deducted from your account", 8)
        setBank(peer_id, 0)
    end
end

-- Implement other necessary adjustments, ensuring that all vehicle interactions use group IDs

-- Implement the getFormattedTileName and getTileIDFromName functions as in your original script

-- Continue to adjust any remaining functions and commands to work with vehicle groups and the updated shared bank system
function getFormattedTileName(tile_id)
    --Base Tiles
    if (tile_id) == "data/tiles/island_33_tile_end.xml" then return "Camodo" end
    if (tile_id) == "data/tiles/island_33_tile_32.xml" then return "Spycakes" end
    if (tile_id) == "data/tiles/island_33_tile_33.xml" then return "Dreimor" end
    if (tile_id) == "data/tiles/island_43_multiplayer_base.xml" then return "MPI" end
    if (tile_id) == "data/tiles/island_15.xml" then return "Coastguard" end
    if (tile_id) == "data/tiles/test_tile.xml" then return "CoastguardTT" end
    if (tile_id) == "data/tiles/island12.xml" then return "CoastguardB" end
    if (tile_id) == "data/tiles/island_24.xml" then return "Airstrip" end
    if (tile_id) == "data/tiles/island_34_military.xml" then return "Military" end
    if (tile_id) == "data/tiles/island_25.xml" then return "Harbor" end
    if (tile_id) == "data/tiles/mega_island_9_8.xml" then return "NorthHarbor" end
    if (tile_id) == "data/tiles/mega_island_2_6.xml" then return "Harrison" end
    if (tile_id) == "data/tiles/mega_island_12_6.xml" then return "ONeill" end
    if (tile_id) == "data/tiles/mega_island_15_2.xml" then return "FishingVillage" end
    if (tile_id) == "data/tiles/island_31_playerbase_combo.xml" then return "CustomSmallBoat" end
    if (tile_id) == "data/tiles/island_30_playerbase_boat.xml" then return "CustomLargeBoat" end
    if (tile_id) == "data/tiles/island_32_playerbase_heli.xml" then return "CustomHeli" end
    if (tile_id) == "data/tiles/island_29_playerbase_submarine.xml" then return "CustomSub" end
    if (tile_id) == "data/tiles/oil_rig_playerbase.xml" then return "CustomRig" end
    if (tile_id) == "data/tiles/arctic_tile_22.xml" then return "Endo" end
    if (tile_id) == "data/tiles/arctic_tile_12_oilrig.xml" then return "Trinite" end
    if (tile_id) == "data/tiles/arctic_island_playerbase.xml" then return "Tajin" end
    --Desert Tiles
    if (tile_id) == "data/tiles/arid_island_5_14.xml" then return "NorthMeier" end
    if (tile_id) == "data/tiles/arid_island_8_15.xml" then return "Uran" end
    if (tile_id) == "data/tiles/arid_island_6_7.xml" then return "Serpentine" end
    if (tile_id) == "data/tiles/arid_island_7_5.xml" then return "Ender" end
    if (tile_id) == "data/tiles/arid_island_11_14.xml" then return "Brainz" end
    if (tile_id) == "data/tiles/arid_island_12_10.xml" then return "Mauve" end
    if (tile_id) == "data/tiles/arid_island_19_12.xml" then return "Monkey" end
    if (tile_id) == "data/tiles/arid_island_19_11.xml" then return "Clarke" end
    if (tile_id) == "data/tiles/arid_island_24_3.xml" then return "JSI" end
    if (tile_id) == "data/tiles/arid_island_26_14.xml" then return "FJWarner" end
    --Desert Oil Deposits
    if (tile_id) == "data/tiles/arid_island_23_14.xml" then return "CarnivoreDeposit" end
    if (tile_id) == "data/tiles/arid_island_24_4.xml" then return "JSIDeposit" end
    if (tile_id) == "data/tiles/arid_island_3_12.xml" then return "TurmoildDeposit" end
    if (tile_id) == "data/tiles/arid_island_8_11.xml" then return "ShymavanDeposit" end
    return "NotFound"
    end
    
    function getTileIDFromName(formatted_name)
    --Base Tiles
    if (formatted_name) == "Camodo" then return "data/tiles/island_33_tile_end.xml" end
    if (formatted_name) == "Spycakes" then return "data/tiles/island_33_tile_32.xml" end
    if (formatted_name) == "Dreimor" then return "data/tiles/island_33_tile_33.xml" end
    if (formatted_name) == "MPI" then return "data/tiles/island_43_multiplayer_base.xml" end
    if (formatted_name) == "Coastguard" then return "data/tiles/island_15.xml" end
    if (formatted_name) == "CoastguardTT" then return "data/tiles/test_tile.xml" end
    if (formatted_name) == "CoastguardB" then return "data/tiles/island12.xml" end
    if (formatted_name) == "Airstrip" then return "data/tiles/island_24.xml" end
    if (formatted_name) == "Military" then return "data/tiles/island_34_military.xml" end
    if (formatted_name) == "Harbor" then return "data/tiles/island_25.xml" end
    if (formatted_name) == "NorthHarbor" then return "data/tiles/mega_island_9_8.xml" end
    if (formatted_name) == "Harrison" then return "data/tiles/mega_island_2_6.xml" end
    if (formatted_name) == "ONeill" then return "data/tiles/mega_island_12_6.xml" end
    if (formatted_name) == "FishingVillage" then return "data/tiles/mega_island_15_2.xml" end
    if (formatted_name) == "CustomSmallBoat" then return "data/tiles/island_31_playerbase_combo.xml" end
    if (formatted_name) == "CustomLargeBoat" then return "data/tiles/island_30_playerbase_boat.xml" end
    if (formatted_name) == "CustomHeli" then return "data/tiles/island_32_playerbase_heli.xml" end
    if (formatted_name) == "CustomSub" then return "data/tiles/island_29_playerbase_submarine.xml" end
    if (formatted_name) == "CustomRig" then return "data/tiles/oil_rig_playerbase.xml" end
    if (formatted_name) == "Endo" then return "data/tiles/arctic_tile_22.xml" end
    if (formatted_name) == "Trinite" then return "data/tiles/arctic_tile_12_oilrig.xml" end
    if (formatted_name) == "Tajin" then return "data/tiles/arctic_island_playerbase.xml" end
    --Desert Tiles
    if (formatted_name) == "NorthMeier" then return "data/tiles/arid_island_5_14.xml" end
    if (formatted_name) == "Uran" then return "data/tiles/arid_island_8_15.xml" end
    if (formatted_name) == "Serpentine" then return "data/tiles/arid_island_6_7.xml" end
    if (formatted_name) == "Ender" then return "data/tiles/arid_island_7_5.xml" end
    if (formatted_name) == "Brainz" then return "data/tiles/arid_island_11_14.xml" end
    if (formatted_name) == "Mauve" then return "data/tiles/arid_island_12_10.xml" end
    if (formatted_name) == "Monkey" then return "data/tiles/arid_island_19_12.xml" end
    if (formatted_name) == "Clarke" then return "data/tiles/arid_island_19_11.xml" end
    if (formatted_name) == "JSI" then return "data/tiles/arid_island_24_3.xml" end
    if (formatted_name) == "FJWarner" then return "data/tiles/arid_island_26_14.xml" end
    --Desert Oil Deposits
    if (formatted_name) == "CarnivoreDeposit" then return "data/tiles/arid_island_23_14.xml" end
    if (formatted_name) == "JSIDeposit" then return "data/tiles/arid_island_24_4.xml" end
    if (formatted_name) == "TurmoildDeposit" then return "data/tiles/arid_island_3_12.xml" end
    if (formatted_name) == "ShymavanDeposit" then return "data/tiles/arid_island_8_11.xml" end
    return "NotFound"
    end