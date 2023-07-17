local CryptServer = {}

local systems = {}
local clientSystems = {}

export type SystemDef = {
	Name: string,
	[any]: any
}

export type ExposeDef = {
	RE: { [any]: string } | any,
	RF: { [any]: string } | any,
}

export type System = {
	Name: string,
	Util: { [any]: any },
	[any]: any
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local InvalidExposeName = { "_Comm", "Name" }
local Util = {}

local initialized = false
local created = false
local started = false
local ready = false
local start

local function initUtil()
	for _, module in script.Parent.Parent:GetChildren() do
		if module:IsA("ModuleScript") and module.Name ~= "Crypt" then
			Util[module.Name] = require(module)
		end
	end
end

local function validateExposeName(exposeName)
	return not table.find(InvalidExposeName, exposeName) and true or false
end

local function createMiddleware()
	local mdw = Instance.new("RemoteFunction")
	mdw.Name = "CMiddleware"
	mdw.Parent = script.Parent
end

local function createSystemsFolder()
	if script.Parent:FindFirstChild("Systems") then
		return
	end

	local systemFolder = Instance.new("Folder")
	systemFolder.Name = "Systems"
	systemFolder.Parent = script.Parent
end

local function createSystemFolder(systemName)
	local systemsFolder = script.Parent.Systems

	if systemsFolder:FindFirstChild(systemName) then
		return systemsFolder[systemName]
	else
		local systemFolder = Instance.new("Folder")
		systemFolder.Name = systemName
		systemFolder.Parent = systemsFolder
		
		return systemFolder
	end
end

local function createSignal(clientSystem, commName, instanceType)
	local signal = Instance.new(instanceType)
	signal.Name = commName
	signal.Parent = createSystemFolder(clientSystem.Name)
	
	if instanceType == "RemoteEvent" then
		clientSystem._Comm.RE[commName] = signal
	elseif instanceType == "RemoteFunction" then
		clientSystem._Comm.RF[commName] = signal
	end
	
	return signal
end

local function initSignal(clientSystem, commName, instanceType)
	assert(not clientSystem._Comm[commName], "Cannot have duplicate comm names")
	return createSignal(clientSystem, commName, instanceType)
end

local function initSignals()
	script.Parent.CMiddleware.OnServerInvoke = function()
		if not ready then
			repeat task.wait()
			until ready
		end
		
		return clientSystems
	end
end

local function findData()
	for _, system: System in systems do
		if system.Name:match("Data") then
			return system
		end
	end
	return nil
end

local function initData()
	local ds = findData()
	local runMode = if RunService:IsStudio() and RunService:IsRunMode() and #Players:GetPlayers() == 0 then true else false
	
	if runMode then
		for i = 1, 100 do
			if #Players:GetPlayers() > 0 then
				runMode = false
				break
			end
			
			task.wait()
		end
	end

	if not ds then
		return
	end

	if ds.Init then
		ds:Init()
	end
	
	local tempReady = false
	
	if ds.PlayerAdded then
		for _, plr in Players:GetPlayers() do
			task.spawn(function()
				ds:PlayerAdded(plr)
				tempReady = true
			end)
		end
		
		Players.PlayerAdded:Connect(function(player)
			ds:PlayerAdded(player)
			repeat task.wait() until not player or ds.Profiles[player.UserId]

			if player then
				tempReady = true
			end
		end)
	end
	
	if ds.PlayerRemoving then
		Players.PlayerRemoving:Connect(function(player)
			ds:PlayerRemoving(player)
		end)
	end

	if not ds.Ready and not runMode then
		repeat task.wait() until tempReady
		tempReady = nil
	end

	if ds.Start then
		task.spawn(ds.Start, ds)
	end

	return ds
end

function CryptServer.Include(path: Folder)
	start = os.clock()
	
	for _, module in path:GetChildren() do
		local s, e =  pcall(require, module)
		if not s then warn(e) end
	end
end

function CryptServer.Utils(path: Folder)
	local utils = {}
	for _, module in path:GetChildren() do
		utils[module.Name] = require(module)
	end
	for _, system in systems do
		for utilName, util in utils do
			system.Util[utilName] = util
		end
	end
end

function CryptServer.Register(systemDef: SystemDef): System
	local system = systemDef
	system.Util = Util
	
	assert(not systems[system.Name], "Cannot register system \"" .. system.Name .. "\" more than once")

	function system.Expose(exposeDef: ExposeDef)
		assert(not clientSystems[system.Name], "Cannot expose the system more than once")
		
		local clientSystem = {
			Name = system.Name,
			_Comm = {}
		}

		for exposeType: string, exposeData: { [any]: string } in exposeDef do
			for _, exposeName in exposeData do
				assert(validateExposeName(exposeName), "Invalid expose name: Cannot use names similar to core methods")
				assert(not clientSystem[exposeName], "Cannot duplicate comm name " .. exposeName)

				if exposeType == "RE" then
					clientSystem._Comm.RE = clientSystem._Comm.RE or {}
					clientSystem[exposeName] = {}

					local signal: RemoteEvent = initSignal(clientSystem, exposeName, "RemoteEvent")
					system[exposeName] = {}

					system[exposeName].Connect = function(_, callback)
						signal.OnServerEvent:Connect(callback)
					end
					system[exposeName].Fire = function(_, player: Player, ...)
						signal:FireClient(player, ...)
					end
					system[exposeName].FireAll = function(_, ...)
						signal:FireAllClients(...)
					end

				elseif exposeType == "RF" then
					clientSystem._Comm.RF = clientSystem._Comm.RF or {}
					clientSystem[exposeName] = {}

					local signal: RemoteFunction = initSignal(clientSystem, exposeName, "RemoteFunction")

					signal.OnServerInvoke = function(...)
						return system[exposeName](system, ...)
					end
				end
			end
		end

		clientSystems[clientSystem.Name] = clientSystem
		system.Expose = nil
		return system
	end

	systems[system.Name] = system
	return system
end

function CryptServer.Import(system: string)
	return systems[system]
end

function CryptServer.Start()
	assert(not started, "Cannot start Crypt: Already started!")
	started = true
	
	createMiddleware()
	initSignals()
	
	local ds = initData()

	for _, system in systems do
		if ds and system.Name == ds.Name then
			continue
		end
		
		if system.Init then
			local s, e = pcall(system.Init, system)
			if not s then warn(e) end
		end
		
		if system.Start then
			local s, e = pcall(function()
				task.spawn(system.Start, system)
			end)
			if not s then warn(e) end
		end
		
		task.spawn(function()
			if system.PlayerAdded then
				for _, plr in Players:GetPlayers() do
					task.spawn(function()
						system:PlayerAdded(plr)
					end)
				end
				Players.PlayerAdded:Connect(function(player)
					system:PlayerAdded(player)
				end)
			end
			
			if system.PlayerRemoving then
				Players.PlayerRemoving:Connect(function(player)
					system:PlayerRemoving(player)
				end)
			end
		end)
	end

	ready = true
	print("Server initialized. Elasped time:", string.format("%.2f", os.clock() - start) .. "s")
end

if not initialized then
	initialized = true
	initUtil()
end

if not created then
	created = true
	createSystemsFolder()
end

return CryptServer
