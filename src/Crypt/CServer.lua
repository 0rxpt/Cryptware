local CryptServer = {}

local systems = {}
local clientSystems = {}

type SystemDef = {
	Name: string,
	[any]: any
}

type ExposeDef = {
	RE: { [any]: string } | any,
	RF: { [any]: string } | any,
}

type System = {
	Name: string,
	[any]: any
}

type InvokeType = "Import" | "Systems"
local InvalidExposeName = { "_Comm", "Name" }

local function validateExposeName(exposeName)
	if exposeName[InvalidExposeName] then
		return false
	end
	return true
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local started = false
local ready = false

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
end

local function initData()
	local ds = findData()

	if not ds then
		return
	end

	if ds.Init then
		ds:Init()
	end

	if ds.PlayerAdded then
		game:GetService("Players").PlayerAdded:Connect(function(player)
			ds:PlayerAdded(player)
			ds.Ready = if not ds.Ready then true else nil
		end)
	end

	if not ds.Ready then
		repeat task.wait() until ds.Ready
	end

	if ds.Start then
		task.spawn(ds.Start, ds)
	end

	return ds
end

function CryptServer.Include(path: Folder)
	for _, module in path:GetChildren() do
		require(module)
	end
end

function CryptServer.Utils(path: Folder)
	local utils = {}
	for _, module in path:GetChildren() do
		utils[module.Name] = require(module)
	end
	for _, system in systems do
		if not system.Util then
			system.Util = utils
		else
			for utilName, util in utils do
				system.Util[utilName] = util
			end
		end
	end
end

function CryptServer.Register(systemDef: SystemDef): System
	createSystemsFolder()

	local system = systemDef

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

					local re = clientSystem._Comm.RE
					re[exposeName] = initSignal(clientSystem, exposeName, "RemoteEvent")

					local signal: RemoteEvent = re[exposeName]
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

					local rf = clientSystem._Comm.RF
					rf[exposeName] = initSignal(clientSystem, exposeName, "RemoteFunction")

					local signal: RemoteFunction = rf[exposeName]

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
		if ds and system.Name == ds.Name then continue end
		if system.Init then
			system:Init()
		end
	end

	for _, system in systems do
		if ds and system.Name == ds.Name then continue end
		if system.Start then
			task.spawn(system.Start, system)
		end
	end

	ready = true
end

return CryptServer
