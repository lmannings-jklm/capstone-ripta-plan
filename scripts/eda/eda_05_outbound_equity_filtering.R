##########################################################
# Project: Harvard Data Science Capstone: Providence Transit Center
# Filename: eda_05_bidirectional_equity_filtering.R
# Purpose: Isolates both Inbound and Outbound AVL trips, extracts 
#          bi-directional R-Line shuttle penalties (deadline vs delay), 
#          calculates population-weighted socioeconomic vulnerability tiers, 
#          and generates visual EDA baselines.
# Author: Larry Mannings
# Date: 2026-11-09
# Inputs:
#   - data/ripta_avl_1yr_log.csv
#   - data/kp_route_summary.csv
#
# Outputs:
#   - data/ripta_bidirectional_filtered.csv
##########################################################

library(tidyverse)
library(lubridate)
library(sf)
library(tidytransit)
library(ggplot2)

options(scipen = 999)

# ==============================================================================
# PHASE 1: Load Data & Extract Bi-Directional R-Line Penalties
# ==============================================================================
cat("Loading raw AVL log and extracting bi-directional R-Line performance...\n")
avl_log <- read_csv("data/ripta_avl_1yr_log.csv")
route_summary <- read_csv("data/kp_route_summary.csv")
target_routes <- as.character(unique(route_summary$route_id))

r_line_avl <- avl_log |> 
  filter(RouteId == "11" | RouteId == 11)  |> 
  mutate(
    run_date = as.Date(IncidentDateTime),
    op_trip_id = paste(TripIdExternal, run_date, sep = "_"),
    ScheduleTime = as_datetime(ScheduleTime),
    IncidentDateTime = as_datetime(IncidentDateTime)
  )

# --- A. Northbound R-Line (Servicing Outbound Riders) ---
r_line_north_kepl <- r_line_avl  |> 
  filter(str_detect(tolower(DirectionDescription), "outbound|north"))  |> 
  filter(str_detect(tolower(BusStopLongNname), "kennedy plaza") | str_detect(tolower(TimePointShortName), "kepl"))  |> 
  select(op_trip_id, r_line_sch_kepl_north = ScheduleTime)  |> 
  group_by(op_trip_id)  |>  slice(1)  |>  ungroup()

r_line_north_psta <- r_line_avl  |> 
  filter(str_detect(tolower(DirectionDescription), "outbound|north"))  |> 
  filter(str_detect(tolower(BusStopLongNname), "providence station|park row west"))  |> 
  select(op_trip_id, r_line_act_psta_north = IncidentDateTime)  |> 
  group_by(op_trip_id)  |>  slice(1)  |>  ungroup()

# Retain the PRW-FS arrival time to serve as the deadline constraint in Phase 5
r_line_north <- inner_join(r_line_north_kepl, r_line_north_psta, by = "op_trip_id") %>%
  filter(!is.na(r_line_sch_kepl_north) & !is.na(r_line_act_psta_north) & r_line_act_psta_north > r_line_sch_kepl_north) %>%
  select(r_line_sch_kepl_north, r_line_act_psta_north) %>%
  arrange(r_line_act_psta_north)

# --- B. Southbound R-Line (Servicing Inbound Riders) ---
r_line_south_psta <- r_line_avl  |> 
  filter(str_detect(tolower(DirectionDescription), "inbound|south"))  |> 
  filter(str_detect(tolower(BusStopLongNname), "providence station|park row west"))  |> 
  select(op_trip_id, r_line_act_psta_south = IncidentDateTime)  |> 
  group_by(op_trip_id)  |>  slice(1)  |>  ungroup()

r_line_south_kepl <- r_line_avl  |> 
  filter(str_detect(tolower(DirectionDescription), "inbound|south"))  |> 
  filter(str_detect(tolower(BusStopLongNname), "kennedy plaza") | str_detect(tolower(TimePointShortName), "kepl"))  |> 
  select(op_trip_id, r_line_act_kepl_south = IncidentDateTime)  |> 
  group_by(op_trip_id)  |>  slice(1)  |>  ungroup()

r_line_south <- inner_join(r_line_south_psta, r_line_south_kepl, by = "op_trip_id")  |> 
  filter(!is.na(r_line_act_psta_south) & !is.na(r_line_act_kepl_south) & r_line_act_kepl_south > r_line_act_psta_south)  |> 
  select(r_line_act_psta_south, r_line_act_kepl_south)  |> 
  arrange(r_line_act_psta_south)

rm(r_line_avl, r_line_north_kepl, r_line_north_psta, r_line_south_psta, r_line_south_kepl)
gc()

# ==============================================================================
# PHASE 2: Isolate the Network & Classify Direction
# ==============================================================================
cat("Filtering target network for bi-directional trips...\n")
all_trips_raw <- avl_log  |> 
  mutate(
    run_date = as.Date(IncidentDateTime),
    op_trip_id = paste(TripIdExternal, run_date, sep = "_"),
    RouteId = as.character(RouteId),
    ScheduleTime = as_datetime(ScheduleTime),
    Actual_Arrival = as_datetime(IncidentDateTime),
    is_inbound = str_detect(tolower(DirectionDescription), "inbound|south")
  )  |> 
  filter(RouteId %in% target_routes & RouteId != "11")  |> 
  mutate(
    is_psta = str_detect(tolower(BusStopLongNname), "providence station|park row west"),
    is_kepl = str_detect(tolower(BusStopLongNname), "kennedy plaza")
  )  |> 
  filter(is_psta | is_kepl)

all_trips <- all_trips_raw  |> 
  arrange(op_trip_id, desc(is_psta))  |> 
  distinct(op_trip_id, .keep_all = TRUE)  |> 
  mutate(
    route_dir = paste(RouteId, DirectionDescription, sep = "_"),
    hour_of_day = hour(Actual_Arrival)
  )

hourly_weights <- all_trips  |> 
  group_by(hour_of_day)  |> 
  summarise(trip_count = n(), .groups = "drop")  |> 
  mutate(hourly_departure_weight = trip_count / sum(trip_count))

# ==============================================================================
# PHASE 3: Equity Demographics & Trip Weighting Reconstruction
# ==============================================================================
cat("Loading GTFS Shapes and Census Block Groups for demographic weighting...\n")
census_bg_sf <- st_read("data/scratch/providence_census_3group_demographics.gpkg", quiet = TRUE)  |> 
  st_transform(3438) 

gtfs <- read_gtfs("data/gtfs_raw_1yr/RIPTA-GTFS.zip")
route_shapes_sf <- shapes_as_sf(gtfs$shapes)  |> 
  st_transform(3438)  |> 
  inner_join(gtfs$trips  |>  distinct(shape_id, route_id), by = "shape_id")  |> 
  filter(route_id %in% unique(all_trips$RouteId))  |> 
  group_by(route_id)  |> 
  slice(1)  |> 
  ungroup()

cat("Executing Population-Weighted Spatial Intersections...\n")
route_equity_intersection <- st_intersection(route_shapes_sf, census_bg_sf)

route_equity_classification <- route_equity_intersection  |> 
  mutate(
    segment_length = as.numeric(st_length(geometry)),
    exposure_weight = segment_length * total_pop
  )  |> 
  st_drop_geometry()  |> 
  group_by(route_id, study_group)  |> 
  summarise(total_exposure = sum(exposure_weight, na.rm = TRUE), .groups = "drop")  |> 
  group_by(route_id)  |> 
  slice_max(total_exposure, n = 1, with_ties = FALSE)  |> 
  rename(dominant_equity_tier = study_group)  |> 
  select(route_id, dominant_equity_tier)

cat("Calculating Bi-Directional Empirical Trip Frequencies and Estimating Boardings...\n")
empirical_trips <- all_trips  |> 
  group_by(RouteId, DirectionDescription)  |> 
  summarise(
    annual_trips = n(),
    daily_trips = annual_trips / 365,
    .groups = "drop"
  )  |> 
  rename(route_id = RouteId)  |> 
  mutate(route_dir = paste(route_id, DirectionDescription, sep = "_"))

route_summary_df <- empirical_trips  |> 
  inner_join(route_equity_classification, by = "route_id")  |> 
  mutate(
    load_factor = case_when(
      dominant_equity_tier == "Transit-Dependent" ~ 75,
      dominant_equity_tier == "Mobility-Challenged" ~ 55,
      dominant_equity_tier == "Non-Vulnerable" ~ 35
    ),
    estimated_daily_ridership = daily_trips * load_factor,
    estimated_daily_hub_boardings = estimated_daily_ridership * 0.40
  )

equity_matrix <- route_summary_df  |> 
  inner_join(gtfs$routes  |>  select(route_id, route_short_name, route_long_name), by = "route_id")  |> 
  mutate(route_name = paste0(route_short_name, " - ", route_long_name, " (", DirectionDescription, ")"))  |> 
  arrange(desc(estimated_daily_hub_boardings))

# ==============================================================================
# PHASE 4: Generating EDA Visualizations
# ==============================================================================
cat("Generating EDA Visualizations...\n")

fig_hub_equity <- ggplot(equity_matrix  |>  slice_head(n = 15), 
       aes(x = reorder(route_name, estimated_daily_hub_boardings), 
           y = estimated_daily_hub_boardings, fill = dominant_equity_tier)) +
  geom_bar(stat = "identity", color = "black", alpha = 0.8) +
  coord_flip() +
  scale_fill_manual(values = c("Transit-Dependent" = "#d62728", 
                               "Mobility-Challenged" = "#ff7f0e", 
                               "Non-Vulnerable" = "#1f77b4")) +
  labs(title = "Estimated Daily Hub Boardings by Route (Direction)",
       subtitle = "Assumes 40% Hub Apportionment Ratio",
       x = "RIPTA Route (Direction)", y = "Estimated Daily Hub Boardings", fill = "Transit Equity Tier") +
  theme_minimal() + theme(legend.position = "bottom")

ggsave("data/scratch/fig_bidirectional_hub_equity.png", fig_hub_equity, width = 10, height = 6)

# ==============================================================================
# PHASE 5: Bi-Directional Temporal Intercepts & Export
# ==============================================================================
cat("Executing directional rolling R-Line joins...\n")

eq_mat_clean <- equity_matrix  |>  
  select(route_dir, route_name, dominant_equity_tier, estimated_daily_ridership)

# --- Outbound Logic (Deadline-Driven) ---
outbound_sim <- all_trips  |>  
  filter(is_inbound == FALSE)  |> 
  left_join(eq_mat_clean, by = "route_dir")  |> 
  left_join(hourly_weights, by = "hour_of_day")  |> 
  left_join(r_line_north, join_by(closest(Actual_Arrival >= r_line_act_psta_north)))  |> 
  mutate(
    shuttle_time_penalty = as.numeric(difftime(Actual_Arrival, r_line_sch_kepl_north, units = "mins")),
    shuttle_time_penalty = ifelse(is.na(shuttle_time_penalty) | shuttle_time_penalty > 60 | shuttle_time_penalty < 0, 15, shuttle_time_penalty)
  )

# --- Inbound Logic (Delay-Driven) ---
inbound_sim <- all_trips  |>  
  filter(is_inbound == TRUE)  |> 
  left_join(eq_mat_clean, by = "route_dir")  |> 
  left_join(hourly_weights, by = "hour_of_day")  |> 
  left_join(r_line_south, join_by(closest(Actual_Arrival <= r_line_act_psta_south)))  |> 
  mutate(
    shuttle_time_penalty = as.numeric(difftime(r_line_act_kepl_south, Actual_Arrival, units = "mins")),
    shuttle_time_penalty = ifelse(is.na(shuttle_time_penalty) | shuttle_time_penalty > 60 | shuttle_time_penalty < 0, 15, shuttle_time_penalty)
  )

# --- Combine and Export ---
bidirectional_data <- bind_rows(outbound_sim, inbound_sim)  |> 
  select(
    Route_ID = RouteId, 
    Route_Name = route_name,
    Direction = DirectionDescription,
    is_inbound,
    Equity_Tier = dominant_equity_tier,
    R_r = estimated_daily_ridership,
    W_t = hourly_departure_weight,
    Trip_ID = op_trip_id,
    Hour = hour_of_day,
    Scheduled_Time = ScheduleTime,    
    Actual_Arrival,
    shuttle_time_penalty
  )

write_csv(bidirectional_data, "data/ripta_bidirectional_filtered.csv")
cat("Success! Exported", nrow(bidirectional_data), "bi-directional observations.\n")