##########################################################
# Project: Harvard Data Science Capstone: Providence Transit Center
# Filename: eda_03_census_rigis_ingestion.R
# Purpose: Direct API Ingestion & Tidy Data Cleaning of US Census ACS 
#          Demographics & RIGIS GIS Layers for Providence, RI.
#          Classifies Block Groups into 3 Study Groups:
#          1) Transit-Dependent (Income, Race/Ethnicity, Vehicle Access)
#          2) Mobility-Challenged (Disability Status, Elderly 65+)
#          3) Non-Vulnerable (Choice Riders / Baseline)
# Author: Larry Mannings
# Date: 2026-09-23
##########################################################

# 1. Load Data Science & Spatial API Libraries
library(tidycensus)
library(tidyverse)
library(sf)

# Set global scientific notation off
options(scipen = 999)

# 2. Configure Census API Key
# Uses Sys.getenv("CENSUS_API_KEY") configured in .Rprofile
if (Sys.getenv("CENSUS_API_KEY") != "") {
  census_api_key(Sys.getenv("CENSUS_API_KEY"))
}

# 3. Step 1: Fetch Tract-Level Disability Data (Table B18101)
cat("Fetching Census Tract Disability Rates (Table B18101)...\n")
providence_tract_disab <- get_acs(
  geography = "tract",
  variables = c(
    disab_total     = "B18101_001", # Total Civilian Noninstitutionalized Pop
    m_disab_under18 = "B18101_004", # Male <18 with disability
    m_disab_18_64   = "B18101_007", # Male 18-64 with disability
    m_disab_65_over = "B18101_010", # Male 65+ with disability
    f_disab_under18 = "B18101_014", # Female <18 with disability
    f_disab_18_64   = "B18101_017", # Female 18-64 with disability
    f_disab_65_over = "B18101_020"  # Female 65+ with disability
  ),
  state = "RI",
  county = "Providence",
  year = 2022,
  output = "wide"
) |> 
  mutate(
    disabled_count = m_disab_under18E + m_disab_18_64E + m_disab_65_overE +
                     f_disab_under18E + f_disab_18_64E + f_disab_65_overE,
    disabled_pct   = (disabled_count / disab_totalE) * 100,
    tract_geoid    = GEOID
  ) |> 
  select(tract_geoid, disabled_pct)

# 4. Step 2: Fetch Block Group Variables & Join Parent Tract Disability Rate
cat("Fetching ACS 5-Year Block Group Demographics for Providence County...\n")
bg_acs_vars <- c(
  med_income   = "B19013_001", # Median Household Income
  total_pop    = "B02001_001", # Total Population
  white_alone  = "B02001_002", # White Alone Population
  total_units  = "B25044_001", # Total Housing Units (Vehicles)
  no_car_owner = "B25044_003", # Owner: No vehicle
  no_car_renter= "B25044_010", # Renter: No vehicle
  
  # Senior Age Variables (65+)
  m_65_66 = "B01001_020", m_67_69 = "B01001_021", m_70_74 = "B01001_022",
  m_75_79 = "B01001_023", m_80_84 = "B01001_024", m_85_over = "B01001_025",
  f_65_66 = "B01001_044", f_67_69 = "B01001_045", f_70_74 = "B01001_046",
  f_75_79 = "B01001_047", f_80_84 = "B01001_048", f_85_over = "B01001_049"
)

providence_acs_bg <- get_acs(
  geography = "block group",
  variables = bg_acs_vars,
  state = "RI",
  county = "Providence",
  year = 2022,
  geometry = TRUE,
  output = "wide"
) |> 
  st_transform(crs = 3438) |> 
  mutate(
    tract_geoid  = str_sub(GEOID, 1, 11),
    total_pop    = total_popE,
    med_income   = med_incomeE,
    minority_pct = ((total_popE - white_aloneE) / total_popE) * 100,
    zero_car_pct = ((no_car_ownerE + no_car_renterE) / total_unitsE) * 100,
    elderly_pct  = ((m_65_66E + m_67_69E + m_70_74E + m_75_79E + m_80_84E + m_85_overE +
                     f_65_66E + f_67_69E + f_70_74E + f_75_79E + f_80_84E + f_85_overE) / total_popE) * 100
  ) |> 
  left_join(providence_tract_disab, by = "tract_geoid")

# 5. Stream RIGIS Providence Boundary & Spatial Clip
cat("Streaming RIGIS Municipal Boundaries & Clipping to Providence City Limits...\n")
rigis_providence_url <- "https://services2.arcgis.com/S8zZg9pg23JUEexQ/arcgis/rest/services/BND_Municipalities_1997_spf/FeatureServer/0/query?outFields=*&where=NAME%20%3D%20'PROVIDENCE'&f=geojson"
rigis_prov_boundary <- st_read(rigis_providence_url, quiet = TRUE) |> 
  st_transform(crs = 3438)

providence_city_bg <- st_intersection(providence_acs_bg, rigis_prov_boundary)

# 6. Option 2 Relative Citywide Benchmarks & 3-Tier Classification Logic
city_med_income  <- median(providence_city_bg$med_income, na.rm = TRUE)
city_avg_minority <- mean(providence_city_bg$minority_pct, na.rm = TRUE)
city_avg_zerocar  <- mean(providence_city_bg$zero_car_pct, na.rm = TRUE)
city_avg_disabled <- mean(providence_city_bg$disabled_pct, na.rm = TRUE)
city_avg_elderly  <- mean(providence_city_bg$elderly_pct, na.rm = TRUE)

providence_city_bg <- providence_city_bg |> 
  mutate(
    study_group = case_when(
      med_income < city_med_income & (minority_pct > city_avg_minority | zero_car_pct > city_avg_zerocar) ~ "Transit-Dependent",
      disabled_pct > city_avg_disabled | elderly_pct > city_avg_elderly ~ "Mobility-Challenged",
      TRUE ~ "Non-Vulnerable"
    ),
    study_group = factor(study_group, levels = c("Transit-Dependent", "Mobility-Challenged", "Non-Vulnerable"))
  ) |> 
  select(GEOID, NAME, total_pop, med_income, minority_pct, zero_car_pct, disabled_pct, elderly_pct, study_group, geometry)

# 7. Output 3-Tier Summary Including Total Population and Shares
cat(sprintf("Successfully classified %d Providence Census Block Groups across 3 study groups:\n", nrow(providence_city_bg)))
summary_3tier <- providence_city_bg |> 
  st_drop_geometry() |> 
  group_by(study_group, .drop = FALSE) |> 
  summarize(
    Count              = n(),
    Total_Population   = sum(total_pop, na.rm = TRUE),
    Mean_Population    = mean(total_pop, na.rm = TRUE),
    Mean_Income        = mean(med_income, na.rm = TRUE),
    Mean_Minority_Pct  = mean(minority_pct, na.rm = TRUE),
    Mean_Zero_Car_Pct  = mean(zero_car_pct, na.rm = TRUE),
    Mean_Disabled_Pct  = mean(disabled_pct, na.rm = TRUE),
    Mean_Elderly_Pct   = mean(elderly_pct, na.rm = TRUE),
    .groups            = "drop"
  ) |> 
  # Calculate unweighted population share %
  mutate(
    Population_Share_Pct = (Total_Population / sum(Total_Population)) * 100
  )

print(summary_3tier)

# Create a local 'data' or 'scratch' directory if it doesn't exist
dir.create("data/scratch", showWarnings = FALSE)

# Save Clean Spatial Layer & Summary Tables
st_write(providence_city_bg, "data/scratch/providence_census_3group_demographics.gpkg", delete_dsn = TRUE)
write_csv(summary_3tier, "data/scratch/census_3group_summary_tabulation.csv")