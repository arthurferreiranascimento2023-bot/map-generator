--==================================================
-- RoomPrefabManager.lua
--
-- Gerenciador de mapeamento entre tipos de salas
-- gerados no contexto e os prefabs disponíveis.
--
-- Funciona assim:
--   Contexto gera: "Cozinha"
--       |
--       v
--   Manager busca em: Prefabs/Rooms/Cozinha/
--       |
--       v
--   Retorna um prefab aleatório dessa pasta
--==================================================


local RoomPrefabManager = {}


--==================================================
-- CONFIGURAÇÃO DE PREFABS
--==================================================
--
-- Mapeia tipos de salas para suas pastas de prefabs.
-- Você pode adicionar quantos tipos quiser aqui.
--
-- Estrutura esperada no ReplicatedStorage:
--   Prefabs/
--     Rooms/
--       Cozinha/
--         - Prefab1
--         - Prefab2
--       Quarto/
--         - Prefab1
--         - Prefab2
--       Banheiro/
--         ...
--       etc
--
-- Se uma pasta não existir, o manager tenta
-- usar a pasta genérica "Generic"
--==================================================

local ROOM_TYPE_MAPPING = {

	-- Tipos de sala -> Nome da pasta em Prefabs/Rooms/

	-- Salas principais
	Cozinha = "Cozinha",
	Quarto = "Quarto",
	Banheiro = "Banheiro",
	SalaDeEstar = "SalaDeEstar",
	SalaDeJantar = "SalaDeJantar",

	-- Salas opcionais
	Biblioteca = "Biblioteca",
	Escritorio = "Escritorio",
	SuiteImovel = "SuiteImovel",
	Lavanderia = "Lavanderia",
	Despensa = "Despensa",
	Garagem = "Garagem",
	["Sala de Jogos"] = "SalaDeJogos",

	-- Salas especiais
	Porao = "Porão",
	Sotao = "Sotao",
	Adega = "Adega",
	["Sala de Utilidades"] = "SalaDeUtilidades",
}


--==================================================
-- SERVIÇOS
--==================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")


--==================================================
-- FUNÇÕES INTERNAS
--==================================================

-- Encontra a pasta de prefabs para um tipo de sala
local function GetRoomTypeFolder(roomType)

	-- Busca o mapeamento
	local folderName = ROOM_TYPE_MAPPING[roomType]

	if not folderName then

		warn("[RoomPrefabManager] Tipo de sala desconhecido: " .. roomType)
		return nil
	end

	-- Tenta encontrar a pasta
	local prefabsFolder = ReplicatedStorage:FindFirstChild("Prefabs")

	if not prefabsFolder then

		error("[RoomPrefabManager] Pasta 'Prefabs' não encontrada em ReplicatedStorage")
	end

	local roomsFolder = prefabsFolder:FindFirstChild("Rooms")

	if not roomsFolder then

		error("[RoomPrefabManager] Pasta 'Rooms' não encontrada em Prefabs")
	end

	local typeFolder = roomsFolder:FindFirstChild(folderName)

	if not typeFolder then

		warn(
			"[RoomPrefabManager] Pasta não encontrada: Prefabs/Rooms/" .. folderName
				.. " - Tentando pasta genérica..."
		)
		typeFolder = roomsFolder:FindFirstChild("Generic")

		if not typeFolder then

			warn(
				"[RoomPrefabManager] Pasta 'Generic' também não encontrada. "
					.. "Nenhum prefab disponível para: " .. roomType
			)
			return nil
		end
	end

	return typeFolder
end


-- Obtém um prefab aleatório de uma pasta
local function GetRandomPrefabFromFolder(folder, rng)

	if not folder then
		return nil
	end

	local prefabs = folder:GetChildren()

	if #prefabs == 0 then

		warn("[RoomPrefabManager] Nenhum prefab encontrado em: " .. folder:GetFullName())
		return nil
	end

	rng = rng or Random.new()

	local randomIndex = rng:NextInteger(1, #prefabs)

	return prefabs[randomIndex]
end


--==================================================
-- API PÚBLICA
--==================================================

-- Retorna um prefab para um tipo de sala específico
function RoomPrefabManager.GetPrefabForRoomType(roomType, rng)

	local typeFolder = GetRoomTypeFolder(roomType)

	if not typeFolder then
		return nil
	end

	local prefab = GetRandomPrefabFromFolder(typeFolder, rng)

	if prefab then
		-- Marca o prefab com o tipo esperado para evitar inconsistências
		-- Isso garante que o MapGeneratorWithContext saiba qual tipo foi realmente colocado.
		pcall(function()
			prefab:SetAttribute("RoomType", roomType)
		end)
	end

	return prefab
end


-- Retorna múltiplos prefabs para um tipo de sala
function RoomPrefabManager.GetPrefabsForRoomType(roomType, count)

	local typeFolder = GetRoomTypeFolder(roomType)

	if not typeFolder then
		return {}
	end

	local prefabs = typeFolder:GetChildren()

	if #prefabs == 0 then
		return {}
	end

	local result = {}

	for i = 1, math.min(count, #prefabs) do

		local p = prefabs[i]
		pcall(function()
			p:SetAttribute("RoomType", roomType)
		end)
		table.insert(result, p)
	end

	return result
end


-- Lista todos os tipos de salas disponíveis
function RoomPrefabManager.GetAvailableRoomTypes()

	local types = {}

	for roomType, _ in pairs(ROOM_TYPE_MAPPING) do

		table.insert(types, roomType)
	end

	table.sort(types)

	return types
end


-- Registra um novo tipo de sala (para adicionar tipos customizados)
function RoomPrefabManager.RegisterRoomType(roomType, folderName)

	ROOM_TYPE_MAPPING[roomType] = folderName

	print("[RoomPrefabManager] Novo tipo registrado: " .. roomType .. " -> " .. folderName)
end


-- Valida se uma pasta de prefabs existe para um tipo de sala
function RoomPrefabManager.ValidateRoomType(roomType)

	local folder = GetRoomTypeFolder(roomType)

	if not folder then
		return false, "Pasta não encontrada"
	end

	local prefabs = folder:GetChildren()

	if #prefabs == 0 then
		return false, "Nenhum prefab nesta pasta"
	end

	return true, #prefabs .. " prefab(s) encontrado(s)"
end


-- Valida todos os tipos de salas
function RoomPrefabManager.ValidateAllRoomTypes()

	print("\n[RoomPrefabManager] Validando tipos de salas...\n")

	local availableTypes = RoomPrefabManager.GetAvailableRoomTypes()
	local validCount = 0
	local invalidCount = 0

	for _, roomType in ipairs(availableTypes) do

		local isValid, message = RoomPrefabManager.ValidateRoomType(roomType)

		if isValid then

			print("  ✓ " .. roomType .. " - " .. message)
			validCount = validCount + 1
		else

			print("  ✗ " .. roomType .. " - " .. message)
			invalidCount = invalidCount + 1
		end
	end

	print(

	
	"\n" .. validCount .. " tipos válidos, " .. invalidCount .. " tipos inválidos\n"
	)
end


return RoomPrefabManager
