--==================================================
-- MainMapGenerator.lua
--
-- Script principal que integra:
--   1. Geração do contexto (estrutura da casa)
--   2. Print do contexto
--   3. Geração do mapa com prefabs
--==================================================


local ContextGen = require(game.ServerScriptService:WaitForChild("MapContextGenerator"))
local MapGen = require(game.ServerScriptService:WaitForChild("MapPrefabsGenerator"))


--==================================================
-- GERA O CONTEXTO
--==================================================

print("\n[MapGen] Gerando contexto da casa...")

local seed = os.time()
local context = ContextGen.Generate(seed)


--==================================================
-- PRINTA O CONTEXTO
--==================================================

print("\n[MapGen] Contexto gerado com sucesso!")
ContextGen.PrintContext(context)

local stats = ContextGen.GetStats(context)

print("\n[MapGen] Estatísticas do Contexto:")
print("  • Total de salas: " .. stats.TotalSalas)
print("  • Salas normais: " .. stats.TotalRooms)
print("  • Salas especiais: " .. stats.TotalSpecialRooms)
print("  • Andares: " .. stats.Andares)


--==================================================
-- GERA O MAPA
--==================================================

print("\n[MapGen] Iniciando geração do mapa...")

local mapFolder, usedSeed = MapGen.Generate({
	seed = seed,
	maxRooms = 40,
	attemptsPerExit = 40,
	mapName = context.Name:gsub(" ", "_")  -- Remove espaços do nome
})

print("\n[MapGen] Mapa gerado com sucesso!")
print("  • Pasta do mapa: " .. mapFolder:GetFullName())
print("  • Seed utilizada: " .. usedSeed)
