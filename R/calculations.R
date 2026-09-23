# ============================================================
# calculations.R - turning raw sets into numbers that mean something
# ============================================================
# Simple Sum-Up:
# One set on its own ("80 kg x 6") doesn't tell you much. These functions
# turn my sets into numbers I can compare over time:
#   - estimated 1RM: how much I could lift for ONE rep (Epley formula)
#   - best estimated 1RM per week: my strongest set of each week
#   - weekly volume: how much total work I did (kg x reps, added up)
#   - personal records (PRs): sets that beat everything before them
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

# >> the best-1RM-per-week tables of several lifts stacked together (for the multi-line chart)
strength_trends <- function(workouts, lifts) {
  parts <- lapply(lifts, function(lift) {
    weekly <- best_1rm_per_week(workouts, lift)
    if (nrow(weekly) == 0) return(NULL)                    # >> skip lifts with no sets
    weekly$exercise <- lift
    weekly
  })
  parts <- Filter(Negate(is.null), parts)                  # >> throw away the empty ones
  if (length(parts) == 0) {
    return(data.frame(week = as.Date(character(0)), best_1rm = numeric(0), exercise = character(0)))
  }
  do.call(rbind, parts)                                    # >> glue the tables under each other
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

# >> total volume (kg x reps) between two dates (both days included)
volume_between <- function(workouts, from, to) {
  lifts <- strength_sets(workouts)
  lifts <- lifts[lifts$date >= from & lifts$date <= to, ]
  sum(lifts$weight_kg * lifts$reps)
}

# >> the volume of my last earlier session in the same category (to compare today with)
previous_session_volume <- function(workouts, date, category) {
  lifts <- strength_sets(workouts)
  lifts <- lifts[lifts$category == category & lifts$date < date, ]
  if (nrow(lifts) == 0) return(NA)                         # >> no earlier session to compare with
  last_day <- lifts[lifts$date == max(lifts$date), ]
  sum(last_day$weight_kg * last_day$reps)
}

# >> TRUE for every set that beat all earlier sets of the same exercise = a personal record (PR)
mark_prs <- function(workouts) {
  is_pr <- rep(FALSE, nrow(workouts))
  lift_rows <- which(workouts$category %in% c("Upper", "Lower") &
                       !is.na(workouts$weight_kg) & !is.na(workouts$reps))
  if (length(lift_rows) == 0) return(is_pr)
  lift_rows <- lift_rows[order(workouts$date[lift_rows], workouts$set_no[lift_rows])] # >> oldest set first
  one_rm <- estimate_1rm(workouts$weight_kg[lift_rows], workouts$reps[lift_rows])
  exercise <- workouts$exercise[lift_rows]
  # >> for every set: the best 1RM of that exercise BEFORE this set (-Inf = there was nothing before)
  best_before <- ave(one_rm, exercise, FUN = function(x) c(-Inf, head(cummax(x), -1)))
  is_pr[lift_rows] <- one_rm > best_before & is.finite(best_before) # >> the very first set isn't a record yet
  is_pr
}

# >> my lifts, most-trained first (counted in sets)
lift_ranking <- function(workouts) {
  lifts <- strength_sets(workouts)
  if (nrow(lifts) == 0) return(character(0))
  counts <- table(lifts$exercise)                          # >> how many sets per exercise
  names(counts)[order(-as.vector(counts), names(counts))]  # >> most sets first, A-Z when it's a tie
}
