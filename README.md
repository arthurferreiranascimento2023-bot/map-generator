# Map Generator System

Sistema procedural de geração de mapas/casas para Roblox usando contexto e prefabs.

## 📦 Arquivos Necessários

### 1. **RoomPrefabManager.lua**
Gerenciador de mapeamento entre tipos de salas e prefabs.

### 2. **MapGeneratorWithContext.lua**
Gerador principal que integra contexto e prefabs.

## 🚀 Como Usar

```lua
local MapGen = require(game.ServerScriptService:WaitForChild("MapGeneratorWithContext"))

local mapFolder, seed, context = MapGen.GenerateWithContext({
    MaxRooms = 40,
    AttemptsPerExit = 30
})
```

## 📁 Estrutura Esperada

```
ReplicatedStorage/Prefabs/Rooms/
├── Cozinha/
│   ├── Prefab1
│   ├── Prefab2
├── Quarto/
├── Banheiro/
├── SalaDeEstar/
├── SalaDeJantar/
├── Biblioteca/
├── Escritorio/
├── SuiteImovel/
├── Lavanderia/
├── Despensa/
├── Garagem/
├── SalaDeJogos/
├── Porão/
├── Sotao/
├── Adega/
├── SalaDeUtilidades/
└── Generic/  (fallback)
```

## 🔧 Adicionar Novo Tipo de Sala

1. Em `RoomPrefabManager.lua`, na tabela `ROOM_TYPE_MAPPING`, adicione:
```lua
MeuTipo = "MeuTipo",
```

2. Crie a pasta correspondente em `Prefabs/Rooms/MeuTipo/`

3. Coloque seus prefabs lá

## 📊 Saída do Sistema

- Gera contexto (estructura da casa: andares, porão, sotão, etc)
- Lista quais tipos de salas serão criadas
- Valida os prefabs disponíveis
- Gera o mapa automaticamente
- Mostra estatísticas finais
