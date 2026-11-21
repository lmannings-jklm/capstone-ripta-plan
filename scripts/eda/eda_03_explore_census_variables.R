##########################################################
# Project: Harvard Data Science Capstone: Providence Transit Center
# Filename: eda_03_explore_census_variables.R
# Purpose: Download and cache the full ACS variable lookup table as an
# interactive data frame.
# Author: Larry Mannings
# Date: 2026-09-21
##########################################################

library(tidycensus)
library(tidyverse)
census_key <- Sys.getenv("CENSUS_API_KEY")

# 2. Configure Census API Key
# Sign up for a free key at: https://api.census.gov/data/key_signup.html
 census_api_key(census_key, install = TRUE)

# Download and cache the 2022 ACS 5-Year Detailed Tables dictionary
acs2022_vars <- load_variables(2022, "acs5", cache = TRUE)

# View interactively in RStudio
View(acs2022_vars)

# Filter for specific topics (e.g., disability, zero-vehicle households, income)
disability_vars <- acs2022_vars |>  
  filter(str_detect(concept, "DISABILITY") | str_detect(label, "disability"))
