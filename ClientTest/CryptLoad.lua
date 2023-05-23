local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Crypt = require(ReplicatedStorage.Cryptware.Crypt)

Crypt.RegisterPath(script.Parent.Handlers)
Crypt.Start()
