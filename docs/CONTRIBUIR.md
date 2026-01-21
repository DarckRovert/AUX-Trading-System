# 🤝 Guía de Contribución - AUX Trading System

**Por Elnazzareno (DarckRovert)**  
**El Séquito del Terror** 🔮

---

## 🌟 ¡Gracias por tu interés!

Las contribuciones son bienvenidas y apreciadas. Esta guía te ayudará a contribuir al proyecto.

---

## 📋 Cómo Contribuir

### Reportar Bugs

1. Verifica que el bug no haya sido reportado antes
2. Abre un Issue en GitHub con:
   - Descripción clara del problema
   - Pasos para reproducirlo
   - Comportamiento esperado vs actual
   - Capturas de pantalla si es posible
   - Versión del addon y del juego

### Sugerir Funcionalidades

1. Abre un Issue con la etiqueta "enhancement"
2. Describe la funcionalidad deseada
3. Explica por qué sería útil
4. Si es posible, sugiere cómo implementarla

### Contribuir Código

1. Haz fork del repositorio
2. Crea una rama para tu feature: `git checkout -b feature/mi-feature`
3. Haz tus cambios
4. Prueba exhaustivamente
5. Haz commit: `git commit -m 'Add: mi nueva feature'`
6. Push a tu fork: `git push origin feature/mi-feature`
7. Abre un Pull Request

---

## 📝 Estándares de Código

### Estilo General

```lua
-- Usar snake_case para variables y funciones
local mi_variable = "valor"
local function mi_funcion()
end

-- Usar MAYUSCULAS para constantes
local MAX_ITEMS = 100
local COLORS = {}

-- Comentarios en español
-- Esto hace algo importante
```

### Estructura de Archivos

```lua
-- 1. Declaración de módulo
module 'aux.tabs.trading'

-- 2. Requires
local aux = require 'aux'

-- 3. Variables locales/constantes
local COLORS = {}
local mi_variable = nil

-- 4. Funciones auxiliares locales
local function helper()
end

-- 5. Funciones públicas del módulo
function M.mi_funcion()
end

-- 6. Inicialización (si aplica)
```

### Compatibilidad Lua 5.0

**IMPORTANTE**: WoW 1.12 usa Lua 5.0. Debes:

- NO usar closures (variables locales en funciones anidadas)
- Usar `this` en scripts de frames
- Usar `math.mod()` en lugar de `%`
- Usar `table.getn()` en lugar de `#tabla`

**Ejemplo correcto:**
```lua
local btn = CreateFrame("Button", nil, parent)
btn.mi_dato = "valor"
btn:SetScript("OnClick", function()
    print(this.mi_dato) -- Usar 'this'
end)
```

---

## 🧪 Testing

### Antes de hacer PR

1. **Prueba en juego**: Verifica que no hay errores de Lua
2. **Prueba todas las funciones afectadas**
3. **Prueba en diferentes situaciones**:
   - Con/sin items en AH
   - Con/sin datos de mercado
   - Con diferentes cantidades de oro

### Checklist

- [ ] No hay errores de Lua al cargar
- [ ] No hay errores al abrir la UI
- [ ] Todas las funciones modificadas funcionan
- [ ] No se rompen funciones existentes
- [ ] El código sigue los estándares

---

## 📁 Estructura del Proyecto

```
aux-addon/
├── aux-addon.toc      # Manifest del addon
├── aux-addon.lua      # Punto de entrada
├── README.md          # Documentación principal
├── docs/              # Documentación adicional
├── core/              # Módulos core (scan, cache, etc.)
├── gui/               # Componentes de UI reutilizables
├── libs/              # Librerías externas
├── tabs/              # Pestañas de la interfaz
│   ├── trading/       # ⭐ Sistema de Trading (nuestro)
│   ├── search/        # Búsqueda
│   ├── post/          # Posteo
│   ├── auctions/      # Subastas
│   └── bids/          # Pujas
└── util/              # Utilidades
```

### Módulos de Trading

| Archivo | Descripción |
|---------|-------------|
| frame.lua | UI principal |
| core.lua | Lógica central |
| groups.lua | Sistema de grupos |
| sniper.lua | Módulo sniper |
| full_scan.lua | Escaneo completo |
| market_data.lua | Datos de mercado |
| accounting.lua | Historial |

---

## 🏷️ Convenciones de Commits

Usar prefijos descriptivos:

- `Add:` Nueva funcionalidad
- `Fix:` Corrección de bug
- `Update:` Actualización de funcionalidad existente
- `Remove:` Eliminación de código
- `Refactor:` Refactorización sin cambio de funcionalidad
- `Docs:` Cambios en documentación
- `Style:` Cambios de formato/estilo

**Ejemplos:**
```
Add: Panel de estadísticas en dashboard
Fix: Error al cambiar de tab en UI
Update: Mejorar rendimiento de full scan
Docs: Añadir guía de instalación
```

---

## 💬 Comunicación

### Canales

- **GitHub Issues**: Para bugs y features
- **Pull Requests**: Para contribuciones de código
- **In-Game**: Contactar a Elnazzareno
- **Discord**: El Séquito del Terror

### Idioma

- Código: Comentarios en **español**
- Commits: **Español** o inglés
- Issues/PRs: **Español** preferido

---

## 🏆 Reconocimiento

Todos los contribuidores serán reconocidos en:
- README.md
- Sección de créditos del addon
- Changelog de la versión

---

## ⚖️ Licencia

Al contribuir, aceptas que tu código se distribuya bajo la misma licencia del proyecto.

---

*¡Gracias por hacer este addon mejor!*  
*Elnazzareno - El Séquito del Terror* 🔮
