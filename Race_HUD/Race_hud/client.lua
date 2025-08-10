local cfg = {
    update_ms = 150,                 -- Refresh-Intervall
    anchor = {x = 0.88, y = 0.78},   -- Position (unten rechts-ähnlich); anpassen bis es wie im Foto sitzt
    scale = 1.0                      -- Gesamt-Skalierung
}

local shown = false
local nextTick = 0

-- kleine Helper
local function round(n) return math.floor(n + 0.5) end

CreateThread(function()
    while true do
        local t = GetGameTimer()
        if t >= nextTick then
            nextTick = t + cfg.update_ms

            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped,false)
            local inVeh = veh ~= 0 and GetPedInVehicleSeat(veh,-1) == ped

            if inVeh then
                if not shown then
                    SendNUIMessage({type='toggle', show=true})
                    shown = true
                end

                -- Speed (km/h)
                local speed = round(GetEntitySpeed(veh) * 3.6)

                -- Fuel (FiveM-native). Falls dein System anderen Range nutzt, hier anpassen:
                local fuel = GetVehicleFuelLevel(veh) or 0.0
                -- auf Prozent normieren (0..100). Viele Scripts halten 0..100 sowieso ein.
                if fuel < 0 then fuel = 0 end
                if fuel > 100 then fuel = 100 end

                -- Lock-Status
                local lock = GetVehicleDoorLockStatus(veh)
                local locked = (lock == 2 or lock == 3 or lock == 4) -- common locked states

                SendNUIMessage({
                    type='update',
                    speed=speed,
                    fuel=fuel,
                    locked=locked,
                    ax=cfg.anchor.x,
                    ay=cfg.anchor.y,
                    scale=cfg.scale
                })
            else
                if shown then
                    SendNUIMessage({type='toggle', show=false})
                    shown = false
                end
            end
        end
        Wait(0)
    end
end)

-- Optional: wenn dein eigenes Lock-/Fuel-Script Events/Exports hat,
-- kannst du hier hooken und die NUI direkt füttern. Beispiel:
-- RegisterNetEvent('hud:setFuel', function(val) SendNUIMessage({type='fuelOnly', fuel=val}) end)
