module 'aux.tabs.trading'

local aux = require 'aux'
local persistence = require 'aux.util.persistence'
local history = require 'aux.core.history'
local info = require 'aux.util.info'

local M = getfenv()

-- ============================================================================
-- SISTEMA DE GRUPOS - Similar a TSM
-- ============================================================================

aux.print('[GROUPS] Módulo de grupos cargado')

-- ============================================================================
-- Datos de Grupos
-- ============================================================================

local grupos = {}
local operaciones = {}
local grupo_seleccionado = nil

-- Grupos predefinidos
local grupos_predefinidos = {
    ['Hierbas'] = {
        nombre = 'Hierbas',
        descripcion = 'Todas las hierbas de herboristería',
        icono = 'Interface\Icons\INV_Misc_Herb_07',
        color = '|cFF00FF00',
        items = {
            'item:765:0:0:0',   -- Raíz de paz de plata
            'item:785:0:0:0',   -- Magnolia
            'item:2447:0:0:0',  -- Paz de plata
            'item:2449:0:0:0',  -- Terrofruta
            'item:2450:0:0:0',  -- Briarthorn
            'item:2452:0:0:0',  -- Alaciervos
            'item:2453:0:0:0',  -- Musgo de tumba
            'item:3355:0:0:0',  -- Loto salvaje
            'item:3356:0:0:0',  -- Kingsblood
            'item:3357:0:0:0',  -- Liferoot
            'item:3358:0:0:0',  -- Khadgar's Whisker
            'item:3369:0:0:0',  -- Grave Moss
            'item:3818:0:0:0',  -- Fadeleaf
            'item:3819:0:0:0',  -- Wintersbite
            'item:3820:0:0:0',  -- Stranglekelp
            'item:3821:0:0:0',  -- Goldthorn
            'item:4625:0:0:0',  -- Firebloom
            'item:8831:0:0:0',  -- Purple Lotus
            'item:8836:0:0:0',  -- Arthas' Tears
            'item:8838:0:0:0',  -- Sungrass
            'item:8839:0:0:0',  -- Blindweed
            'item:8845:0:0:0',  -- Ghost Mushroom
            'item:8846:0:0:0',  -- Gromsblood
            'item:13463:0:0:0', -- Dreamfoil
            'item:13464:0:0:0', -- Golden Sansam
            'item:13465:0:0:0', -- Mountain Silversage
            'item:13466:0:0:0', -- Plaguebloom
            'item:13467:0:0:0', -- Icecap
            'item:13468:0:0:0', -- Black Lotus
        },
        operacion_posting = 'undercut_1c',
        operacion_shopping = 'max_80pct',
    },
    ['Minerales'] = {
        nombre = 'Minerales',
        descripcion = 'Minerales y barras de minería',
        icono = 'Interface\Icons\INV_Ore_Copper_01',
        color = '|cFFB87333',
        items = {
            'item:2770:0:0:0',  -- Cobre
            'item:2771:0:0:0',  -- Estaño
            'item:2772:0:0:0',  -- Hierro
            'item:2775:0:0:0',  -- Plata
            'item:2776:0:0:0',  -- Oro
            'item:3858:0:0:0',  -- Mithril
            'item:7911:0:0:0',  -- Truesilver
            'item:10620:0:0:0', -- Thorium
            'item:2840:0:0:0',  -- Barra de cobre
            'item:2841:0:0:0',  -- Barra de bronce
            'item:2842:0:0:0',  -- Barra de estaño
            'item:3575:0:0:0',  -- Barra de hierro
            'item:3576:0:0:0',  -- Barra de acero
            'item:3577:0:0:0',  -- Barra de oro
            'item:3859:0:0:0',  -- Barra de mithril
            'item:3860:0:0:0',  -- Barra de plata
            'item:6037:0:0:0',  -- Barra de truesilver
            'item:12359:0:0:0', -- Barra de thorium
        },
        operacion_posting = 'undercut_1c',
        operacion_shopping = 'max_80pct',
    },
    ['Encantamiento'] = {
        nombre = 'Encantamiento',
        descripcion = 'Materiales de encantamiento',
        icono = 'Interface\Icons\INV_Enchant_DustStrange',
        color = '|cFFAA88FF',
        items = {
            'item:10940:0:0:0', -- Strange Dust
            'item:11083:0:0:0', -- Soul Dust
            'item:11137:0:0:0', -- Vision Dust
            'item:11176:0:0:0', -- Dream Dust
            'item:16204:0:0:0', -- Illusion Dust
            'item:10938:0:0:0', -- Lesser Magic Essence
            'item:10939:0:0:0', -- Greater Magic Essence
            'item:10998:0:0:0', -- Lesser Astral Essence
            'item:11082:0:0:0', -- Greater Astral Essence
            'item:11134:0:0:0', -- Lesser Mystic Essence
            'item:11135:0:0:0', -- Greater Mystic Essence
            'item:11174:0:0:0', -- Lesser Nether Essence
            'item:11175:0:0:0', -- Greater Nether Essence
            'item:16202:0:0:0', -- Lesser Eternal Essence
            'item:16203:0:0:0', -- Greater Eternal Essence
            'item:10978:0:0:0', -- Small Glimmering Shard
            'item:11084:0:0:0', -- Large Glimmering Shard
            'item:11138:0:0:0', -- Small Glowing Shard
            'item:11139:0:0:0', -- Large Glowing Shard
            'item:11177:0:0:0', -- Small Radiant Shard
            'item:11178:0:0:0', -- Large Radiant Shard
            'item:14343:0:0:0', -- Small Brilliant Shard
            'item:14344:0:0:0', -- Large Brilliant Shard
            'item:20725:0:0:0', -- Nexus Crystal
        },
        operacion_posting = 'undercut_1c',
        operacion_shopping = 'max_70pct',
    },
    ['Telas'] = {
        nombre = 'Telas',
        descripcion = 'Telas para sastrería',
        icono = 'Interface\Icons\INV_Fabric_Linen_01',
        color = '|cFFFFFFFF',
        items = {
            'item:2589:0:0:0',  -- Lino
            'item:2592:0:0:0',  -- Lana
            'item:4306:0:0:0',  -- Seda
            'item:4338:0:0:0',  -- Paño mágico
            'item:14047:0:0:0', -- Paño rúnico
            'item:14256:0:0:0', -- Paño vil
        },
        operacion_posting = 'undercut_1c',
        operacion_shopping = 'max_80pct',
    },
    ['Cueros'] = {
        nombre = 'Cueros',
        descripcion = 'Cueros para peletería',
        icono = 'Interface\Icons\INV_Misc_LeatherScrap_02',
        color = '|cFF8B4513',
        items = {
            'item:2318:0:0:0',  -- Cuero ligero
            'item:2319:0:0:0',  -- Cuero medio
            'item:4234:0:0:0',  -- Cuero pesado
            'item:4304:0:0:0',  -- Cuero grueso
            'item:8170:0:0:0',  -- Cuero rugoso
            'item:15417:0:0:0', -- Cuero de escamas
        },
        operacion_posting = 'undercut_1c',
        operacion_shopping = 'max_80pct',
    },
    ['Consumibles Raid'] = {
        nombre = 'Consumibles Raid',
        descripcion = 'Pociones, elixires y comida para raids',
        icono = 'Interface\Icons\INV_Potion_54',
        color = '|cFFFF00FF',
        items = {
            'item:13442:0:0:0', -- Poción de maná mayor
            'item:13443:0:0:0', -- Poción de curación mayor
            'item:13445:0:0:0', -- Elixir de la Mangosta
            'item:13447:0:0:0', -- Elixir de fuerza bruta
            'item:13452:0:0:0', -- Elixir de los Sabios
            'item:13454:0:0:0', -- Elixir de poder de las sombras
            'item:13457:0:0:0', -- Elixir de poder de escarcha
            'item:13458:0:0:0', -- Elixir de poder de fuego
            'item:9206:0:0:0',  -- Elixir de los Gigantes
            'item:20007:0:0:0', -- Runn Tum Tuber Surprise
            'item:13928:0:0:0', -- Grilled Squid
        },
        operacion_posting = 'market_value',
        operacion_shopping = 'max_90pct',
    },
}

-- Operaciones predefinidas
local operaciones_predefinidas = {
    ['undercut_1c'] = {
        nombre = 'Undercut 1c',
        descripcion = 'Postear 1 cobre por debajo del más barato',
        tipo = 'posting',
        config = {
            undercut = 1,
            min_price = '50% mercado',
            max_price = '200% mercado',
            duracion = 24,
            stack_size = 0, -- 0 = automático
        },
    },
    ['undercut_5pct'] = {
        nombre = 'Undercut 5%',
        descripcion = 'Postear 5% por debajo del más barato',
        tipo = 'posting',
        config = {
            undercut_pct = 0.05,
            min_price = '50% mercado',
            max_price = '200% mercado',
            duracion = 24,
            stack_size = 0,
        },
    },
    ['market_value'] = {
        nombre = 'Precio de Mercado',
        descripcion = 'Postear al precio de mercado',
        tipo = 'posting',
        config = {
            price = '100% mercado',
            min_price = '80% mercado',
            max_price = '150% mercado',
            duracion = 24,
            stack_size = 0,
        },
    },
    ['max_80pct'] = {
        nombre = 'Máximo 80%',
        descripcion = 'Comprar hasta 80% del precio de mercado',
        tipo = 'shopping',
        config = {
            max_price = '80% mercado',
            cantidad = 0, -- 0 = ilimitado
        },
    },
    ['max_70pct'] = {
        nombre = 'Máximo 70%',
        descripcion = 'Comprar hasta 70% del precio de mercado',
        tipo = 'shopping',
        config = {
            max_price = '70% mercado',
            cantidad = 0,
        },
    },
    ['max_90pct'] = {
        nombre = 'Máximo 90%',
        descripcion = 'Comprar hasta 90% del precio de mercado',
        tipo = 'shopping',
        config = {
            max_price = '90% mercado',
            cantidad = 0,
        },
    },
    ['sniper_50pct'] = {
        nombre = 'Sniper 50%',
        descripcion = 'Comprar items a 50% o menos del mercado',
        tipo = 'sniper',
        config = {
            max_price = '50% mercado',
            auto_buy = false,
        },
    },
}

-- ============================================================================
-- Inicialización
-- ============================================================================

function M.init_grupos()
    -- Cargar grupos guardados
    if aux.account_data and aux.account_data.trading_groups then
        grupos = aux.account_data.trading_groups
    else
        -- Usar grupos predefinidos
        grupos = {}
        for nombre, grupo in pairs(grupos_predefinidos) do
            grupos[nombre] = {
                nombre = grupo.nombre,
                descripcion = grupo.descripcion,
                icono = grupo.icono,
                color = grupo.color,
                items = grupo.items,
                operacion_posting = grupo.operacion_posting,
                operacion_shopping = grupo.operacion_shopping,
                subgrupos = {},
                creado = time(),
                modificado = time(),
            }
        end
    end
    
    -- Cargar operaciones guardadas
    if aux.account_data and aux.account_data.trading_operations then
        operaciones = aux.account_data.trading_operations
    else
        operaciones = operaciones_predefinidas
    end
    
    aux.print('[GROUPS] Grupos inicializados: ' .. M.contar_grupos())
end

function M.guardar_grupos()
    if not aux.account_data then
        aux.account_data = {}
    end
    aux.account_data.trading_groups = grupos
    aux.account_data.trading_operations = operaciones
end

-- ============================================================================
-- Gestión de Grupos
-- ============================================================================

function M.crear_grupo(nombre, descripcion, icono, color)
    if not nombre or nombre == '' then
        aux.print('|cFFFF4444[GROUPS]|r Nombre de grupo requerido')
        return false
    end
    
    if grupos[nombre] then
        aux.print('|cFFFF4444[GROUPS]|r Ya existe un grupo con ese nombre')
        return false
    end
    
    grupos[nombre] = {
        nombre = nombre,
        descripcion = descripcion or '',
        icono = icono or 'Interface\Icons\INV_Misc_QuestionMark',
        color = color or '|cFFFFFFFF',
        items = {},
        subgrupos = {},
        operacion_posting = 'undercut_1c',
        operacion_shopping = 'max_80pct',
        creado = time(),
        modificado = time(),
    }
    
    M.guardar_grupos()
    aux.print('|cFF00FF00[GROUPS]|r Grupo creado: ' .. nombre)
    return true
end

function M.eliminar_grupo(nombre)
    if not grupos[nombre] then
        aux.print('|cFFFF4444[GROUPS]|r Grupo no encontrado: ' .. nombre)
        return false
    end
    
    grupos[nombre] = nil
    M.guardar_grupos()
    aux.print('|cFF00FF00[GROUPS]|r Grupo eliminado: ' .. nombre)
    return true
end

function M.renombrar_grupo(nombre_actual, nombre_nuevo)
    if not grupos[nombre_actual] then
        return false
    end
    
    if grupos[nombre_nuevo] then
        aux.print('|cFFFF4444[GROUPS]|r Ya existe un grupo con ese nombre')
        return false
    end
    
    grupos[nombre_nuevo] = grupos[nombre_actual]
    grupos[nombre_nuevo].nombre = nombre_nuevo
    grupos[nombre_nuevo].modificado = time()
    grupos[nombre_actual] = nil
    
    M.guardar_grupos()
    return true
end

function M.obtener_grupo(nombre)
    return grupos[nombre]
end

function M.obtener_todos_grupos()
    return grupos
end

function M.contar_grupos()
    local count = 0
    for _ in pairs(grupos) do
        count = count + 1
    end
    return count
end

function M.seleccionar_grupo(nombre)
    if grupos[nombre] then
        grupo_seleccionado = nombre
        return true
    end
    return false
end

function M.obtener_grupo_seleccionado()
    return grupo_seleccionado, grupos[grupo_seleccionado]
end

-- ============================================================================
-- Gestión de Items en Grupos
-- ============================================================================

function M.agregar_item_a_grupo(nombre_grupo, item_key)
    local grupo = grupos[nombre_grupo]
    if not grupo then
        return false
    end
    
    -- Verificar si ya existe
    for _, item in ipairs(grupo.items) do
        if item == item_key then
            return false -- Ya existe
        end
    end
    
    table.insert(grupo.items, item_key)
    grupo.modificado = time()
    M.guardar_grupos()
    return true
end

function M.eliminar_item_de_grupo(nombre_grupo, item_key)
    local grupo = grupos[nombre_grupo]
    if not grupo then
        return false
    end
    
    for i, item in ipairs(grupo.items) do
        if item == item_key then
            table.remove(grupo.items, i)
            grupo.modificado = time()
            M.guardar_grupos()
            return true
        end
    end
    
    return false
end

function M.contar_items_en_grupo(nombre_grupo)
    local grupo = grupos[nombre_grupo]
    if not grupo then
        return 0
    end
    return table.getn(grupo.items)
end

function M.obtener_items_de_grupo(nombre_grupo)
    local grupo = grupos[nombre_grupo]
    if not grupo then
        return {}
    end
    return grupo.items
end

-- ============================================================================
-- Operaciones de Grupo
-- ============================================================================

function M.asignar_operacion_posting(nombre_grupo, operacion)
    local grupo = grupos[nombre_grupo]
    if not grupo then
        return false
    end
    
    grupo.operacion_posting = operacion
    grupo.modificado = time()
    M.guardar_grupos()
    return true
end

function M.asignar_operacion_shopping(nombre_grupo, operacion)
    local grupo = grupos[nombre_grupo]
    if not grupo then
        return false
    end
    
    grupo.operacion_shopping = operacion
    grupo.modificado = time()
    M.guardar_grupos()
    return true
end

function M.obtener_operacion(nombre_operacion)
    return operaciones[nombre_operacion]
end

function M.obtener_todas_operaciones()
    return operaciones
end

function M.crear_operacion(nombre, tipo, config)
    if operaciones[nombre] then
        return false
    end
    
    operaciones[nombre] = {
        nombre = nombre,
        tipo = tipo,
        config = config,
        creado = time(),
    }
    
    M.guardar_grupos()
    return true
end

-- ============================================================================
-- Cálculos de Grupo
-- ============================================================================

function M.calcular_valor_grupo(nombre_grupo)
    local grupo = grupos[nombre_grupo]
    if not grupo then
        return 0
    end
    
    local valor_total = 0
    for _, item_key in ipairs(grupo.items) do
        local market_value = history.value(item_key)
        if market_value then
            valor_total = valor_total + market_value
        end
    end
    
    return valor_total
end

function M.obtener_estadisticas_grupo(nombre_grupo)
    local grupo = grupos[nombre_grupo]
    if not grupo then
        return nil
    end
    
    local stats = {
        total_items = table.getn(grupo.items),
        items_con_precio = 0,
        items_sin_precio = 0,
        valor_total = 0,
        precio_promedio = 0,
        precio_min = nil,
        precio_max = nil,
    }
    
    for _, item_key in ipairs(grupo.items) do
        local market_value = history.value(item_key)
        if market_value and market_value > 0 then
            stats.items_con_precio = stats.items_con_precio + 1
            stats.valor_total = stats.valor_total + market_value
            
            if not stats.precio_min or market_value < stats.precio_min then
                stats.precio_min = market_value
            end
            if not stats.precio_max or market_value > stats.precio_max then
                stats.precio_max = market_value
            end
        else
            stats.items_sin_precio = stats.items_sin_precio + 1
        end
    end
    
    if stats.items_con_precio > 0 then
        stats.precio_promedio = stats.valor_total / stats.items_con_precio
    end
    
    return stats
end

-- ============================================================================
-- Import/Export de Grupos
-- ============================================================================

function M.exportar_grupo(nombre_grupo)
    local grupo = grupos[nombre_grupo]
    if not grupo then
        return nil
    end
    
    -- Formato simple: nombre,item1,item2,item3...
    local items_str = table.concat(grupo.items, ',')
    return grupo.nombre .. ':' .. items_str
end

function M.importar_grupo(cadena)
    if not cadena or cadena == '' then
        return false
    end
    
    -- Parsear formato: nombre:item1,item2,item3... (Lua 5.0 compatible)
    local _, _, nombre, items_str = string.find(cadena, '([^:]+):(.+)')
    if not nombre or not items_str then
        aux.print('|cFFFF4444[GROUPS]|r Formato de importación inválido')
        return false
    end
    
    -- Crear grupo
    if not M.crear_grupo(nombre, 'Grupo importado') then
        return false
    end
    
    -- Agregar items
    for item_key in string.gfind(items_str, '([^,]+)') do
        M.agregar_item_a_grupo(nombre, item_key)
    end
    
    aux.print('|cFF00FF00[GROUPS]|r Grupo importado: ' .. nombre)
    return true
end

-- ============================================================================
-- Búsqueda en Grupos
-- ============================================================================

function M.buscar_item_en_grupos(item_key)
    local resultados = {}
    
    for nombre, grupo in pairs(grupos) do
        for _, item in ipairs(grupo.items) do
            if item == item_key then
                table.insert(resultados, nombre)
                break
            end
        end
    end
    
    return resultados
end

function M.buscar_grupos_por_nombre(texto)
    local resultados = {}
    texto = string.lower(texto)
    
    for nombre, grupo in pairs(grupos) do
        if string.find(string.lower(nombre), texto) then
            table.insert(resultados, nombre)
        end
    end
    
    return resultados
end

-- ============================================================================
-- Inicializar al cargar
-- ============================================================================

M.init_grupos()

aux.print('[GROUPS] Sistema de grupos listo')
