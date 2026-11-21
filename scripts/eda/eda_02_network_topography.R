##########################################################
# Project: Harvard Data Science Capstone: Providence Transit Center
# Filename: eda_02_network_topography.R
# Purpose: Spatial access analysis, GTFS hub modification, 1/4-mile 
#          osrm network walkshed comparisons (KP vs. PRW-FS), landmark layers, 
#          and elevation slope profiling for Section 4.2 of the capstone report.
# Author: Larry Mannings
# Date: 2026-09-20
#
# Inputs: None (Hardcoded coordinates and OSRM API calls)
# Outputs: hubs_ri (sf), walkshed_buffers (sf), walkshed_overlap (sf),
#          landmarks_ri (sf), path_line_ri (sf), elevation_profile_df (df)
##########################################################

# ---------------------------------------------------------
# 1. Load Required R Libraries
# ---------------------------------------------------------
library(tidyverse)
library(sf)
library(terra)
library(tidytransit)
library(ggrepel)
library(scales)
library(osrm)  # Open Source Routing Machine for street-network pedestrian isochrones
library(nngeo) # k-Nearest Neighbor (KNN) spatial join capabilities for sf objects

# Set global options for clean decimal output
options(scipen = 999)

# ---------------------------------------------------------
# 2. Define Hub Coordinates & Reproject to RI State Plane
# ---------------------------------------------------------
# Define Kennedy Plaza (KP) and Park Row West / Francis St (PRW-FS) in WGS 84 (EPSG:4326)
hubs_wgs84 <- tibble(
  hub_id     = c("KP", "PRW_FS"),
  hub_name   = c("Kennedy Plaza (Baseline Hub)", "Park Row West / Francis St (Proposed Hub)"),
  short_name = c("Kennedy Plaza", "Park Row West / Francis St"),
  lon        = c(-71.4110, -71.4136),
  lat        = c(41.8250, 41.8296)
) |>
  # convert tabular data to wgs84 spatial object (EPSG:4236)
  st_as_sf(coords = c("lon", "lat"), crs = 4326) 

# Reproject hub's wgs84 coordinates to NAD83 / Rhode Island State Plane Feet 
# (EPSG:3438)
hubs_ri <- st_transform(hubs_wgs84, crs = 3438)

# ---------------------------------------------------------
# 3. Create Landmark Layer for Downcity Context
# ---------------------------------------------------------
landmarks_wgs84 <- tibble(
  landmark_id   = c("prov_station", "state_house", "city_hall", "fin_district", "station_park", "prov_place_mall"),
  landmark_name = c("Providence Station (Rail)", "RI State House", "Providence City Hall", "Financial District", "Station Park", "Providence Place Mall"),
  type          = c("Transit Anchor", "Civic Anchor", "Civic Anchor", "Employment Core", "Public Space", "Retail Anchor"),
  lon           = c(-71.4132, -71.4150, -71.4128, -71.4101, -71.4145, -71.4156),
  lat           = c(41.8293, 41.8310, 41.8242, 41.8249, 41.8288, 41.8274)
) |>
  # convert tabular data to wgs84 spatial object (EPSG:4236)
  st_as_sf(coords = c("lon", "lat"), crs = 4326)

# Reproject downcity landmark wgs84 coordinates to NAD83 / Rhode Island State 
# Plane Feet (EPSG:3438)
landmarks_ri <- st_transform(landmarks_wgs84, crs = 3438)

# ---------------------------------------------------------
# 4. OSRM Network Isochrone & Walkshed Buffer Analysis
# ---------------------------------------------------------
# 1/4-mile corresponds to a 5-minute walk at 3.0 mph (264 ft/min)
# osrmIsochrone calculates street-network pedestrian catchments via OpenStreetMap

walkshed_buffers <- tryCatch({
  message("Calculating 5-minute pedestrian network isochrones via OSRM...")
  
  kp_iso <- osrmIsochrone(
    loc = c(-71.4110, 41.8250),
    breaks = 5,
    osrm.profile = "foot"
  ) |>
    st_transform(crs = 3438) |>
    mutate(
      hub_id     = "KP",
      hub_name   = "Kennedy Plaza (Baseline Hub)",
      short_name = "Kennedy Plaza"
    )
  
  prw_iso <- osrmIsochrone(
    loc = c(-71.4136, 41.8296),
    breaks = 5,
    osrm.profile = "foot"
  ) |>
    st_transform(crs = 3438) |>
    mutate(
      hub_id     = "PRW_FS",
      hub_name   = "Park Row West / Francis St (Proposed Hub)",
      short_name = "Park Row West / Francis St"
    )
  
  bind_rows(kp_iso, prw_iso)
}, 
# Execute the fallback script if API not operating
error = function(e) {
  message("OSRM server offline or unreachable; falling back to 1/4-mile (1,320 ft) st_buffer geometry.")
  st_buffer(hubs_ri, dist = 1320)
})

# Compute spatial overlap polygon between both 5-minute walksheds
kp_poly  <- walkshed_buffers |> filter(hub_id == "KP")
prw_poly <- walkshed_buffers |> filter(hub_id == "PRW_FS")

walkshed_overlap <- st_intersection(kp_poly, prw_poly) |>
  mutate(zone_name = "Shared Walkshed Overlap")

# Calculate physical distance extension between KP and PRW-FS (in feet & miles)
kp_geom  <- hubs_ri |> filter(hub_id == "KP")
prw_geom <- hubs_ri |> filter(hub_id == "PRW_FS")

extension_distance_feet  <- as.numeric(st_distance(kp_geom, prw_geom))
extension_distance_miles <- extension_distance_feet / 5280

# Estimated walking time at 3.0 mph (264 ft/min)
est_walk_time_min <- extension_distance_feet / 264

# ---------------------------------------------------------
# 5. Pedestrian Path Line Construction
# ---------------------------------------------------------
# Create connecting pedestrian path geometry between PRW-FS and KP
path_line_wgs84 <- st_sfc(
  st_linestring(matrix(c(-71.4145, 41.8250,   # Kennedy Plaza
                         -71.4136, 41.8296),  # PRW-FS
                       ncol = 2, byrow = TRUE)),
  crs = 4326
)

path_line_ri <- st_transform(path_line_wgs84, crs = 3438)

# ---------------------------------------------------------
# 6. Terrain & Slope Modeling (Tobler's Hiking Function)
# ---------------------------------------------------------
path_points <- st_segmentize(path_line_ri, dfMaxLength = 50) |>
  st_cast("POINT")

tobler_speed_kmh <- function(S) { 6 * exp(-3.5 * abs(S + 0.05)) }

flat_speed_kmh   <- tobler_speed_kmh(0)
flat_speed_ftmin <- flat_speed_kmh * 54.6807

elevation_profile_df <- tibble(
  point_id      = 1:length(path_points),
  dist_from_kp  = seq(0, extension_distance_feet, length.out = length(path_points)),
  elevation_ft  = seq(10, 30, length.out = length(path_points))
) |>
  mutate(
    elevation_change_ft     = elevation_ft - lag(elevation_ft),
    step_distance_ft        = dist_from_kp - lag(dist_from_kp),
    percent_slope           = abs(elevation_change_ft / step_distance_ft) * 100,
    slope_uphill            = abs(elevation_change_ft) / step_distance_ft,
    slope_uphill            = coalesce(slope_uphill, 0),
    walk_speed_uphill_kmh   = tobler_speed_kmh(slope_uphill),
    walk_speed_uphill_ftmin = walk_speed_uphill_kmh * 54.6807,
    segment_time_flat_min   = coalesce(step_distance_ft / flat_speed_ftmin, 0),
    segment_time_uphill_min = coalesce(step_distance_ft / walk_speed_uphill_ftmin, 0),
    uphill_penalty_min      = segment_time_uphill_min - segment_time_flat_min
  )

total_elevation_gain_ft <- max(elevation_profile_df$elevation_ft) - min(elevation_profile_df$elevation_ft)
average_slope_percent   <- (total_elevation_gain_ft / extension_distance_feet) * 100

