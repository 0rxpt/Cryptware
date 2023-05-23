local CryptServer = {}

local systems = {}
local clientSystems = {}

type SystemDef = {
	Name: string,
	[any]: any
}

type CommDef = {
	[any]: string
}

type System = {
	Name: string,
	[any]: any
}

type Comm = {
	[any]: any
}

type InvokeType = "Get" | "Set" | "Import" | "Systems"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local started = false
local ready = false

local function createSystemsFolder()
	local systemsFolder = Instance.new("Folder")
	systemsFolder.Name = "Systems"
	systemsFolder.Parent = script.Parent
	return systemsFolder
end

local function getSystemsFolder()
	if not script.Parent:FindFirstChild("Systems") then
		return createSystemsFolder()
	else
		return script.Parent.Systems
	end
end

local function createSystemFolder(systemsFolder, systemName)
	local systemFolder = Instance.new("Folder")
	systemFolder.Name = systemName
	systemFolder.Parent = systemsFolder
	return systemFolder
end

local function getSystemFolder(systemsFolder, systemName)
	if not systemsFolder:FindFirstChild(systemName) then
		return createSystemFolder(systemsFolder, systemName)
	else
		return systemsFolder[systemName]
	end
end

local function createSignal(systemFolder, commName)
	local rf = Instance.new("RemoteFunction")
	rf.Name = commName
	rf.Parent = systemFolder
	return rf
end

local function initSignalPath(systemName: string, commName)
	local systemsFolder = getSystemsFolder()
	local systemFolder = getSystemFolder(systemsFolder, systemName)
	
	assert(not systemFolder:FindFirstChild(commName), "Cannot have duplicate comm names")
	return createSignal(systemFolder, commName)
end

local invokeTypes = {
	["Get"] = function(systemName: string, returnType: string, ...)
		local system = systems[systemName]

		if system then
			local get = system.Get[returnType]
			if get then
				return get(...)
			end
		end
	end,
	
	["Set"] = function(systemName: string, returnType: string, ...)
		local system = systems[systemName]

		if system then
			local set = system.Set[returnType]
			if set then
				return set(...)
			end
		end
	end
}

local function initSignals()
	script.Parent.CMiddleware.OnServerInvoke = function(player, invokeType: InvokeType, ...)
		if not ready then
			repeat task.wait()
			until ready
		end
		
		if invokeType == "Import" then
			return systems[...].Client
		elseif invokeType == "Systems" then
			return clientSystems
		end
	end

	for _, system: System in systems do
		if system.Comm then
			for commName, signal: RemoteFunction in system.Comm do
				signal.OnServerInvoke = function(player, invokeType: InvokeType, returnType: string, ...)
					if invokeTypes[invokeType]
						and system[invokeType] 
						and system[invokeType][returnType]
					then
						return invokeTypes[invokeType](system.Name, returnType, player, ...)
					end
				end
			end
		end
	end
end

function CryptServer.RegisterPath(path: Folder)
	for _, module in path:GetChildren() do
		require(module)
	end
end

function CryptServer.Register(systemDef: SystemDef, commDef: CommDef | nil): System
	local system = systemDef

	if commDef then
		system.Get = {}
		system.Set = {}
		system.Comm = {}
		system.Client = { Name = system.Name }
		for _, commName: string in commDef do
			system.Client[commName] = {}
			system.Comm[commName] = initSignalPath(system.Name, commName)
		end
		clientSystems[system.Name] = {
			Name = system.Name,
			Comm = system.Comm,
			Client = system.Client
		}
	end

	systems[system.Name] = system
	return system
end

function CryptServer.Import(system: string)
	return systems[system].Client
end

function CryptServer.Start()
	if started then return end
	started = true
	
	initSignals()
	
	local ds = systems["Data"] or systems["DataSystem"]
	if ds.Init then
		ds:Init()
	end
	if ds.Start then
		ds:Start()
	end
	
	for _, system in systems do
		if system.Name == ds.Name then continue end
		
		if system.Init then
			system:Init()
		end
	end
	
	for _, system in systems do
		if system.Name == ds.Name then continue end

		if system.Start then
			task.spawn(system.Start, system)
		end
	end
	
	ready = true
end

return CryptServer
