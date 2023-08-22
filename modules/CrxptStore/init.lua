-- Table Definitions
local CrxptStore = {}
local CrxptDataStore = {}
local Account = {}

CrxptDataStore.__index = CrxptDataStore

-- Private Variables
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Configuration = {
    AutoSaveDuration = 30,
    AssumeDeadSessionLock = 60 * 30
}

-- Class: CrxptDataStore
function CrxptDataStore.GetStore(storeKey, defaultData)
    local self = setmetatable({}, CrxptDataStore)

    self.Store = DataStoreService:GetDataStore(storeKey)
    self.StoreKey = storeKey
    self.DefaultData = defaultData

    return self
end

function CrxptDataStore:LoadAccount(playerKey, loadMethod)
    local account

    if loadMethod == "Force" then
        local data, message = pcall(function(currentData)
            return DataStoreService:GetAsync(playerKey)
        end)

        -- error handle
    end

    return account
end

-- Account Class
function Account:Register(playerKey, loadMethod)
    local self = setmetatable({}, Account)

    self.Data =  {} -- Placeholder for player data
    self.LockDate = 0
    self.Session = game.JobId
    self.Version = 0

    return self
end

function Account:Save()
    -- Save account data to the data store
end

function Account:Free()
    -- Free account data
end

function Account:OnFree(callback)
    -- Execute callback when account data is freed
end

-- Class: CrxptStore
function CrxptStore:GetStore(storeKey, defaultData)
    local store = CrxptDataStore:GetStore(storeKey, defaultData)

    return store
end

-- Runtime
task.spawn(function()
    while task.wait(Configuration.AutoSaveDuration) do
        
    end
end)

game:BindToClose(function()
    CrxptStore.Locked = true

    local activeAccounts = {}
    local jobCount = 0

    for key, account in CrxptStore.AutoSaveList do
        activeAccounts[key] = account
    end

    for _, account in activeAccounts do
        if account:IsActive() then
            jobCount += 1
            
            task.spawn(function()
                saveAccount(account)
                jobCount -= 1
            end)
        end
    end
end)

-- Return the CrxptStore class
return CrxptStore
