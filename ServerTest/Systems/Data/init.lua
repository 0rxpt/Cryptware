local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Crypt = require(ReplicatedStorage.Cryptware.Crypt)

local Data = Crypt.Register({ Name = "Data" }).Expose({
	RF = { "GetProfiles" },
	RE = {}
})

function Data:GetProfile(player)
	return self:decyclic(self.Profiles[player], {self.Profiles[player]})
end

function Data:GetProfiles()
	return self:decyclic(self.Profiles, {self.Profiles})
end

function Data:Init()
	local key = self.Util.KeyHandler:GetKey()

	local ProfileService = self.Util.ProfileService
	local DefaultData = self.Util.DefaultData

	self.ProfileStore = ProfileService.GetProfileStore(key, DefaultData)
	self.Profiles = {}
	self.UseMock = true

	require(script.Funcs):Init(self)
end

return Data
