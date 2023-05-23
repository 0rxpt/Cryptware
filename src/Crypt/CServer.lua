local CryptServer = {}
local systems = {}

function CryptServer:Register(systemDef, commDef)
    assert(systemDef, "Must pass a system definition to register.")
    assert(type(systemDef) == "table", "Must pass a valid system type to register.")

    assert(systemDef.Name, "Must pass a system name definition to register.")
    assert(type(systemDef.Name) == "string", "Must pass a valid system name type to register.")

    local system = systemDef

    if commDef then
        system.Get = {}
        system.Set = {}
        system.Comm = {}
        for _, commName in pairs(commDef) do
            assert(type(commName) == "string", "Must pass a valid comm name type to register.")
            system.Comm[commName] = {}
        end
    end

    systems[system.Name] = system
    return system
end

function CryptServer:Get(systemName, commName, player)
    local system = systems[systemName]

    if system then
        local get = system.Get[commName]
        if get then
            return get(player)
        end
    end
end

return CryptServer