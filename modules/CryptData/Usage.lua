local Players = game:GetService("Players")

local CryptData = require(game:GetService("ReplicatedStorage").CryptData)
local Accounts = {}

local DefaultData = {
    Cash = 0
}

local keyVersion = 10
local AccountStore = CryptData.GetStore("PlayerData_00" .. keyVersion, DefaultData)

local function getAccount(player)
    return Accounts[player]
end

local function playerAdded(player)
    local account = AccountStore:LoadAccount("Player_" .. player.UserId)

    if not account then
        player:Kick("Please rejoin.")

        return
    end

    account:Reconcile()
    account:OnFree(function()
        print("Freed ", player)
        Accounts[player] = nil
        player:Kick()
    end)

    if player:IsDescendantOf(Players) then
        Accounts[player] = account
        print("Loaded:", account)
        
        coroutine.wrap(function()
            while task.wait(10) do
                if not account:IsActive() then
                    break
                end
                
                account.Data.Cash += 1
            end
        end)()
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
