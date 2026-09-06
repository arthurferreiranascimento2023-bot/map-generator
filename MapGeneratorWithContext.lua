--==================================================
-- MapGeneratorWithContext.lua
--
-- Versão melhorada do MapPrefabsGenerator que
-- integra com o contexto e o gerenciador de prefabs.
--
-- Fluxo:
--   1. Contexto define quais salas existem
--   2. RoomPrefabManager encontra os prefabs
--   3. MapGenerator coloca tudo no mapa
--==================================================


local MapGenerator = {}


--==================================================
-- SERVIÇOS E MÓDULOS
--==================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ContextGen = require(game.ServerScriptService:WaitForChild("MapContextGenerator"))
local PrefabManager = require(game.ServerScriptService:WaitForChild("RoomPrefabManager"))


--==================================================
-- CONFIGURAÇÃO PADRÃO
--==================================================

local DEFAULT_CONFIG = {

	-- Onde as salas geradas serão colocadas
	MapName = "Map",

	-- Quantidade máxima de salas
	MaxRooms = 40,

	-- Quantas tentativas são feitas para cada Exit
	AttemptsPerExit = 30,

	-- Posição inicial da primeira sala
	StartCFrame = CFrame.new(0, 0, 0),
}


--==================================================
-- ATTACHMENTS
--==================================================

local function GetAttachment(model, name)

	for _, object in ipairs(model:GetDescendants()) do

		if object:IsA("Attachment") and object.Name == name then

			return object
		end
	end

	return nil
end


--==================================================
-- COLISÃO
--==================================================

local function GetAABB(model)

	local boxCFrame, size = model:GetBoundingBox()
	local half = size * 0.5

	local min = Vector3.new(math.huge, math.huge, math.huge)
	local max = Vector3.new(-math.huge, -math.huge, -math.huge)

	for x = -1, 1, 2 do

		for y = -1, 1, 2 do

			for z = -1, 1, 2 do

				local point = boxCFrame:PointToWorldSpace(
					Vector3.new(half.X * x, half.Y * y, half.Z * z)
				)

				min = Vector3.new(
					math.min(min.X, point.X),
					math.min(min.Y, point.Y),
					math.min(min.Z, point.Z)
				)

				max = Vector3.new(
					math.max(max.X, point.X),
					math.max(max.Y, point.Y),
					math.max(max.Z, point.Z)
				)
			end
		end
	end

	return { Min = min, Max = max }
end

local function AABBOverlaps(a, b)

	return not (
		a.Max.X <= b.Min.X or a.Min.X >= b.Max.X or a.Max.Y <= b.Min.Y or a.Min.Y >= b.Max.Y or a.Max.Z <= b.Min.Z or a.Min.Z >= b.Max.Z
	)
end


--==================================================
-- EXITS
--==================================================

local function GetAvailableExits(rooms)

	local exits = {}

	for _, room in ipairs(rooms) do

		for _, object in ipairs(room:GetDescendants()) do

			if object:IsA("Attachment") and object.Name == "Exit" and not object:GetAttribute("Used") then

				table.insert(exits, { Room = room, Attachment = object })
			end
		end
	end

	return exits
end

local function MarkUsed(attachment)

	attachment:SetAttribute("Used", true)
end


--==================================================
-- POSICIONAMENTO
--==================================================

local function PlaceRoom(prefab, exitInfo, existingRooms, mapFolder)

	local room = prefab:Clone()
	room.Parent = mapFolder

	local entry = GetAttachment(room, "Entry")

	if not entry then
		room:Destroy()
		return nil
	end

	room:PivotTo(CFrame.new())

	local entryLocal = room:GetPivot():ToObjectSpace(entry.WorldCFrame)
	local exitCFrame = exitInfo.Attachment.WorldCFrame

	local desiredEntryCFrame = exitCFrame * CFrame.Angles(0, math.pi, 0)
	local targetPivot = desiredEntryCFrame * entryLocal:Inverse()

	room:PivotTo(targetPivot)

	local roomAABB = GetAABB(room)

	for _, otherRoom in ipairs(existingRooms) do

		if otherRoom ~= exitInfo.Room then

			local otherAABB = GetAABB(otherRoom)

			if AABBOverlaps(roomAABB, otherAABB) then

				room:Destroy()
				return nil
			end
		end
	end

	return room
end


--==================================================
-- MAP
--==================================================

local function GetOrCreateMapFolder(name)

	local map = Workspace:FindFirstChild(name)

	if not map then

		map = Instance.new("Folder")
		map.Name = name
		map.Parent = Workspace
	end

	return map
end


--==================================================
-- GERADOR COM CONTEXTO
--==================================================

function MapGenerator.GenerateWithContext(options)

	options = options or {}

	--------------------------------------------------
	-- GERA O CONTEXTO
	--------------------------------------------------

	local seed = options.Seed or options.seed or os.time()
	local rng = Random.new(seed)

	print("\n[MapGen] Gerando contexto...")
	local context = ContextGen.Generate(seed)

	ContextGen.PrintContext(context)

	local stats = ContextGen.GetStats(context)
	print(
		"\n[MapGen] Total de salas no contexto: "
			.. stats.TotalSalas
			.. " (normais: "
			.. stats.TotalRooms
			.. " | especiais: "
			.. stats.TotalSpecialRooms
			.. ")"
	)

	--------------------------------------------------
	-- CONFIGURAÇÕES DE MAPA
	--------------------------------------------------

	local mapName = options.MapName or context.Name:gsub(" ", "_")
	local maxRooms = options.MaxRooms or options.maxRooms or DEFAULT_CONFIG.MaxRooms
	local attemptsPerExit = options.AttemptsPerExit or options.attemptsPerRoom or DEFAULT_CONFIG.AttemptsPerExit
	local startCFrame = options.StartCFrame or DEFAULT_CONFIG.StartCFrame

	--------------------------------------------------
	-- VALIDAÇÃO DE PREFABS
	--------------------------------------------------

	print("\n[MapGen] Validando prefabs disponíveis...")
	PrefabManager.ValidateAllRoomTypes()

	--------------------------------------------------
	-- MAP
	--------------------------------------------------

	local mapFolder = GetOrCreateMapFolder(mapName)
	mapFolder:ClearAllChildren()

	--------------------------------------------------
	-- PRIMEIRA SALA - Usa o contexto
	--------------------------------------------------

	print("[MapGen] Gerando primeira sala...")

	local firstRoomType = context.Rooms[1].Type
	local firstPrefab = PrefabManager.GetPrefabForRoomType(firstRoomType, rng)

	if not firstPrefab then

		error(
			"[MapGen] Nenhum prefab encontrado para a primeira sala: "
				.. firstRoomType
		)
	end

	local firstRoom = firstPrefab:Clone()
	firstRoom.Parent = mapFolder
	firstRoom:PivotTo(startCFrame)

	local rooms = { firstRoom }
	local generatedRooms = { [firstRoomType] = 1 }

	--------------------------------------------------
	-- GERAÇÃO PROCEDURAL
	--------------------------------------------------

	print("[MapGen] Iniciando geração procedural...\n")

	while #rooms < maxRooms do

		local availableExits = GetAvailableExits(rooms)

		if #availableExits == 0 then

			break
		end

		local exitInfo = availableExits[rng:NextInteger(1, #availableExits)]

		-- Escolhe um tipo de sala aleatório do contexto
		local randomRoomIndex = rng:NextInteger(1, #context.Rooms)
		local desiredRoomType = context.Rooms[randomRoomIndex].Type

		local newRoom = nil

		for _ = 1, attemptsPerExit do

			local prefab = PrefabManager.GetPrefabForRoomType(desiredRoomType, rng)

			if prefab then

				newRoom = PlaceRoom(prefab, exitInfo, rooms, mapFolder)

				if newRoom then

					break
				end
			end
		end

		if newRoom then

			MarkUsed(exitInfo.Attachment)

			local entry = GetAttachment(newRoom, "Entry")

			if entry then

				MarkUsed(entry)
			end

			table.insert(rooms, newRoom)

			generatedRooms[desiredRoomType] = (generatedRooms[desiredRoomType] or 0) + 1
		else

			MarkUsed(exitInfo.Attachment)
		end
	end

	--------------------------------------------------
	-- RESULTADO
	--------------------------------------------------

	print("\n" .. string.rep("=", 50))
	print("[MapGen] GERAÇÃO CONCLUÍDA")
	print(string.rep("=", 50))
	print("  Salas geradas: " .. #rooms .. "/" .. maxRooms)
	print("  Seed: " .. seed)
	print("  Mapa: " .. mapFolder:GetFullName())
	print("\n[MapGen] Distribuição de salas:")

	for roomType, count in pairs(generatedRooms) do

		print("  - " .. roomType .. ": " .. count)
	end

	print(string.rep("=", 50) .. "\n")

	return mapFolder, seed, context
end

return MapGenerator
