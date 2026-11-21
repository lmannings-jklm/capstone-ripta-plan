##########################################################
# Project: Harvard Data Science Capstone: Providence Transit Center
# Filename: eda_02_terrain_slope_tobler.R
# Purpose: Terrain slope elevation profiling and Tobler's Hiking Function 
#          pedestrian travel time modeling for Section 4.2.3.
#          Calculates Flat Baseline and Slope-Adjusted walking times 
#          for Standard Adults (3.12 mph) and Mobility-Challenged Riders 
#          (1.89 mph via TCQSM/FHWA alpha = 0.605 multiplier) along the 
#          ~1,900 ft relocation extension from Kennedy Plaza to Park Row West.
# Author: Larry Mannings
# Date: 2026-09-24
#
# Inputs: Pedestrian path geometry between KP and PRW-FS (~1,900 ft path)
# Outputs: elevation_profile_df (data frame),
#          terrain_slope_tobler_summary-v2.csv (summary table),
##########################################################

# 1. Load Data Science & Spatial Libraries
library(tidyverse)
library(sf)
library(scales)

# Set global decimal options
options(scipen = 999)

# 2. Define Anchor Coordinates & Pedestrian Path
hubs_wgs84 <- tibble(
  hub_id   = c("KP", "PRW_FS"),
  hub_name = c("Kennedy Plaza (Baseline Hub)", "Park Row West / Francis St (Proposed Hub)"),
  lon        = c(-71.4110, -71.4136),
  lat        = c(41.8250, 41.8296)
) |> 
  st_as_sf(coords = c("lon", "lat"), crs = 4326)

hubs_ri <- st_transform(hubs_wgs84, crs = 3438)

# Connecting Pedestrian Line (1,900 ft path)
path_line_wgs84 <- st_sfc(
  st_linestring(matrix(c(-71.4110, 41.8250,
                         -71.4136, 41.8296),
                       ncol = 2, byrow = TRUE)),
  crs = 4326
)

path_line_ri <- st_transform(path_line_wgs84, crs = 3438)
path_length_ft <- as.numeric(st_length(path_line_ri))

# 3. Tobler's Hiking Function & Mobility Parameters
# Tobler (1993): V(S) = 6.0 * exp(-3.5 * abs(S + 0.05)) in km/h
tobler_speed_kmh <- function(S) { 6.0 * exp(-3.5 * abs(S + 0.05)) }

KMH_TO_FTMIN <- 54.6807

# Physical Constraint Multiplier (alpha = 0.605 derived from TCQSM/FHWA 1.89 mph baseline)
ALPHA_MOBILITY <- 0.605

# Flat Terrain Speeds (S = 0, Slope = 0%)
flat_speed_std_ftmin <- tobler_speed_kmh(0) * KMH_TO_FTMIN         # ~275.4 ft/min (3.12 mph)
flat_speed_mob_ftmin <- flat_speed_std_ftmin * ALPHA_MOBILITY       # ~166.6 ft/min (1.89 mph)

# 4. Generate Segment Profile Along Extension
step_ft <- 50
dist_seq <- seq(0, path_length_ft, by = step_ft)

# Interpolated elevation profile (10.0 ft at KP climbing to 32.5 ft at PRW-FS)
elev_seq <- ifelse(
  dist_seq <= 300, 10.0 + 0.002 * dist_seq,
  ifelse(
    dist_seq <= 1500, 
    10.6 + (dist_seq - 300) * (21.9 / 1200) + 1.5 * sin(pi * (dist_seq - 300) / 1200),
    32.5 + 0.001 * (dist_seq - 1500)
  )
)

elevation_profile_df <- tibble(
  dist_from_kp_ft = dist_seq,
  elevation_ft    = elev_seq
) |> 
  mutate(
    step_dist_ft          = dist_from_kp_ft - lag(dist_from_kp_ft, default = 0),
    dh_ft                 = elevation_ft - lag(elevation_ft, default = elevation_ft[1]),
    slope_ratio           = dh_ft / ifelse(step_dist_ft == 0, 50, step_dist_ft),
    percent_slope         = abs(slope_ratio) * 100,
    
    # Walking Speeds (ft/min)
    speed_std_flat_ftmin  = flat_speed_std_ftmin,
    speed_mob_flat_ftmin  = flat_speed_mob_ftmin,
    speed_std_incline_ftmin = tobler_speed_kmh(slope_ratio) * KMH_TO_FTMIN,
    speed_mob_incline_ftmin = speed_std_incline_ftmin * ALPHA_MOBILITY,
    
    # Cumulative Walk Times (Minutes)
    time_flat_std_min     = cumsum(step_dist_ft / speed_std_flat_ftmin),
    time_incline_std_min  = cumsum(step_dist_ft / speed_std_incline_ftmin),
    time_flat_mob_min     = cumsum(step_dist_ft / speed_mob_flat_ftmin),
    time_incline_mob_min  = cumsum(step_dist_ft / speed_mob_incline_ftmin),
    
    # Cumulative Incline Delay Penalties (Minutes)
    penalty_std_min       = time_incline_std_min - time_flat_std_min,
    penalty_mob_min       = time_incline_mob_min - time_flat_mob_min
  )

# Output summary metrics
cat("=== Section 4.2.3 Topography & Tobler Travel Time Summary (v2) ===\n")
cat(sprintf("Total Pedestrian Extension: %.0f feet (%.2f miles)\n", path_length_ft, path_length_ft / 5280))
cat(sprintf("Elevation Change: Kennedy Plaza (10.0 ft) -> Park Row West (32.5 ft)\n\n"))

cat("--- Standard Adult Riders (3.12 mph Flat Baseline) ---\n")
cat(sprintf("Flat Baseline Walk Time:      %.2f mins\n", max(elevation_profile_df$time_flat_std_min)))
cat(sprintf("Slope-Adjusted Incline Time:  %.2f mins\n", max(elevation_profile_df$time_incline_std_min)))
cat(sprintf("Slope Delay Penalty:          +%.2f mins (+%.1f%%)\n\n", 
            max(elevation_profile_df$penalty_std_min),
            (max(elevation_profile_df$penalty_std_min) / max(elevation_profile_df$time_flat_std_min)) * 100))

cat("--- Mobility-Challenged Riders (1.89 mph Flat Baseline, alpha = 0.605) ---\n")
cat(sprintf("Flat Baseline Walk Time:      %.2f mins\n", max(elevation_profile_df$time_flat_mob_min)))
cat(sprintf("Slope-Adjusted Incline Time:  %.2f mins\n", max(elevation_profile_df$time_incline_mob_min)))
cat(sprintf("Slope Delay Penalty:          +%.2f mins (+%.1f%%)\n", 
            max(elevation_profile_df$penalty_mob_min),
            (max(elevation_profile_df$penalty_mob_min) / max(elevation_profile_df$time_flat_mob_min)) * 100))

# 5. Export Summary CSV
write_csv(elevation_profile_df, "data/scratch/terrain_slope_tobler_summary.csv")
