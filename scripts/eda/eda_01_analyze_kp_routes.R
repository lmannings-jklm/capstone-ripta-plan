##########################################################
# Project: Harvard Data Science Capstone: Providence Transit Center Relocation
# Filename: eda_01_analyze_kp_route.R
# Purpose: Filter and analyze RIPTA GTFS transit data to extract trips
# within a specific time window (08:00 to 18:00) that serve Kennedy Plaza
# (inbound radial and cross-town through-routes), eliminate outbound
# runs originating at Providence Station, and retain frequent routes (<= 30 min).
# 
# Author: Larry Mannings
# Date: 2026-09-15
# 
# Source: https://ripta.com/RIPTA-GTFS.zip
# Inputs: trips.txt, stop_times.txt, stops.txt, routes.txt
# Outputs: filtered_trips(data_frame), route_kp_frequency(data_frame)
##########################################################

library(tidyverse)

# ---------------------------------------------------------
# 1. Load GTFS tables & Helpers
# ---------------------------------------------------------
trips <- read_csv("data/GTFS/trips.txt", col_types = cols(.default = "c"))
stop_times <- read_csv("data/GTFS/stop_times.txt", col_types = cols(.default = "c")) |>
  mutate(stop_sequence = as.numeric(stop_sequence))
stops <- read_csv("data/GTFS/stops.txt", col_types = cols(.default = "c"))
routes <- read_csv("data/GTFS/routes.txt", col_types = cols(.default = "c"))

# Convert GTFS HH:MM:SS string to seconds past midnight
to_seconds <- function(time_str) {
  parts <- strsplit(time_str, ":")
  sapply(parts, function(x) {
    x <- as.numeric(x)
    x[1] * 3600 + x[2] * 60 + x[3]
  })
}

# ---------------------------------------------------------
# 2. Identify Stop IDs for Kennedy Plaza, RI Hospital, and Providence Station
# ---------------------------------------------------------
kp_stop_ids <- stops |>
  filter(stop_associated_place == "kepl") |>
  pull(stop_id) |>
  unique()

psta_stop_ids <- stops |>
  filter(stop_associated_place == "psta") |>
  pull(stop_id) |>
  unique()

rihos_stop_ids <- stops |> 
    filter(stop_associated_place == "riho") |> 
    pull(stop_id) |> 
    unique()

kp_stop_events <- stop_times |>
  filter(stop_id %in% kp_stop_ids)

kp_trip_ids <- unique(kp_stop_events$trip_id)

# ---------------------------------------------------------
# 3. Identify & Exclude PSTA or RIHO -> KP Outbound Trips, Then Get Endpoints
# ---------------------------------------------------------
psta_riho_to_kp_trips <- stop_times |>
  filter(trip_id %in% kp_trip_ids) |>
  group_by(trip_id) |>
  summarize(
    first_stop  = stop_id[order(stop_sequence)[1]],
    second_stop = stop_id[order(stop_sequence)[2]],
    riho_seq    = suppressWarnings(min(stop_sequence[stop_id %in% rihos_stop_ids], na.rm = TRUE)),
    kp_seq      = suppressWarnings(min(stop_sequence[stop_id %in% kp_stop_ids], na.rm = TRUE)),
    .groups     = "drop"
  ) |>
  filter(
    # 1. PSTA -> KP adjacent check (Routes 3 & 4)
    (first_stop %in% psta_stop_ids & second_stop %in% kp_stop_ids) |
    # 2. RI Hospital visited before Kennedy Plaza (Routes 51, 54, 72)
    (!is.infinite(riho_seq) & !is.infinite(kp_seq) & riho_seq < kp_seq)
  ) |>
  pull(trip_id)

trip_endpoints <- stop_times |>
  filter(trip_id %in% kp_trip_ids) |>
  group_by(trip_id) |>
  summarize(
    start_time  = departure_time[which.min(stop_sequence)],
    end_time    = arrival_time[which.max(stop_sequence)],
    origin_stop = stop_id[which.min(stop_sequence)],
    dest_stop   = stop_id[which.max(stop_sequence)],
    .groups     = "drop"
  ) |>
  filter(
    !(origin_stop %in% kp_stop_ids) &
    !(trip_id %in% psta_riho_to_kp_trips)
  )

# Combine with route metadata and stop names
filtered_trips <- trips |>
  select(route_id, trip_id, direction_id) |>
  inner_join(trip_endpoints, by = "trip_id") |>
  left_join(routes |> select(route_id, route_long_name), by = "route_id") |>
  left_join(stops |> select(stop_id, origin_name = stop_name), by = c("origin_stop" = "stop_id")) |>
  left_join(stops |> select(stop_id, dest_name = stop_name), by = c("dest_stop" = "stop_id")) |>
  arrange(as.numeric(route_id), direction_id, start_time)

# ---------------------------------------------------------
# 4. Calculate Route Arrival Frequencies at Kennedy Plaza
#    (Restricted strictly to arrivals between 08:00 and 18:00)
# ---------------------------------------------------------
t_start_limit <- to_seconds("08:00:00")
t_end_limit   <- to_seconds("18:00:00")

kp_arrivals <- kp_stop_events |>
  filter(trip_id %in% filtered_trips$trip_id) |>
  inner_join(
    filtered_trips |> select(trip_id, route_id, route_long_name, direction_id),
    by = "trip_id"
  ) |>
  mutate(arr_sec = to_seconds(arrival_time)) |>
  # 1. Filter explicitly for Kennedy Plaza arrivals occurring between 08:00 and 18:00
  filter(arr_sec >= t_start_limit & arr_sec <= t_end_limit) |>
  # 2. Pick earliest KP berth event if a bus calls at multiple KP stops on the same trip
  group_by(trip_id) |>
  slice_min(arr_sec, n = 1, with_ties = FALSE) |>
  ungroup() |>
  arrange(as.numeric(route_id), direction_id, arr_sec)

route_kp_frequency <- kp_arrivals |>
  group_by(route_id, route_long_name, direction_id) |>
  mutate(headway_min = (arr_sec - lag(arr_sec)) / 60) |>
  summarize(
    total_arrivals = n(),
    first_arrival  = arrival_time[which.min(arr_sec)],
    last_arrival   = arrival_time[which.max(arr_sec)],
    trip_hdwy      = if(n() > 1) round(mean(headway_min, na.rm = TRUE), 1) else NA_real_,
    trip_freq      = 60 / trip_hdwy,
    .groups        = "drop"
  ) |>
  filter(!is.na(trip_hdwy) & trip_hdwy <= 30) |>
  arrange(as.numeric(route_id), direction_id)

# ---------------------------------------------------------
# 5. Assign Cardinal Approach Direction to Kennedy Plaza
# ---------------------------------------------------------
approach_lookup <- tribble(
  ~route_id, ~direction_id, ~approach_direction,
  "1",       "0",           "East",
  "1",       "1",           "South",
  "3",       "0",           "South",
  "4",       "0",           "South",
  "6",       "0",           "South",
  "11",      "0",           "East",
  "11",      "1",           "West",
  "14",      "0",           "South",
  "17",      "0",           "West",
  "19",      "0",           "West",
  "20",      "0",           "South",
  "21",      "0",           "North",
  "22",      "0",           "South",
  "27",      "0",           "West",
  "28",      "0",           "West",
  "30",      "0",           "West",
  "31",      "0",           "North",
  "32",      "0",           "East",
  "33",      "0",           "East",
  "34",      "0",           "East",
  "35",      "0",           "East",
  "40",      "0",           "East",
  "50",      "0",           "North",
  "51",      "0",           "North",
  "51",      "1",           "South",
  "54",      "0",           "North",
  "54",      "1",           "South",
  "55",      "0",           "North",
  "56",      "0",           "North",
  "57",      "0",           "North",
  "58",      "0",           "North",
  "60",      "0",           "East",
  "66",      "0",           "North",
  "72",      "0",           "North",
  "72",      "1",           "South",
  "78",      "0",           "East",
  "92",      "0",           "East",
  "92",      "1",           "West"
)

route_kp_frequency <- route_kp_frequency |>
  left_join(approach_lookup, by = c("route_id", "direction_id")) |>
  relocate(approach_direction, .after = direction_id) |> 
  select(-direction_id)

#------------------------------------------------------------------------------
# 5a. Compute the ratio of routes that are deemed high-frequency
#------------------------------------------------------------------------------
# Compute number of KP Outbound lines

# Recompute trip endpoints
  kp_outbound_endpoints <- stop_times |>
  filter(trip_id %in% kp_trip_ids) |>
  group_by(trip_id) |>
  summarize(
    start_time  = departure_time[which.min(stop_sequence)],
    end_time    = arrival_time[which.max(stop_sequence)],
    origin_stop = stop_id[which.min(stop_sequence)],
    dest_stop   = stop_id[which.max(stop_sequence)],
    .groups     = "drop"
  ) |>
  filter(!(origin_stop %in% kp_stop_ids)) 

# Combine with route metadata and stop names
kp_outbound_tot <- trips |>
  select(route_id, trip_id, direction_id) |>
  inner_join(kp_outbound_endpoints, by = "trip_id") |>
  left_join(routes |> select(route_id, route_long_name), by = "route_id") |>
  left_join(stops |> select(stop_id, origin_name = stop_name), by = c("origin_stop" = "stop_id")) |>
  left_join(stops |> select(stop_id, dest_name = stop_name), by = c("dest_stop" = "stop_id")) |>
  arrange(as.numeric(route_id), direction_id, start_time) |> 
    distinct(route_id, direction_id) |> 
    summarize(n())

# Create a local 'data' or 'scratch' directory if it doesn't exist
dir.create("data/scratch", showWarnings = FALSE)

# Save Clean Spatial Layer & Summary Tables
write_csv(route_kp_frequency, "data/scratch/route_kp_frequency.csv")
