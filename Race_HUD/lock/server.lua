local ESX = exports['es_extended']:getSharedObject()

-- Normalisiert Kennzeichen: trim + ohne doppelte Spaces + upper
local function normalizePlate(plate)
    plate = (plate or ""):gsub("^%s*(.-)%s*$", "%1")
    plate = plate:gsub("%s+", " ")
    return plate:upper()
end

ESX.RegisterServerCallback('nick_lockcar:isOwned', function(src, cb, rawPlate)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then cb(false) return end

    local plate = normalizePlate(rawPlate)

    -- Passe Feldernamen an, falls bei dir anders:
    -- Standard ESX: table owned_vehicles(owner VARCHAR, plate VARCHAR, ...)
    MySQL.scalar('SELECT 1 FROM owned_vehicles WHERE owner = ? AND REPLACE(UPPER(plate),"  "," ") = ? LIMIT 1', {
        xPlayer.identifier, plate
    }, function(row)
        cb(row ~= nil)
    end)
end)
