##########################################################
# Project: Harvard Data Science Capstone: Providence Transit Center
# Filename: test_05_generate_op_costs.R
# Purpose: Calculate downstream operational costs and fleet requirements 
# (VRH, OpsCost, VOMS) based on deterministic temporal delay penalties from 
# the hub relocation.
# Author: Larry Mannings
# Date: 2026-11-02
#
# Inputs:
#   - data/ripta_kp_final_dataset.csv (N=335,933 trip observations)
#
# Outputs:
#   - data/ripta_operational_cost.csv
##########################################################

library(tidyverse)
library(scales)

# 1. Define FTA & System Constants (from Section 5.2.1)
cost_per_vrh <- 168.77 # RIPTA system-wide unit operating cost per revenue hour
days_in_year <- 365

# 2. Ingest the Micro-Dataset
df_raw <- read_csv("data/ripta_kp_final_dataset.csv", show_col_types = FALSE)

# 3. Aggregate Route-Level Metrics and Execute Formulas
route_costs <- df_raw |>
  group_by(route_id, approach_direction) |>
  summarize(
    # Y_i: Average deterministic extension penalty (minutes)
    Y_i = mean(temporal_delay_mins, na.rm = TRUE),
    
    # Peak-hour empirical frequency (buses/hr), with fallback if a route has no peak trips
    peak_freq = coalesce(
      mean(trip_freq_buses_hr[time_of_day_factor == 1], na.rm = TRUE),
      mean(trip_freq_buses_hr, na.rm = TRUE)
    ),
    
    # h_i: Empirical peak headway in minutes (60 / peak hourly frequency)
    h_i = 60 / peak_freq,
    
    # Daily Trips_i: Total trips in log divided by days in year
    daily_trips_i = n() / days_in_year,
    
    .groups = "drop"
  ) |>
  mutate(
    # Daily Added Minutes: 2-way round trip * Y_i * daily trips
    daily_added_mins = 2 * Y_i * daily_trips_i,
    
    # Formula 1: Annual Additional Vehicle Revenue Hours (delta_VRH)
    delta_VRH = (daily_added_mins / 60) * days_in_year,
    
    # Formula 2: Annual Marginal Operating Cost (delta_OpsCost)
    delta_OpsCost = delta_VRH * cost_per_vrh,
    
    # Formula 3: Vehicles Operating in Maximum Service (delta_VOMS)
    delta_VOMS = 2*(Y_i / h_i)
  ) |>
  # Sort by most expensive routes first for reporting priority
  arrange(desc(delta_OpsCost))

# 4. Export to CSV for Quarto table ingestion
write_csv(route_costs, "data/ripta_operational_cost.csv")

# 5. Print System-Wide Summary to Console for Validation
cat("=== System-Wide Operational Cost Impacts (PRW-FS Relocation) ===\n")
cat("Total Annual Additional VRH: ", 
    format(sum(route_costs$delta_VRH), big.mark = ",", 
           nsmall = 2, scientific = FALSE), " hours\n", sep = "")
cat("Total Annual Marginal Operating Cost: $", 
    format(sum(route_costs$delta_OpsCost), big.mark = ",", 
           nsmall = 2, scientific = FALSE), "\n", sep = "")
cat("Total Additional VOMS Required: ", 
    format(sum(route_costs$delta_VOMS), big.mark = ",", 
           nsmall = 2, scientific = FALSE), " vehicles\n", sep = "")
cat("================================================================\n")