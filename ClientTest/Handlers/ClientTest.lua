local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Crypt = require(ReplicatedStorage.Cryptware.Crypt)

local ClientTest = Crypt.Register({ Name = "ClientTest" })

function ClientTest:Start()
	local Data = Crypt.Import("Data")
	local profiles = Data:GetProfiles()
	
	print(profiles)
end

return ClientTest
