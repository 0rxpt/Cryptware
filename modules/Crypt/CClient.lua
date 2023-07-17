local CryptClient = {}

local handlers = {}
local systems = {}

export type HandlerDef = {
	Name: string,
	[any]: any
}

export type Handler = {
	Name: string,
	[any]: any
}

export type System = {
	Name: string,
	[any]: any
}

export type Comm = {
	[any]: any
}

local started = false
local gotSystems = false
local start

local function getSystems()
	local _systems = script.Parent.CMiddleware:InvokeServer()
	script.Parent.CMiddleware:Destroy()
	
	if _systems then
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
	
	assert(not handlers[handler.Name], "Cannot register handler \"" .. handler.Name .. "\" more than once")
	assert(not systems[handler.Name], "Cannot register handler \"" .. handler.Name .. "\": A registered system already has this name.")
	
	handlers[handler.Name] = handler
	return handler
end

function CryptClient.Include(path: Folder)
	start = os.clock()
	
	for _, module in path:GetChildren() do
		local s, e =  pcall(require, module)
		if not s then warn(e) end
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
	assert(not started, "Cannot start Crypt: Already started!")
	started = true
	
	initSignals()
	
	local loading = handlers.Loading or handlers.LoadingHandler
	local music = handlers.Music or handlers.MusicHandler
	
	if loading and loading.Init then
		task.spawn(loading.Init, loading)
	end
	
	for _, handler in handlers do
		if handler.Init and ((loading and handler.Name ~= loading.Name) or (not loading)) then
			local s, e = pcall(handler.Init, handler)
			if not s then warn(e) end
		end
	end
	
	for _, handler in handlers do
		if handler.Start and ((loading and handler.Name ~= loading.Name) or (not loading))
			and ((music and handler.Name ~= music.Name) or (not music))
		then
			local s, e = pcall(function()
				task.spawn(handler.Start, handler)
			end)
			if not s then warn(e) end
		end
	end
	
	if not loading then
		if music then
			task.spawn(music.Start, music)
		end
		
		print("Client initialized. Elasped time:", string.format("%.2f", os.clock() - start) .. "s")
		return
	end
	
	repeat task.wait() until loading.Loaded
	
	if music then
		task.spawn(music.Start, music)
	end
	
	print("Client initialized. Elasped time:", string.format("%.2f", os.clock() - start) .. "s")
end

if not gotSystems then
	gotSystems = true
	getSystems()
end

return CryptClient
