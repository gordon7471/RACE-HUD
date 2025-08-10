local ESX = exports['es_extended']:getSharedObject()

-- =====================================
-- Config
-- =====================================
local Config = {
    key = 'G',                 -- Standardtaste
    searchRadius = 6.0,        -- Suchradius für nächstes Fahrzeug wenn man nicht drin sitzt
    useHornChirp = false,      -- kurzer Hup-Chirp am Fahrzeug
    useUiBeep = true,          -- GTA Frontend Beep
    doubleFlashOnLock = true,  -- zweimal blinken beim Abschließen
    singleFlashOnUnlock = true,-- einmal blinken beim Aufschließen
    serverCallback = 'nick_lockcar:isOwned' -- ggf. anpassen, wenn dein Server-Event anders heißt
}

-- Forward declarations
local playLockSound

-- =====================================
-- Keybinding
-- =====================================
RegisterCommand('nick_togglelock', function()
    ToggleClosestOwnedVehicleLock()
end, false)

RegisterKeyMapping('nick_togglelock', 'Eigene Fahrzeuge auf-/abschließen', 'keyboard', Config.key)

-- =====================================
-- Utils
-- =====================================
local function normalizePlate(plate)
    plate = (plate or ''):gsub('^%s*(.-)%s*$', '%1')
    plate = plate:gsub('%s+', ' ')
    return plate:upper()
end

local function ensureNetworkControl(entity, timeoutMs)
    if entity == 0 then return false end
    timeoutMs = timeoutMs or 500
    local start = GetGameTimer()
    if not NetworkHasControlOfEntity(entity) then
        NetworkRequestControlOfEntity(entity)
        while not NetworkHasControlOfEntity(entity) and (GetGameTimer() - start) < timeoutMs do
            Wait(10)
        end
    end
    return NetworkHasControlOfEntity(entity)
end

local function GetClosestVehicleToPlayer(radius)
    local ped = PlayerPedId()
    local pCoords = GetEntityCoords(ped)
    local handle, veh = FindFirstVehicle()
    local success
    local closestVeh = 0
    local closestDist = radius + 0.001

    repeat
        if DoesEntityExist(veh) then
            local vCoords = GetEntityCoords(veh)
            local dist = #(pCoords - vCoords)
            if dist < closestDist then
                closestDist = dist
                closestVeh = veh
            end
        end
        success, veh = FindNextVehicle(handle)
    until not success

    EndFindVehicle(handle)
    return closestVeh
end

-- =====================================
-- Animation
-- =====================================
local function playKeyFobAnim()
    local ped = PlayerPedId()
    local dict = 'anim@mp_player_intmenu@key_fob@'
    local anim = 'fob_click'

    RequestAnimDict(dict)
    local t = GetGameTimer()
    while not HasAnimDictLoaded(dict) and GetGameTimer() - t < 2000 do
        Wait(10)
    end

    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, 700, 48, 0.0, false, false, false)
    SetTimeout(800, function()
        ClearPedSecondaryTask(ped)
        RemoveAnimDict(dict)
    end)
end

-- =====================================
-- Doors, Lights, Sounds
-- =====================================
-- Türen animiert schließen
local function closeAllDoors(veh)
    for doorIndex = 0, 5 do
        if GetVehicleDoorAngleRatio(veh, doorIndex) and GetVehicleDoorAngleRatio(veh, doorIndex) > 0.0 then
            SetVehicleDoorShut(veh, doorIndex, false) -- false = animiert
        end
    end
end

-- Scheinwerfer blinken
local function flashHeadlights(veh, times)
    times = times or 1
    for i = 1, times do
        SetVehicleLights(veh, 2)
        SetVehicleFullbeam(veh, true)
        Wait(160)
        SetVehicleFullbeam(veh, false)
        SetVehicleLights(veh, 0)
        if i < times then Wait(120) end
    end
end

-- Abschließ- bzw. Aufschließ-Sound
playLockSound = function(veh, willLock)
    if Config.useHornChirp and veh ~= 0 then
        StartVehicleHorn(veh, willLock and 150 or 90, GetHashKey('HELDDOWN'), false)
    end
    if Config.useUiBeep then
        if willLock then
            PlaySoundFrontend(-1, 'CONFIRM_BEEP', 'HUD_MINI_GAME_SOUNDSET', true)
        else
            PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        end
    end
end

-- =====================================
-- Core
-- =====================================
function ToggleClosestOwnedVehicleLock()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)

    if veh == 0 then
        veh = GetClosestVehicleToPlayer(Config.searchRadius)
        if veh == 0 then
            exports['race_notify']:Small('~r~Kein Fahrzeug in der Nähe~s~', 'info')
            return
        end
    end

    local plate = normalizePlate(GetVehicleNumberPlateText(veh))

    ESX.TriggerServerCallback(Config.serverCallback, function(isMine)
        if not isMine then
            exports['race_notify']:Small('~r~Dieses Fahrzeug gehört dir nicht~s~', 'info')
            return
        end
        doLockToggle(veh)
    end, plate)
end

function doLockToggle(veh)
    if not DoesEntityExist(veh) then return end

    if not ensureNetworkControl(veh, 800) then
        ESX.ShowNotification('Konnte keine Kontrolle über das Fahrzeug erhalten.')
        return
    end

    playKeyFobAnim()

    local status = GetVehicleDoorLockStatus(veh)
    local willLock = not (status == 2 or status == 3 or status == 4)

    local netId = NetworkGetNetworkIdFromEntity(veh)
    SetNetworkIdCanMigrate(netId, true)

    if willLock then
        closeAllDoors(veh)                       -- animiert zu
        SetVehicleDoorsLocked(veh, 2)            -- locked
        SetVehicleDoorsLockedForAllPlayers(veh, true)
        exports['race_notify']:Small('Fahrzeug ~r~abgeschlossen~s~', 'success')
        playLockSound(veh, true)
        if Config.doubleFlashOnLock then flashHeadlights(veh, 2) end
    else
        SetVehicleDoorsLocked(veh, 1)            -- unlocked
        SetVehicleDoorsLockedForAllPlayers(veh, false)
        exports['race_notify']:Small('Fahrzeug ~g~aufgeschlossen~s~', 'success')
        playLockSound(veh, false)
        if Config.singleFlashOnUnlock then flashHeadlights(veh, 1) end
    end
end
