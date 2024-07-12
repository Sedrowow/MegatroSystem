Noir.Started:Once(function()
    if Noir.AddonReason == "AddonReload" then
        server.cleanVehicles()
        server.announce("[MegatroSystem]", "The [MegatroSystem] has been reloaded ")
    elseif Noir.AddonReason == "SaveCreate" then
        server.announce("[MegatroSystem]", "A save was created with [MegatroSystem]")
    elseif Noir.AddonReason == "SaveLoad" then
        server.announce("[MegatroSystem]", "A save was loaded into with [MegatroSystem]")
    else -- don't worry! AddonReason will never be anything but AddonReload, SaveCreate, or SaveLoad
        server.announce("[MegatroSystem]", "something has gone wrong...")
    end
end)


Noir.Services.CommandService:CreateCommand("help", {"h"}, {"Nerd"}, false, false, false, "Example Command", function(player, message, args, hasPermission)
    if not hasPermission then
        player:Notify("Lacking Permissions", "Sorry, you don't have permission to run this command. Try again.", 3)
        player:SetPermission("Nerd")
        return
    end

    player:Notify("Help", "TODO: Add a help message", 4)
end)


Noir:Start()