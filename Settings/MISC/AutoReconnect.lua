local Debounce = 0

local function Signal()
	local now = os.time()
	if now > Debounce then
		game:GetService("TeleportService"):Teleport(game.PlaceId, game.Players.LocalPlayer)
		Debounce = now + 1
	end
end

if #game:GetService("GuiService"):GetErrorMessage() > 0 then
	Signal()
end

game:GetService("GuiService").ErrorMessageChanged:Connect(function()
	Signal()
end)

local old
old = hookfunction(game.Players.LocalPlayer.Kick, function(...)
	Signal()
	return nil
end)
