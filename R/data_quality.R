# ============================================================
# data_quality.R - checking my own logs for mistakes
# ============================================================
# Simple Sum-Up:
# Before I trust a chart, I want to know if the data behind it is OK.
# These functions look through my workouts.csv and point at things
# that look wrong or messy:
#   - empty cells (missing values) per column
#   - the same exercise written in different ways ("Abs curl" vs "abs curls")
#   - names typed in a different style (ALL CAPITALS or all small letters)
#   - weights that jump a lot from one session to the next (typo? other machine?)
#   - numbers that can't be real (0 reps, 900 kg, RPE 14)
#   - the same set saved twice
# They only POINT at problems - they never change or delete my data.
# Think of a spell checker: it underlines words, but I decide what to fix.
#
# Two of these helpers are also used while I log (see app.R):
#   - match_known_name(): "bench press" becomes "Bench press" if I logged that before
#   - jump_warning(): a heads-up when a weight is way off compared to last time
# So the same rules that FIND messy data later also STOP it at the door.
# ============================================================

# >> WHY 40%? Normal progress is a few kg per week (2-10%). A change of
# >> more than 40% between two sessions almost always means a typo, a
# >> different machine or dumbbells instead of a barbell - not real strength.
jump_limit <- 0.4

# >> how many empty cells (NA) every column has, as a count and a percentage
missing_values <- function(table) {
  counts <- colSums(is.na(table))                      # >> is.na() gives TRUE/FALSE, colSums counts the TRUEs per column
  data.frame(
    column  = names(counts),
    missing = as.integer(counts),
    percent = round(100 * as.integer(counts) / max(nrow(table), 1), 1), # >> max(..., 1): no dividing by 0 for an empty table
    row.names = NULL                                   # >> no extra row-number column
  )
}

# >> the "key" of a name: the version I use to compare names with each other
# >> "  Hex  Squats " -> "hex squat" (small letters, single spaces, no plural s at the end)
name_key <- function(names) {
  key <- tolower(trimws(names))                        # >> small letters, no spaces at the start/end
  key <- gsub("\\s+", " ", key)                        # >> "hex   squats" -> "hex squats" (\\s+ = one or more spaces)
  sub("s$", "", key)                                   # >> drop ONE "s" at the very end: "squats" -> "squat"
}

# >> exercises that I wrote in more than one way (same key, different spelling)
name_variants <- function(workouts) {
  spellings <- unique(workouts$exercise)               # >> every different spelling once
  if (length(spellings) == 0) {
    return(data.frame(key = character(0), spellings = character(0), count = integer(0)))
  }
  groups <- split(spellings, name_key(spellings))      # >> a list: key -> all the spellings with that key
  groups <- groups[lengths(groups) > 1]                # >> keep only keys with 2+ spellings (those are the problem)
  if (length(groups) == 0) {
    return(data.frame(key = character(0), spellings = character(0), count = integer(0)))
  }
  data.frame(
    key = names(groups),
    spellings = sapply(groups, paste, collapse = " / "), # >> "Abs curl / abs curls"
    count = lengths(groups),
    row.names = NULL
  )
}

# >> names written in a different style than the rest: "ABS" (all capitals) or "shoulders" (all small)
name_style_issues <- function(workouts) {
  names <- unique(workouts$exercise)
  has_letters <- grepl("[A-Za-z]", names)              # >> skip names without letters (can't be capitals or small)
  all_caps  <- has_letters & names == toupper(names) & nchar(names) > 1
  all_small <- has_letters & names == tolower(names)
  data.frame(
    exercise = names[all_caps | all_small],
    problem  = ifelse(all_caps, "all capitals", "all small letters")[all_caps | all_small],
    row.names = NULL
  )
}

# >> how far a weight is OUTSIDE the range of last session (as a fraction)
# >> 0 = inside the range = normal, -0.63 = 63% lighter than my lightest set last time
# >> WHY a range and not one number? My warm-up sets are lighter on purpose.
# >> A 30 kg warm-up is fine if last time I did 30 kg AND 65 kg.
range_change <- function(weight_kg, last_weights) {
  low  <- min(last_weights)                            # >> lightest set last session
  high <- max(last_weights)                            # >> heaviest set last session
  if (low <= 0 || high <= 0) return(0)                 # >> body-weight sets logged as 0 kg: can't compare, so call it normal
  if (weight_kg < low)  return((weight_kg - low) / low)   # >> below the range: negative change
  if (weight_kg > high) return((weight_kg - high) / high) # >> above the range: positive change
  0                                                    # >> inside the range
}

# >> every session where the heaviest set of an exercise is far outside the previous session's range
weight_jumps <- function(workouts, limit = jump_limit) {
  sets <- strength_sets(workouts)                      # >> only lifting sets with weight + reps (from calculations.R)
  rows <- list()                                       # >> I collect the problems here, one small table each
  for (lift in unique(sets$exercise)) {
    mine <- sets[sets$exercise == lift, ]
    days <- sort(unique(mine$date))                    # >> every session of this lift, oldest first
    if (length(days) < 2) next                         # >> need at least 2 sessions to compare (next = skip to the next lift)
    for (i in 2:length(days)) {
      before <- mine$weight_kg[mine$date == days[i - 1]] # >> all weights of the session before
      top    <- max(mine$weight_kg[mine$date == days[i]]) # >> heaviest set of this session
      change <- range_change(top, before)
      if (abs(change) > limit) {
        rows[[length(rows) + 1]] <- data.frame(
          exercise = lift,
          from_date = days[i - 1], to_date = days[i],
          from_kg = max(before), to_kg = top,
          change_pct = round(100 * change)
        )
      }
    }
  }
  if (length(rows) == 0) {
    return(data.frame(exercise = character(0), from_date = as.Date(character(0)), to_date = as.Date(character(0)),
                      from_kg = numeric(0), to_kg = numeric(0), change_pct = numeric(0)))
  }
  do.call(rbind, rows)                                 # >> glue the small tables under each other
}

# >> rows with numbers that can't be real, with the reason why
impossible_values <- function(workouts) {
  reason <- rep("", nrow(workouts))                    # >> start with "no problem" for every row
  # >> each rule adds its reason to the rows it catches (%in% TRUE also handles NA safely)
  reason[(workouts$reps < 1 | workouts$reps > 50) %in% TRUE]          <- "reps not between 1 and 50"
  reason[(workouts$weight_kg < 0 | workouts$weight_kg > 400) %in% TRUE] <- "weight not between 0 and 400 kg"
  reason[(workouts$rpe < 1 | workouts$rpe > 10) %in% TRUE]            <- "RPE not between 1 and 10"
  reason[(workouts$duration_min <= 0 | workouts$duration_min > 300) %in% TRUE] <- "minutes not between 1 and 300"
  problems <- workouts[reason != "", ]
  problems$reason <- reason[reason != ""]
  problems
}

# >> sets that were saved twice: same date + exercise + set number more than once
duplicate_sets <- function(workouts) {
  id <- paste(workouts$date, workouts$exercise, workouts$set_no) # >> one "ID" text per set
  workouts[duplicated(id) | duplicated(id, fromLast = TRUE), ]  # >> both copies, not only the second one
}

# >> one overview table: every check, how many rows it found, and OK / Check
quality_report <- function(workouts) {
  lifting <- workouts$category %in% c("Upper", "Lower")
  checks <- data.frame(
    check = c("Lifting sets without weight or reps",
              "Exercise written in 2+ ways",
              "Name in another style (CAPS / small)",
              "Weight jump > 40% between sessions",
              "Impossible values",
              "Set saved twice",
              "Sets without RPE (optional field)"),
    found = c(sum(lifting & (is.na(workouts$weight_kg) | is.na(workouts$reps))),
              nrow(name_variants(workouts)),
              nrow(name_style_issues(workouts)),
              nrow(weight_jumps(workouts)),
              nrow(impossible_values(workouts)),
              nrow(duplicate_sets(workouts)),
              sum(lifting & is.na(workouts$rpe)))
  )
  checks$status <- ifelse(checks$found == 0, "OK", "Check")
  checks$status[grepl("optional", checks$check)] <- "Info"  # >> RPE is optional, so an empty RPE is not an error
  checks
}

# ---- Used while logging (app.R) -------------------------------------------------

# >> if I type a name that I already used (only capitals/spaces/plural differ), use the old spelling
# >> "bench press" -> "Bench press", "calf raises" -> "Calf raise"
match_known_name <- function(typed, known) {
  typed <- gsub("\\s+", " ", trimws(typed))            # >> tidy the spaces first
  same <- known[name_key(known) == name_key(typed)]    # >> earlier names with the same key
  if (length(same) > 0) same[1] else typed             # >> first match wins, otherwise keep what I typed
}

# >> a warning text when a new weight is far outside my last session of that exercise, otherwise NULL
jump_warning <- function(workouts, exercise, weight_kg, date, limit = jump_limit) {
  if (is.na(weight_kg)) return(NULL)                   # >> cardio or empty: nothing to check
  earlier <- workouts[workouts$exercise == exercise & workouts$date < date & !is.na(workouts$weight_kg), ]
  if (nrow(earlier) == 0) return(NULL)                 # >> first time I log this lift: nothing to compare with
  last_day <- max(earlier$date)                        # >> my last session of this lift before today
  last_weights <- earlier$weight_kg[earlier$date == last_day]
  change <- range_change(weight_kg, last_weights)
  if (abs(change) <= limit) return(NULL)               # >> normal change: stay quiet
  direction <- if (change < 0) "less" else "more"
  # >> "70 kg" when all sets were the same weight, "30-65 kg" when they were different
  last_text <- if (min(last_weights) == max(last_weights)) {
    paste(max(last_weights), "kg")
  } else {
    paste0(min(last_weights), "-", max(last_weights), " kg")
  }
  paste0("Check this set: ", weight_kg, " kg is ", round(abs(change) * 100), "% ", direction,
         " than your last ", exercise, " (", last_text, " on ", short_day(last_day), "). ",
         "A typo? Or other equipment? Then give it its own name, like \"", exercise, " (dumbbells)\".")
}
