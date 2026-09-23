# ============================================================
# storage.R - saving and loading my logs as CSV files
# ============================================================
# Simple Sum-Up:
# All my data lives in two CSV files (think: two Excel sheets).
#   workouts.csv -> one row for every set I do
#   body.csv     -> one row for every smart-scale reading
# These functions open a file, add a new row at the bottom and save it back.
# If a file doesn't exist yet (first time you run the app), you just get an
# empty table with the right columns, so the rest of the app never breaks.
# ============================================================

# >> every column of workouts.csv and what type it is (so R never guesses wrong)
workout_types <- c(
  date = "character",       # >> saved as text like "2026-09-23", turned into a real date when loading
  category = "character",   # >> "Upper", "Lower" or "Cardio"
  exercise = "character",   # >> e.g. "Bench press"
  set_no = "numeric",       # >> 1st, 2nd, 3rd... set of that exercise on that day
  weight_kg = "numeric",    # >> empty (NA) for cardio
  reps = "numeric",         # >> empty (NA) for cardio
  rpe = "numeric",          # >> optional: how hard it felt, 1-10
  duration_min = "numeric", # >> cardio only
  distance_km = "numeric"   # >> cardio only (optional)
)

# >> every column of body.csv (the 8 numbers from the smart scale + the date)
body_types <- c(
  date = "character",
  weight_kg = "numeric",
  bmi = "numeric",
  body_fat_pct = "numeric",
  muscle_kg = "numeric",
  protein_kg = "numeric",
  visceral_fat = "numeric",
  bone_kg = "numeric",
  water_pct = "numeric"
)

# >> opens one CSV file and gives it back as a table (data frame)
load_table <- function(path, types) {
  if (file.exists(path)) {
    table <- read.csv(path, colClasses = types)             # >> read the file with the right column types
  } else {
    header_only <- paste(names(types), collapse = ",")     # >> "date,category,exercise,..."
    table <- read.csv(text = header_only, colClasses = types) # >> an empty table with just the column names
  }
  table$date <- as.Date(table$date)                         # >> "2026-09-23" (text) -> real date
  table
}

# >> adds one new row to a CSV file: open it, stick the row at the bottom, save it back
add_row <- function(new_row, path, types) {
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE) # >> make the data/ folder if it's missing
  table <- load_table(path, types)                          # >> open the log (or get an empty one)
  table <- rbind(table, new_row[names(types)])              # >> put the new row at the bottom, columns in the right order
  write.csv(table, path, row.names = FALSE)                 # >> save the whole thing back
}

# >> small shortcuts so app.R stays readable
load_workouts <- function(data_dir) {
  load_table(file.path(data_dir, "workouts.csv"), workout_types)
}

load_body <- function(data_dir) {
  load_table(file.path(data_dir, "body.csv"), body_types)
}

save_workout_set <- function(new_set, data_dir) {
  add_row(new_set, file.path(data_dir, "workouts.csv"), workout_types)
}

save_body_reading <- function(reading, data_dir) {
  add_row(reading, file.path(data_dir, "body.csv"), body_types)
}
