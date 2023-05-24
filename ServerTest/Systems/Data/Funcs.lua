local Funcs = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

function Funcs:Init(Data)
	function Data:PlayerAdded(player)
		local profile
		if self.UseMock and RunService:IsStudio() then
			profile = self.ProfileStore.Mock:LoadProfileAsync("Player_" .. player.UserId)
		else
			profile = self.ProfileStore:LoadProfileAsync("Player_" .. player.UserId)
		end
		if profile ~= nil then
			profile:AddUserId(player.UserId)
			profile:Reconcile()
			profile:ListenToRelease(function()
				self.Profiles[player] = nil
				player:Kick()
			end)
			if player:IsDescendantOf(Players) == true then
				self.Profiles[player] = profile
			else
				profile:Release()
			end
		else
			player:Kick() 
		end
	end

	function Data:decyclic(t, p)
		local t1 = {}
		for k in pairs(t) do
			if table.find(p, t[k]) then 
				continue 
			end
			if typeof(t[k]) ~= "table" then
				t1[k] = t[k]
			else
				table.insert(p, t[k])
				t1[k] = t[k]
				local nonCyc = self:decyclic(t[k], p)
				for k1 in pairs(t1[k]) do
					if not nonCyc[k1] then
						t1[k][k1] = nil
					end
				end
			end
		end
		return t1
	end
end

return Funcs
