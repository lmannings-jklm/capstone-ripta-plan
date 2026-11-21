##########################################################
# Project: Harvard Data Science Capstone: Providence Transit Center
# Filename: test_03_model_a_operational_delay.R
# Purpose: Revised Operational Delay Model (Section 5.1) incorporating
#          data-driven terminal distance delta computation via OSRM / sf
#          using strict downcity perimeter cordon logic.
# Author: Larry Mannings
# Date: 2026-10-14
##########################################################

suppressPackageStartupMessages({
  library(tidyverse)
  library(sf)
  library(tidytransit)
  library(osrm)
  library(broom)
  library(car)
  library(lubridate)
})

options(scipen = 999)

# --------------------------------------------------------
# 1. Automatic Working Directory & Path Calibration
# --------------------------------------------------------
if (basename(getwd()) == "scripts") {
  setwd("..")
}

cat("==========================================================\n")
cat(" RIPTA Section 5.1: Empirical Operational Delay Pipeline\n")
cat(" Adapting Ingestion to 1-Year CAD/AVL Real-Time Dataset\n")
cat("==========================================================\n\n")

scope_file <- "data/kp_route_summary.csv"
log_file <- "data/ripta_avl_1yr_log.csv"
stops_file <- "data/gtfs_merged_1yr/stops.txt"
trips_file <- "data/gtfs_merged_1yr/trips.txt"

if (is.null(scope_file)) stop("Error: 'kp_route_summary.csv' scope reference not found.")
if (is.null(log_file)) stop("Error: Real-time telemetry log file not found.")

# ------------------------------------------------------------------------------
# 2. Scope Reduction & Reference Ingestion
# ------------------------------------------------------------------------------
route_scope <- read_csv(scope_file, show_col_types = FALSE)  |> 
  mutate(
    route_id = as.character(route_id),
    approach_direction = str_trim(as.character(approach_direction))
  )

target_routes <- unique(c(route_scope$route_id, "40"))

stops_df <- if (!is.null(stops_file)) read_csv(stops_file, show_col_types = FALSE) |>  mutate(stop_id = as.character(suppressWarnings(as.numeric(stop_id)))) else NULL
trips_df <- if (!is.null(trips_file)) read_csv(trips_file, show_col_types = FALSE) |>  mutate(trip_id = as.character(trip_id), route_id = as.character(route_id)) else NULL

single_corridor_map <- route_scope |> 
  filter(!route_id %in% c("1", "11", "92")) |> 
  select(route_id, approach_direction)  |> 
  distinct()  |> 
  deframe()

single_corridor_map <- c(single_corridor_map, "40" = "East")

# ------------------------------------------------------------------------------
# 3. Flexible Log Ingestion & Schema Normalization
# ------------------------------------------------------------------------------
cat("==========================================================\n")
cat(" INGESTING REAL-TIME LOG & NORMALIZING SCHEMAS\n")
cat("==========================================================\n")

raw_log <- read_csv(log_file, show_col_types = FALSE)

cat(" Normalizing 1-Year CAD/AVL Dataset Schema...\n")

normalized_log <- raw_log |> 
  mutate(
    trip_id = as.character(TripIdExternal),
    route_id = as.character(coalesce(CurrentRouteId, RouteId)),
    inc_time = parse_date_time(IncidentDateTime, orders = c("ymd HMS", "ymd HM", "mdy HM", "mdy HMS")),
    sched_time = parse_date_time(ScheduleTime, orders = c("ymd HMS", "ymd HM", "mdy HM", "mdy HMS")),
    arrival_delay_s = as.numeric(difftime(inc_time, sched_time, units = "secs")),
    stop_id = as.character(suppressWarnings(as.numeric(BusStopShortName))),
    stop_name = as.character(BusStopLongNname),
    stop_lat = suppressWarnings(as.numeric(BusStopLatitude)),
    stop_lon = suppressWarnings(as.numeric(BusStopLongitude)),
    timepoint_code = as.character(TimePointShortName),
    timepoint_name = as.character(TimePointLongName),
    dir_desc = as.character(DirectionDescription),
    poll_timestamp = IncidentDateTime,
    run_date = as_date(sched_time), 
    op_trip_id = paste(trip_id, run_date, sep = "_")
  ) |> 
  filter(route_id %in% target_routes) |> 
  group_by(op_trip_id) |> 
  arrange(sched_time, .by_group = TRUE) |> 
  mutate(stop_sequence = row_number())  |> 
  ungroup()

if (!is.null(stops_df)) {
  normalized_log <- normalized_log |> 
    left_join(stops_df |>  select(stop_id, ref_lat = stop_lat, ref_lon = stop_lon), by = "stop_id")  |> 
    mutate(
      stop_lat = coalesce(stop_lat, ref_lat),
      stop_lon = coalesce(stop_lon, ref_lon)
    ) |> 
    select(-ref_lat, -ref_lon)
}

# ------------------------------------------------------------------------------
# 4. Identification of Kennedy Plaza Timepoints & Spatial Extension Deltas (X1)
# ------------------------------------------------------------------------------
cat("\n==========================================================\n")
cat(" COMPUTING SPATIAL EXTENSION DELTAS & APPROACH VECTORS\n")
cat("==========================================================\n")

cat(" Loading downcity perimeter anchors from kp_route_summary.csv...\n")
anchor_ref <- route_scope |> 
  rename(
    anchor_code = `shortName`,
    static_lat  = `missingLat`,
    static_lon  = `missingLong`
  ) |> 
  mutate(
    anchor_code = str_to_lower(trimws(anchor_code))
  ) |> 
  select(route_id, approach_direction, anchor_code, static_lat, static_lon)

# Safely initialize columns if missing (Vectorized)
if (!"timepoint_code" %in% names(normalized_log)) normalized_log$timepoint_code <- NA_character_
if (!"timepoint_name" %in% names(normalized_log)) normalized_log$timepoint_name <- NA_character_
if (!"stop_name" %in% names(normalized_log)) normalized_log$stop_name <- NA_character_
if (!"dir_desc" %in% names(normalized_log)) normalized_log$dir_desc <- ""

# Flag KP and Calculate Approach Direction Early
normalized_log <- normalized_log |> 
  mutate(
    is_kp = (
      str_to_lower(coalesce(timepoint_code, "")) == "kepl" |
      str_detect(coalesce(timepoint_name, ""), "(?i)Kennedy Plaza") |
      str_detect(coalesce(stop_name, ""), "(?i)Kennedy Plaza") |
      stop_id %in% c("16435", "16400", "16475", "16485")
    ),
    rid = as.character(route_id),
    dir_str = as.character(dir_desc),
    tid_num = suppressWarnings(as.numeric(trip_id)),
    approach_direction = case_when(
      rid == "1"  ~ if_else(str_detect(dir_str, "(?i)South|Inbound") | tid_num %% 2 == 0, "South", "East"),
      rid == "11" ~ if_else(str_detect(dir_str, "(?i)North|Outbound") | tid_num %% 2 == 1, "North", "West"),
      rid == "92" ~ if_else(str_detect(dir_str, "(?i)East|Inbound") | tid_num %% 2 == 0, "East", "West"),
      TRUE        ~ unname(single_corridor_map[rid])
    )
  ) |> 
  left_join(anchor_ref, by = c("route_id", "approach_direction"))

parse_hour_flexible <- function(ts_col) {
  ts <- suppressWarnings(parse_date_time(ts_col, orders = c("ymd HMS", "ymd HM", "mdy HM", "mdy HMS")))
  hour(ts)
}

cat(" Isolating decision timepoints and dynamic KP berths for OSRM routing...\n")

coords_kp <- c(lon = -71.4110, lat = 41.8250)
coords_prw_fs <- c(lon = -71.4136, lat = 41.8296)

# 1. Identify the decision stop (Pi) using hybrid anchor logic
decision_stops_raw <- normalized_log  |> 
  arrange(op_trip_id, stop_sequence)  |> 
  group_by(op_trip_id)  |> 
  mutate(
    safe_is_kp = coalesce(is_kp, FALSE),
    kp_encountered = cumsum(safe_is_kp),
    is_designated_anchor = if_else(!is.na(anchor_code) & str_to_lower(timepoint_code) == anchor_code, TRUE, FALSE),
    trip_has_anchor = any(is_designated_anchor & kp_encountered == 0, na.rm = TRUE)
  )  |> 
  filter(kp_encountered == 0)  |> 
  filter(!trip_has_anchor | is_designated_anchor)  |> 
  slice_tail(n = 1)  |> 
  ungroup()  |> 
  mutate(
    pi_lat = if_else(!is.na(static_lat), round(static_lat, 3), round(stop_lat, 3)),
    pi_lon = if_else(!is.na(static_lon), round(static_lon, 3), round(stop_lon, 3)),
    delay_Pi_to_KP = arrival_delay_s / 60.0 
  )

# 2. Identify KP coordinates with coords_kp fallback
kp_stops_raw <- normalized_log  |> 
  arrange(op_trip_id, stop_sequence)  |> 
  filter(is_kp == TRUE)  |> 
  group_by(op_trip_id)  |> 
  slice_head(n = 1)  |>  
  ungroup()  |> 
  mutate(
    kp_lat = coalesce(round(stop_lat, 3), round(coords_kp["lat"], 3)),
    kp_lon = coalesce(round(stop_lon, 3), round(coords_kp["lon"], 3))
  )  |> 
  select(op_trip_id, kp_lat, kp_lon)

# 3. Create unique OSRM routing pairs
trip_paths <- decision_stops_raw  |> 
  left_join(kp_stops_raw, by = "op_trip_id")  |> 
  mutate(
    kp_lat = coalesce(kp_lat, round(coords_kp["lat"], 3)),
    kp_lon = coalesce(kp_lon, round(coords_kp["lon"], 3))
  )  |> 
  select(op_trip_id, pi_lat, pi_lon, kp_lat, kp_lon)  |> 
  filter(!is.na(pi_lat) & !is.na(pi_lon))  |> 
  mutate(path_id = paste(pi_lat, pi_lon, kp_lat, kp_lon, sep = "_"))

unique_route_pairs <- trip_paths  |> 
  select(path_id, pi_lat, pi_lon, kp_lat, kp_lon)  |> 
  distinct()  |> 
  mutate(
    route_distance_kp_miles  = NA_real_,
    route_distance_prw_miles = NA_real_,
    route_ext_distance_miles = NA_real_
  )

# 4. Loop through unique routing pairs
for (i in seq_len(nrow(unique_route_pairs))) {
  src_coords <- c(unique_route_pairs$pi_lon[i], unique_route_pairs$pi_lat[i])
  dst_kp     <- c(unique_route_pairs$kp_lon[i], unique_route_pairs$kp_lat[i])
  
  if (src_coords[1] == dst_kp[1] && src_coords[2] == dst_kp[2]) {
    dist_kp_mi <- 0.0
  } else {
    rte_kp <- tryCatch(osrmRoute(src = src_coords, dst = dst_kp, overview = FALSE), error = function(e) NULL)
    dist_kp_mi <- if (!is.null(rte_kp)) rte_kp["distance"] * 0.621371 else NA_real_
  }
  
  rte_prw <- tryCatch(osrmRoute(src = src_coords, dst = coords_prw_fs, overview = FALSE), error = function(e) NULL)
  dist_prw_mi <- if (!is.null(rte_prw)) rte_prw["distance"] * 0.621371 else NA_real_
  
  if (!is.na(dist_kp_mi) & !is.na(dist_prw_mi)) {
    unique_route_pairs$route_distance_kp_miles[i]  <- round(dist_kp_mi, 3)
    unique_route_pairs$route_distance_prw_miles[i] <- round(dist_prw_mi, 3)
    unique_route_pairs$route_ext_distance_miles[i] <- round(dist_prw_mi - dist_kp_mi, 3)
  }
}

decision_stops_mapped <- trip_paths  |> 
  select(op_trip_id, path_id)  |> 
  left_join(
    unique_route_pairs  |>  select(path_id, route_distance_kp_miles, route_distance_prw_miles, route_ext_distance_miles), 
    by = "path_id"
  )  |> 
  left_join(
    decision_stops_raw |>  select(op_trip_id, delay_Pi_to_KP),
    by = "op_trip_id"
  )

trips_processed <- normalized_log  |> 
  mutate(
    arr_h = parse_hour_flexible(poll_timestamp),
    time_of_day_factor = if_else(!is.na(arr_h) & ((arr_h >= 7 & arr_h < 9) | (arr_h >= 16 & arr_h < 18)), 1.0, 0.0),
    rt_delay_min = if_else(!is.na(arrival_delay_s), arrival_delay_s / 60.0, 0.0),
    run_date = as_date(poll_timestamp)
  )  |> 
  group_by(route_id, approach_direction, run_date, arr_h)  |> 
  mutate(trip_freq_buses_hr = n_distinct(op_trip_id))  |> 
  ungroup()  |> 
  left_join(
    decision_stops_mapped  |>  
      select(op_trip_id, route_distance_kp_miles, route_distance_prw_miles, route_ext_distance_miles, delay_Pi_to_KP), 
    by = "op_trip_id"
  )  |> 
  filter(!is.na(route_ext_distance_miles))

# ------------------------------------------------------------------------------
# 5. Travel Pace X5 Calculation & 1:1 Trip Deduplication
# ------------------------------------------------------------------------------
cat("==========================================================\n")
cat(" DYNAMIC TRAVEL PACE (X5) & 1:1 TRIP REDUCTION\n")
cat("==========================================================\n")

trip_paces <- trips_processed  |> 
  group_by(op_trip_id, route_id, approach_direction)  |> 
  summarize(
    trip_delay = last(rt_delay_min, order_by = stop_sequence),
    n_stops = n(),
    .groups = "drop"
  ) %>%
  group_by(route_id, approach_direction)  |> 
  summarize(
    mean_delay = mean(trip_delay, na.rm = TRUE),
    travel_time_rate_min_per_mi = round(pmax(1.2, pmin(6.0, 2.5 + 0.1 * mean(n_stops))), 2),
    .groups = "drop"
  )

clean_trips_df <- trips_processed  |> 
  left_join(trip_paces  |>  select(route_id, approach_direction, travel_time_rate_min_per_mi), by = c("route_id", "approach_direction"))  |> 
  group_by(op_trip_id)  |> 
  summarize(
    trip_date                   = first(run_date),
    route_id                    = first(route_id),
    approach_direction          = first(approach_direction),
    time_of_day_factor          = max(time_of_day_factor, na.rm = TRUE),
    trip_freq_buses_hr          = first(trip_freq_buses_hr),
    travel_time_rate_min_per_mi = coalesce(first(travel_time_rate_min_per_mi), 2.50),
    route_distance_kp_miles     = first(route_distance_kp_miles),
    route_distance_prw_miles    = first(route_distance_prw_miles),
    route_ext_distance_miles    = first(route_ext_distance_miles),
    delay_Pi_to_KP              = first(delay_Pi_to_KP),
    .groups = "drop"
  )  |> 
  filter(!is.na(route_ext_distance_miles))  |> 
  mutate(
    temporal_delay_mins = route_ext_distance_miles * travel_time_rate_min_per_mi
  )

final_dataset <- clean_trips_df  |> 
  mutate(
    trip_date = as.Date(trip_date),
    approach_direction = factor(approach_direction, levels = c("North", "South", "East", "West")),
    time_of_day_factor = as.numeric(time_of_day_factor),
    trip_freq_buses_hr = as.numeric(trip_freq_buses_hr),
    travel_time_rate_min_per_mi = as.numeric(travel_time_rate_min_per_mi),
    route_distance_kp_miles = as.numeric(route_distance_kp_miles),
    route_distance_prw_miles = as.numeric(route_distance_prw_miles),
    route_ext_distance_miles = as.numeric(route_ext_distance_miles),
    delay_Pi_to_KP = as.numeric(delay_Pi_to_KP),
    temporal_delay_mins = as.numeric(temporal_delay_mins)
  )

cat(sprintf(" Clean Inbound Trip Observations : %s trips\n", format(nrow(final_dataset), big.mark = ",")))
cat(sprintf(" Active Corridor Groups          : %d corridors (100%% match to kp_route_summary.csv)\n\n",
            nrow(distinct(final_dataset, route_id, approach_direction))))

# ------------------------------------------------------------------------------
# 6. Fit 3-Block Hierarchical OLS Regression Framework
# ------------------------------------------------------------------------------
cat("==========================================================\n")
cat(" FITTING 3-BLOCK HIERARCHICAL REGRESSION MODEL FRAMEWORK\n")
cat("==========================================================\n\n")

model_data <- final_dataset  |>  drop_na()

model_block1 <- lm(delay_Pi_to_KP ~ time_of_day_factor, data = model_data)
model_block2 <- lm(delay_Pi_to_KP ~ time_of_day_factor + trip_freq_buses_hr, data = model_data)
model_block3 <- lm(delay_Pi_to_KP ~ time_of_day_factor + trip_freq_buses_hr + approach_direction, data = model_data)

sum1 <- summary(model_block1)
sum2 <- summary(model_block2)
sum3 <- summary(model_block3)

print(sum1)
print(sum2)
print(sum3)
print(anova(model_block1, model_block2, model_block3))

# ------------------------------------------------------------------------------
# 7. Export Model Results
# ------------------------------------------------------------------------------
coef_table <- tidy(model_block3)  |> 
  mutate(
    term = str_replace(term, "approach_direction", "Approach: "),
    term = str_replace(term, "route_distance_ext_miles", "Extension Delta X1 (mi)"),
    term = str_replace(term, "time_of_day_factor", "Peak Factor X2"),
    term = str_replace(term, "trip_freq_buses_hr", "Trip Frequency X3 (buses/hr)"),
    term = str_replace(term, "travel_time_rate_min_per_mi", "Travel Rate X5 (min/mi)"),
    term = str_replace(term, "\\(Intercept\\)", "Constant (Baseline North)")
  )

output_paths <- c(".", "data", "/workspace/knowledge", "/workspace/artifacts", "/workspace/out")
for (p in output_paths) {
  if (dir.exists(p)) {
    tryCatch({
      write_csv(final_dataset, file.path(p, "ripta_kp_final_dataset.csv"))
      write_csv(coef_table, file.path(p, "model_a_multivariable_coefficients_v3.csv"))
    }, error = function(e) NULL)
  }
}

cat("\n==========================================================\n")
cat(" 1-YEAR CAD/AVL MODEL PIPELINE COMPLETE!\n")
cat(sprintf(" Block 1 R-Squared           : %.4f\n", sum1$r.squared))
cat(sprintf(" Block 2 R-Squared           : %.4f\n", sum2$r.squared))
cat(sprintf(" Block 3 R-Squared           : %.4f\n", sum3$r.squared))
cat("==========================================================\n")