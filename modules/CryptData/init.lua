local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Class Definitions
local CryptStore = {
    StoreLocked = false,
    NoSave = false,
    
    AutoSaveList = {}    
}

local CryptDataStore = {}
CryptDataStore.__index = CryptDataStore

local Account = {}

-- Private Variables
local placeId = game.PlaceId
local jobId = game.JobId

local liveCheck = false
local lastSave = os.clock()

local saveIndex = 1
local loadIndex = 0

local activeSaveJobs = 0
local activeLoadJobs = 0

local isStudio = RunService:IsStudio()
local isLiveCheckActive =false

local Configuration = {
    AutoSaveDuration = 30,
    AssumeDeadSessionLock = 60 * 30
}

-- Private Functions
local function deepCopy(tbl)
    local newTbl = {}

    for key, value in tbl do
        newTbl[key] = (type(value) == "table" and deepCopy(value)) or value
    end

    return newTbl
end

local function reconcile(tbl, tbl2)
    for key, value in tbl2 do
        if type(value) == "table" then
            tbl[key] = tbl[key] or {}
			reconcile(tbl[key], value)
        elseif tbl[key] == nil then
            tbl[key] = value
        end
    end
end

local function delayUntilLiveAccess()
    while isLiveCheckActive do
        task.wait()
    end
end

local function saveAccount(account)
    
end

-- Class: CryptStore
function CryptStore.GetStore(storeKey, defaultData)
    local self = setmetatable({}, CryptDataStore)

    self.GlobalDataStore = nil
    self.StoreKey = storeKey
    self.DefaultData = defaultData
    self.LoadedAccounts = {}
    self.LoadJobs = {}
    self.IsPending = false

    if isLiveCheckActive then
        self.IsPending = true

        task.spawn(function()
            delayUntilLiveAccess()
            
            if not CryptStore.NoSave then
                self.GlobalDataStore = DataStoreService:GetDataStore(storeKey)
            end

            self.IsPending = false
        end)
    elseif not CryptStore.NoSave then
        self.GlobalDataStore = DataStoreService:GetDataStore(storeKey)
    end

    return self
end

function CryptStore:IsLive()
    delayUntilLiveAccess()

    return not self.NoSave
end

-- Class: CryptDataStore
function CryptDataStore:LoadAccount(playerKey, loadMethod)
    local account

    if loadMethod == "Force" then
        local data, message = pcall(function(currentData)
            return DataStoreService:GetAsync(playerKey)
        end)

        if not data then

        end
    end

    return account
end

-- Class: Account
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

-- Runtime
RunService.Heartbeat:Connect(function()
    local saveLength = #CryptStore.AutoSaveList

    if saveLength < 1 then
        return
    end

    local saveSpeed = Configuration.AutoSaveDuration / saveLength
    local lastClock = os.clock()

    while lastClock - lastSave > saveSpeed do
        lastSave += saveSpeed

        local account = CryptStore.AutoSaveList[saveIndex]

        if lastClock - account.LoadTimestamp < Configuration.AutoSaveDuration then
            account = nil

            for _ = 1, saveLength do
                saveIndex += 1

                if saveIndex > saveLength then
                    saveIndex = 1
                end

                account = CryptStore.AutoSaveList[saveIndex]

                if lastClock - account.LoadTimestamp < Configuration.AutoSaveDuration then
                    account = nil
                else
                    break
                end
            end
        end

        saveIndex += 1

        if saveIndex > saveLength then
            saveIndex = 1
        end

        if account then
            task.spawn(saveAccount, account)
        end
    end
end)

-- Initialization
if isStudio then
    isLiveCheckActive = true

    task.spawn(function()
        local status, message = pcall(function()
            -- This will error if current instance has no Studio API access:
        	DataStoreService:GetDataStore("____CS"):SetAsync("____CS", os.time())
        end)
        
        local noInternetAccess = not status and message:find("ConnectFail", 1, true) ~= nil
        
        if noInternetAccess then
            warn("[CryptStore]: No internet access - check your network connection")
        end

        local condition =
            message:find("403", 1, true) ~= nil -- Cannot write to DataStore from studio if API access is not enabled
            or message:find("must publish", 1, true) ~= nil -- Game must be published to access live keys
            or noInternetAccess -- No internet access
        
        if not status and condition then
            CryptStore.NoSave = true
            print("[CryptStore]: Roblox API services unavailable - data will not be saved")
        else
            print("[CryptStore]: Roblox API services available - data will be saved")
        end

        isLiveCheckActive = false
    end)
end

game:BindToClose(function()
    delayUntilLiveAccess()
    CryptStore.StoreLocked = true

    local activeAccounts = {}
    local jobCount = 0

    for key, account in CryptStore.AutoSaveList do
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

return CryptStore
