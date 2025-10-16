# taxi (Standalone ESX Taxi Companion)

A lightweight, optimized taxi companion that spawns an AI taxi and driver, lets you enter the **rear seat**,
select destinations, change them on the fly, stop/hold, and optionally boost speed — with robust cleanup and
optional MySQL ride logging.

## Features
- Spawn taxi + AI driver at configurable location (`Config.TaxiSpawn`, `Config.TaxiModel`, `Config.DriverModel`).
- Enter the taxi via keybind and auto-warp to a rear seat (prevents stealing the driver).
- Destination selector (uses configured list in `Config.Destinations`).
- Change destination mid-ride.
- **Stop** (despawn) or **Hold** (wait in place) controls.
- Optional **speed boost** mode with safe speed caps.
- Defensive entity cleanup and `onResourceStop` safety.
- Optional MySQL logging (see `Config.LogRidesToDB`, `Config.DBTable`).

## Default Controls
- **H**: Enter the taxi (rear seat).
- **G**: Change destination.
- **Z**: Stop & despawn taxi.
- **U**: Hold position (driver waits).
- **X**: Temporary speed boost (~120 mph), with engine power bump.

You can change keys in **`config.lua`**:
```lua
Config.KeyEnterTaxi         = 74   -- H
Config.KeyChangeDestination = 47   -- G
Config.KeyStopTaxi          = 20   -- Z
Config.KeyHoldTaxi          = 303  -- U
Config.KeyBoostTaxi         = 73   -- X
```

## Driving Behaviour
Speeds are explicitly defined in meters/second to avoid nil errors:
```lua
Config.DriveStyle    = 2883621   -- safe/normal style
Config.MaxSpeedCapMS = 44.70     -- ~100 mph
Config.BoostSpeedMS  = 53.64     -- ~120 mph
Config.CruiseMS      = 15.65     -- ~35 mph city
```

## Installation
1. Put the `taxi` folder in your `resources/`.
2. Ensure your server has **ESX Legacy** and **mysql-async** (if logging enabled).
3. Add to your `server.cfg`:
   ```cfg
   ensure taxi
   ```

## MySQL Logging (Optional)
If `Config.LogRidesToDB = true`, the resource will auto-create a table named by `Config.DBTable`.
It logs identifier, start/destination names and timestamps.

## Configuration Tips
- Add/remove destinations in `Config.Destinations`.
- Toggle the map blip with `Config.ShowTaxiBlip`.
- Tweak speeds and drive style to suit your server feel.

## Notes
- This version adds **defensive defaults** to prevent `nil` arithmetic (e.g., `MaxSpeedCapMS`, `BoostSpeedMS`).
- Clean shutdown via `onResourceStop` avoids stranded peds/vehicles.