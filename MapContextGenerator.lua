--==================================================
-- MapContextGenerator.lua
--
-- Gerador procedural de contexto para a casa/mapa.
-- Cria as características da casa na hora de forma aleatória.
--
-- Um contexto define:
--   • Número de andares
--   • Se tem porão
--   • Se tem sotão
--   • Áreas temáticas (cozinha, sala, quartos, etc)
--   • Quantidade de salas por tipo
--==================================================


local MapContextGenerator = {}


--==================================================
-- TIPOS DE SALAS
--==================================================

local ROOM_TYPES = {
	"SalaDeEstar",
	"Cozinha",
	"Quarto",
	"Banheiro",
	"SalaDeJantar",
	"Biblioteca",
	"Escritorio",
	"SuiteImovel",
	"Lavanderia",
	"Despensa",
	"Garagem",
	"Sala de Jogos",
}

local SPECIAL_ROOM_TYPES = {
	"Porão",
	"Sotao",
	"Adega",
	"Sala de Utilidades",
}


--==================================================
-- GERADOR PROCEDURAL
--==================================================

-- Gera o contexto de forma procedural
local function GenerateContext(rng)

	rng = rng or Random.new()

	-- Decide número de andares (1-4)
	local floors = rng:NextInteger(1, 4)

	-- Decide características especiais
	local hasBasement = rng:NextNumber() > 0.4  -- 60% de chance
	local hasAttic = rng:NextNumber() > 0.3    -- 70% de chance

	-- Salas por tipo
	local rooms = {}

	-- COZINHA - sempre tem 1
	table.insert(rooms, {
		Type = "Cozinha",
		Count = 1,
		Floor = 1,
	})

	-- SALA DE ESTAR - 1-2
	table.insert(rooms, {
		Type = "SalaDeEstar",
		Count = rng:NextInteger(1, 2),
		Floor = 1,
	})

	-- SALA DE JANTAR - 30% de chance
	if rng:NextNumber() > 0.7 then

		table.insert(rooms, {
			Type = "SalaDeJantar",
			Count = 1,
			Floor = 1,
		})
	end

	-- QUARTOS - depende do número de andares (1-4 por andar)
	for floor = 1, floors do

		local quarterCount = rng:NextInteger(1, 4)

		table.insert(rooms, {
			Type = "Quarto",
			Count = quarterCount,
			Floor = floor,
		})
	end

	-- BANHEIROS - geralmente 1 por 2 quartos
	for floor = 1, floors do

		local bathroomCount = rng:NextInteger(1, 2)

		table.insert(rooms, {
			Type = "Banheiro",
			Count = bathroomCount,
			Floor = floor,
		})
	end

	-- SUITE IMÓVEL - 20% de chance, em andar alto
	if rng:NextNumber() > 0.8 then

		local suiteFloor = (floors > 1) and floors or 1

		table.insert(rooms, {
			Type = "SuiteImovel",
			Count = 1,
			Floor = suiteFloor,
		})
	end

	-- BIBLIOTECA - 25% de chance
	if rng:NextNumber() > 0.75 then

		table.insert(rooms, {
			Type = "Biblioteca",
			Count = 1,
			Floor = math.min(2, floors),
		})
	end

	-- ESCRITÓRIO - 35% de chance
	if rng:NextNumber() > 0.65 then

		table.insert(rooms, {
			Type = "Escritorio",
			Count = 1,
			Floor = math.min(2, floors),
		})
	end

	-- LAVANDERIA - 40% de chance
	if rng:NextNumber() > 0.6 then

		table.insert(rooms, {
			Type = "Lavanderia",
			Count = 1,
			Floor = 1,
		})
	end

	-- SALA DE JOGOS - 30% de chance
	if rng:NextNumber() > 0.7 then

		table.insert(rooms, {
			Type = "Sala de Jogos",
			Count = 1,
			Floor = math.min(2, floors),
		})
	end

	-- SALAS ESPECIAIS
	local specialRooms = {}

	-- PORÃO
	if hasBasement then

		table.insert(specialRooms, {
			Type = "Porão",
			Count = 1,
		})

		-- Sala de Utilidades sempre no porão
		if rng:NextNumber() > 0.5 then

			table.insert(specialRooms, {
				Type = "Sala de Utilidades",
				Count = 1,
			})
		end

		-- Adega no porão
		if rng:NextNumber() > 0.7 then

			table.insert(specialRooms, {
				Type = "Adega",
				Count = 1,
			})
		end
	end

	-- SOTÃO
	if hasAttic then

		table.insert(specialRooms, {
			Type = "Sotao",
			Count = 1,
		})
	end

	return {
		Name = GenerateName(floors, hasBasement, hasAttic),
		Floors = floors,
		HasBasement = hasBasement,
		HasAttic = hasAttic,
		Rooms = rooms,
		SpecialRooms = specialRooms,
	}
end


-- Gera um nome descritivo para a casa
local function GenerateName(floors, hasBasement, hasAttic)

	local names = {
		"Casa",
		"Mansão",
		"Residência",
		"Solar",
		"Propriedade",
	}

	local baseName = names[math.random(1, #names)]

	if floors >= 3 then

		baseName = "Mansão"
	elseif floors == 2 then

		baseName = "Casa de Dois Andares"
	end

	if hasBasement and hasAttic then

		return baseName .. " Completa"
	elseif hasBasement then

		return baseName .. " com Porão"
	elseif hasAttic then

		return baseName .. " com Sotão"
	end

	return baseName
end


--==================================================
-- FORMATAÇÃO E DISPLAY
--==================================================

-- Formata o contexto para print legível
local function FormatContextForPrint(context)

	local output = {}

	table.insert(output, "")
	table.insert(output, "╔════════════════════════════════════════════════════╗")
	table.insert(output, "║           CONTEXTO DO MAPA GERADO                  ║")
	table.insert(output, "╠════════════════════════════════════════════════════╣")
	table.insert(output, "║ Nome: " .. context.Name .. string.rep(" ", 43 - #context.Name) .. "║")
	table.insert(output, "╠════════════════════════════════════════════════════╣")

	-- Estrutura
	table.insert(output, "║ ESTRUTURA:                                         ║")
	table.insert(
		output,
		"║   • Andares: " .. context.Floors .. string.rep(" ", 40 - #tostring(context.Floors)) .. "║"
	)
	table.insert(
		output,
		"║   • Porão: " .. (context.HasBasement and "Sim" or "Não") .. string.rep(" ", 41) .. "║"
	)
	table.insert(output, "║   • Sotão: " .. (context.HasAttic and "Sim" or "Não") .. string.rep(" ", 41) .. "║")

	-- Salas por andar
	if #context.Rooms > 0 then

		table.insert(output, "╠════════════════════════════��═══════════════════════╣")
		table.insert(output, "║ SALAS POR ANDAR:                                   ║")

		for floor = 1, context.Floors do

			local roomsInFloor = {}

			for _, room in ipairs(context.Rooms) do

				if (room.Floor == nil or room.Floor == floor) then

					for _ = 1, room.Count do

						table.insert(roomsInFloor, room.Type)
					end
				end
			end

			if #roomsInFloor > 0 then

				table.insert(output, "║   Andar " .. floor .. ":                                      ║")

				for _, roomType in ipairs(roomsInFloor) do

					table.insert(
						output,
						"║      - " .. roomType .. string.rep(" ", 43 - #roomType) .. "║"
					)
				end
			end
		end
	end

	-- Salas especiais
	if #context.SpecialRooms > 0 then

		table.insert(output, "╠════════════════════════════════════════════════════╣")
		table.insert(output, "║ SALAS ESPECIAIS:                                   ║")

		for _, special in ipairs(context.SpecialRooms) do

			for _ = 1, special.Count do

				table.insert(
					output,
					"║   • " .. special.Type .. string.rep(" ", 45 - #special.Type) .. "║"
				)
			end
		end
	end

	table.insert(output, "╚════════════════════════════════════════════════════╝")
	table.insert(output, "")

	return table.concat(output, "\n")
end


-- Calcula estatísticas do contexto
local function GetContextStats(context)

	local totalRooms = 0
	local totalSpecialRooms = 0

	for _, room in ipairs(context.Rooms) do

		totalRooms = totalRooms + room.Count
	end

	for _, special in ipairs(context.SpecialRooms) do

		totalSpecialRooms = totalSpecialRooms + special.Count
	end

	return {
		TotalRooms = totalRooms,
		TotalSpecialRooms = totalSpecialRooms,
		TotalSalas = totalRooms + totalSpecialRooms,
		Andares = context.Floors,
	}
end


--==================================================
-- API PÚBLICA
--==================================================

-- Gera um novo contexto proceduralmente
function MapContextGenerator.Generate(seed)

	local rng = Random.new(seed or os.time())

	return GenerateContext(rng)
end


-- Printa o contexto formatado
function MapContextGenerator.PrintContext(context)

	print(FormatContextForPrint(context))
end


-- Retorna o contexto como string formatada
function MapContextGenerator.GetContextString(context)

	return FormatContextForPrint(context)
end


-- Retorna estatísticas do contexto
function MapContextGenerator.GetStats(context)

	return GetContextStats(context)
end


return MapContextGenerator
