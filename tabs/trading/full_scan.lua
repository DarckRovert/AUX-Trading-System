module 'aux.tabs.trading'

local aux = require 'aux'
local scan = require 'aux.core.scan'
local history = require 'aux.core.history'
local info = require 'aux.util.info'
local M = getfenv()

--[[
    FULL SCAN SYSTEM - Usando el sistema de scan de aux-addon
    
    Escanea TODA la casa de subastas para obtener datos completos.
]]

-- Estado del scan
local scan_estado = {
    activo = false,
    inicio = 0,
    auctions_procesados = 0,
    items_unicos = {},
    oportunidades = {}
}

-- Formatear tiempo
local function formatear_tiempo(segundos)
    if segundos < 60 then
        return string.format('%ds', segundos)
    else
        return string.format('%dm %ds', math.floor(segundos / 60), math.mod(segundos, 60))
    end
end

-- Callback cuando se procesa cada auction
local function on_auction(auction_info)
    if not scan_estado.activo then return end
    if not auction_info then return end
    
    scan_estado.auctions_procesados = scan_estado.auctions_procesados + 1
    
    -- Registrar item unico
    local item_key = auction_info.item_key or (tostring(auction_info.item_id or 0) .. ':0')
    if not scan_estado.items_unicos[item_key] then
        scan_estado.items_unicos[item_key] = {
            nombre = auction_info.name,
            item_id = auction_info.item_id,
            min_buyout = auction_info.buyout_price,
            count = 0
        }
    end
    
    local item_data = scan_estado.items_unicos[item_key]
    item_data.count = item_data.count + 1
    
    -- Actualizar min buyout
    if auction_info.buyout_price and auction_info.buyout_price > 0 then
        local buyout_unit = auction_info.buyout_price / (auction_info.aux_quantity or auction_info.count or 1)
        if not item_data.min_buyout or buyout_unit < item_data.min_buyout then
            item_data.min_buyout = buyout_unit
        end
    end
    
    -- Evaluar oportunidad
    local market_value = 0
    if history and history.value then
        market_value = history.value(item_key) or 0
    end
    
    if market_value > 0 and auction_info.buyout_price and auction_info.buyout_price > 0 then
        local buyout_unit = auction_info.buyout_price / (auction_info.aux_quantity or auction_info.count or 1)
        local ganancia = market_value - buyout_unit
        local porcentaje = math.floor((1 - buyout_unit / market_value) * 100)
        
        -- Si hay ganancia de al menos 10% y 50 cobre
        if porcentaje >= 10 and ganancia >= 50 then
            table.insert(scan_estado.oportunidades, {
                nombre = auction_info.name or '?',
                item_key = item_key,
                precio = buyout_unit,
                mercado = market_value,
                ganancia = ganancia,
                porcentaje = porcentaje,
                vendedor = auction_info.owner or '?',
                cantidad = auction_info.aux_quantity or auction_info.count or 1,
                auction_info = auction_info
            })
        end
    end
    
    -- Actualizar UI cada 100 auctions
    if math.mod(scan_estado.auctions_procesados, 100) == 0 then
        local tiempo = time() - scan_estado.inicio
        local num_items = 0
        for _ in scan_estado.items_unicos do num_items = num_items + 1 end
        
        if M.frame and M.frame.estado then
            M.frame.estado:SetText(string.format(
                '|cFFFFFF00Escaneando: %d auctions, %d items (%s)|r',
                scan_estado.auctions_procesados, num_items, formatear_tiempo(tiempo)
            ))
        end
    end
end

-- Callback cuando se completa una pagina
local function on_page_scanned()
    local tiempo = time() - scan_estado.inicio
    aux.print(string.format('|cFF888888Pagina escaneada... %d auctions en %s|r', 
        scan_estado.auctions_procesados, formatear_tiempo(tiempo)))
end

-- Callback cuando se completa el scan
local function on_complete()
    scan_estado.activo = false
    
    local tiempo = time() - scan_estado.inicio
    local num_items = 0
    for _ in scan_estado.items_unicos do num_items = num_items + 1 end
    
    aux.print('|cFF00FF00=== FULL SCAN COMPLETADO ===|r')
    aux.print(string.format('|cFFFFFFFFTiempo: %s|r', formatear_tiempo(tiempo)))
    aux.print(string.format('|cFFFFFFFFItems unicos: %d|r', num_items))
    aux.print(string.format('|cFFFFFFFFAuctions procesados: %d|r', scan_estado.auctions_procesados))
    aux.print(string.format('|cFF00FF00Oportunidades encontradas: %d|r', table.getn(scan_estado.oportunidades)))
    
    -- Ordenar oportunidades por ganancia
    table.sort(scan_estado.oportunidades, function(a, b)
        return (a.ganancia or 0) > (b.ganancia or 0)
    end)
    
    -- Actualizar UI del panel de oportunidades
    local trading_module = require('aux.tabs.trading')
    if trading_module and trading_module.update_opportunities then
        trading_module.update_opportunities()
    end
end

-- Callback cuando se aborta el scan
local function on_abort()
    scan_estado.activo = false
    aux.print('|cFFFF0000Full Scan abortado|r')
    
    if M.frame and M.frame.estado then
        M.frame.estado:SetText('|cFFFF0000Scan abortado|r')
    end
end

-- Iniciar Full Scan usando el sistema de aux
function M.iniciar_full_scan()
    if scan_estado.activo then
        aux.print('|cFFFFFF00Ya hay un scan en progreso|r')
        return
    end
    
    -- Resetear estado
    scan_estado.activo = true
    scan_estado.inicio = time()
    scan_estado.auctions_procesados = 0
    scan_estado.items_unicos = {}
    scan_estado.oportunidades = {}
    
    aux.print('|cFF00FF00=== INICIANDO FULL SCAN ===|r')
    aux.print('|cFFFFFFFFEscaneando toda la casa de subastas...|r')
    aux.print('|cFFFFFFFFEsto puede tomar varios minutos.|r')
    
    -- Actualizar UI
    if M.frame and M.frame.estado then
        M.frame.estado:SetText('|cFFFFFF00Full Scan en progreso...|r')
    end
    
    -- Usar el sistema de scan de aux-addon
    scan.start({
        type = 'list',
        ignore_owner = true,
        queries = {
            {
                blizzard_query = {
                    name = '',  -- Filtro vacio = todo
                    first_page = 0,
                }
            }
        },
        on_scan_start = function()
            aux.print('|cFFFFFFFFScan iniciado...|r')
        end,
        on_page_scanned = on_page_scanned,
        on_auction = on_auction,
        on_complete = on_complete,
        on_abort = on_abort
    })
end

-- Detener Full Scan
function M.detener_full_scan()
    if scan_estado.activo then
        scan.abort()
        scan_estado.activo = false
        aux.print('|cFFFFFF00Full Scan detenido|r')
        
        if M.frame and M.frame.estado then
            M.frame.estado:SetText('|cFFFF0000Scan detenido|r')
        end
    end
end

-- Obtener estado del scan
function M.get_scan_estado()
    return {
        activo = scan_estado.activo,
        auctions = scan_estado.auctions_procesados,
        items = scan_estado.items_unicos,
        oportunidades = scan_estado.oportunidades,
        tiempo = scan_estado.activo and (time() - scan_estado.inicio) or 0
    }
end

-- Obtener oportunidades del ultimo scan
function M.get_full_scan_opportunities()
    return scan_estado.oportunidades or {}
end

-- Registrar modulo
M.modules = M.modules or {}
M.modules.full_scan = M

aux.print('|cFFFFD700[Trading]|r Full Scan system cargado')

--[[ CODIGO VIEJO COMENTADO
function M.ejecutar_query_pagina_OLD(pagina)
    if not scan_estado.activo then return end
    
    -- Verificar si podemos hacer query
    local puede_query, puede_full = CanSendAuctionQuery()
    if not puede_query then
        -- Esperar y reintentar
        local timer = CreateFrame('Frame')
        timer.elapsed = 0
        timer:SetScript('OnUpdate', function()
            this.elapsed = this.elapsed + arg1
            if this.elapsed >= 0.5 then
                this:SetScript('OnUpdate', nil)
                M.ejecutar_query_pagina(pagina)
            end
        end)
        return
    end
    
    scan_estado.pagina_actual = pagina
    
    -- Query con filtro vacío = escanea todo
    QueryAuctionItems('', nil, nil, pagina, nil, nil, nil, nil, nil)
    
    -- Esperar resultados
    local timer = CreateFrame('Frame')
    timer.elapsed = 0
    timer:SetScript('OnUpdate', function()
        this.elapsed = this.elapsed + arg1
        if this.elapsed >= 0.3 then
            this:SetScript('OnUpdate', nil)
            M.procesar_pagina_scan()
        end
    end)
end

-- Procesar página de resultados
function M.procesar_pagina_scan()
    if not scan_estado.activo then return end
    
    local num_batch, num_total = GetNumAuctionItems('list')
    
    if num_total == 0 then
        aux.print('|cFFFF0000No se encontraron auctions|r')
        M.finalizar_full_scan()
        return
    end
    
    scan_estado.total_paginas = math.ceil(num_total / 50)
    
    -- Procesar cada auction de esta página
    for i = 1, num_batch do
        local name, texture, count, quality, canUse, level, levelColHeader, 
              minBid, minIncrement, buyoutPrice, bidAmount, highBidder, 
              bidderFullName, owner, ownerFullName, saleStatus, itemId, hasAllInfo = GetAuctionItemInfo('list', i)
        
        if name and itemId then
            local item_key = tostring(itemId) .. ':0'
            
            -- Inicializar datos del item
            if not scan_estado.datos[item_key] then
                scan_estado.datos[item_key] = {
                    records = {},
                    minBuyout = 0,
                    cantidad = 0,
                    nombre = name
                }
            end
            
            local item_data = scan_estado.datos[item_key]
            
            -- Agregar record si tiene buyout
            if buyoutPrice and buyoutPrice > 0 then
                local buyout_por_unidad = math.floor(buyoutPrice / (count or 1))
                
                table.insert(item_data.records, {
                    buyout = buyout_por_unidad,
                    count = count or 1,
                    seller = owner
                })
                
                -- Actualizar minBuyout
                if item_data.minBuyout == 0 or buyout_por_unidad < item_data.minBuyout then
                    item_data.minBuyout = buyout_por_unidad
                end
            end
            
            item_data.cantidad = item_data.cantidad + (count or 1)
            scan_estado.items_encontrados = scan_estado.items_encontrados + 1
        end
    end
    
    -- Actualizar progreso
    local progreso = math.floor((scan_estado.pagina_actual + 1) / scan_estado.total_paginas * 100)
    local tiempo = time() - scan_estado.inicio
    
    if M.frame then
        M.frame.estado:SetText(string.format(
            '|cFFFFFF00● Escaneando: %d%% (%d/%d)|r',
            progreso, scan_estado.pagina_actual + 1, scan_estado.total_paginas
        ))
        M.frame.progreso:SetText(string.format(
            '|cFF888888Items: %d | Tiempo: %s|r',
            scan_estado.items_encontrados, formatear_tiempo(tiempo)
        ))
    end
    
    -- Siguiente página o finalizar
    if scan_estado.pagina_actual + 1 < scan_estado.total_paginas then
        M.ejecutar_query_pagina(scan_estado.pagina_actual + 1)
    else
        M.finalizar_full_scan()
    end
end

-- Finalizar Full Scan
function M.finalizar_full_scan()
    scan_estado.activo = false
    local tiempo_total = time() - scan_estado.inicio
    
    -- Procesar datos con el sistema de market_data
    local items_procesados = 0
    if M.modules and M.modules.market_data and M.modules.market_data.procesar_scan then
        items_procesados = M.modules.market_data.procesar_scan(scan_estado.datos)
    end
    
    -- Buscar oportunidades
    local oportunidades = M.buscar_oportunidades_full_scan()
    
    aux.print('|cFF00FF00=== FULL SCAN COMPLETADO ===' .. '|r')
    aux.print(string.format('|cFFFFFFFFTiempo: %s|r', formatear_tiempo(tiempo_total)))
    aux.print(string.format('|cFFFFFFFFItems únicos: %d|r', items_procesados))
    aux.print(string.format('|cFFFFFFFFAuctions procesados: %d|r', scan_estado.items_encontrados))
    aux.print(string.format('|cFF00FF00Oportunidades encontradas: %d|r', table.getn(oportunidades)))
    
    -- Actualizar UI
    if M.frame then
        M.frame.estado:SetText(string.format('|cFF00FF00● Scan completo: %d oportunidades|r', table.getn(oportunidades)))
        M.frame.progreso:SetText('')
    end
    
    -- Guardar oportunidades para mostrar
    M.full_scan_oportunidades = oportunidades
    
    -- Actualizar lista
    if M.actualizar_lista then
        M.actualizar_lista()
    end
end

-- Buscar oportunidades después del full scan
function M.buscar_oportunidades_full_scan()
    local oportunidades = {}
    
    for item_key, data in pairs(scan_estado.datos) do
        if data.minBuyout and data.minBuyout > 0 then
            -- Obtener valor de mercado
            local market_value = 0
            if M.modules and M.modules.market_data then
                market_value = M.modules.market_data.obtener_valor_mercado(item_key)
            end
            
            -- Si no hay valor de mercado, usar el promedio de los records
            if market_value == 0 and table.getn(data.records) > 1 then
                local total = 0
                for _, r in ipairs(data.records) do
                    total = total + r.buyout
                end
                market_value = math.floor(total / table.getn(data.records))
            end
            
            if market_value > 0 then
                local ganancia = market_value - data.minBuyout
                local porcentaje = math.floor((ganancia / market_value) * 100)
                
                -- Solo si hay al menos 10% de ganancia
                if porcentaje >= 10 and ganancia > 100 then
                    table.insert(oportunidades, {
                        item_key = item_key,
                        nombre = data.nombre,
                        precio = data.minBuyout,
                        mercado = market_value,
                        ganancia = ganancia,
                        porcentaje = porcentaje,
                        cantidad = data.cantidad,
                        auction_info = {
                            name = data.nombre,
                            buyout_price = data.minBuyout,
                            item_key = item_key
                        },
                        market_value = market_value,
                        score = porcentaje,
                        data = data
                    })
                end
            end
        end
    end
    
    -- Ordenar por ganancia
    table.sort(oportunidades, function(a, b)
        return (a.ganancia or 0) > (b.ganancia or 0)
    end)
    
    -- Limitar a 100
    while table.getn(oportunidades) > 100 do
        table.remove(oportunidades)
    end
    
    return oportunidades
end

-- Detener scan
function M.detener_full_scan()
    if scan_estado.activo then
        scan_estado.activo = false
        aux.print('|cFFFF8888Full Scan detenido|r')
        
        if M.frame then
            M.frame.estado:SetText('|cFFFF4444● Scan detenido|r')
        end
    end
end

-- Obtener estado del scan
function M.obtener_estado_scan()
    return {
        activo = scan_estado.activo,
        pagina = scan_estado.pagina_actual,
        total = scan_estado.total_paginas,
        items = scan_estado.items_encontrados,
        progreso = scan_estado.total_paginas > 0 and 
                   math.floor((scan_estado.pagina_actual + 1) / scan_estado.total_paginas * 100) or 0
    }
end

-- Obtener oportunidades del full scan
function M.obtener_oportunidades_full_scan()
    return M.full_scan_oportunidades or {}
end

-- Verificar si hay datos de scan reciente
function M.hay_datos_recientes()
    local stats = {}
    if M.modules and M.modules.market_data and M.modules.market_data.obtener_estadisticas_db then
        stats = M.modules.market_data.obtener_estadisticas_db()
    end
    return stats.total_items and stats.total_items > 100
end

CODIGO VIEJO FIN --]]

-- Registrar modulo
M.modules = M.modules or {}
M.modules.full_scan = M

aux.print('|cFFFFD700[Trading]|r Sistema Full Scan cargado')
