-- Script for managing shared bank, vehicle ownership, and island claiming.


-- Global variables
playertable = {}
vehicletable = {}
islandtable = {}
datatable = { incometax = 0.1 }
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
negativetaxdebt = true
  -- Set this to true or false based on your server settings

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

function saveTables()
    g_savedata.playertable = playertable
    g_savedata.vehicletable = vehicletable
    g_savedata.islandtable = islandtable
    g_savedata.datatable = datatable
    -- shared_bank is already in g_savedata
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



function isInMainland(target_id)
    local playerloc = server.getPlayerPos(target_id)
    local x, y, z = matrix.position(playerloc)
    if (z < 0 and z > -14000) then
        return true
    else
        return false
    end
end
-- Functions for shared bank management
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

-- Player bank functions
function getBank(peer_id)
    if playertable[peer_id] and playertable[peer_id].bank then
        return playertable[peer_id].bank
    else
        return 0
    end
end

function addBank(peer_id, amount)
    if not playertable[peer_id] then
        playertable[peer_id] = { bank = 0, debt = 0, last_vehicle = -1 }
    end
    playertable[peer_id].bank = playertable[peer_id].bank + amount
end

function getDebt(peer_id)
    if playertable[peer_id] and playertable[peer_id].debt then
        return playertable[peer_id].debt
    else
        return 0
    end
end

function addDebt(peer_id, amount)
    if not playertable[peer_id] then
        playertable[peer_id] = { bank = 0, debt = 0, last_vehicle = -1 }
    end
    playertable[peer_id].debt = playertable[peer_id].debt + amount
end

-- Vehicle ownership functions
function ownsVehicle(peer_id, group_id)
    local playername = server.getPlayerName(peer_id)
    local group_info = vehicletable[group_id]
    if group_info and group_info.owner_name == playername then
        return true
    end
    return false
end

function nearestVehicleGroup(peer_id)
    local player_pos = server.getPlayerPos(peer_id)
    local nearest_group = -1
    local nearest_distance = math.huge

    for group_id, group_info in pairs(vehicletable) do
        for _, vehicle_id in ipairs(group_info.vehicle_ids) do
            local vehicle_pos = server.getVehiclePos(vehicle_id)
            local dist = matrix.distance(player_pos, vehicle_pos)
            if dist < nearest_distance then
                nearest_distance = dist
                nearest_group = group_id
            end
        end
    end

    return nearest_group, nearest_distance
end

function getVehicleCost(group_id)
    local group_info = vehicletable[group_id]
    if group_info then
        return group_info.cost
    else
        return 0
    end
end

-- Vehicle spawn and despawn handling
function onGroupSpawn(group_id, peer_id, x, y, z, cost)
    if (peer_id > -1) then
        local playername = server.getPlayerName(peer_id)
        local islandname = getCurrentTileName(peer_id)
        if (not islandclaiming) or hasSpawnAccess(playername, islandname) or isHomeIsland(islandname) then
            if (cost ~= 2) then
                if (getDebt(peer_id) >= maxdebt) then
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

function onVehicleSpawn(vehicle_id, peer_id, x, y, z, cost)
    if peer_id > -1 then
        local playername = server.getPlayerName(peer_id)
        local vehicle_ids = { vehicle_id }
        local group_id = vehicle_id  -- Use vehicle_id as group_id for individual vehicles

        -- Store vehicle info in vehicletable
        vehicletable[group_id] = {
            owner_name = playername,
            cost = cost,
            vehicle_ids = vehicle_ids
        }

        -- Set vehicle to editable
        server.setVehicleEditable(vehicle_id, false)

        -- Notify player
        server.notify(peer_id, "Vehicle Purchased", "$" .. string.format('%.0f', getBank(peer_id)) .. " remains", 8)
    end
end

function onVehicleDespawn(vehicle_id, peer_id)
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

-- Player sit and unsit handling
function onPlayerSit(peer_id, vehicle_id, seat_name)
    local group_id = getGroupIDFromVehicleID(vehicle_id)
    setLastVehicle(peer_id, group_id)
end

function onPlayerUnsit(peer_id, vehicle_id, seat_name)
    setLastVehicle(peer_id, -1)
end

function setLastVehicle(peer_id, group_id)
    if not playertable[peer_id] then
        playertable[peer_id] = { bank = 0, debt = 0, last_vehicle = -1 }
    end
    playertable[peer_id].last_vehicle = group_id
end

-- Command handling
function onCustomCommand(full_message, user_peer_id, is_admin, is_auth, command, ...)
    local args = { ... }
    local playername = server.getPlayerName(user_peer_id)

    -- ?help command
    if command == "?help" then
        server.announce("Commands", "?bank\n?deposit (amount)\n?claim (amount)\n?pay (player id) (amount)\n?loan (amount)\n?payloan (amount)\n?bench\n?recover [" .. string.format('%.0f', recoverycostpercent * 100) .. "% vehicle cost fee]\n?lock\n?unlock\n?savegame", user_peer_id)
        server.announce("Island Commands", "?claimisland\n?unclaimisland\n?setcoowner (player id) (island name)\n?setteleport (player id) (island name)\n?setspawn (player id) (island name)\n?setbench (player id) (island name)\n?teleport (island name)\n?access", user_peer_id)
    end

    -- Include all the other commands and functions as defined earlier
    -- ?bench, ?recover, ?lock, ?unlock, island commands, etc.
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
    -- ?bench command
    if command == "?bench" or command == "?c" then
        local islandname = getCurrentTileName(user_peer_id)
        local formattedname = getFormattedTileName(islandname)
        if isInPurchasedArea(user_peer_id) or string.find(formattedname, "Deposit") then
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

    -- ?recover command
    if command == "?recover" then
        local islandname = getCurrentTileName(user_peer_id)
        local formattedname = getFormattedTileName(islandname)
        if isInPurchasedArea(user_peer_id) or string.find(formattedname, "Deposit") then
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

    -- ?lock command
    if command == "?lock" then
        local nearest_group, nearest_dist = nearestVehicleGroup(user_peer_id)
        if nearest_dist <= 25 and nearest_group ~= -1 then
            if ownsVehicle(user_peer_id, nearest_group) then
                local vehicle_ids = vehicletable[nearest_group].vehicle_ids
                for _, vehicle_id in ipairs(vehicle_ids) do
                    server.setVehicleEditable(vehicle_id, false)
                end
                server.notify(user_peer_id, "Vehicle Locked", "", 8)
            else
                server.notify(user_peer_id, "Lock Failed", "You do not own this vehicle", 8)
            end
        else
            server.notify(user_peer_id, "Lock Failed", "No vehicle within 25m found", 8)
        end
    end

    -- ?unlock command
    if command == "?unlock" then
        local nearest_group, nearest_dist = nearestVehicleGroup(user_peer_id)
        if nearest_dist <= 25 and nearest_group ~= -1 then
            if ownsVehicle(user_peer_id, nearest_group) then
                local vehicle_ids = vehicletable[nearest_group].vehicle_ids
                for _, vehicle_id in ipairs(vehicle_ids) do
                    server.setVehicleEditable(vehicle_id, true)
                end
                server.notify(user_peer_id, "Vehicle Unlocked", "", 8)
            else
                server.notify(user_peer_id, "Unlock Failed", "You do not own this vehicle", 8)
            end
        else
            server.notify(user_peer_id, "Unlock Failed", "No vehicle within 25m found", 8)
        end
    end

    -- Island claiming commands
    if islandclaiming then
        -- ?claimisland command
        if command == "?claimisland" then
            local island_name = getCurrentTileName(user_peer_id)
            local formatted_name = getFormattedTileName(island_name)
            local island_data = islandtable[island_name]

            if formatted_name ~= "NotFound" then
                if not isHomeIsland(island_name) then
                    if isInPurchasedArea(user_peer_id) or string.find(formatted_name, "Deposit") then
                        if not island_data then
                            if getBank(user_peer_id) >= 50000 then
                                -- Deduct $50,000 from player's bank
                                addBank(user_peer_id, -50000)

                                -- Add island to islandtable
                                islandtable[island_name] = {
                                    owner = playername,
                                    co_owners = {},
                                    teleport_access = {},
                                    spawn_access = {},
                                    bench_access = {},
                                    location = server.getPlayerPos(user_peer_id),
                                }

                                server.notify(user_peer_id, "Claim Successful", "You now own " .. formatted_name .. ". $50,000 has been deducted from your account.", 8)
                            else
                                server.notify(user_peer_id, "Claim Failed", "You need $50,000 to claim this island.", 8)
                            end
                        else
                            server.notify(user_peer_id, "Claim Failed", formatted_name .. " is already owned by " .. island_data.owner, 8)
                        end
                    else
                        server.notify(user_peer_id, "Claim Failed", "This island is not purchased", 8)
                    end
                else
                    server.notify(user_peer_id, "Claim Failed", "The starting area is not ownable", 8)
                end
            else
                server.notify(user_peer_id, "Claim Failed", "This area is not ownable", 8)
            end
        end

        -- ?unclaimisland command
        if command == "?unclaimisland" then
            local island_name = getCurrentTileName(user_peer_id)
            local formatted_name = getFormattedTileName(island_name)
            local island_data = islandtable[island_name]

            if formatted_name ~= "NotFound" then
                if island_data and island_data.owner == playername then
                    -- Refund $20,000
                    addBank(user_peer_id, 20000)

                    -- Remove the island from islandtable
                    islandtable[island_name] = nil

                    server.notify(user_peer_id, "Unclaim Successful", "You no longer own " .. formatted_name .. ". $20,000 has been refunded to your account.", 8)
                else
                    server.notify(user_peer_id, "Unclaim Failed", "You do not own " .. formatted_name, 8)
                end
            else
                server.notify(user_peer_id, "Unclaim Failed", "This area is not ownable", 8)
            end
        end

        -- ?setcoowner command
        if command == "?setcoowner" then
            if islandclaiming then
                local target_id = tonumber(args[1])
                local island_formatted_name = args[2]
                local island_name = getTileIDFromName(island_formatted_name)
        
                if target_id and island_name then
                    local target_name = server.getPlayerName(target_id)
                    local island_data = islandtable[island_name]
        
                    if island_data then
                        if island_data.owner == playername or isCoOwner(playername, island_name) then
                            if target_name ~= island_data.owner then
                                local co_owners = island_data.co_owners
                                local is_co_owner = false
        
                                for i, co_owner in ipairs(co_owners) do
                                    if co_owner == target_name then
                                        table.remove(co_owners, i)
                                        is_co_owner = true
                                        break
                                    end
                                end
        
                                if is_co_owner then
                                    server.notify(user_peer_id, "Permission Removed", target_name .. " is no longer a co-owner of " .. island_formatted_name, 8)
                                else
                                    table.insert(co_owners, target_name)
                                    server.notify(user_peer_id, "Permission Added", target_name .. " is now a co-owner of " .. island_formatted_name, 8)
                                end
                            else
                                server.notify(user_peer_id, "Permission Failed", "Cannot modify permissions for the island owner.", 8)
                            end
                        else
                            server.notify(user_peer_id, "Permission Failed", "You do not have permission to modify this island.", 8)
                        end
                    else
                        server.notify(user_peer_id, "Permission Failed", "Island not found or not owned.", 8)
                    end
                else
                    server.notify(user_peer_id, "Command Failed", "Invalid arguments.", 8)
                end
            else
                server.notify(user_peer_id, "Island Claiming Disabled", "This command has been disabled by server settings.", 8)
            end
        end

        -- ?setteleport command
        if command == "?setteleport" then
            -- (Code as previously defined)
        end

        -- ?setspawn command
        if command == "?setspawn" then
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
                                    if hasSpawnAccess(targetname, islandtilename) then
                                        server.notify(user_peer_id, "Permission Removed", targetname .. " can no longer spawn vehicles at " .. islandformattedname, 8)
                                        local playerkey = searchTable(islandtable[islandkey][5], targetname)
                                        if playerkey ~= -1 then
                                            table.remove(islandtable[islandkey][5], playerkey)
                                        end
                                    else
                                        table.insert(islandtable[islandkey][5], targetname)
                                        server.notify(user_peer_id, "Permission Added", targetname .. " can now spawn vehicles at " .. islandformattedname, 8)
                                    end
                                else
                                    server.notify(user_peer_id, "Permission Failed", "Island not found in islandtable", 8)
                                end
                            else
                                server.notify(user_peer_id, "Permission Failed", "That player is the owner of the island", 8)
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
        end

        -- ?setbench command
        if command == "?setbench" then
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
                                    if hasBenchAccess(targetname, islandtilename) then
                                        server.notify(user_peer_id, "Permission Removed", targetname .. " can no longer bench vehicles at " .. islandformattedname, 8)
                                        local playerkey = searchTable(islandtable[islandkey][6], targetname)
                                        if playerkey ~= -1 then
                                            table.remove(islandtable[islandkey][6], playerkey)
                                        end
                                    else
                                        table.insert(islandtable[islandkey][6], targetname)
                                        server.notify(user_peer_id, "Permission Added", targetname .. " can now bench vehicles at " .. islandformattedname, 8)
                                    end
                                else
                                    server.notify(user_peer_id, "Permission Failed", "Island not found in islandtable", 8)
                                end
                            else
                                server.notify(user_peer_id, "Permission Failed", "That player is the owner of the island", 8)
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
        -- ?teleport command
        if command == "?teleport" or command == "?tp" then
            local islandformattedname = args[1]
            local islandtilename = getTileIDFromName(islandformattedname)
            if islandtilename ~= "NotFound" then
                if getIslandOwner(islandtilename) == playername or isCoOwner(playername, islandtilename) or hasTeleportAccess(playername, islandtilename) or isHomeIsland(islandtilename) then
                    if isHomeIsland(islandtilename) then
                        local hometile = server.getStartTile()
                        local x = hometile["x"]
                        local y = hometile["y"]
                        local z = hometile["z"]
                        local loc = matrix.translation(x, y, z)
                        server.setPlayerPos(user_peer_id, loc)
                    else
                        local islandkey = getIslandKeyFromID(islandtilename)
                        if islandkey ~= -1 then
                            local loc = islandtable[islandkey][7]
                            server.setPlayerPos(user_peer_id, loc)
                        else
                            server.notify(user_peer_id, "Teleport Failed", "Island not found in islandtable", 8)
                        end
                    end
                else
                    server.notify(user_peer_id, "Teleport Failed", "You do not have clearance to teleport to " .. islandformattedname, 8)
                end
            else
                server.notify(user_peer_id, "Teleport Failed", "Island not found", 8)
            end
        end

        -- ?access command
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
                            accessstring = accessstring .. "\n" .. islandformattedname .. ": " .. table.concat(permissions, ", ")
                        end
                    end
                end
                server.announce("Access", accessstring, user_peer_id)
            else
                server.notify(user_peer_id, "Island Claiming Disabled", "This command has been disabled by server settings", 8)
            end
        end

        -- ?islandaccess command
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
                server.notify(user_peer_id, "Island Claiming Disabled", "This command has been disabled by server settings", 8)
            end
        end

    else
        if command == "?access" or command == "?islandaccess" or command == "?claimisland" or command == "?unclaimisland" or command == "?setcoowner" or command == "?setteleport" or command == "?setspawn" or command == "?setbench" or command == "?teleport" or command == "?tp" then
            server.notify(user_peer_id, "Island Claiming Disabled", "This command has been disabled by server settings", 8)
        end
    end
    if command == "?addsharedbank" and is_admin then
        local amount = tonumber(args[1])
        if amount then
            addSharedBank(amount)
            server.notify(user_peer_id, "Shared Account Updated", "Balance: $" .. getSharedBank(), 8)
        else
            server.notify(user_peer_id, "Command Failed", "Invalid amount", 8)
        end
    end
    if command == "?claim" then
        local amount = tonumber(args[1])
        if amount and amount > 0 then
            if getSharedBank() >= amount then
                addBank(user_peer_id, amount)
                addSharedBank(-amount)
                server.notify(-1, server.getPlayerName(user_peer_id) .. " has claimed $" .. amount, "Shared Bank: $" .. getSharedBank(), 8)
            else
                server.notify(user_peer_id, "Claim Failed", "The shared bank only has $" .. getSharedBank(), 8)
            end
        else
            server.notify(user_peer_id, "Invalid number", "Please enter a valid number", 8)
        end
    end
    if command == "?deposit" then
        local amount = tonumber(args[1])
        if amount and amount > 0 then
            if getBank(user_peer_id) >= amount then
                addBank(user_peer_id, -amount)
                addSharedBank(amount)
                server.notify(-1, server.getPlayerName(user_peer_id) .. " has deposited $" .. amount, "Shared Bank: $" .. getSharedBank(), 8)
            else
                server.notify(user_peer_id, "Deposit Failed", "You only have $" .. getBank(user_peer_id), 8)
            end
        else
            server.notify(user_peer_id, "Invalid number", "Please enter a valid number", 8)
        end
    end
            
    -- Other commands (e.g., ?bank, ?deposit, ?claim, ?pay, etc.) would be implemented here as well.
end

-- Event handling functions
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
        datatable = { incometax = 0.1 }
        server.setCurrency(1000000, server.getResearchPoints())  -- Set server currency to 1,000,000
        saveGame()
    else
        playertable = g_savedata.playertable or {}
        vehicletable = g_savedata.vehicletable or {}
        islandtable = g_savedata.islandtable or {}
        datatable = g_savedata.datatable or { incometax = 0.1 }
        -- Do not reset server currency in existing worlds
    end
end

function onPlayerJoin(steam_id, name, peer_id, is_admin, is_auth)
    -- Initialize player data
    if not playertable[peer_id] then
        playertable[peer_id] = { bank = 0, debt = 0, last_vehicle = -1 }
    end
end

function onPlayerLeave(steam_id, name, peer_id, admin, auth)
    server.announce("[Server]", name .. " left the game")
    saveGame()
end

function onTick(game_ticks)
    incomeTax()
    accrueDebt()
    displayUI()
end

-- Helper functions
function isInPurchasedArea(peer_id)
    local pos = server.getPlayerPos(peer_id)
    return server.isPosInPurchasedArea(pos)
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

function isHomeIsland(island_name)
    local hometile = server.getStartTile()
    if hometile and hometile.name == island_name then
        return true
    else
        return false
    end
end

-- Island ownership and permission functions

function getIslandOwner(island_name)
    local island_data = islandtable[island_name]
    if island_data and island_data.owner then
        return island_data.owner
    else
        return "Unowned"
    end
end

function isCoOwner(player_name, island_name)
    local island_data = islandtable[island_name]
    if island_data and island_data.co_owners then
        for _, co_owner in ipairs(island_data.co_owners) do
            if co_owner == player_name then
                return true
            end
        end
    end
    return false
end

function hasSpawnAccess(player_name, island_name)
    local island_data = islandtable[island_name]
    if not island_data then
        return false
    end

    if island_data.owner == player_name then
        return true  -- Owners have spawn access
    end

    if isCoOwner(player_name, island_name) then
        return true  -- Co-owners have spawn access
    end

    for _, name in ipairs(island_data.spawn_access) do
        if name == player_name then
            return true
        end
    end

    return false
end

function hasBenchAccess(player_name, island_name)
    local island_data = islandtable[island_name]
    if not island_data then
        return false
    end

    if island_data.owner == player_name then
        return true  -- Owners have bench access
    end

    if isCoOwner(player_name, island_name) then
        return true  -- Co-owners have bench access
    end

    for _, name in ipairs(island_data.bench_access) do
        if name == player_name then
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

-- Utility functions for mapping island names and tile IDs
-- Ensure you define getFormattedTileName and getTileIDFromName functions in your script.

-- Remember to include any other required functions and event handlers.
function hasBenchAccess(player_name, island_tile_name)
    if isHomeIsland(island_tile_name) then return true end
    local access = getIslandBenchAccess(island_tile_name)
    for k, v in pairs(access) do
        if v == player_name then return true end
    end
    return false
end

function hasSpawnAccess(player_name, island_tile_name)
    if isHomeIsland(island_tile_name) then return true end
    local access = getIslandSpawnAccess(island_tile_name)
    for k, v in pairs(access) do
        if v == player_name then return true end
    end
    return false
end

function getIslandOwner(island_name)
    local island_data = islandtable[island_name]
    if island_data and island_data.owner then
        return island_data.owner
    else
        return "Unowned"
    end
end


function isCoOwner(player_name, island_name)
    local island_data = islandtable[island_name]
    if island_data and island_data.co_owners then
        for _, co_owner in ipairs(island_data.co_owners) do
            if co_owner == player_name then
                return true
            end
        end
    end
    return false
end


-- Save and load functions (e.g., saveGame) should also be implemented to persist data.

-- The rest of the commands and functions are included as per your request.
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