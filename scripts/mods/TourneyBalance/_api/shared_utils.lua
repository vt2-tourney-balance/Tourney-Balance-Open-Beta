local shared_utils = {}

--[[
    is_server() - Checks if the current machine is the server (host).

    is_local(unit) - Checks if a specific unit is controlled by the local player.

    Use case: Check is_local(unit) first to decide whether a client-side proc should react at all
    (so it fires once, for the client whose own unit was involved, not redundantly on every client
    watching it happen); check is_server() separately to decide HOW to commit a change to shared
    game state. Apply and broadcast if this client is authoritative, or ask the server to do else.
]]
function shared_utils.is_server()
    return Managers.player.is_server
end

function shared_utils.is_local(unit)
    local player = Managers.player:owner(unit)
    return player and not player.remote
end

return shared_utils


