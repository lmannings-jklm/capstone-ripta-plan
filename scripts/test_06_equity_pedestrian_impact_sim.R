# ==============================================================================
# Project: Harvard Data Science Capstone: Providence Transit Center
# Script: test_06_equity_pedestrian_impact_sim.R
# Purpose: Executes parallelized Monte Carlo simulation across bi-directional 
#          trips. Incorporates Tobler's downhill walking normalization.
# Author: Larry Mannings
# Date: 2026-11-10
#
# Inputs:
#   - data/ripta_bidirectional_filtered.csv
#   - data/ripta_kp_final_dataset.csv
#
# Outputs:
#   - data/mc_pedestrian_results_bidirectional.csv
##########################################################

library(tidyverse)
library(future)
library(furrr)

# 1. Setup Parallel Processing
plan(multisession, workers = availableCores() - 1)
set.seed(2026)
n_iterations <- 1000

# Tobler's Conversions
tobler_speed_ratio <- 1.138 # Downhill (-1.85%) is 13.8% faster than uphill (+1.85%)

# ==============================================================================
# 2. Prepare Bi-Directional Trips & Spatial Delay Penalties
# ==============================================================================
cat("Loading Bi-Directional Trips...\n")
bdir_trips <- read_csv("data/ripta_bidirectional_filtered.csv")  |> 
  mutate(shuttle_time_penalty = if("shuttle_time_penalty" %in% names(pick(everything()))) 
      coalesce(shuttle_time_penalty), 15)

spatial_penalties <- read_csv("data/ripta_kp_final_dataset.csv")  |> 
  group_by(route_id)  |> 
  summarise(Y_ext = mean(temporal_delay_mins, na.rm = TRUE), .groups = "drop")  |> 
  rename(Route_ID = route_id)

bdir_trips <- bdir_trips  |> 
  left_join(spatial_penalties, by = "Route_ID")  |> 
  mutate(Y_ext = replace_na(Y_ext, 0))

# ==============================================================================
# 3. Execute Monte Carlo Simulation
# ==============================================================================
cat("Executing parallelized Monte Carlo Simulation...\n")
simulated_pedestrians <- bdir_trips  |> 
  group_split(Route_ID, Direction, Equity_Tier)  |> 
  future_map_dfr(~ {
    .x  |> 
      uncount(n_iterations)  |> #replicate the rows for parallezed operations
      mutate(
        H = runif(n(), min = 0.30, max = 0.50),
        D = runif(n(), min = 0.490, max = 0.641),
        lambda = R_r * H * W_t,
        n_boardings = rpois(n(), lambda = lambda),
        disp_riders = rbinom(n(), size = n_boardings, prob = D),
        
        # Tobler's Walk Probabilities (Scaled for downhill advantage if inbound)
        able_min = ifelse(is_inbound, 0.20 * tobler_speed_ratio, 0.20),
        able_max = ifelse(is_inbound, 0.30 * tobler_speed_ratio, 0.30),
        mob_min = ifelse(is_inbound, 0.01 * tobler_speed_ratio, 0.01),
        mob_max = ifelse(is_inbound, 0.10 * tobler_speed_ratio, 0.10),
        
        walk_prob = ifelse(Equity_Tier == "Mobility-Challenged", 
                           runif(n(), min = mob_min, max = mob_max), 
                           runif(n(), min = able_min, max = able_max)),
        
        actual_walkers = rbinom(n(), size = disp_riders, prob = walk_prob),
        shuttle_waiters = disp_riders - actual_walkers,
        
        # Tobler's Walk Time 
        std_time = ifelse(is_inbound, 7.20 / tobler_speed_ratio, 7.20),
        mob_time = ifelse(is_inbound, 11.90 / tobler_speed_ratio, 11.90),
        route_walk_time = ifelse(Equity_Tier == "Mobility-Challenged", mob_time, std_time),
        
        total_walk_mins = actual_walkers * route_walk_time,
        total_shuttle_mins = shuttle_waiters * shuttle_time_penalty,
        total_delay_mins = total_walk_mins + total_shuttle_mins
      ) |> 
      group_by(Route_ID, Route_Name, Direction, Equity_Tier, Y_ext)  |> 
      summarise(
        Mean_Expected_Boardings = mean(n_boardings),
        Mean_Displaced_Riders = mean(disp_riders),
        Mean_Physical_Walkers = mean(actual_walkers),
        Mean_Shuttle_Waiters = mean(shuttle_waiters),
        Total_Delay_Minutes = mean(total_delay_mins),
        .groups = "drop"
      )  |> 
      mutate(
        Avg_Pedestrian_Penalty = Total_Delay_Minutes / Mean_Displaced_Riders,
        Equity_Status = ifelse(Equity_Tier == "Non-Vulnerable", "Non-Vulnerable", "Vulnerable"),
        Operational_Burden = ifelse(Y_ext > 0, "Severe Burden", "Truncated/Relief")
      )
  }, .options = furrr_options(seed = TRUE)) 

write_csv(simulated_pedestrians, "data/mc_pedestrian_results_bidirectional.csv")
cat("Simulation Complete. Results exported to data/mc_pedestrian_results_bidirectional.csv\n")