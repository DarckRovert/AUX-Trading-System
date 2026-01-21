# 🚀 Guía de Instalación - AUX Trading System

**Por Elnazzareno (DarckRovert)**  
**El Séquito del Terror** 🔮

---

## 📋 Requisitos

- World of Warcraft 1.12.1 (Vanilla) o Turtle WoW
- Acceso a la carpeta de AddOns del juego

---

## 📥 Descarga

### Opción 1: GitHub

1. Ve al repositorio: `github.com/DarckRovert/aux-addon`
2. Haz clic en **"Code"** > **"Download ZIP"**
3. Extrae el archivo descargado

### Opción 2: Release

1. Ve a la sección **Releases** del repositorio
2. Descarga la última versión estable
3. Extrae el archivo

---

## 📁 Instalación

### Paso 1: Localizar la carpeta de AddOns

La carpeta de AddOns se encuentra en:

**Windows:**
```
C:\Program Files\World of Warcraft\Interface\AddOns\
```

**Turtle WoW (común):**
```
E:\Turtle Wow\Interface\AddOns\
```

**Mac:**
```
/Applications/World of Warcraft/Interface/AddOns/
```

### Paso 2: Copiar el addon

1. Copia la carpeta `aux-addon` completa
2. Pégala en la carpeta `AddOns`

**Estructura correcta:**
```
Interface/
└── AddOns/
    └── aux-addon/
        ├── aux-addon.toc
        ├── aux-addon.lua
        ├── README.md
        ├── core/
        ├── gui/
        ├── libs/
        ├── tabs/
        └── util/
```

### Paso 3: Verificar instalación

1. Inicia World of Warcraft
2. En la pantalla de selección de personaje, haz clic en **"AddOns"**
3. Verifica que **"aux"** aparezca en la lista y esté habilitado

---

## ⚙️ Configuración Inicial

### Primera vez

1. Entra al juego con tu personaje
2. Ve a una **Casa de Subastas**
3. Habla con el subastador
4. Deberías ver la interfaz de AUX
5. Haz clic en el tab **"Trading"**

### Verificar funcionamiento

Deberías ver:
- Sidebar con iconos a la izquierda
- Dashboard con tarjetas de estadísticas
- Tu oro mostrado en la esquina superior derecha

---

## 🔄 Actualización

### Actualizar a nueva versión

1. **Cierra el juego completamente**
2. Haz backup de tu carpeta actual (opcional pero recomendado)
3. Elimina la carpeta `aux-addon` antigua
4. Copia la nueva versión
5. Inicia el juego

### Conservar datos

Tus datos de mercado y configuración se guardan en:
```
WTF/Account/[TU_CUENTA]/SavedVariables/aux.lua
```

Este archivo **NO se elimina** al actualizar el addon.

---

## 🐛 Solución de Problemas

### El addon no aparece en la lista

**Causas posibles:**
- La carpeta no se llama exactamente `aux-addon`
- La carpeta está en ubicación incorrecta
- Hay una subcarpeta extra (ej: `aux-addon/aux-addon/`)

**Solución:**
Verifica que la estructura sea:
```
AddOns/aux-addon/aux-addon.toc
```
Y NO:
```
AddOns/aux-addon-master/aux-addon/aux-addon.toc
```

### Error "Interface action failed"

**Causa:** Conflicto con otro addon de AH

**Solución:**
1. Deshabilita otros addons de casa de subastas
2. Haz `/reload`

### La UI de Trading no aparece

**Causa:** Error de carga del módulo

**Solución:**
1. Revisa si hay errores de Lua (instala BugSack o similar)
2. Haz `/reload`
3. Si persiste, reinstala el addon

### Errores de Lua al abrir

**Causa:** Versión incompatible o archivos corruptos

**Solución:**
1. Elimina la carpeta `aux-addon` completamente
2. Descarga una copia fresca
3. Reinstala

---

## 📞 Soporte

Si tienes problemas:

1. **In-Game**: Contacta a Elnazzareno en Turtle WoW
2. **Discord**: El Séquito del Terror
3. **GitHub**: Abre un Issue en el repositorio

---

## ✅ Verificación Final

Tu instalación está correcta si:

- [ ] El addon aparece en la lista de AddOns
- [ ] No hay errores al iniciar sesión
- [ ] La interfaz de AUX se abre en la AH
- [ ] El tab "Trading" muestra la nueva UI
- [ ] El sidebar tiene iconos y es navegable
- [ ] Tu oro se muestra correctamente

---

*¡Disfruta del trading!*  
*Elnazzareno - El Séquito del Terror* 🔮
