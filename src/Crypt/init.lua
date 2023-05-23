local RunService = game:GetService("RunService")

if RunService:IsServer() then
	return require(script.CServer)
else
	if script:FindFirstChild("CServer") then
		script.CServer:Destroy()
	end
	
	return require(script.CClient)
end
