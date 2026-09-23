# ============================================================
# calculations.R - turning raw sets into numbers that mean something
# ============================================================
# Simple Sum-Up:
# One set on its own ("80 kg x 6") doesn't tell you much. These functions
# turn my sets into numbers I can compare over time:
#   - estimated 1RM: how much I could lift for ONE rep (Epley formula)
#   - best estimated 1RM per week: my strongest set of each week
#   - weekly volume: how much total work I did (kg x reps, added up)
# Everything here is plain base R, no extra packages.
# ============================================================

# >> Epley formula: turns any set into "what I could lift for 1 rep"
# >> it's like converting every currency to euros so you can compare them
estimate_1rm <- function(weight_kg, reps) {
  weight_kg * (1 + reps / 30)
}

# >> gives the Monday of the week a date is in (so sets can be grouped per week)
week_start <- function(dates) {
  weekday <- as.integer(format(dates, "%u"))  # >> %u = day of the week: 1 = Monday ... 7 = Sunday
  dates - (weekday - 1)                       # >> go back to that week's Monday
}

# >> keeps only the lifting sets (Upper/Lower) that have a weight and reps, drops cardio
strength_sets <- function(workouts) {
  keep <- workouts$category %in% c("Upper", "Lower") &
    !is.na(workouts$weight_kg) & !is.na(workouts$reps)
  workouts[keep, ]
}

# >> which set number comes next for this exercise on this day (1, 2, 3, ...)
next_set_number <- function(workouts, date, exercise) {
  sum(workouts$date == date & workouts$exercise == exercise, na.rm = TRUE) + 1
}

# >> my best estimated 1RM for one exercise, week by week
best_1rm_per_week <- function(workouts, exercise) {
  sets <- strength_sets(workouts)
  sets <- sets[sets$exercise == exercise, ]
  if (nrow(sets) == 0) {                                   # >> nothing logged yet -> empty table
    return(data.frame(week = as.Date(character(0)), best_1rm = numeric(0)))
  }
  sets$one_rm <- estimate_1rm(sets$weight_kg, sets$reps)   # >> 1RM for every single set
  sets$week <- format(week_start(sets$date))               # >> the week each set belongs to (as text)
  weekly <- aggregate(one_rm ~ week, data = sets, FUN = max) # >> keep the best set of each week
  data.frame(week = as.Date(weekly$week), best_1rm = round(weekly$one_rm, 1))
}

# >> total volume (kg x reps) per week, split into Upper and Lower
weekly_volume <- function(workouts) {
  sets <- strength_sets(workouts)
  if (nrow(sets) == 0) {
    return(data.frame(week = as.Date(character(0)), category = character(0), volume_kg = numeric(0)))
  }
  sets$volume_kg <- sets$weight_kg * sets$reps             # >> 1 row = 1 set, so its volume = kg x reps
  sets$week <- format(week_start(sets$date))
  weekly <- aggregate(volume_kg ~ week + category, data = sets, FUN = sum) # >> add up per week + category
  weekly$week <- as.Date(weekly$week)
  weekly
}

# >> turns a number into "+2.5 kg" / "-0.3 %" style text for the stat tiles
signed <- function(x, unit = "") {
  x <- round(x, 1)
  sign <- if (x > 0) "+" else ""                           # >> negative numbers already have their "-"
  trimws(paste0(sign, x, " ", unit))
}
