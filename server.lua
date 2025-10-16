local ESX = exports['es_extended']:getSharedObject()

-- Create log table (if enabled)
CreateThread(function()
  if not Config.LogRidesToDB then return end
  local q = ([[
    CREATE TABLE IF NOT EXISTS `%s` (
      id INT AUTO_INCREMENT PRIMARY KEY,
      identifier VARCHAR(64) NOT NULL,
      destination VARCHAR(128) NOT NULL,
      x DOUBLE NOT NULL, y DOUBLE NOT NULL, z DOUBLE NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  ]]):format(Config.DBTable)
  MySQL.Async.execute(q, {}, function(_) end)
end)

RegisterNetEvent('prison_taxi:logRide', function(destName, x, y, z)
  if not Config.LogRidesToDB then return end
  local src = source
  if not src then return end
  local xPlayer = ESX.GetPlayerFromId(src)
  if not xPlayer then return end
  local identifier = xPlayer.getIdentifier() or 'unknown'
  MySQL.Async.execute(
    ('INSERT INTO `%s` (identifier, destination, x, y, z) VALUES (?, ?, ?, ?, ?)'):format(Config.DBTable),
    { identifier, tostring(destName or 'Waypoint'), x+0.0, y+0.0, z+0.0 },
    function(_) end
  )
end)
