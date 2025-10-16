Config = {}

-- Spawn outside Bolingbroke (adjust if you want a different curb position)
Config.TaxiSpawn     = vector4(1973.94, 2625.47, 45.97, 310.79)
Config.TaxiModel     = 'taxi'
Config.DriverModel   = 's_m_m_gentransport'

-- Keys
Config.KeyEnterTaxi         = 74    -- H
Config.KeyChangeDestination = 47    -- G
Config.KeyStopTaxi          = 20    -- Z  (stop & despawn)
Config.KeyHoldTaxi          = 303   -- U  (hold position; no despawn)
Config.KeyBoostTaxi         = 73    -- X  (speed boost)

-- Blip: Yellow Taxi
Config.Blip = {
  Enabled = true,
  Sprite  = 198,     -- Taxi icon
  Colour  = 5,       -- Yellow
  Scale   = 1.0,
  Name    = 'Return Taxi'
}

-- Driving/logic
Config.DriveSpeed        = 20.0     -- default cruise speed (m/s) ~45 mph
Config.DriveStyle        = 443      -- balanced, goes around cars (your preference)
Config.BoostSpeedMS      = 54.0     -- boosted cruise (m/s) ~120.8 mph
Config.MaxSpeedCapMS     = 65.0     -- hard cap (m/s) ~145 mph
Config.ApproachRange     = 3.5      -- distance to show "Press H"
Config.WaitEnterTimeoutMs= 8000     -- wait to seat before cancel
Config.StuckTimeoutMs    = 120000   -- give up if pathing fails
Config.ArrivalDist       = 10.0     -- consider "arrived"
Config.PostDropDriveAhead= 10.0     -- roll forward before despawn

-- Destination presets (extend freely)
Config.Destinations = {
  { name = 'Legion Square',            coords = vec3(215.76, -922.62, 30.69) },
  { name = 'Pillbox Hill Medical',     coords = vec3(307.19, -595.49, 43.29) },
  { name = 'Mission Row PD',           coords = vec3(434.80, -981.88, 30.71) },
  { name = 'LSIA (Airport)',           coords = vec3(-1044.55, -2749.12, 21.36) },
  { name = 'Del Perro Pier',           coords = vec3(-1613.22, -1083.07, 13.02) },
  { name = 'Vespucci Beach',           coords = vec3(-1286.20, -1487.23, 4.37) },
  { name = 'Rockford Plaza',           coords = vec3(-1338.28, -280.06, 39.35) },
  { name = 'Vinewood Blvd',            coords = vec3(318.56, 180.36, 103.49) },
  { name = 'Sandy Shores',             coords = vec3(1853.18, 3686.41, 34.27) },
  { name = 'Paleto Bay',               coords = vec3(-274.56, 6226.48, 31.49) }
}

-- Optional MySQL logging
Config.LogRidesToDB = true
Config.DBTable      = 'return_taxi_logs'
