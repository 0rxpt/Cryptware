local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Crypt = require(ReplicatedStorage.Cryptware.Crypt)

local Data = Crypt.Register({ Name = "Data" }, {
	"Profile"
})

function Data.Get.Profile(player)
	return Data.Profiles[player]
end

function Data.Set.Profile(player, newData)
	Data.Profiles[player].Data = newData
	return Data.Get.Profile(player)
end

function Data:Init()
	self.Profiles = {}
	self:HandlePlayers()
end

function Data:HandlePlayers()
	Players.PlayerAdded:Connect(function(player)
		self.Profiles[player] = { Data = {} }
		
		--[[
		local profile = Crypt.Get("Data", "Profile", player)
		print(profile.Data)
		]]
	end)
end

return Data
