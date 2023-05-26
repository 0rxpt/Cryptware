local CryptClient = {}

local handlers = {}
local systems = {}

type HandlerDef = {
	Name: string,
	[any]: any
}

type Handler = {
	Name: string,
	[any]: any
}

type System = {
	Name: string,
	[any]: any
}

type Comm = {
	[any]: any
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local started = false
local gotSystems = false

local function getSystems()
	local _systems = script.Parent.CMiddleware:InvokeServer("Systems")
	script.Parent.CMiddleware:Destroy()
	if _systems and not gotSystems then
		systems = _systems
		gotSystems = true
	end
end

local function initSignals()
	for _, system: System in systems do
		for commType, commData in system._Comm do
			if commType == "RE" then
				for commName, signal: RemoteEvent in commData do
					system[commName].Connect = function(_, callback)
						signal.OnClientEvent:Connect(callback)
					end
					system[commName].Fire = function(_, ...)
						signal:FireServer(...)
					end
				end
			elseif commType == "RF" then
				for commName, signal: RemoteFunction in commData do
					system[commName] = function(_, ...)
						return signal:InvokeServer(...)
					end
				end
			end
		end
	end
end

function CryptClient.Utils(path: Folder)
	local utils = {}
	for _, module in path:GetChildren() do
		utils[module.Name] = require(module)
	end
	for _, handler in handlers do
		if not handler.Util then
			handler.Util = utils
		else
			for utilName, util in utils do
				handler.Util[utilName] = util
			end
		end
	end
end

function CryptClient.Register(handlerDef: HandlerDef): Handler
	local handler = handlerDef
	handlers[handler.Name] = handler
	return handler
end

function CryptClient.Include(path: Folder)
	for _, module in path:GetChildren() do
		require(module)
	end
end

function CryptClient.Import(importDef: string)
	if handlers[importDef] then
		return handlers[importDef]
	else
		return systems[importDef]
	end
end

function CryptClient.Start()
	if started then return end
	started = true

	initSignals()

	for _, handler in handlers do
		if handler.Init then
			handler:Init()
		end
	end

	for _, handler in handlers do
		if handler.Start then
			task.spawn(handler.Start, handler)
		end
	end
end

if not gotSystems then
	getSystems()
end

return CryptClient
