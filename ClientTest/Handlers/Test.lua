local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Crypt = require(ReplicatedStorage.Cryptware.Crypt)

local Test = Crypt.Register({ Name = "Test" })

function Test:Init()
	--print(`{self.Name} initialized`)
end

function Test:Start()
	--print(`{self.Name} started`)
	
	local Data = Crypt.Import("Data")
	local profile = Data.Profile:Set({
		["TestValue"] = "Works!"
	})
	
	print(profile)
end

return Test
