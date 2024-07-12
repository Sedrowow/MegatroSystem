Noir.Started:Once(function()
    if Noir.AddonReason == "AddonReload" then
        server.cleanVehicles()
        server.announce("[MegatroSystem]", "")
    elseif Noir.AddonReason == "SaveCreate" then
        server.announce("[MegatroSystem]", "A save was created with [MegatroSystem]")
    elseif Noir.AddonReason == "SaveLoad" then
        server.announce("[MegatroSystem]", "A save was loaded into with [MegatroSystem]")
    else -- don't worry! AddonReason will never be anything but AddonReload, SaveCreate, or SaveLoad
        server.announce("[MegatroSystem]", "something has gone wrong...")
    end
end)



Noir:Start()
server.announce("Server", "Noir hasn't started yet!")