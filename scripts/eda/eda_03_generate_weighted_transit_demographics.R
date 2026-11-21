##########################################################
# Project: Harvard Data Science Capstone: Providence Transit Center
# Filename: eda_03_generate_weighted_transit_demographics.R
# Purpose: Compute Route-Volume Weighted Transit Demographics and
#          generate the Weighted Version of Table 5 from capstone-ripta.pdf
#          using knitr::kable() for HTML & PDF rendering.
# Author: Larry Mannings
# Date: 2026-09-25
#
# Inputs:
#   1) providence_city_bg (from eda_03_census_rigis_ingestion-v3.R / eda_03_census_rigis_ingest.R)
#   2) route_impact_summary (from eda_01_ingest_route_kp_frequency.R / ripta-simulated-routes-v3.csv)
# Outputs:
#   1) weighted_table5_transit_demographics.csv
##########################################################

# 1. Load Data Science & Formatting Libraries
library(tidyverse)
library(knitr)
library(kableExtra)
library(sf)

options(scipen = 999)

# 2. Source Block Group Ingestion Script for providence_city_bg
cat("Step 1: Sourcing Block Group Demographics (providence_city_bg)...\n")
if (file.exists("scripts/eda_03_census_rigis_ingestion.R")) {
  source("scripts/eda_03_census_rigis_ingestion.R")
}

# Fallback check if providence_city_bg is loaded or created
if (!exists("providence_city_bg")) {
  stop("Error: providence_city_bg object was not found. Please ensure eda_03_census_rigis_ingestion-v3.R runs successfully.")
}

# 3. Source Route Frequency Ingestion Script for route_impact_summary
cat("Step 2: Sourcing Route Frequency & Ridership Summary (route_impact_summary)...\n")
if (file.exists("scripts/eda_01_ingest_route_kp_frequency.R")) {
  source("scripts/eda_01_ingest_route_kp_frequency.R")
}

# Fallback check for route_impact_summary
if (!exists("route_impact_summary")) {
  route_impact_summary <- read_csv("ripta-simulated-routes-v3.csv", show_col_types = FALSE)
}

# 4. Map Corridor Tier Daily Ridership (R_r) to Block Groups
cat("Step 3: Calculating Daily Route Ridership (R_r) per Block Group...\n")

# Calculate total daily corridor ridership by operational tier
tier_ridership_lookup <- route_impact_summary |> 
  group_by(corridor_tier)  |> 
  summarize(
    Tier_Daily_Ridership = sum(daily_ridership, na.rm = TRUE),
    .groups = "drop"
  )

# Join ridership volume to block groups based on study group corridor tiers:
# Transit-Dependent -> Tier 1 High-Frequency Equity Corridors
# Mobility-Challenged -> Tier 2 Medical & Mobility Corridors
# Non-Vulnerable -> Tier 3 Choice & Regional Express Corridors
providence_city_bg <- providence_city_bg %>%
  mutate(
    corridor_tier = case_when(
      study_group == "Transit-Dependent"   ~ "Tier 1: High-Frequency Urban Equity Corridor",
      study_group == "Mobility-Challenged" ~ "Tier 2: Medical & Mobility Access Corridor",
      study_group == "Non-Vulnerable"     ~ "Tier 3: Choice & Regional Express Corridor"
    )
  ) |> 
  left_join(tier_ridership_lookup, by = "corridor_tier") |> 
  mutate(
    # Daily Ridership per block group: sum_{r in bg} R_r
    daily_ridership_bg = Tier_Daily_Ridership,
    
    # Weight per block group: Pop_bg * sum_{r in bg} R_r
    bg_rider_weight = total_pop * daily_ridership_bg
  )

# 5. Apply Formula (3) & Formula (4) for Weighted Demographics and Rider Shares
cat("Step 4: Computing Weighted Transit Rider Shares & Weighted Demographic Rates...\n")

total_system_rider_weight <- sum(providence_city_bg$bg_rider_weight, na.rm = TRUE)
total_system_population   <- sum(providence_city_bg$total_pop, na.rm = TRUE)

weighted_table5_data <- providence_city_bg |> 
  st_drop_geometry() |> 
  group_by(study_group, .drop = FALSE)  |> 
  summarise(
    Block_Groups           = n(),
    Total_Population       = sum(total_pop, na.rm = TRUE),
    Unweighted_Pop_Share   = (sum(total_pop, na.rm = TRUE) / total_system_population) * 100,
    
    # Formula (4): Weighted Transit Rider Share %
    # Rider_Share_g = sum_{i in Group g} (Pop_i * Daily_Ridership_i) / sum_{All i} (Pop_i * Daily_Ridership_i) * 100%
    Weighted_Rider_Share   = (sum(bg_rider_weight, na.rm = TRUE) / total_system_rider_weight) * 100,
    
    # Formula (3): Weighted Demographic Rates %
    # Rate_weighted = sum_{bg} (Demographic_Rate_bg * Pop_bg * sum_{r in bg} R_r) / sum_{bg} (Pop_bg * sum_{r in bg} R_r)
    Weighted_Income        = sum(med_income * bg_rider_weight, na.rm = TRUE) / sum(bg_rider_weight, na.rm = TRUE),
    Weighted_Minority_Pct  = sum(minority_pct * bg_rider_weight, na.rm = TRUE) / sum(bg_rider_weight, na.rm = TRUE),
    Weighted_ZeroCar_Pct   = sum(zero_car_pct * bg_rider_weight, na.rm = TRUE) / sum(bg_rider_weight, na.rm = TRUE),
    Weighted_Disabled_Pct  = sum(disabled_pct * bg_rider_weight, na.rm = TRUE) / sum(bg_rider_weight, na.rm = TRUE),
    Weighted_Elderly_Pct   = sum(elderly_pct * bg_rider_weight, na.rm = TRUE) / sum(bg_rider_weight, na.rm = TRUE),
    .groups                = "drop"
  )

# Calculate System-wide Weighted Totals
system_total_row <- tibble(
  study_group          = "Total / Weighted Avg.",
  Block_Groups         = sum(weighted_table5_data$Block_Groups),
  Total_Population     = total_system_population,
  Unweighted_Pop_Share = 100.0,
  Weighted_Rider_Share = 100.0,
  Weighted_Income      = sum(providence_city_bg$med_income * providence_city_bg$bg_rider_weight, na.rm = TRUE) / total_system_rider_weight,
  Weighted_Minority_Pct= sum(providence_city_bg$minority_pct * providence_city_bg$bg_rider_weight, na.rm = TRUE) / total_system_rider_weight,
  Weighted_ZeroCar_Pct = sum(providence_city_bg$zero_car_pct * providence_city_bg$bg_rider_weight, na.rm = TRUE) / total_system_rider_weight,
  Weighted_Disabled_Pct= sum(providence_city_bg$disabled_pct * providence_city_bg$bg_rider_weight, na.rm = TRUE) / total_system_rider_weight,
  Weighted_Elderly_Pct = sum(providence_city_bg$elderly_pct * providence_city_bg$bg_rider_weight, na.rm = TRUE) / total_system_rider_weight
)

# Combine Study Groups + System Total
table5_combined <- bind_rows(weighted_table5_data, system_total_row)

# Export raw unformatted CSV summary
write_csv(table5_combined, "data/scratch/weighted_transit_demographics.csv")




