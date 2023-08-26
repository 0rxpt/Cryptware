local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

export type _cryptStore = {
	StoreKey: string,
	DefaultData: {},
	GlobalDataStore: any,
	LoadedAccounts: {},
	MockLoadedAccounts: {},
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
local shouldLog = true
local session
local placeId = game.PlaceId

local activeCryptStores = {}
local autoSaveList = {}

local isStudio = RunService:IsStudio()
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
	LastUpdate = true,
}

-- Private Functions
local function log(...)
	local args = {...}
	local callback = args[#args]
	
	args[#args] = nil
	
	if shouldLog then
		if type(callback) == "function" then
			callback(table.unpack(args))
		else
			print(table.unpack(args))
		end
	end
end

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

local function generate(length)
	length = length or 12
	
	local choices = {
		"0123456788",
		"abcdefghijklmnopqrstuvwxyz"
	}
	
	choices[3] = choices[2]:upper()
	
	local str = ""
	
	for i = 1, length do
		local nextChoice = choices[math.random(#choices)]
		local nextChar = math.random(#nextChoice)
		
		str = str .. nextChoice:sub(nextChar, nextChar)
	end
	
	return str
end

local function delayUntilLiveAccessCheck()
	while isLiveCheckActive do
		task.wait()
	end
end

local function delayUntilPendingAccountStoreCheck(accountStore)
	while accountStore.Pending do
		task.wait()
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
	log("Freeing...")
	
	if account.AccountStore.UseMock then
		account.MetaData.ActiveSession = nil
		account.AccountStore.MockLoadedAccounts[account.AccountKey] = nil
	else
		removeFromAutoSave(account)

		account.MetaData.ActiveSession = nil
		account.AccountStore.LoadedAccounts[account.AccountKey] = nil
	end
end

local function isThisSession(activeSession)
	return activeSession.JobId == session and activeSession.PlaceId == placeId
end

local function saveAccount(account, freeFromSession, isOverwriting)
	if account.AccountStore.UseMock then
		if freeFromSession then
			freeAccount(account)
		end
	else
		print("Saving...")

		if type(account.Data) ~= "table" then
			error("[CryptData]: ACCOUNT DATA CORRUPTED DURING RUNTIME! Account: " .. account:Identify())
		end

		if freeFromSession and isOverwriting then
			freeAccount(account)
		end

		activeSaveJobs += 1
		--log("Attempting to save data:", account)

		local loadedData
		local succ, err = pcall(function()
			account.AccountStore.GlobalDataStore:UpdateAsync(account.AccountKey, function(latestData)
				local sessionOwnsAccount = false

				latestData = latestData or {
					AccountKey = account.AccountKey,
					Data = account.Data,
					MetaData = account.MetaData,
					LoadTimestamp = account.LoadTimestamp,
					Version = 0
				}

				if not isOverwriting then
					local activeSession = latestData.MetaData.ActiveSession

					if type(activeSession) == "table" then
						sessionOwnsAccount = isThisSession(activeSession)
					end
				else
					sessionOwnsAccount = true
				end

				log(sessionOwnsAccount and "Session owns account." or "Session does not own account.")

				if sessionOwnsAccount then
					latestData.Data = account.Data
					latestData.Version += 1

					log(isOverwriting and "Overwriting." or "Will not overwrite.")

					if not isOverwriting then
						latestData.MetaData.LastUpdate = os.time()

						log(freeFromSession and "Will free from session." or "Will not free from session.")

						if freeFromSession then
							latestData.MetaData.ActiveSession = nil
						end
					else
						latestData.MetaData = account.MetaData
						latestData.MetaData.ActiveSession = nil
					end
				end

				loadedData = latestData
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
				sessionOwnsAccount = isThisSession(activeSession)
			end

			local isActive = account:IsActive()

			if not sessionOwnsAccount and isActive then
				freeAccount(account)
			end
		end

		activeSaveJobs -= 1
	end
end

-- Class: CryptData
function CryptData.GetStore(storeKey, defaultData): _cryptStore
	local self = setmetatable({}, CryptStore)

	self.StoreKey = storeKey
	self.DefaultData = defaultData
	self.LoadedAccounts = {}
	self.MockLoadedAccounts = {}
	self.Pending = false
	
	self.Mock = {
		LoadAccount = function(_, accountKey, loadMethod)
			self.UseMock = true
			
			return self:LoadAccount(accountKey, loadMethod, true)
		end,
	}
	
	if isLiveCheckActive then
		self.Pending = true
		
		task.spawn(function()
			delayUntilLiveAccessCheck()
			
			self.GlobalDataStore = DataStoreService:GetDataStore(storeKey)
			self.Pending = false
		end)
	else
		self.GlobalDataStore = DataStoreService:GetDataStore(storeKey)
	end

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
	
	delayUntilPendingAccountStoreCheck(self)

	for _, cryptStore: _cryptStore in activeCryptStores do
		if cryptStore.StoreKey ~= self.StoreKey then
			continue
		end

		local loadedAccounts = doesNotSave and cryptStore.MockLoadedAccounts or cryptStore.LoadedAccounts

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
	
	local loadedData
	local succ, err = pcall(function()
		if doesNotSave then
			loadedData = {
				AccountKey = accountKey,
				Data = deepCopy(self.DefaultData),
				MetaData = {
					AccountCreateTime = os.time(),
					ActiveSession = {
						PlaceId = placeId,
						JobId = session
					},
				},
				Version = 0
			}
			
			return
		end
		
		self.GlobalDataStore:UpdateAsync(accountKey, function(latestData)
			if latestData == nil then
				latestData = {
					AccountKey = accountKey,
					Data = deepCopy(self.DefaultData),
					MetaData = {
						AccountCreateTime = os.time(),
						ActiveSession = {
							PlaceId = placeId,
							JobId = session
						},
					},
					Version = 0
				}
			else
				if not CryptData.Locked then
					local activeSession = latestData.MetaData.ActiveSession

					if not activeSession then
						latestData.MetaData.ActiveSession = {
							PlaceId = placeId,
							JobId = session
						}
						
						self.LoadedAccounts[accountKey] = latestData
					elseif type(activeSession) == "table" and isThisSession(activeSession) then
						local lastUpdate = latestData.MetaData.LastUpdate

						if lastUpdate and os.time() - lastUpdate > Configuration.AssumeDeadSessionLock then
							latestData.MetaData.ActiveSession = {
								PlaceId = placeId,
								JobId = session
							}
						end
					end
				end
			end
			
			if CryptData.Locked then
				return latestData
			end
			
			local activeSession = latestData.MetaData.ActiveSession
			
			if activeSession and isThisSession(activeSession) then
				latestData.MetaData.LastUpdate = os.time()
			end
			
			loadedData = latestData
			return latestData
		end)
	end)
	
	if not succ then
		warn('[CryptData]: DataStore API error - "' .. tostring(err) .. '"')
		
		return
	end
	
	if not loadedData then
		activeLoadJobs -= 1
		
		return
	end
	
	--log("Attempting to load data:", loadedData)
	
	local activeSession = loadedData.MetaData.ActiveSession
	
	if type(activeSession) ~= "table" then
		activeLoadJobs -= 1
		
		return
	end
	
	if isThisSession(activeSession) then
		if forceLoad then
			local nullifyAccount = false
			
			local account = {
				Data = loadedData.Data,
				MetaData = loadedData.MetaData,
				Version = loadedData.Version,
				AccountKey = accountKey,
				LoadTimestamp = os.clock(),
				AccountStore = self,
			}
			
			setmetatable(account, Account)
			
			if not doesNotSave then
				self.LoadedAccounts[accountKey] = account
				addToAutoSave(account)
				
				if CryptData.Locked then
					saveAccount(account, true)
					nullifyAccount = true
				end
			else
				self.MockLoadedAccounts[accountKey] = account
			end
			
			activeLoadJobs -= 1
			
			return (nullifyAccount and nil) or account
		end
	end
end

-- Class: Account
function Account:IsActive()
	local loadedAccounts = self.AccountStore.UseMock and self.AccountStore.MockLoadedAccounts or self.AccountStore.LoadedAccounts

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
	else
		log("Cannot free: not active.")
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
		
		log("Freed.")

		local _placeId, _jobId
		local activeSession = self.MetaData.ActiveSession

		if activeSession then
			_placeId = activeSession.PlaceId
			_jobId = activeSession.JobId
		end

		callback(_placeId, _jobId)
	end)
end

-- Initialization
if isStudio then
	isLiveCheckActive = true

	task.spawn(function()
		local status, message = pcall(function()
			DataStoreService:GetDataStore("____CS"):SetAsync("____CS", os.time())
		end)

		local noInternetAccess = not status and string.find(message, "ConnectFail", 1, true) ~= nil

		if noInternetAccess then
			log("[CryptData]: No internet access - check your network connection", warn)
		end

		local condition

		if message then
			condition = string.find(message, "403", 1, true) ~= nil
				or string.find(message, "must publish", 1, true) ~= nil
				or noInternetAccess
		end

		if not status and condition then
			shouldNotSave = true

			log("[CryptData]: Roblox API services unavailable - data will not be saved")
		else
			log("[CryptData]: Roblox API services available - data will be saved")
		end

		isLiveCheckActive = false
	end)
end

task.spawn(function()
	delayUntilLiveAccessCheck()
	
	if isStudio or not shouldNotSave then
		--log("Will not run BindToClose")
		
		return
	end
	
	game:BindToClose(function()
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
					log("Saved account.")
					jobCount -= 1
				end)
			end
		end
		
		--log("Successfully saved all active accounts.")

		while jobCount > 0 or activeLoadJobs > 0 or activeSaveJobs > 0 do
			task.wait()
		end
		
		return
	end)
end)

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

session = generate()
return CryptData
