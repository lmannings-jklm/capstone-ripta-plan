##########################################################
# Project: Harvard Data Science Capstone: Providence Transit Center
# Filename: tool_03_generate_isochrone_map.R
# Purpose: Query Open Street Routing API (osrm) and generate a pedestrian
#          path between Kennedy Plaza and Park Row West proxy (Providence 
#          Station). Export the coordinates for plotting in Google Maps.
# Author: Larry Mannings
# Date: 2026-10-07
#
# Inputs:
#   N/A
#
# Outputs:
#   - N/A
##########################################################

# Load necessary libraries
library(sf)
library(osrm)
library(dplyr)

# 1. Define Hub Coordinates (Longitude, Latitude)
# Note: osrm expects c(lon, lat)
kp_coords <- c(-71.4110, 41.8250)
prw_coords <- c(-71.4136, 41.8296)

# 2. Query the OpenStreetMap Routing API for the Pedestrian Path
cat("Routing pedestrian path via OSRM...\n")
pedestrian_path_sf <- osrmRoute(
  src = kp_coords,
  dst = prw_coords,
  osrm.profile = "foot" 
)

# 3. Export to Google Earth (KML)
# This creates a file you can double-click to open directly in Google Earth
cat("Exporting path to Google Earth KML...\n")
st_write(
  pedestrian_path_sf, 
  "kp_to_prw_pedestrian_path.kml", 
  driver = "KML", 
  delete_dsn = TRUE # Overwrites if the file already exists
)
