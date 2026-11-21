##########################################################
# Project: Harvard Data Science Capstone: Providence Transit Center
# Filename: eda_03_generate_acs_table.R
# Purpose: Programmatically query the U.S. Census Bureau API to download, 
#          cache, and interactively view the 2022 ACS 5-Year Data Dictionary. 
#          Used to identify specific demographic block codes (e.g., disability, 
#          income, vehicle access) for the equity analysis.
# Author: Larry Mannings
# Date: 2026-11-16
#
# Inputs: U.S. Census API via tidycensus
# Outputs: acs2022_vars (Interactive dataframe view in RStudio)
##########################################################

# ---------------------------------------------------------
# 1. Load Required R Libraries
# ---------------------------------------------------------
library(tidycensus)
library(tidyverse)

# Note: A Census API key is required to use tidycensus. 
# Ensure it is set in your environment using census_api_key("YOUR_API_KEY", install = TRUE) 
# if you haven't already configured it on your machine.

# ---------------------------------------------------------
# 2. Download and Cache the ACS Data Dictionary
# ---------------------------------------------------------
message("Downloading the 2022 ACS 5-Year Detailed Tables Data Dictionary...")

acs2022_vars <- load_variables(year = 2022, dataset = "acs5", cache = TRUE)

# ---------------------------------------------------------
# 3. View Interactively in RStudio
# ---------------------------------------------------------
message("Opening interactive viewer. Use the filter box to search for 'concept' or 'label' keywords.")

# This opens the spreadsheet-style viewer in RStudio so you can manually 
# search and identify exact table codes for your Quarto documentation.
View(acs2022_vars)