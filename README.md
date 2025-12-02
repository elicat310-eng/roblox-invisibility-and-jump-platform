# Roblox - Invisibility & Jump Platform System
Sistema creado para Elias. Incluye:

- GUI completa con botones:
  - Invisibilidad (ON/OFF)
  - Salto con plataforma predictiva (ON/OFF)
  - Minimizar GUI a un círculo flotante
  - Botón de cerrar
- GUI draggable y el círculo también
- Soporte total de servidor para invisibilidad real en todo el servidor
- Plataforma predictiva que sigue al jugador al saltar

## Instalación

### 1. Crear RemoteEvents
En **ReplicatedStorage**, crea:
- `ToggleInvisibility` (RemoteEvent)
- `ToggleJumpPlatform` (RemoteEvent)

### 2. Script del servidor
En **ServerScriptService**, crea un Script llamado:
