local Players = game:GetService("Players")

local CrxptStore = require(...)
local Accounts = {}

local DefaultData = {
	Cash = 0
}

local AccountStore = CrxptStore:GetStore("PlayerData", DefaultData)

local function getAccount(player)
	return Accounts[player]
end

local function playerAdded(player)
	local account = AccountStore:Load("Player_" .. player.UserId)

	if not account then
		player:Kick()
		
		return
	end

	account:Reconcile()
	account:OnFree(function()
		Accounts[player] = nil
		player:Kick()
	end)

	if player:IsDescendantOf(Players) then
		Accounts[player] = account
		
		print(account)
	else
		account:Free()
	end
end

local function playerRemoving(player)
	local account = getAccount(player)

	if not account then
		return
	end

	account:Free()
end

for _, player in Players:GetPlayers() do
	task.spawn(playerAdded, player)
end

Players.PlayerAdded:Connect(playerAdded)
Players.PlayerRemoving:Connect(playerRemoving)
