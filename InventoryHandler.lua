local player = game.Players.LocalPlayer
local PlayerPetsFolder = player:WaitForChild("PetsDatastore")
local equippedFolder = player:WaitForChild("EquippedPets")

local PetTemplate = script.Parent.PetTemplate
local equipPetFrameOuter = script.Parent.Parent.EquipFrame
local equipPetFrame = equipPetFrameOuter.Frame
local equipPetFrameTemplate = equipPetFrame.PetTemplate
local inventoryFrame = script.Parent

local tweenService = game:GetService("TweenService")
local equipSize = player:WaitForChild("PetEquips")

local equipPetEvent = game.ReplicatedStorage.Pets.EquipPet
local unequipPetEvent = game.ReplicatedStorage.Pets.UnequipPet
local index = require(game.ReplicatedStorage.Pets.Index)

local updateValuesEvent = game.ReplicatedStorage.Pets.UpdateValues
local hoverSound = script.Pop
local originalSize = UDim2.new(0.734, 0,1, 0)
local shrinkSize = UDim2.new(0.734, 0, 0.635, 0)

local oldPosition = UDim2.new(0.367, 0, 0.5, 0)
local newPosition = UDim2.new(.367, 0,0.682, 0)


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

local function findPetInfo(petName)
	for _, petInfo in pairs(index) do
		if petInfo.name == petName then
			return petInfo
		end
	end
	return nil
end

local function fillPetInfoFrame(petName)
	local petInfo = findPetInfo(petName)
	if petInfo then
		local petFrame = script.Parent.Parent.PetInfoFrame
		petFrame.PetName.Text = petInfo.name
		petFrame.PetImage.Image = petInfo.imageId
		petFrame.Rarity.Text = petInfo.category
		petFrame.Odds.Text = "1 / " .. petInfo.odds
		petFrame.Value.Text = "Pet Value: " .. formatNumber(petInfo.Value)
		petFrame.Visible = true
		
		petFrame.Sell.Visible = true
		petFrame.Sell5.Visible = true
		petFrame.Sell10.Visible = true
		petFrame.SellAll.Visible = true
		petFrame.SellAllButOne.Visible = true

	end
end


local function erasePetInfoFrame(petName)
	local petInfo = findPetInfo(petName)
	if petInfo then
		local petFrame = script.Parent.Parent.PetInfoFrame
		petFrame.PetName.Text = ""
		petFrame.PetImage.Image = "76738323868091"
		petFrame.PetImage.Visible= true
		petFrame.Rarity.Text = ""
		petFrame.Odds.Text = ""
		petFrame.Value.Text = ""
		petFrame.Visible = true
		
		petFrame.Sell.Visible = false
		petFrame.Sell5.Visible = false
		petFrame.Sell10.Visible = false
		petFrame.SellAll.Visible = false
		petFrame.SellAllButOne.Visible = false
	else
		print("Pet info doesn't exist")
	end
	
end

local function resetInventoryFrame()
	inventoryFrame.Size = originalSize
	inventoryFrame.Position = UDim2.new(0.367, 0, 0.5, 0)
	equipPetFrameOuter.Visible = false
end

local function updateEquipCountText()
	local equipSize = player:WaitForChild("PetEquips").Value
	local totalEquipped =0
	for _, item in pairs(equippedFolder:GetChildren()) do
		if item and item:IsA("IntValue") then
			totalEquipped+=item.Value
		end
	end
	local amountEquipped = #equippedFolder:GetChildren()
	equipPetFrameOuter.PetEquips.Text = tostring(totalEquipped) .. " / " .. tostring(equipSize)
end

local function destroyTemplateIfEmpty(template, count)
	if count <= 0 then
		template:Destroy()
	end
end

local function unequipPet(petName, templateToDestroy)
	-- Notify the server to unequip the pet
	updateValuesEvent:FireServer("Unequip", petName)
	unequipPetEvent:FireServer(petName)


	-- Remove the pet from the equipped frame
	if templateToDestroy then
		templateToDestroy:Destroy()
	end

	-- Adjust the UI if there are no pets equipped
	if #equippedFolder:GetChildren() == 0 then
		resetInventoryFrame()
	else
		updateEquipCountText()
	end
end



local function clearSellButtons(petInfoFrame)
	local sellButtons = {
		petInfoFrame:FindFirstChild("Sell"),
		petInfoFrame:FindFirstChild("Sell5"),
		petInfoFrame:FindFirstChild("Sell10"),
		petInfoFrame:FindFirstChild("SellAllButOne"),
		petInfoFrame:FindFirstChild("SellAll")
	}

	for _, button in ipairs(sellButtons) do
		if button then
			-- Clear existing connections by cloning the button
			local clonedButton = button:Clone()
			clonedButton.Parent = button.Parent
			button:Destroy()

			-- Reset button text and visibility
			clonedButton.Text = ""
			clonedButton.Visible = false
		end
	end
end



local function sellButton(newPetClone, petName, petInfo)
	-- Find the Sell buttons dynamically
	local sell = newPetClone.Parent.Parent.PetInfoFrame:FindFirstChild("Sell")
	local sell5 = newPetClone.Parent.Parent.PetInfoFrame:FindFirstChild("Sell5")
	local sell10 = newPetClone.Parent.Parent.PetInfoFrame:FindFirstChild("Sell10")
	local sellAllButOne = newPetClone.Parent.Parent.PetInfoFrame:FindFirstChild("SellAllButOne")
	local sellAll = newPetClone.Parent.Parent.PetInfoFrame:FindFirstChild("SellAll")
	local openSellButtons = newPetClone.Parent.Parent.PetInfoFrame:FindFirstChild("OpenSellButtons")

	-- Dependencies
	local sellPetEvent = game.ReplicatedStorage.Misc.Remotes.SellPet
	local fireworks = require(game.ReplicatedStorage.Fireworks)

	-- Sell button states
	local sellPetLevel = 0
	local sellPetLevel5 = 0
	local sellPetLevel10 = 0
	local sellAllButOneLevel = 0
	local sellAllLevel = 0

	-- Set up Sell button functionality
	if sell then
		sell.Text = "Sell 1: " .. formatNumber(petInfo.Value)
		sell.MouseButton1Click:Connect(function()

			if sellPetLevel == 0 then
				sell.Text = "Are you sure?"
				sellPetLevel = 1
				script.Click:Play()
				task.wait(2)
				sellPetLevel = 0
				sell.Text = "Sell 1: " .. formatNumber(petInfo.Value)

			elseif sellPetLevel == 1 then
				if PlayerPetsFolder:WaitForChild(petName).Value == 1 then
					erasePetInfoFrame(petName)
					print("frame erased")
				end
				sellPetEvent:FireServer(petInfo.Value, petName, 1)
				script.Buy2:Play()
				coroutine.wrap(function()
					fireworks.PlayFireworks(player.Character.Head)
					task.wait(1)
					script.Fireworks:Play()

				end)()
			end

		end)
	end

	-- Set up Sell 5 button functionality
	if sell5 then
		sell5.Text = "Sell 5: " .. formatNumber(petInfo.Value * 5)
		sell5.MouseButton1Click:Connect(function()
			if sellPetLevel5 == 0 then
				sell5.Text = "Are you sure?"
				sellPetLevel5 = 1
				script.Click:Play()
				task.wait(1)
				sellPetLevel5 = 0
				sell5.Text = "Sell 5: " .. formatNumber(petInfo.Value)

			elseif sellPetLevel5 == 1 then
				if PlayerPetsFolder:WaitForChild(petName).Value >= 5 then
					if PlayerPetsFolder:WaitForChild(petName).Value == 0 then
						erasePetInfoFrame(petName)
					end
					sellPetEvent:FireServer(petInfo.Value * 5, petName, 5)
					script.Buy2:Play()
					coroutine.wrap(function()
						fireworks.PlayFireworks(player.Character.Head)
						task.wait(1)
						script.Fireworks:Play()

					end)()
				else
					sell5.Text = "Not Enough Pets"
					task.wait(1)
					sell5.Text = "Sell 5: " .. formatNumber(petInfo.Value * 5)
				end
			end
		end)
	end

	-- Set up Sell 10 button functionality
	if sell10 then
		sell10.Text = "Sell 10: " .. formatNumber(petInfo.Value * 10)
		sell10.MouseButton1Click:Connect(function()
			if sellPetLevel10 == 0 then
				sell10.Text = "Are you sure?"
				sellPetLevel10 = 1
				script.Click:Play()
				task.wait(1)
				sellPetLevel10 = 0
				sell10.Text = "Sell 10: " .. formatNumber(petInfo.Value)

			elseif sellPetLevel10 == 1 then
				if PlayerPetsFolder:WaitForChild(petName).Value >= 10 then
					if PlayerPetsFolder:WaitForChild(petName).Value == 0 then
						erasePetInfoFrame(petName)
					end
					sellPetEvent:FireServer(petInfo.Value * 10, petName, 10)
					script.Buy2:Play()
					coroutine.wrap(function()
						fireworks.PlayFireworks(player.Character.Head)
						task.wait(1)
						script.Fireworks:Play()

					end)()
				else
					sell10.Text = "Not Enough Pets"
					task.wait(1)
					sell10.Text = "Sell 10: " .. formatNumber(petInfo.Value)
				end
			end
		end)
	end

	if sellAllButOne then
		local pet = PlayerPetsFolder:FindFirstChild(petName)
		if pet.Value == 1 then
			sellAllButOne.Text = "All But One"		
		else
			sellAllButOne.Text = "All But One " .. formatNumber(petInfo.Value*(pet.Value-1))

		end
		sellAllButOne.MouseButton1Click:Connect(function()
			if pet.Value == 1 then
				sellAllButOne.Text = "Not Enough Pets"
				task.wait(1)
				sellAllButOne.Text = "All But One"

			elseif sellAllButOneLevel == 0 then
				sellAllButOne.Text = "Are you sure?"
				sellAllButOneLevel = 1
				script.Click:Play()
				task.wait(1)
				sellAllButOneLevel = 0
				sellAllButOne.Text = "All But One: " .. formatNumber(petInfo.Value)

			elseif sellAllButOneLevel == 1 then
				if PlayerPetsFolder:FindFirstChild(petName).Value > 1 then
					
					sellPetEvent:FireServer(petInfo.Value * (pet.Value-1), petName, pet.Value-1) print("event fired")
					script.Buy2:Play()
					coroutine.wrap(function()
						fireworks.PlayFireworks(player.Character.Head)
						task.wait(1)
						script.Fireworks:Play()
					end)()
				else
					sellAllButOne.Text = "Not Enough Pets"
					task.wait(1)
					sellAllButOne.Text = "All But One"
				end
			end
		end)
	end

	if sellAll then
		local pet = PlayerPetsFolder:FindFirstChild(petName)
		if pet.Value >= 1 then
			sellAll.Text = "Sell All " .. formatNumber(petInfo.Value*(pet.Value))
		end

		sellAll.MouseButton1Click:Connect(function()
			local pet = PlayerPetsFolder:FindFirstChild(petName)
			if pet.Value >= 1 then
				sellAll.Text = "Sell All " .. formatNumber(petInfo.Value*(pet.Value))
			end
			if sellAllLevel == 0 then
				sellAll.Text = "Are you sure?"
				sellAllLevel = 1
				script.Click:Play()
				task.wait(1)
				sellAllLevel = 0
				sellAll.Text = "Sell All: " .. formatNumber(petInfo.Value)

			elseif sellAllLevel == 1 then
				if PlayerPetsFolder:FindFirstChild(petName).Value >= 1 then
					sellPetEvent:FireServer(petInfo.Value * (pet.Value), petName, pet.Value)
					script.Buy2:Play()
					erasePetInfoFrame(petName)
					coroutine.wrap(function()
						fireworks.PlayFireworks(player.Character.Head)
						task.wait(1)
						script.Fireworks:Play()
					end)()
				else
					sellAll.Text = "Not Enough Pets"
					task.wait(1)
					sellAll.Text = "Sell All " .. formatNumber(petInfo.Value*(pet.Value))

				end
			end
		end)
	end
	-- Handle OpenSellButtons functionality
	if openSellButtons then
		openSellButtons.MouseButton1Click:Connect(function()
			if sell then sell.Visible = not sell.Visible end
			if sell5 then sell5.Visible = not sell5.Visible end
			if sell10 then sell10.Visible = not sell10.Visible end
			if sellAllButOne then sellAllButOne.Visible = not sellAllButOne.Visible end
			if sellAll then sellAll.Visible = not sellAll.Visible end
			if sell.Visible then
				openSellButtons.Text = "Close Sell Buttons"
				script.Click:Play()
			end
		end)
	end
end

function formatNumber(num)
	if num >= 1e9 then
		return string.format("%.1fb", num / 1e9)
	elseif num >= 1e6 then
		return string.format("%.1fm", num / 1e6)
	elseif num >= 1e3 then
		return string.format("%.1fk", num / 1e3)
	else
		return tostring(num)
	end
end

local function equipPet(petName)
	local equipSize = player:WaitForChild("PetEquips").Value

	erasePetInfoFrame(petName)
	if #equippedFolder:GetChildren() >= equipSize then
		return
	end
	local totalEquipped =0
	for _, item in pairs(equippedFolder:GetChildren()) do
		if item and item:IsA("IntValue") then
			totalEquipped+=item.Value
		end
	end
	if totalEquipped >= equipSize then
		return
	end

	-- Notify the server to equip the pet
	equipPetEvent:FireServer(petName)
	updateValuesEvent:FireServer("Equip", petName)

	-- Update the UI to reflect the equipped pet
	local petInfo = findPetInfo(petName)
	if petInfo then
		local newPetClone = equipPetFrameTemplate:Clone()
		newPetClone.Name = petName .. "_Clone_" .. tostring(#equippedFolder:GetChildren() + 1)
		newPetClone.Title.Text = petName
		newPetClone.Title.Visible = true
		newPetClone.Image = petInfo.imageId
		newPetClone.Parent = equipPetFrame
		newPetClone.Visible = true
		
		--newPetClone.Info.Odds.Text = "1 / " .. formatOdds(petInfo.odds)
		--newPetClone.Info.Rarity.Text = petInfo.category

		-- Add unequip functionality
		newPetClone.MouseButton1Click:Connect(function()
			script.Unequip:Play()
			unequipPet(petName, newPetClone)
		end)

		local openInfo = newPetClone:FindFirstChild("OpenInfo")
		if openInfo then
			openInfo.MouseButton1Click:Connect(function()
				local infoFrame = script.Parent.Parent.PetInfoFrame
				erasePetInfoFrame(petName)
				clearSellButtons(script.Parent.Parent.PetInfoFrame)

				for _, item in pairs(infoFrame:GetChildren()) do
					if item:IsA("TextButton") or item:IsA("TextLabel") or item:IsA("ImageLabel") then
						fillPetInfoFrame(petName)
						item.Visible= true
					end
				end
				hoverSound:Play()
				fillPetInfoFrame(petName)
				sellButton(newPetClone, petName, petInfo)
			end)
		end


	end

	-- Adjust the UI
	equipPetFrameOuter.Visible = true
	local divider = equipPetFrameOuter.Divider
	divider.Size = UDim2.new(0,0,3,0)
	local tweenInfo = TweenInfo.new(.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	local dividerTween = tweenService:Create(divider, tweenInfo, {Size = UDim2.new(1,0,3,0)})
	inventoryFrame.Size = shrinkSize
	if #equippedFolder:GetChildren() == 0 then
		dividerTween:Play()
	else
		divider.Size = UDim2.new(1, 0 , 3, 0)
	end
	inventoryFrame.Position = UDim2.new(.367, 0,0.682, 0)
	updateEquipCountText()
end




function createInventoryTemplate(petName, count)
	local existingTemplate = inventoryFrame:FindFirstChild(petName)
	if count <= 0 then
		if existingTemplate then
			existingTemplate:Destroy()
		end
		return
	end
	if existingTemplate then
		local amount = existingTemplate:FindFirstChild("Amount")
		if amount then
			amount.Text = tostring(count) .. "x"
			amount.Visible = true
		end
	else
		local petInfo = findPetInfo(petName)
		if petInfo then
			local newPetClone = PetTemplate:Clone()
			newPetClone.Name = petName
			newPetClone.Title.Text = petName
			newPetClone.Title.Visible = true
			newPetClone.Info.Odds.Text = "1 / " .. formatOdds(petInfo.odds)
			newPetClone.Info.Rarity.Text = petInfo.category
			newPetClone.Info.Odds.Visible = true
			newPetClone.Info.Rarity.Visible = true
			newPetClone.Info.OpenSellButtons.Visible = true
			
			local amount = newPetClone:FindFirstChild("Amount")
			if amount then
				amount.Text = tostring(count) .. "x"
				amount.Visible = true
			end


			newPetClone.Image = petInfo.imageId
			newPetClone.Parent = inventoryFrame
			newPetClone.Visible = true
			local openInfo = newPetClone:FindFirstChild("OpenInfo")
			if openInfo then
				openInfo.Visible= true
			end
			local equipButton = newPetClone:FindFirstChild("EquipButton")
			if equipButton then
				equipButton.Visible =true
			end
			
			local equipButton = newPetClone:FindFirstChild("EquipButton")
			if equipButton then
				equipButton.MouseButton1Click:Connect(function()
					script.Equip:Play()
					equipPet(petName)
				end)
			end

			local openInfo = newPetClone:FindFirstChild("OpenInfo")
			openInfo.MouseButton1Click:Connect(function()
				local infoFrame = script.Parent.Parent.PetInfoFrame
				local infoFrame = script.Parent.Parent.PetInfoFrame
				erasePetInfoFrame(petName)
				clearSellButtons(script.Parent.Parent.PetInfoFrame)
				for _, item in pairs(infoFrame:GetChildren()) do
					if item:IsA("TextButton") or item:IsA("TextLabel") or item:IsA("ImageLabel") then
						fillPetInfoFrame(petName)
						item.Visible = true
					end
				end
				hoverSound:Play()
				sellButton(newPetClone, petName, petInfo)
				fillPetInfoFrame(petName)

			end)
		end
	end
end

local function processPets()
	-- Clear the inventory and equip frames
	for _, child in pairs(inventoryFrame:GetChildren()) do
		if child:IsA("GuiObject") and child ~= PetTemplate then
			child:Destroy()
		end
	end

	for _, child in pairs(equipPetFrame:GetChildren()) do
		if child:IsA("GuiObject") and child ~= equipPetFrameTemplate then
			child:Destroy()
		end
	end

	local hasEquippedPets = false

	-- Gather all pets and their information
	local pets = {}
	for _, pet in pairs(PlayerPetsFolder:GetChildren()) do
		local petInfo = findPetInfo(pet.Name)
		if petInfo then
			table.insert(pets, {name = pet.Name, count = pet.Value, odds = petInfo.odds})
		end
	end

	-- Sort pets by odds in descending order
	table.sort(pets, function(a, b)
		return a.odds > b.odds
	end)

	-- Create inventory templates in the sorted order
	for _, petData in ipairs(pets) do
		createInventoryTemplate(petData.name, petData.count)
	end

	-- Process equipped pets
	for _, pet in ipairs(equippedFolder:GetChildren()) do
		hasEquippedPets = true
		for i = 1, pet.Value do
			local petInfo = findPetInfo(pet.Name)
			if petInfo then
				local newPetClone = equipPetFrameTemplate:Clone()
				newPetClone.Name = pet.Name
				newPetClone.Title.Text = pet.Name
				newPetClone.Title.Visible = true

				local openInfo = newPetClone:FindFirstChild("OpenInfo")
				if openInfo then
					openInfo.Visible= true
				end
				local equipButton = newPetClone:FindFirstChild("EquipButton")
				if equipButton then
					equipButton.Visible =true
				end
				local amount = newPetClone:FindFirstChild("Amount")
				if amount then
					amount.Text = tostring(pet.Value) .. "x"
					amount.Visible = true
				end

				newPetClone.Image = petInfo.imageId
				newPetClone.Parent = equipPetFrame
				newPetClone.Visible = true

				newPetClone.MouseButton1Click:Connect(function()
					script.Unequip:Play()
					unequipPet(newPetClone.Name)
				end)
			end
		end
	end

	-- Update UI
	updateEquipCountText()
	if hasEquippedPets then
		inventoryFrame.Size = shrinkSize
		inventoryFrame.Position = newPosition
		equipPetFrameOuter.Visible = true
	else
		resetInventoryFrame()
	end
end


local function monitorPlayerPetsFolder()
	for _, pet in pairs(PlayerPetsFolder:GetChildren()) do
		if pet:IsA("IntValue") then
			pet:GetPropertyChangedSignal("Value"):Connect(function()
				processPets()
			end)
		end
	end

	PlayerPetsFolder.ChildAdded:Connect(function(child)
		if child:IsA("IntValue") then
			child:GetPropertyChangedSignal("Value"):Connect(function()
				processPets()
			end)
		end
		processPets()
	end)

	PlayerPetsFolder.ChildRemoved:Connect(function()
		processPets()
	end)
end

equipSize.Changed:Connect(function(Value)
	updateEquipCountText()
end)

PlayerPetsFolder.ChildAdded:Connect(processPets)
PlayerPetsFolder.ChildRemoved:Connect(processPets)
equippedFolder.ChildAdded:Connect(processPets)
equippedFolder.ChildRemoved:Connect(processPets)

monitorPlayerPetsFolder()
processPets()
