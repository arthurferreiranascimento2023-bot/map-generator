--==================================================
-- MapPrefabsGenerator.lua
--
-- Gerador procedural de salas por Prefabs.
--
-- COMO FUNCIONA:
--
--   Sala existente
--        Exit >
--              < Entry
--               Sala nova
--
-- O Entry da nova sala:
--   • vai para a posição do Exit
--   • fica virado para o Exit
--   • controla a orientação através do próprio Attachment
--
-- O Model inteiro é movido.
-- Attachments nunca são modificados.
--
-- A geração para quando:
--   • atingir MaxRooms
--   • não houver mais Exits utilizáveis
--==================================================


local MapGenerator = {}


--==================================================
-- SERVIÇOS
--==================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")


--==================================================
-- CONFIGURAÇÃO PADRÃO
--==================================================
--
-- Você pode futuramente substituir tudo isso
-- por configuração externa/contextual.
--==================================================

local DEFAULT_CONFIG = {

	-- Onde estão os prefabs de sala
	RoomsFolder =
		ReplicatedStorage
		:WaitForChild("Prefabs")
		:WaitForChild("Rooms"),

	-- Onde as salas geradas serão colocadas
	MapName = "Map",

	-- Quantidade máxima de salas
	MaxRooms = 10,

	-- Quantas tentativas são feitas para cada Exit
	AttemptsPerExit = 30,

	-- Posição inicial da primeira sala
	StartCFrame = CFrame.new(0, 0, 0),
}


--==================================================
-- ATTACHMENTS
--==================================================


-- Procura um Attachment pelo nome dentro do Model.
local function GetAttachment(model, name)

	for _, object in ipairs(model:GetDescendants()) do

		if object:IsA("Attachment")
			and object.Name == name then

			return object
		end
	end

	return nil
end


--==================================================
-- COLISÃO
--==================================================


-- Retorna a AABB mundial do Model.
--
-- A AABB é usada somente para saber se uma
-- sala está atravessando outra.
local function GetAABB(model)

	local boxCFrame, size =
		model:GetBoundingBox()

	local half =
		size * 0.5


	local min =
		Vector3.new(
			math.huge,
			math.huge,
			math.huge
		)

	local max =
		Vector3.new(
			-math.huge,
			-math.huge,
			-math.huge
		)


	-- Os 8 cantos da BoundingBox.
	for x = -1, 1, 2 do

		for y = -1, 1, 2 do

			for z = -1, 1, 2 do

				local point =
					boxCFrame:PointToWorldSpace(
						Vector3.new(
							half.X * x,
							half.Y * y,
							half.Z * z
						)
					)


				min =
					Vector3.new(
						math.min(min.X, point.X),
						math.min(min.Y, point.Y),
						math.min(min.Z, point.Z)
					)


				max =
					Vector3.new(
						math.max(max.X, point.X),
						math.max(max.Y, point.Y),
						math.max(max.Z, point.Z)
					)
			end
		end
	end


	return {
		Min = min,
		Max = max
	}
end


-- Verifica se duas AABBs se atravessam.
local function AABBOverlaps(a, b)

	return not (

		a.Max.X <= b.Min.X
			or
			a.Min.X >= b.Max.X

			or

		a.Max.Y <= b.Min.Y
			or
		a.Min.Y >= b.Max.Y

			or

		a.Max.Z <= b.Min.Z
			or
		a.Min.Z >= b.Max.Z
	)
end


--==================================================
-- EXITS
--==================================================


-- Retorna todas as Exits ainda não utilizadas.
local function GetAvailableExits(rooms)

	local exits = {}


	for _, room in ipairs(rooms) do

		for _, object in ipairs(room:GetDescendants()) do

			if object:IsA("Attachment")
				and object.Name == "Exit"
				and not object:GetAttribute("Used") then


				table.insert(
					exits,
					{
						Room = room,
						Attachment = object
					}
				)
			end
		end
	end


	return exits
end


-- Marca um Attachment como utilizado.
local function MarkUsed(attachment)

	attachment:SetAttribute(
		"Used",
		true
	)
end


--==================================================
-- POSICIONAMENTO
--==================================================
--
-- Esta é a parte responsável por:
--
--        EXIT  >  <  ENTRY
--
-- O Entry:
--   • ocupa a mesma posição do Exit
--   • recebe a orientação oposta
--
-- A orientação vem do CFrame do Attachment.
--
-- Não existem rotações fixas de 90/180 graus
-- para "procurar" uma posição.
--==================================================

local function PlaceRoom(
	prefab,
	exitInfo,
	existingRooms,
	mapFolder
)

	--------------------------------------------------
	-- CRIA O PREFAB
	--------------------------------------------------

	local room =
		prefab:Clone()

	room.Parent =
		mapFolder


	--------------------------------------------------
	-- PROCURA O ENTRY
	--------------------------------------------------

	local entry =
		GetAttachment(
			room,
			"Entry"
		)


	if not entry then

		room:Destroy()

		return nil
	end


	--------------------------------------------------
	-- COLOCA O MODEL NA ORIGEM
	--------------------------------------------------
	--
	-- Isso permite descobrir a transformação local
	-- do Entry em relação ao Pivot do Model.
	--------------------------------------------------

	room:PivotTo(
		CFrame.new()
	)


	--------------------------------------------------
	-- ENTRY LOCAL
	--------------------------------------------------

	local entryLocal =
		room:GetPivot():ToObjectSpace(
			entry.WorldCFrame
		)


	--------------------------------------------------
	-- EXIT DA SALA EXISTENTE
	--------------------------------------------------

	local exitCFrame =
		exitInfo.Attachment.WorldCFrame


	--------------------------------------------------
	-- ALINHAMENTO
	--------------------------------------------------
	--
	-- O Entry deve:
	--
	--   1. estar exatamente na posição do Exit
	--   2. olhar para o lado oposto
	--
	-- Resultado:
	--
	--   EXIT  >  <  ENTRY
	--
	--------------------------------------------------

	local desiredEntryCFrame =
		exitCFrame
		* CFrame.Angles(
			0,
			math.pi,
			0
		)


	--------------------------------------------------
	-- CALCULA O PIVOT FINAL
	--------------------------------------------------

	local targetPivot =
		desiredEntryCFrame
		* entryLocal:Inverse()


	--------------------------------------------------
	-- COLOCA A SALA
	--------------------------------------------------
	--
	-- ESTE é o ponto onde o prefab realmente
	-- é colocado no mapa.
	--------------------------------------------------

	room:PivotTo(
		targetPivot
	)


	--------------------------------------------------
	-- COLISÃO
	--------------------------------------------------

	local roomAABB =
		GetAABB(room)


	for _, otherRoom in ipairs(existingRooms) do

		-- A sala que possui o Exit usado não entra
		-- na verificação, pois é justamente a sala
		-- conectada.
		if otherRoom ~= exitInfo.Room then

			local otherAABB =
				GetAABB(otherRoom)


			if AABBOverlaps(
				roomAABB,
				otherAABB
				) then

				room:Destroy()

				return nil
			end
		end
	end


	--------------------------------------------------
	-- SUCESSO
	--------------------------------------------------

	return room
end


--==================================================
-- MAP
--==================================================


local function GetOrCreateMapFolder(name)

	local map =
		Workspace:FindFirstChild(name)


	if not map then

		map =
			Instance.new("Folder")

		map.Name =
			name

		map.Parent =
			Workspace
	end


	return map
end


--==================================================
-- GERADOR
--==================================================

function MapGenerator.Generate(options)

	options =
		options or {}


	--------------------------------------------------
	-- CONFIGURAÇÃO
	--------------------------------------------------

	local roomsFolder =
		options.RoomsFolder
		or DEFAULT_CONFIG.RoomsFolder


	local mapName =
		options.MapName
		or DEFAULT_CONFIG.MapName


	local maxRooms =
		options.MaxRooms
		or options.maxRooms
		or DEFAULT_CONFIG.MaxRooms


	local attemptsPerExit =
		options.AttemptsPerExit
		or options.attemptsPerRoom
		or DEFAULT_CONFIG.AttemptsPerExit


	local startCFrame =
		options.StartCFrame
		or DEFAULT_CONFIG.StartCFrame


	local seed =
		options.Seed
		or options.seed
		or os.time()


	local rng =
		Random.new(seed)


	--------------------------------------------------
	-- MAP
	--------------------------------------------------

	local mapFolder =
		GetOrCreateMapFolder(
			mapName
		)

	mapFolder:ClearAllChildren()


	--------------------------------------------------
	-- PREFABS
	--------------------------------------------------

	local prefabs =
		roomsFolder:GetChildren()


	if #prefabs == 0 then

		error(
			"Nenhum prefab encontrado em " ..
				roomsFolder:GetFullName()
		)
	end


	--------------------------------------------------
	-- PROCURA PREFABS VÁLIDOS PARA COMEÇAR
	--------------------------------------------------

	local startPrefabs = {}


	for _, prefab in ipairs(prefabs) do

		if GetAttachment(
			prefab,
			"Entry"
			)
				and GetAttachment(
					prefab,
					"Exit"
				) then

			table.insert(
				startPrefabs,
				prefab
			)
		end
	end


	if #startPrefabs == 0 then

		error(
			"Nenhum prefab possui Entry e Exit."
		)
	end


	--------------------------------------------------
	-- PRIMEIRA SALA
	--------------------------------------------------

	local firstPrefab =
		startPrefabs[
		rng:NextInteger(
			1,
			#startPrefabs
		)
		]


	local firstRoom =
		firstPrefab:Clone()


	firstRoom.Parent =
		mapFolder


	firstRoom:PivotTo(
		startCFrame
	)


	--------------------------------------------------
	-- LISTA DE SALAS
	--------------------------------------------------

	local rooms = {
		firstRoom
	}


	--------------------------------------------------
	-- GERAÇÃO PROCEDURAL
	--------------------------------------------------

	while #rooms < maxRooms do


		--------------------------------------------------
		-- PROCURA EXITS DISPONÍVEIS
		--------------------------------------------------

		local availableExits =
			GetAvailableExits(
				rooms
			)


		--------------------------------------------------
		-- NÃO HÁ MAIS SAÍDAS
		--------------------------------------------------

		if #availableExits == 0 then

			break
		end


		--------------------------------------------------
		-- ESCOLHE UMA EXIT
		--------------------------------------------------

		local exitInfo =
			availableExits[
			rng:NextInteger(
				1,
				#availableExits
			)
			]


		--------------------------------------------------
		-- TENTA GERAR UMA SALA NESSA EXIT
		--------------------------------------------------

		local newRoom = nil


		for _ = 1, attemptsPerExit do


			local prefab =
				prefabs[
				rng:NextInteger(
					1,
					#prefabs
				)
				]


			newRoom =
				PlaceRoom(
					prefab,
					exitInfo,
					rooms,
					mapFolder
				)


			if newRoom then

				break
			end
		end


		--------------------------------------------------
		-- SALA CRIADA
		--------------------------------------------------

		if newRoom then


			----------------------------------------------
			-- FECHA O EXIT UTILIZADO
			----------------------------------------------

			MarkUsed(
				exitInfo.Attachment
			)


			----------------------------------------------
			-- FECHA O ENTRY UTILIZADO
			----------------------------------------------

			local entry =
				GetAttachment(
					newRoom,
					"Entry"
				)


			if entry then

				MarkUsed(entry)
			end


			----------------------------------------------
			-- ADICIONA À LISTA
			----------------------------------------------

			table.insert(
				rooms,
				newRoom
			)


			--------------------------------------------------
			-- NÃO CONSEGUIU COLOCAR
			--------------------------------------------------

		else

			-- Esse Exit fica indisponível para
			-- evitar que o gerador fique tentando
			-- infinitamente a mesma conexão.

			MarkUsed(
				exitInfo.Attachment
			)
		end
	end


	--------------------------------------------------
	-- RESULTADO
	--------------------------------------------------

	print(
		string.format(
			"[MapGen] %d/%d salas geradas | Seed: %d",
			#rooms,
			maxRooms,
			seed
		)
	)


	return mapFolder, seed
end


return MapGenerator
