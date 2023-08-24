local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

export type _cryptDataStore = {
	GlobalDataStore: any,
	StoreKey: string,
	DefaultData: {},
	LoadedAccounts: {},
}

-- Class Definitions
local CryptData = {
	StoreLocked = false,
	TempDataStore = {},
	UserTempDataStore = {}
}

local CryptDataStore = {}
CryptDataStore.__index = CryptDataStore

local Account = {}

-- Private Variables
local placeId = game.PlaceId
local jobId = game.JobId

local liveCheck = false
local lastSave = os.clock()
local shouldntSave = false

local saveIndex = 1
local loadIndex = 0

local activeSaveJobs = 0
local activeLoadJobs = 0

local activeCryptDataStores = {}
local customWriteQueue = {}

local isStudio = RunService:IsStudio()
local isLiveCheckActive = false

local Configuration = {
	AutoSaveDuration = 30,
	AssumeDeadSessionLock = 60 * 30,
	
	ForceLoadMaxSteps = 8,
	RobloxWriteCooldown = 7,
	
	MetaTagsUpdatedValues = {
		AccountCreateTime = true,
		SessionLoadCount = true,
		ActiveSession = true,
		ForceLoadSession = true,
		LastUpdate = true
	}
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

local function identifyAccount(storeKey, accountKey)
	return string.format(
		"[Store:\"%s\";Key:\"%s\"]",
		storeKey,
		accountKey
	)
end

local function saveAccount(account, freeFromSession, isOverwriting)
	if type(account.Data) ~= "table" then
		error("[CryptData]: ACCOUNT DATA CORRUPTED DURING RUNTIME! Account: " .. account:Identify())
	end
	
	activeSaveJobs += 1
	
	
	
	activeSaveJobs -= 1
end

-- Class: CryptData
function CryptData.GetStore(storeKey, defaultData): _cryptDataStore
	local self = setmetatable({}, CryptDataStore)

	self.StoreKey = storeKey
	self.StoreLookup = storeKey .. "\0"
	self.DefaultData = defaultData
	
	self.IsPending = false
	self.GlobalDataStore = DataStoreService:GetDataStore(storeKey)
	
	self.LoadedAccounts = {}

	return self
end

-- Class: CryptDataStore
function CryptDataStore:LoadAccount(accountKey, loadMethod, doesNotSave)
	loadMethod = loadMethod or "Force"
	
	if self.DefaultData == nil then
		error("[CryptData]: Default data not set - CryptDataStore:LoadAccount() locked for this CryptDataStore")
	end
	
	if type(accountKey) ~= "string" then
		error("[CryptData]: accountKey must be a string")
	elseif #accountKey == 0 then
		error("[CryptData]: Invalid accountKey")
	end
	
	if loadMethod ~= "Force" and loadMethod ~= "Steal" then
		error("[CryptData]: Invalid loadMethod")
	end

	if CryptData.StoreLocked then
		return nil
	end
	
	for _, cryptDataStore: _cryptDataStore in activeCryptDataStores do
		if cryptDataStore.StoreLookup == self.StoreLookup then
			local loadedAccounts = cryptDataStore.LoadedAccounts
			
			if loadedAccounts[accountKey] then
				error("[CryptData]: Account " .. identifyAccount(self.StoreKey, accountKey) .. " is already loaded in this session")
			end
		end
	end
	
	activeLoadJobs += 1
	
	local forceLoad = loadMethod == "Force"
	local aggressiveSteal = loadMethod == "Steal"
	
	
	
	activeLoadJobs -= 1
	
	return
end

-- Class: Account
function Account:IsActive()
	local loadedAccounts = self.AccountStore.LoadedAccounts -- self._isTemp and 
	
	return loadedAccounts[self.AccountKey] == self
end

function Account:Identify()
	return identifyAccount(
		self.AccountStore.StoreKey,
		self.AccountKey
	)
end

function Account:Reconcile()
	reconcile(self.Data, self.AccountStore.DefaultData)
end

function Account:Save()
	if not self:IsActive() then
		warn("[CryptData]: Attempted saving an inactive account "
			.. self:Identify() .. "; Traceback:\n" .. debug.traceback())
		
		return
	end
	
	task.spawn(saveAccount, self)
end

function Account:OverwriteAsync()
	saveAccount(self, nil, true)
end

function Account:Free()
	if self:IsActive() then
		task.spawn(saveAccount, self, true)
	end
end

function Account:OnFree(callback)
	if type(callback) ~= "function" then
		error("[CryptData]: Only a function can be set as listener in Account:OnRelease()")
	end
	
	if not self:IsActive() then
		local _placeId, _jobId
		local activeSession = self.MetaData.ActiveSession
		
		if not activeSession then
			_placeId = activeSession[1]
			_jobId = activeSession[2]
		end
		
		callback(_placeId, _jobId)
	end
end

-- Runtime
RunService.Heartbeat:Connect(function()
	local saveLength = #CryptData.AutoSaveList

	if saveLength < 1 then
		return
	end

	local saveSpeed = Configuration.AutoSaveDuration / saveLength
	local lastClock = os.clock()

	while lastClock - lastSave > saveSpeed do
		lastSave += saveSpeed

		local account = CryptData.AutoSaveList[saveIndex]

		if lastClock - account.LoadTimestamp < Configuration.AutoSaveDuration then
			account = nil

			for _ = 1, saveLength do
				saveIndex += 1

				if saveIndex > saveLength then
					saveIndex = 1
				end

				account = CryptData.AutoSaveList[saveIndex]

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
		
		print(status, message)

		local noInternetAccess = not status and message:find("ConnectFail", 1, true) ~= nil

		if noInternetAccess then
			warn("[CryptData]: No internet access - check your network connection")
		end

		local condition =
			message:find("403", 1, true) ~= nil -- Cannot write to DataStore from studio if API access is not enabled
			or message:find("must publish", 1, true) ~= nil -- Game must be published to access live keys
			or noInternetAccess -- No internet access

		if not status and condition then
			shouldntSave = true
			
			print("[CryptData]: Roblox API services unavailable - data will not be saved")
		else
			print("[CryptData]: Roblox API services available - data will be saved")
		end

		isLiveCheckActive = false
	end)
end

if not isStudio or shouldntSave then
	game:BindToClose(function()
		--delayLiveAccess()
		CryptData.StoreLocked = true

		local activeAccounts = {}
		local jobCount = 0

		for key, account in CryptData.AutoSaveList do
			activeAccounts[key] = account
		end

		for _, account in activeAccounts do
			if account:IsActive() then
				jobCount += 1

				task.spawn(function()
					saveAccount(account, true)
					jobCount -= 1
				end)
			end
		end

		while jobCount > 0 or activeLoadJobs > 0 or activeSaveJobs > 0 do
			task.wait()
		end

		return
	end)
end

return CryptData
