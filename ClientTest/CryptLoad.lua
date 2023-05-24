local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Crypt = require(ReplicatedStorage.Cryptware.Crypt)

Crypt.Include(script.Parent.Handlers)
Crypt.Utils(script.Parent.Utils)
Crypt.Utils(ReplicatedStorage.Shared)
Crypt.Start()
