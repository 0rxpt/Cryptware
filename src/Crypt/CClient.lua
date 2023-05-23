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
	if _systems then
		systems = _systems
		gotSystems = true
	end
end

local function initSignals()
	for _, system: System in systems do
		if system.Comm then
			for commName, signal: RemoteFunction in system.Comm do
				system.Client[commName].Get = function()
					return signal:InvokeServer("Get", "Profile")
				end
				
				system.Client[commName].Set = function(_, ...)
					return signal:InvokeServer("Set", "Profile", ...)
				end
			end
		end
	end
end

function CryptClient.Register(handlerDef: HandlerDef): Handler
	local handler = handlerDef
	handlers[handler.Name] = handler
	return handler
end

function CryptClient.RegisterPath(path: Folder)
	for _, module in path:GetChildren() do
		require(module)
	end
end

function CryptClient.Import(importDef: string)
	if handlers[importDef] then
		return handlers[importDef]
	else
		return systems[importDef].Client
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
