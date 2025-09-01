local equipPet = game.ReplicatedStorage.Pets.EquipPet
local unequipPet = game.ReplicatedStorage.Pets.UnequipPet

local index = require(game.ReplicatedStorage.Pets.Index)

local function formatOdds(odds)
	if odds >= 1e9 then
		local rounded = math.floor(odds / 1e8 + 0.5) / 10 -- Divide by 1e8 to keep one decimal place
		if rounded % 1 == 0 then
			return tostring(math.floor(rounded)) .. "b"
		else
			return string.format("%.1fb", rounded)
		end
	elseif odds >= 1e6 then
		local rounded = math.floor(odds / 1e5 + 0.5) / 10 -- Divide by 1e5 to keep one decimal place
		if rounded % 1 == 0 then
			return tostring(math.floor(rounded)) .. "m"
		else
			return string.format("%.1fm", rounded)
		end
	elseif odds >= 1e3 then
		local rounded = math.floor(odds / 1e2 + 0.5) / 10 -- Divide by 1e2 to keep one decimal place
		if rounded % 1 == 0 then
			return tostring(math.floor(rounded)) .. "k"
		else
			return string.format("%.1fk", rounded)
		end
	else
		return tostring(odds)
	end
end

local function findPetModel(petName)
	for _, petData in pairs(index) do
		if petData.name == petName then
			return petData.model, petData.odds, petData.imageId
		end
	end
	return nil
end

local function ensurePlayerPetsFolder(player)
	local playerPetsFolder = workspace:FindFirstChild("PlayerPets")

	local playerFolder = playerPetsFolder:FindFirstChild(player.Name)
	if not playerFolder then
		playerFolder = Instance.new("Folder")
		playerFolder.Name = player.Name
		playerFolder.Parent = playerPetsFolder
	end
	return playerFolder
end



local function monitorEquippedPets(player)
	local equippedPetsFolder = player:WaitForChild("EquippedPets", 5)
	if not equippedPetsFolder then return end

	equippedPetsFolder.ChildAdded:Connect(function(pet)
		if pet:IsA("IntValue") then
			pet:GetPropertyChangedSignal("Value"):Connect(function()
				if pet.Value < 0 then return end
				local playerFolder = ensurePlayerPetsFolder(player)
				local petModel = playerFolder:FindFirstChild(pet.Name .. tostring(pet.Value + 1))
				if petModel then
					petModel:Destroy()
				end

				-- Cleanup the IntValue if no more pets of this type exist
				if pet.Value <= 0 then
					pet:Destroy()
				end
			end)
		end
	end)
end


local function loadPlayerPets(player)
	local equippedPetsFolder = player:WaitForChild("EquippedPets", 5)
	if not equippedPetsFolder then 
		return 
	end

	local playerFolder = ensurePlayerPetsFolder(player)
	task.wait(1)
	for _, pet in pairs(equippedPetsFolder:GetChildren()) do
		local petName = pet.Name
		local petCount = pet.Value
		for i = 1, petCount do
			local model, odds, imageId = findPetModel(petName)
			if model then
				local clonedModel = model:Clone()
				local image = clonedModel.ImagePart.SurfaceGui.ImageLabel
				local TitleTextLabel = clonedModel:FindFirstChild("PrimaryPart").TitleBillboard.TextLabel
				local OddsTextLabel = clonedModel:FindFirstChild("PrimaryPart").OddsBillboard.TextLabel

				TitleTextLabel.Text = petName
				image.Image = imageId
				OddsTextLabel.Text = "1 / " .. formatOdds(odds)

				clonedModel.Name = petName..i
				clonedModel.Parent = playerFolder
			end
		end
	end
end

game.Players.PlayerAdded:Connect(function(player)
	monitorEquippedPets(player)
	loadPlayerPets(player)
end)

equipPet.OnServerEvent:Connect(function(player, petName)
	local equippedPetsFolder = player:WaitForChild("EquippedPets", 5)
	if not equippedPetsFolder then
		warn("EquippedPets folder not found for player:", player.Name)
		return
	end

	if not petName or petName == "" then
		warn("Invalid petName received from player:", player.Name)
		return
	end

	local pet = equippedPetsFolder:FindFirstChild(petName)
	if not pet then
		-- Initialize the pet if it doesn't exist
		pet = Instance.new("IntValue")
		pet.Name = petName
		pet.Value = 0
		pet.Parent = equippedPetsFolder
	end

	local playerFolder = ensurePlayerPetsFolder(player)
	local model, odds, imageId = findPetModel(petName)

	if model then
		local clonedModel = model:Clone()
		local image = clonedModel.ImagePart.SurfaceGui.ImageLabel
		local TitleTextLabel = clonedModel:FindFirstChild("PrimaryPart").TitleBillboard.TextLabel
		local OddsTextLabel = clonedModel:FindFirstChild("PrimaryPart").OddsBillboard.TextLabel

		TitleTextLabel.Text = petName
		image.Image = imageId
		OddsTextLabel.Text = "1 / " .. formatOdds(odds)

		clonedModel.Name = petName
		clonedModel.Parent = playerFolder
	end
end)





