--==================================================
-- MapGeneratorWithContext.lua
--
-- Versão melhorada do MapPrefabsGenerator que
-- integra com o contexto e o gerenciador de prefabs.
--
-- Agora com suporte a constraints customizáveis!
--
-- Fluxo:
--   1. Contexto define quais salas existem (respeitando Min/Max)
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
-- HELPERS DE CONTEXTO
--==================================================

local function GetContextMaxForType(context, typeName)
	-- Busca em context.Rooms
	if context and context.Rooms then
		for _, r in ipairs(context.Rooms) do
			if r.Type == typeName then
				return r.Count or 0
			end
		end
	end
	-- Busca em SpecialRooms
	if context and context.SpecialRooms then
		for _, r in ipairs(context.SpecialRooms) do
			if r.Type == typeName then
				return r.Count or 0
			end
		end
	end
	return 0
end


--==================================================
-- GERADOR COM CONTEXTO
--==================================================

function MapGenerator.GenerateWithContext(options)

	options = options or {}

	--------------------------------------------------
	-- GERA O CONTEXTO (OU USA O CONTEXTO FORNECIDO)
	--------------------------------------------------

	local seed = options.Seed or options.seed or os.time()
	local rng = Random.new(seed)

	print("\n[MapGen] Gerando contexto...")

	-- Pega constraints customizados ou usa os padrões
	local customConstraints = options.Constraints or options.constraints or nil

	local context = nil
	if options.Context and type(options.Context) == "table" then
		context = options.Context
	else
		context = ContextGen.Generate(seed, customConstraints)
	end

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

	-- Garante que o prefab retornado corresponde ao tipo (safety)
	local firstPrefabType = firstPrefab:GetAttribute("RoomType") or firstPrefab.Name
	if firstPrefabType ~= firstRoomType then
		-- tenta forçar o atributo no prefab ou falhar com erro claro
		pcall(function() firstPrefab:SetAttribute("RoomType", firstRoomType) end)
		firstPrefabType = firstRoomType
	end

	local firstRoom = firstPrefab:Clone()
	firstRoom.Parent = mapFolder
	firstRoom:PivotTo(startCFrame)

	local rooms = { firstRoom }
	local generatedRooms = {}
	generatedRooms[firstPrefabType] = (generatedRooms[firstPrefabType] or 0) + 1

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

		-- Escolhe um tipo de sala elegível do contexto (respeita as quantidades do contexto)
		local eligibleRoomTypes = {}
		for _, roomDef in ipairs(context.Rooms) do
			local t = roomDef.Type
			local maxCount = roomDef.Count or 0
			local current = generatedRooms[t] or 0
			if current < maxCount then
				table.insert(eligibleRoomTypes, t)
			end
		end

		local desiredRoomType = nil

		-- Se não há tipos elegíveis, tenta colocar salas especiais (se houver) ou encerra
		if #eligibleRoomTypes == 0 then
			-- tenta special rooms (opcionais)
			local eligibleSpecials = {}
			if context.SpecialRooms then
				for _, s in ipairs(context.SpecialRooms) do
					local t = s.Type
					local maxCount = s.Count or 0
					local current = generatedRooms[t] or 0
					if current < maxCount then
						table.insert(eligibleSpecials, t)
					end
				end
			end

			if #eligibleSpecials == 0 then
				break
			else
				desiredRoomType = eligibleSpecials[rng:NextInteger(1, #eligibleSpecials)]
			end
		else
			desiredRoomType = eligibleRoomTypes[rng:NextInteger(1, #eligibleRoomTypes)]
		end

		local newRoom = nil
		local placedPrefab = nil

		for _ = 1, attemptsPerExit do

			local prefab = PrefabManager.GetPrefabForRoomType(desiredRoomType, rng)

			if not prefab then
				break
			end

			-- determine the prefab's declared type (attribute or name)
			local prefabType = prefab:GetAttribute("RoomType") or prefab.Name

			-- find allowed count in context for that prefabType
			local allowed = GetContextMaxForType(context, prefabType)
			local current = generatedRooms[prefabType] or 0

			-- if this prefab's type already reached allowed, skip this prefab
			if allowed > 0 and current >= allowed then
				-- skip and continue attempts
				prefab = nil
				-- small fallback: try next iteration
			else
				-- try place
				newRoom = PlaceRoom(prefab, exitInfo, rooms, mapFolder)
				if newRoom then
					placedPrefab = prefab
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

			-- conta pelo tipo real do prefab colocado (atributo RoomType, se existir, senão o nome)
			local placedType = nil
			if placedPrefab then
				placedType = placedPrefab:GetAttribute("RoomType") or placedPrefab.Name
			else
				placedType = desiredRoomType
			end

			generatedRooms[placedType] = (generatedRooms[placedType] or 0) + 1
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
	print("\n[MapGen] Distribuição de salas geradas:")

	for roomType, count in pairs(generatedRooms) do

		print("  - " .. roomType .. ": " .. count)
	end

	print(string.rep("=", 50) .. "\n")

	return mapFolder, seed, context
end

return MapGenerator
