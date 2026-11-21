library(readxl)
library(readr)

input_file <- "data/AVL_Incident_Log_20251001_20260930.xlsx"
output_file <- "ripta_avl_1yr_log.csv"

# Extract the names of all 5 tabs without loading the data
sheet_names <- excel_sheets(input_file)

for (i in seq_along(sheet_names)) {
  message(sprintf("Processing sheet %d of %d: %s", i, length(sheet_names), sheet_names[i]))
  
  # Read only the current sheet into memory
  current_sheet <- read_excel(input_file, sheet = sheet_names[i])
  
  # Write to CSV
  if (i == 1) {
    # For the first sheet, create the file and include column headers
    write_csv(current_sheet, output_file, append = FALSE)
  } else {
    # For subsequent sheets, append data to the bottom (readr automatically skips headers when appending)
    write_csv(current_sheet, output_file, append = TRUE)
  }
  
  # Delete the object and trigger R's garbage collector to free up RAM
  rm(current_sheet)
  gc()
}

message("Successfully spliced all sheets into ", output_file)