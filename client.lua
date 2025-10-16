local ESX = exports['es_extended']:getSharedObject()

local taxiVeh, driverPed, taxiBlip = nil, nil, nil
local prisonSpawn = Config.TaxiSpawn
local activeDriveToken = 0

--[[
  Bootstrap configuration sanity: provide safe defaults for any missing Config values
  to avoid nil indexing and arithmetic errors at runtime.
--]]
local function _def(v, d) return v == nil and d or v end

Config = Config or {}

-- Keybinds (safe defaults if missing)
Config.KeyEnterTaxi         = _def(Config.KeyEnterTaxi,         74)   -- H
Config.KeyChangeDestination = _def(Config.KeyChangeDestination, 47)   -- G
Config.KeyStopTaxi          = _def(Config.KeyStopTaxi,          20)   -- Z
Config.KeyHoldTaxi          = _def(Config.KeyHoldTaxi,          303)  -- U
Config.KeyBoostTaxi         = _def(Config.KeyBoostTaxi,         73)   -- X

-- Driving styles & speeds
-- DriveStyle 2883621 is safe/avoid traffic, tweak in Config if desired.
Config.DriveStyle    = _def(Config.DriveStyle,    2883621)
-- Max speed cap in m/s (approx 100 mph)
Config.MaxSpeedCapMS = _def(Config.MaxSpeedCapMS, 44.70)
-- Boost cruise in m/s (approx 120 mph)
Config.BoostSpeedMS  = _def(Config.BoostSpeedMS,  53.64)
-- Normal cruise speed in m/s (approx 35 mph city)
Config.CruiseMS      = _def(Config.CruiseMS,      15.65)

-- Spawn positions/models (fallbacks)
Config.TaxiSpawn   = Config.TaxiSpawn or vector4(1973.94, 2625.47, 45.97, 310.79)
Config.TaxiModel   = Config.TaxiModel or 'taxi'
Config.DriverModel = Config.DriverModel or 's_m_m_gentransport'

-- Blip toggles
Config.ShowTaxiBlip = _def(Config.ShowTaxiBlip, true)

-- Defensive utility: safe deletion for entities
local function SafeDeleteEntity(ent)
  if ent and DoesEntityExist(ent) then
    local attempt = 0
    SetEntityAsMissionEntity(ent, true, true)
    while not IsEntityAMissionEntity(ent) and attempt < 20 do
      attempt = attempt + 1
      Wait(10)
      SetEntityAsMissionEntity(ent, true, true)
    end
    DeleteEntity(ent)
  end
end

-- Defensive utility: end any active taxi session cleanly
local function CleanupTaxiEntities()
  if taxiBlip then RemoveBlip(taxiBlip); taxiBlip = nil end
  if driverPed then SafeDeleteEntity(driverPed); driverPed = nil end
  if taxiVeh  then SafeDeleteEntity(taxiVeh);    taxiVeh  = nil end
end -- cancels any in-flight drive loop when incremented

----------------------------------------------------------------
-- Utilities
----------------------------------------------------------------
local function LoadModel(model)
  model = type(model) == 'number' and model or GetHashKey(model)
  if not IsModelInCdimage(model) or not IsModelValid(model) then return false end
  RequestModel(model)
  local tries = 0
  while not HasModelLoaded(model) and tries < 200 do
    Wait(25); tries = tries + 1
  end
  return HasModelLoaded(model)
end

local function SafeDelEntity(ent)
  if ent and DoesEntityExist(ent) then
    SetEntityAsMissionEntity(ent, true, true)
    DeleteEntity(ent)
    if DoesEntityExist(ent) then
      if IsEntityAVehicle(ent) then DeleteVehicle(ent) end
      if DoesEntityExist(ent) then SetEntityAsNoLongerNeeded(ent) end
    end
  end
end

-- Simple 3D text helper
local function DrawText3D(x, y, z, text)
  local onScreen, sx, sy = World3dToScreen2d(x, y, z)
  local px, py, pz = table.unpack(GetGameplayCamCoords())
  local dist = #(vector3(px, py, pz) - vector3(x, y, z))
  local scale = (1 / dist) * 2
  local fov = (1 / GetGameplayCamFov()) * 100
  scale = scale * fov

  if onScreen then
    SetTextScale(0.0 * scale, 0.35 * scale)
    SetTextFont(0)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 205)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentString(text)
    EndTextCommandDisplayText(sx, sy)
  end
end

----------------------------------------------------------------
-- Spawner
----------------------------------------------------------------
local function CreateTaxi()
  if taxiVeh and DoesEntityExist(taxiVeh) then return true end

  if not LoadModel(Config.TaxiModel) then
    print("^1[return_taxi]^7 failed to load taxi model:", Config.TaxiModel)
    return false
  end
  if not LoadModel(Config.DriverModel) then
    print("^1[return_taxi]^7 failed to load driver model:", Config.DriverModel)
    return false
  end

  taxiVeh = CreateVehicle(GetHashKey(Config.TaxiModel), prisonSpawn.x, prisonSpawn.y, prisonSpawn.z, prisonSpawn.w, true, false)
  if not taxiVeh or not DoesEntityExist(taxiVeh) then
    print("^1[return_taxi]^7 failed to create taxi vehicle")
    return false
  end

  SetVehicleOnGroundProperly(taxiVeh)
  SetVehicleDoorsLocked(taxiVeh, 1) -- unlocked (passenger)
  SetVehicleRadioEnabled(taxiVeh, false)
  SetVehicleNumberPlateText(taxiVeh, "RETURNTX")
  SetEntityAsMissionEntity(taxiVeh, true, true)
  SetVehicleMaxSpeed(taxiVeh, -1.0) -- default unclamped; we clamp during boost

  driverPed = CreatePedInsideVehicle(taxiVeh, 26, GetHashKey(Config.DriverModel), -1, true, false)
  if not driverPed or not DoesEntityExist(driverPed) then
    SafeDelEntity(taxiVeh); taxiVeh = nil
    print("^1[return_taxi]^7 failed to create driver ped")
    return false
  end

  -- Anti-jack / calm AI
  SetBlockingOfNonTemporaryEvents(driverPed, true)
  SetPedFleeAttributes(driverPed, 0, false)
  SetPedCombatAttributes(driverPed, 46, true)
  SetPedCanBeDraggedOut(driverPed, false)
  SetPedStayInVehicleWhenJacked(driverPed, true)
  SetDriverAggressiveness(driverPed, 0.0)
  SetDriverAbility(driverPed, 0.8)
  SetEntityAsMissionEntity(driverPed, true, true)

  if Config.Blip.Enabled then
    if taxiBlip and DoesBlipExist(taxiBlip) then RemoveBlip(taxiBlip) end
    taxiBlip = AddBlipForEntity(taxiVeh)
    SetBlipSprite(taxiBlip, Config.Blip.Sprite)
    SetBlipColour(taxiBlip, Config.Blip.Colour)
    SetBlipScale(taxiBlip, Config.Blip.Scale)
    SetBlipAsShortRange(taxiBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.Blip.Name)
    EndTextCommandSetBlipName(taxiBlip)
  end

  SetModelAsNoLongerNeeded(GetHashKey(Config.TaxiModel))
  SetModelAsNoLongerNeeded(GetHashKey(Config.DriverModel))
  return true
end

local function CleanupAll()
  if taxiBlip and DoesBlipExist(taxiBlip) then RemoveBlip(taxiBlip) end
  taxiBlip = nil
  SafeDelEntity(driverPed); driverPed = nil
  SafeDelEntity(taxiVeh);   taxiVeh   = nil
end

AddEventHandler('onResourceStop', function(res)
  if res == GetCurrentResourceName() then
    CleanupAll()
  end
end)

----------------------------------------------------------------
-- Waypoint helpers
----------------------------------------------------------------
local function IsWaypointActive()
  local wp = GetFirstBlipInfoId(8)
  return DoesBlipExist(wp)
end

local function GetWaypointCoords()
  local blip = GetFirstBlipInfoId(8)
  if not DoesBlipExist(blip) then return nil end
  local coord = GetBlipInfoIdCoord(blip)
  if coord and coord.x and coord.y and coord.z then
    return vec3(coord.x, coord.y, coord.z)
  end
  return nil
end

----------------------------------------------------------------
-- Seat-first: try to enter as passenger before any menu
----------------------------------------------------------------
local function TrySeatPassenger(vehicle, timeoutMs)
  if not vehicle or not DoesEntityExist(vehicle) then return false end
  local ped = PlayerPedId()

  if IsPedInAnyVehicle(ped, false) then
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == vehicle and GetPedInVehicleSeat(vehicle, -1) == driverPed then
      return true
    else
      ESX.ShowNotification('Please exit your current vehicle to use the taxi.', 'error', 4500)
      return false
    end
  end

  -- choose a passenger seat: front-right (0), rear-left (1), rear-right (2), middle (3)
  local candidateSeats = {0, 1, 2, 3}
  local seatIndex
  for _, s in ipairs(candidateSeats) do
    if IsVehicleSeatFree(vehicle, s) then seatIndex = s break end
  end
  if not seatIndex then
    ESX.ShowNotification('No passenger seat available.', 'error', 4000)
    return false
  end

  -- keep driver locked in driver seat during entry
  SetPedIntoVehicle(driverPed, vehicle, -1)

  TaskEnterVehicle(ped, vehicle, 30000, seatIndex, 1.0, 1, 0)
  local t = GetGameTimer() + (timeoutMs or Config.WaitEnterTimeoutMs)
  while GetGameTimer() < t and (not IsPedInVehicle(ped, vehicle, false)) do
    if driverPed and DoesEntityExist(driverPed) then
      if GetPedInVehicleSeat(vehicle, -1) ~= driverPed then
        SetPedIntoVehicle(driverPed, vehicle, -1)
      end
    end
    Wait(100)
  end

  if not IsPedInVehicle(ped, vehicle, false) then
    ESX.ShowNotification('Failed to enter the taxi.', 'error', 4000)
    return false
  end

  return true
end

----------------------------------------------------------------
-- Destination Picker (ESX menu)
----------------------------------------------------------------
local function OpenDestinationMenu(cb)
  local elements = {}
  if IsWaypointActive() then
    elements[#elements+1] = { label = 'Go to Waypoint (Free)', value = '__WAYPOINT__' }
  end
  for _, d in ipairs(Config.Destinations) do
    elements[#elements+1] = { label = d.name, value = d.name }
  end

  ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'return_taxi_menu', {
    title    = 'Select Destination',
    align    = 'top-left',
    elements = elements
  }, function(data, menu)
    local val = data.current.value
    if cb then cb(val) end
    menu.close()
  end, function(_, menu)
    menu.close()
  end)
end

----------------------------------------------------------------
-- Taxi Drive Routine (cancellable via activeDriveToken)
----------------------------------------------------------------
local function DriveTaxiTo(destVec3, onDone)
  if not taxiVeh or not DoesEntityExist(taxiVeh) then if onDone then onDone(false) end return end
  if not driverPed or not DoesEntityExist(driverPed) then if onDone then onDone(false) end return end

  if GetPedInVehicleSeat(taxiVeh, -1) ~= driverPed then
    SetPedIntoVehicle(driverPed, taxiVeh, -1)
  end

  ClearPedTasks(driverPed)
  -- start fresh at default cruise
  SetVehicleMaxSpeed(taxiVeh, -1.0)
  TaskVehicleDriveToCoordLongrange(driverPed, taxiVeh, destVec3.x, destVec3.y, destVec3.z, Config.DriveSpeed, Config.DriveStyle, 30.0)

  local token = activeDriveToken
  local startTime = GetGameTimer()
  local arrived = false
  while true do
    Wait(500)
    if token ~= activeDriveToken then return end -- replaced/cancelled
    if not DoesEntityExist(taxiVeh) or not DoesEntityExist(driverPed) then break end
    local vpos = GetEntityCoords(taxiVeh)
    local dist = #(vpos - destVec3)
    if dist <= Config.ArrivalDist then
      arrived = true
      break
    end
    if (GetGameTimer() - startTime) > Config.StuckTimeoutMs then
      ESX.ShowNotification('Taxi could not reach the destination.', 'error', 5000)
      break
    end
  end

  if arrived and DoesEntityExist(driverPed) then
    TaskVehicleTempAction(driverPed, taxiVeh, 1, 1000) -- brake
    Wait(750)
  end

  local playerPed = PlayerPedId()
  if IsPedInVehicle(playerPed, taxiVeh, false) then
    TaskLeaveVehicle(playerPed, taxiVeh, 0)
    local t2 = GetGameTimer() + 6000
    while GetGameTimer() < t2 and IsPedInVehicle(playerPed, taxiVeh, false) do
      Wait(100)
    end
  end

  if DoesEntityExist(taxiVeh) and DoesEntityExist(driverPed) then
    local ahead = GetOffsetFromEntityInWorldCoords(taxiVeh, 0.0, Config.PostDropDriveAhead, 0.0)
    TaskVehicleDriveToCoordLongrange(driverPed, taxiVeh, ahead.x, ahead.y, ahead.z, 10.0, 2883621, 5.0)
    Wait(2500)
  end

  CleanupAll()
  if onDone then onDone(arrived) end
end

----------------------------------------------------------------
-- Spawn/keep-alive loop
----------------------------------------------------------------
CreateThread(function()
  while true do
    if not taxiVeh or not DoesEntityExist(taxiVeh) then
      CreateTaxi()
    end
    Wait(2000)
  end
end)

----------------------------------------------------------------
-- Interaction: H near taxi (seat first) -> notify -> menu -> drive
----------------------------------------------------------------
CreateThread(function()
  while true do
    Wait(0)
    if taxiVeh and DoesEntityExist(taxiVeh) then
      local ply = PlayerPedId()
      if IsPedInAnyVehicle(ply, false) then goto continue end

      local pcoords = GetEntityCoords(ply)
      local vcoords = GetEntityCoords(taxiVeh)
      local dist = #(pcoords - vcoords)

      if dist <= Config.ApproachRange then
        -- bottom HUD hint
        SetTextFont(0); SetTextProportional(0); SetTextScale(0.35, 0.35)
        SetTextColour(255, 255, 255, 215); SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(1, 0, 0, 0, 205); SetTextDropShadow(); SetTextOutline()
        BeginTextCommandDisplayText('STRING')
        AddTextComponentString('Press ~y~H~s~ to ~g~Enter Taxi~s~')
        EndTextCommandDisplayText(0.5, 0.90)

        if IsControlJustPressed(0, Config.KeyEnterTaxi) then
          if not TrySeatPassenger(taxiVeh, Config.WaitEnterTimeoutMs) then
            -- failed to seat
          else
            ESX.ShowNotification('~g~The City Has Covered Your Taxi Ride This Time~s~', 'success', 5000)

            OpenDestinationMenu(function(choice)
              if not choice then return end
              local destVec, destName

              if choice == '__WAYPOINT__' then
                local wp = GetWaypointCoords()
                if not wp then
                  ESX.ShowNotification('No waypoint set.', 'error', 4000)
                  return
                end
                destVec  = wp + vec3(0,0,0)
                destName = 'Waypoint'
              else
                for _, d in ipairs(Config.Destinations) do
                  if d.name == choice then destVec = d.coords; destName = d.name; break end
                end
              end

              if not destVec then
                ESX.ShowNotification('Invalid destination.', 'error', 4000)
                return
              end

              activeDriveToken = activeDriveToken + 1
              TriggerServerEvent('prison_taxi:logRide', destName, destVec.x, destVec.y, destVec.z)
              ESX.ShowNotification(('Heading to ~y~%s~s~. Enjoy your free ride!'):format(destName), 'success', 5000)

              DriveTaxiTo(destVec, function(ok)
                if ok then ESX.ShowNotification('Arrived at destination.', 'success', 3500)
                else ESX.ShowNotification('Ride cancelled or failed.', 'error', 3500) end
              end)
            end)
          end
        end
      end
    end
    ::continue::
  end
end)

----------------------------------------------------------------
-- Change Destination while seated (G) + 3D prompt
----------------------------------------------------------------
CreateThread(function()
  while true do
    Wait(0)
    if taxiVeh and DoesEntityExist(taxiVeh) and driverPed and DoesEntityExist(driverPed) then
      local ped = PlayerPedId()
      if IsPedInVehicle(ped, taxiVeh, false) and GetPedInVehicleSeat(taxiVeh, -1) == driverPed then
        local vpos = GetEntityCoords(taxiVeh)
        DrawText3D(vpos.x, vpos.y, vpos.z + 1.08, "~y~G~s~: Change Destination")

        if IsControlJustPressed(0, Config.KeyChangeDestination) then
          ESX.ShowNotification('~y~Change Destination~s~ selected', 'inform', 3000)

          OpenDestinationMenu(function(choice)
            if not choice then return end
            local destVec, destName

            if choice == '__WAYPOINT__' then
              local wp = GetWaypointCoords()
              if not wp then
                ESX.ShowNotification('No waypoint set.', 'error', 4000)
                return
              end
              destVec  = wp + vec3(0,0,0)
              destName = 'Waypoint'
            else
              for _, d in ipairs(Config.Destinations) do
                if d.name == choice then destVec = d.coords; destName = d.name; break end
              end
            end

            if not destVec then
              ESX.ShowNotification('Invalid destination.', 'error', 4000)
              return
            end

            activeDriveToken = activeDriveToken + 1
            ClearPedTasks(driverPed)
            TriggerServerEvent('prison_taxi:logRide', destName, destVec.x, destVec.y, destVec.z)
            ESX.ShowNotification(('Taxi now heading to ~y~%s~s~.'):format(destName), 'success', 5000)

            DriveTaxiTo(destVec, function(ok)
              if ok then ESX.ShowNotification('Arrived at destination.', 'success', 3500)
              else ESX.ShowNotification('Ride cancelled or failed.', 'error', 3500) end
            end)
          end)
        end
      end
    end
  end
end)

----------------------------------------------------------------
-- Stop & despawn while seated (Z) + 3D prompt
----------------------------------------------------------------
CreateThread(function()
  while true do
    Wait(0)
    if taxiVeh and DoesEntityExist(taxiVeh) and driverPed and DoesEntityExist(driverPed) then
      local ped = PlayerPedId()
      if IsPedInVehicle(ped, taxiVeh, false) and GetPedInVehicleSeat(taxiVeh, -1) == driverPed then
        local vpos = GetEntityCoords(taxiVeh)
        DrawText3D(vpos.x, vpos.y, vpos.z + 1.20, "~r~Z~s~: Stop Taxi (Despawn)")

        if IsControlJustPressed(0, Config.KeyStopTaxi) then
          ESX.ShowNotification("~r~Taxi stopped here.~s~ Ride cancelled.", "error", 4000)

          activeDriveToken = activeDriveToken + 1
          ClearPedTasks(driverPed)

          TaskVehicleTempAction(driverPed, taxiVeh, 1, 2000)
          Wait(2000)

          if IsPedInVehicle(ped, taxiVeh, false) then
            TaskLeaveVehicle(ped, taxiVeh, 0)
            local t2 = GetGameTimer() + 6000
            while GetGameTimer() < t2 and IsPedInVehicle(ped, taxiVeh, false) do Wait(100) end
          end

          if DoesEntityExist(taxiVeh) and DoesEntityExist(driverPed) then
            local ahead = GetOffsetFromEntityInWorldCoords(taxiVeh, 0.0, Config.PostDropDriveAhead, 0.0)
            TaskVehicleDriveToCoordLongrange(driverPed, taxiVeh, ahead.x, ahead.y, ahead.z, 10.0, 2883621, 5.0)
            Wait(2500)
          end

          CleanupAll()
        end
      end
    end
  end
end)

----------------------------------------------------------------
-- Hold position while seated (U) + 3D prompt
----------------------------------------------------------------
CreateThread(function()
  while true do
    Wait(0)
    if taxiVeh and DoesEntityExist(taxiVeh) and driverPed and DoesEntityExist(driverPed) then
      local ped = PlayerPedId()
      if IsPedInVehicle(ped, taxiVeh, false) and GetPedInVehicleSeat(taxiVeh, -1) == driverPed then
        local vpos = GetEntityCoords(taxiVeh)
        DrawText3D(vpos.x, vpos.y, vpos.z + 1.32, "~b~U~s~: Hold Position")

        if IsControlJustPressed(0, Config.KeyHoldTaxi) then
          ESX.ShowNotification("Taxi will wait here.", "inform", 3500)
          activeDriveToken = activeDriveToken + 1
          ClearPedTasks(driverPed)

          TaskVehicleTempAction(driverPed, taxiVeh, 1, 2000) -- brake
          Wait(200)
          local pos = GetEntityCoords(taxiVeh)
          local heading = GetEntityHeading(taxiVeh)
          TaskVehiclePark(driverPed, taxiVeh, pos.x, pos.y, pos.z, heading, 1, 20.0, true)
        end
      end
    end
  end
end)

----------------------------------------------------------------
-- Speed Boost while seated (X) + 3D prompt
----------------------------------------------------------------
CreateThread(function()
  while true do
    Wait(0)
    if taxiVeh and DoesEntityExist(taxiVeh) and driverPed and DoesEntityExist(driverPed) then
      local ped = PlayerPedId()
      if IsPedInVehicle(ped, taxiVeh, false) and GetPedInVehicleSeat(taxiVeh, -1) == driverPed then
        local vpos = GetEntityCoords(taxiVeh)
        DrawText3D(vpos.x, vpos.y, vpos.z + 1.44, "~o~X~s~: Speed Boost (~120 mph)")

        if IsControlJustPressed(0, Config.KeyBoostTaxi) then
          -- allow high speed and set cruise; does not reset route
          SetVehicleMaxSpeed(taxiVeh, Config.MaxSpeedCapMS + 0.0)
          SetDriveTaskCruiseSpeed(driverPed, Config.BoostSpeedMS + 0.0)
          SetVehicleEnginePowerMultiplier(taxiVeh, 10.0)
          ESX.ShowNotification("~o~Speed boost engaged.~s~ Target ~y~120 mph~s~.", "inform", 3500)
        end
      end
    end
  end
end)
