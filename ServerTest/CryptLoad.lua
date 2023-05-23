local CryptServer = require("src/Crypt/CServer")
local Data = CryptServer:Register({ Name = "Data" }, { "Profile" })

function Data.Get.Profile(player)
    return "Got: " .. player
end

function Data.Set.Profile(player, value)
    return "Set: " .. player .. "\n  to: " .. value
end

local returned = CryptServer:Get("Data", "Profile", "encrxpt3d")
print(returned)