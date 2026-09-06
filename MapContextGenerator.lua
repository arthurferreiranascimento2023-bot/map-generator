--==================================================
-- MapContextGenerator.lua
--
-- Gerador procedural de contexto para a casa/mapa.
-- Cria as características da casa na hora de forma aleatória
-- com lógica realista e constraints customizáveis.
--
-- Um contexto define:
--   • Número de andares
--   • Se tem porão
--   • Se tem sotão
--   • Áreas temáticas com MIN/MAX
--   • Quantidade de salas por tipo respeitando constraints
--==================================================


local MapContextGenerator = {}


--==================================================
-- CONSTRAINTS DE SALAS
--==================================================
--
-- Define mínimo, máximo e chance para cada tipo.
-- ChanceDecrement: quanto % de chance diminui a cada novo item
--
-- Exemplo:
--   Quarto { Min = 1, Max = 4, ChanceDecrement = 20 }
--   1º Quarto: 100%
--   2º Quarto: 80%
--   3º Quarto: 60%
--   4º Quarto: 40%
--==================================================

local ROOM_CONSTRAINTS = {

	-- SALAS OBRIGATÓRIAS
	Cozinha = {
		Min = 1,
		Max = 1,
		ChanceDecrement = 100,  -- Sempre 1, nunca mais
		BaseChance = 1.0,
	},

	Corredor = {
		Min = 2,
		Max = 12,
		ChanceDecrement = 30,
		BaseChance = 0.8,
	},

	-- SALAS PRINCIPAIS
	Quarto = {
		Min = 1,
		Max = 8,
		ChanceDecrement = 20,
		BaseChance = 0.9,
	},

	Banheiro = {
		Min = 1,
		Max = 5,
		ChanceDecrement = 25,
		BaseChance = 0.85,
	},

	SalaDeEstar = {
		Min = 1,
		Max = 2,
		ChanceDecrement = 70,
		BaseChance = 0.95,
	},

	SalaDeJantar = {
		Min = 0,
		Max = 1,
		ChanceDecrement = 100,
		BaseChance = 0.4,
	},

	-- SALAS OPCIONAIS
	Biblioteca = {
		Min = 0,
		Max = 1,
		ChanceDecrement = 100,
		BaseChance = 0.25,
	},

	Escritorio = {
		Min = 0,
		Max = 1,
		ChanceDecrement = 100,
		BaseChance = 0.35,
	},

	SuiteImovel = {
		Min = 0,
		Max = 1,
		ChanceDecrement = 100,
		BaseChance = 0.2,
	},

	Lavanderia = {
		Min = 0,
		Max = 1,
		ChanceDecrement = 100,
		BaseChance = 0.5,
	},

	Despensa = {
		Min = 0,
		Max = 1,
		ChanceDecrement = 100,
		BaseChance = 0.3,
	},

	Garagem = {
		Min = 0,
		Max = 1,
		ChanceDecrement = 100,
		BaseChance = 0.4,
	},

	["Sala de Jogos"] = {
		Min = 0,
		Max = 1,
		ChanceDecrement = 100,
		BaseChance = 0.2,
	},
}


--==================================================
-- CONSTRAINTS DE SALAS ESPECIAIS
--==================================================

local SPECIAL_ROOM_CONSTRAINTS = {

	Porão = {
		Min = 0,
		Max = 1,
		ChanceDecrement = 100,
		BaseChance = 0.6,
	},

	Sotao = {
		Min = 0,
		Max = 1,
		ChanceDecrement = 100,
		BaseChance = 0.7,
	},

	Adega = {
		Min = 0,
		Max = 1,
		ChanceDecrement = 100,
		BaseChance = 0.3,
	},

	["Sala de Utilidades"] = {
		Min = 0,
		Max = 1,
		ChanceDecrement = 100,
		BaseChance = 0.5,
	},
}


--==================================================
-- GERA UM NOME DESCRITIVO PARA A CASA
--==================================================

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
-- CALCULA CHANCE COM DECREMENT
--==================================================

local function CalculateChance(constraint, currentCount)

	if currentCount >= constraint.Max then

		return 0
	end

	if currentCount < constraint.Min then

		return 1.0  -- Obrigatório
	end

	local baseChance = constraint.BaseChance or 0.5
	local decrement = (constraint.ChanceDecrement or 50) / 100
	local timesReached = currentCount - constraint.Min

	local finalChance = baseChance * (1 - (decrement * timesReached))

	return math.max(0, finalChance)
end


--==================================================
-- GERADOR PROCEDURAL
--==================================================

local function GenerateContext(rng, customConstraints)

	rng = rng or Random.new()

	-- Mescla constraints customizados com os padrões
	local constraints = {}
	for k, v in pairs(ROOM_CONSTRAINTS) do

		constraints[k] = customConstraints and customConstraints[k] or v
	end

	for k, v in pairs(SPECIAL_ROOM_CONSTRAINTS) do

		constraints[k] = customConstraints and customConstraints[k] or v
	end

	-- Decide número de andares (1-4)
	local floors = rng:NextInteger(1, 4)

	-- Decide características especiais
	local hasBasement = rng:NextNumber() > 0.4  -- 60% de chance
	local hasAttic = rng:NextNumber() > 0.3    -- 70% de chance

	-- Salas por tipo (respeitando constraints)
	local rooms = {}
	local roomCounts = {}

	-- GERA SALAS NORMAIS
	for roomType, constraint in pairs(constraints) do

		if not SPECIAL_ROOM_CONSTRAINTS[roomType] then

			roomCounts[roomType] = 0

			-- Gera entre Min e Max
			for i = 1, constraint.Max do

				local chance = CalculateChance(constraint, roomCounts[roomType])

				if i <= constraint.Min then

					-- Obrigatório
					roomCounts[roomType] = roomCounts[roomType] + 1

				elseif rng:NextNumber() < chance then

					-- Chance de adicionar mais
					roomCounts[roomType] = roomCounts[roomType] + 1
				else

					break
				end
			end

			-- Adiciona à lista se tiver algum
			if roomCounts[roomType] > 0 then

				table.insert(rooms, {
					Type = roomType,
					Count = roomCounts[roomType],
					Floor = math.min((roomType == "Garagem" and 1) or (roomType == "SuiteImovel" and floors) or math.random(1, floors), floors),
				})
			end
		end
	end

	-- SALAS ESPECIAIS
	local specialRooms = {}
	local specialCounts = {}

	-- PORÃO
	if hasBasement then

		local constraint = constraints.Porão
		specialCounts.Porão = constraint.Min

		if rng:NextNumber() < CalculateChance(constraint, 0) then

			specialCounts.Porão = specialCounts.Porão + 1
		end

		table.insert(specialRooms, {
			Type = "Porão",
			Count = specialCounts.Porão,
		})

		-- Sala de Utilidades no porão
		local utilConstraint = constraints["Sala de Utilidades"]

		if rng:NextNumber() < CalculateChance(utilConstraint, 0) then

			table.insert(specialRooms, {
				Type = "Sala de Utilidades",
				Count = 1,
			})
		end

		-- Adega no porão
		local adeConstraint = constraints.Adega

		if rng:NextNumber() < CalculateChance(adeConstraint, 0) then

			table.insert(specialRooms, {
				Type = "Adega",
				Count = 1,
			})
		end
	end

	-- SOTÃO
	if hasAttic then

		local constraint = constraints.Sotao

		if rng:NextNumber() < CalculateChance(constraint, 0) then

			table.insert(specialRooms, {
				Type = "Sotao",
				Count = 1,
			})
		end
	end

	return {
		Name = GenerateName(floors, hasBasement, hasAttic),
		Floors = floors,
		HasBasement = hasBasement,
		HasAttic = hasAttic,
		Rooms = rooms,
		SpecialRooms = specialRooms,
		RoomCounts = roomCounts,
	}
end


--==================================================
-- FORMATAÇÃO E DISPLAY
--==================================================

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

		table.insert(output, "╠════════════════════════════════════════════════════╣")
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

function MapContextGenerator.Generate(seed, customConstraints)

	local rng = Random.new(seed or os.time())

	return GenerateContext(rng, customConstraints)
end

function MapContextGenerator.PrintContext(context)

	print(FormatContextForPrint(context))
end

function MapContextGenerator.GetContextString(context)

	return FormatContextForPrint(context)
end

function MapContextGenerator.GetStats(context)

	return GetContextStats(context)
end

-- Retorna os constraints padrão para customização
function MapContextGenerator.GetDefaultConstraints()

	local result = {}

	for k, v in pairs(ROOM_CONSTRAINTS) do

		result[k] = {
			Min = v.Min,
			Max = v.Max,
			ChanceDecrement = v.ChanceDecrement,
			BaseChance = v.BaseChance,
		}
	end

	for k, v in pairs(SPECIAL_ROOM_CONSTRAINTS) do

		result[k] = {
			Min = v.Min,
			Max = v.Max,
			ChanceDecrement = v.ChanceDecrement,
			BaseChance = v.BaseChance,
		}
	end

	return result
end

return MapContextGenerator
