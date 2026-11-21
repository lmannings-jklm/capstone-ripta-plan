route_summary_30 <- final_dataset |> 
  group_by(route_id, approach_direction) |> 
  summarize(
    total_arrivals           = n(), 
    avg_trip_freq            = mean(trip_freq_buses_hr, na.rm = TRUE),
    trp_hwy_min              = if_else(avg_trip_freq > 0, 60 / avg_trip_freq, NA_real_),
    time_of_day_factor       = mean(time_of_day_factor, na.rm = TRUE),
    avg_travel_rate          = mean(travel_time_rate_min_per_mi, na.rm = TRUE),
    route_ext_distance_miles = mean(route_ext_distance_miles, na.rm = TRUE),
    delay_Pi_to_KP           = mean(delay_Pi_to_KP, na.rm = TRUE),
    .groups                  = "drop"
  )

# Export model block data to file

saveRDS(model_block1, file = "data/model_block1.rds")
saveRDS(model_block2, file = "data/model_block2.rds")
saveRDS(model_block3, file = "data/model_block3.rds")

