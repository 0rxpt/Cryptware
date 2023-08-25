local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

export type _cryptStore = {
	StoreKey: string,
	DefaultData: {},
	GlobalDataStore: any,
	LoadedAccounts: {},
}

-- Class Definitions
local CryptData = {
	Locked = false,

	TempDataStore = {},
	UserTempDataStore = {},
}

local CryptStore = {}
local Account = {}

CryptStore.__index = CryptStore
Account.__index = Account

-- Private Variables
local placeId = game.PlaceId
local jobId = game.JobId

local activeCryptStores = {}
local autoSaveList = {}

local isStudio = RunService:IsStudio()

local shouldntSave = false
local isLiveCheckActive = false

local activeLoadJobs = 0
local activeSaveJobs = 0

local autoSaveIndex = 1
local lastAutoSave

local Configuration = {
	AutoSaveDuration = 30,
	AssumeDeadSessionLock = 60 * 30,
}

local MetaTags = {
	AccountCreateTime = true,
	ActiveSession = true,
	ForceLoadSession = true,
	LastUpdate = true,
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
	return string.format('[Store:"%s";Key:"%s"]', storeKey, accountKey)
end

local function addToAutoSave(account)
	table.insert(autoSaveList, autoSaveIndex, account)

	if #autoSaveList > 1 then
		autoSaveIndex += 1
	elseif #autoSaveList == 1 then
		lastAutoSave = os.clock()
	end
end

local function removeFromAutoSave(account)
	local _autoSaveIndex = table.find(autoSaveList, account)

	if _autoSaveIndex then
		table.remove(autoSaveList, _autoSaveIndex)

		if _autoSaveIndex < autoSaveIndex then
			autoSaveIndex -= 1
		end

		if not autoSaveList[autoSaveIndex] then
			autoSaveIndex = 1
		end
	end
end

local function freeAccount(account)
	removeFromAutoSave(account)

	account.MetaData.ActiveSession = nil
	account.AccountStore.LoadedAccounts[account.AccountKey] = nil
end

local function isActiveSession(activeSession)
	return activeSession.JobId == jobId and activeSession.PlaceId == placeId
end

local function saveAccount(account, freeFromSession, isOverwriting)
	if shouldntSave then
		return
	end

	if type(account.Data) ~= "table" then
		error("[CryptData]: ACCOUNT DATA CORRUPTED DURING RUNTIME! Account: " .. account:Identify())
	end

	if freeFromSession and isOverwriting then
		freeAccount(account)
	end

	activeSaveJobs += 1

	local loadedData
	local succ, err = pcall(function()
		account.AccountStore.GlobalDataStore:UpdateAsync(account.AccountKey, function(latestData)
			local sessionOwnsAccount = false

			latestData = latestData
				or {
					AccountKey = account.AccountKey,
					Data = account.Data,
					MetaData = account.MetaData,
				}

			if not isOverwriting and latestData and latestData.MetaData then
				local activeSession = latestData.MetaData.ActiveSession

				if type(activeSession) == "table" then
					sessionOwnsAccount = isActiveSession(activeSession)
				end
			else
				sessionOwnsAccount = true
			end

			if sessionOwnsAccount then
				latestData.Data = account.Data

				if not isOverwriting then
					latestData.MetaData.LastUpdate = os.time()

					if freeFromSession then
						latestData.MetaData.ActiveSession = nil
					end
				else
					latestData.MetaData = account.MetaData
					latestData.MetaData.ActiveSession = nil
				end

				loadedData = latestData
			end

			latestData.AccountStore = nil
			return latestData
		end)
	end)

	if not succ then
		warn(
			"[CryptData]: DataStore API error "
				.. identifyAccount(account.AccountStore.StoreKey, account.AccountKey)
				.. ' - "'
				.. tostring(err)
				.. '"'
		)
	end

	if loadedData then
		local sessionMetaData = account.MetaData
		local latestMetaData = loadedData.MetaData

		for key in MetaTags do
			sessionMetaData[key] = latestMetaData[key]
		end

		local activeSession = loadedData.MetaData.ActiveSession
		local sessionOwnsAccount = false

		if type(activeSession) == "table" then
			sessionOwnsAccount = isActiveSession(activeSession)
		end

		local isActive = account:IsActive()

		if not sessionOwnsAccount and isActive then
			freeAccount(account)
		end
	end

	activeSaveJobs -= 1
end

-- Class: CryptData
function CryptData.GetStore(storeKey, defaultData): _cryptStore
	local self = setmetatable({}, CryptStore)

	self.StoreKey = storeKey
	self.DefaultData = defaultData
	self.GlobalDataStore = DataStoreService:GetDataStore(storeKey)
	self.LoadedAccounts = {}

	activeCryptStores[storeKey] = self
	return self
end

-- Class: CryptStore
function CryptStore:LoadAccount(accountKey, loadMethod, doesNotSave)
	loadMethod = loadMethod or "Force"

	if self.DefaultData == nil then
		error("[CryptData]: Default data not set - CryptStore:LoadAccount() locked for this CryptStore")
	end

	if type(accountKey) ~= "string" then
		error("[CryptData]: accountKey must be a string")
	elseif #accountKey == 0 then
		error("[CryptData]: Invalid accountKey")
	end

	if loadMethod ~= "Force" and loadMethod ~= "Steal" then
		error("[CryptData]: Invalid loadMethod")
	end

	if CryptData.Locked then
		return
	end

	for _, cryptStore: _cryptStore in activeCryptStores do
		if cryptStore.StoreKey ~= self.StoreKey then
			continue
		end

		local loadedAccounts = cryptStore.LoadedAccounts

		if loadedAccounts[accountKey] then
			error(
				"[CryptData]: Account "
					.. identifyAccount(self.StoreKey, accountKey)
					.. " is already loaded in this session"
			)
		end
	end

	activeLoadJobs += 1

	local forceLoad = loadMethod == "Force"
	local aggressiveSteal = loadMethod == "Steal"

	local account
	local success, err = pcall(function()
		account = self.GlobalDataStore:GetAsync(accountKey)
	end)

	if not success then
		warn('[CryptData]: DataStore API error - "' .. tostring(err) .. '"')
		return
	end

	if account == nil then
		account = {
			AccountKey = accountKey,

			Data = deepCopy(self.DefaultData),
			MetaData = deepCopy(MetaTags),
		}

		account.MetaData.AccountCreateTime = os.time()
		account.MetaData.LastUpdate = os.time()
	end

	if type(account.MetaData.ActiveSession) == "table" then
		return
	end

	account.LoadTimestamp = os.clock()
	account.AccountStore = self
	account.MetaData.ActiveSession = { placeId, jobId }

	self.LoadedAccounts[accountKey] = account
	activeLoadJobs -= 1

	setmetatable(account, Account)
	addToAutoSave(account)

	return account
end

-- Class: Account
function Account:IsActive()
	local loadedAccounts = self.AccountStore.LoadedAccounts

	return loadedAccounts[self.AccountKey] == self
end

function Account:Identify()
	return identifyAccount(self.AccountStore.StoreKey, self.AccountKey)
end

function Account:Reconcile()
	reconcile(self.Data, self.AccountStore.DefaultData)
end

function Account:Save()
	if not self:IsActive() then
		warn(
			"[CryptData]: Attempted saving an inactive account "
				.. self:Identify()
				.. "; Traceback:\n"
				.. debug.traceback()
		)

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

	task.spawn(function()
		while self:IsActive() do
			task.wait()
		end

		local _placeId, _jobId
		local activeSession = self.MetaData.ActiveSession

		if not activeSession then
			_placeId = activeSession[1]
			_jobId = activeSession[2]
		end

		callback(_placeId, _jobId)
	end)
end

-- Initialization
if isStudio then
	isLiveCheckActive = true

	task.spawn(function()
		local status, message = pcall(function()
			-- This will error if current instance has no Studio API access:
			DataStoreService:GetDataStore("____CS"):SetAsync("____CS", os.time())
		end)

		local noInternetAccess = not status and string.find(message, "ConnectFail", 1, true) ~= nil

		if noInternetAccess then
			warn("[CryptData]: No internet access - check your network connection")
		end

		local condition

		if message then
			condition = string.find(message, "403", 1, true) ~= nil -- Cannot write to DataStore from studio if API access is not enabled
				or string.find(message, "must publish", 1, true) ~= nil -- Game must be published to access live keys
				or noInternetAccess -- No internet access
		end

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
		while isLiveCheckActive do
			task.wait()
		end

		CryptData.Locked = true

		local activeAccounts = {}
		local jobCount = 0

		for key, account in autoSaveList do
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

RunService.Heartbeat:Connect(function()
	local autoSaveListLength = #autoSaveList

	if autoSaveListLength > 0 then
		local autoSaveIndexSpeed = Configuration.AutoSaveDuration / autoSaveListLength
		local osClock = os.clock()

		while osClock - lastAutoSave > autoSaveIndexSpeed do
			lastAutoSave += autoSaveIndexSpeed

			local account = autoSaveList[autoSaveIndex]

			if osClock - account.LoadTimestamp < Configuration.AutoSaveDuration then
				account = nil

				for _ = 1, autoSaveListLength do
					autoSaveIndex += 1

					if autoSaveIndex > autoSaveListLength then
						autoSaveIndex = 1
					end

					account = autoSaveList[autoSaveIndex]

					if osClock - account.LoadTimestamp >= Configuration.AutoSaveDuration then
						break
					else
						account = nil
					end
				end
			end

			autoSaveIndex += 1

			if autoSaveIndex > autoSaveListLength then
				autoSaveIndex = 1
			end

			if account then
				task.spawn(saveAccount, account)
			end
		end
	end
end)

return CryptData
