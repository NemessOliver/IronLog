# ============================================================
# run_tests.R - automatic checks for my helper functions
# ============================================================
# Simple Sum-Up:
# A test = "I give a function an input where I KNOW the right answer,
# and check that the function gives exactly that answer."
# If I change something later and break a function by accident,
# a test fails and tells me which one - before I trust a wrong chart.
# It's like checking a calculator with 2 + 2 before an exam.
#
# Run it from the IronLog folder, in the terminal:
#   Rscript tests/run_tests.R
# All checks use plain R (no extra test package needed) and made-up
# data - never my real log. The account tests need the sodium package,
# which the app needs anyway.
# ============================================================

# >> load every helper file from the R/ folder (the same files the app uses)
for (file in list.files("R", pattern = "\\.R$", full.names = TRUE)) source(file)

passed <- 0   # >> how many checks passed so far

# >> one check: compare what a function gave (actual) with the right answer (expected)
check <- function(what, actual, expected) {
  if (isTRUE(all.equal(actual, expected))) {           # >> all.equal = "the same" (with a tiny tolerance for decimals)
    passed <<- passed + 1                              # >> <<- changes the counter OUTSIDE this function
  } else {
    # >> stop() halts the whole script and prints what broke
    stop("FAILED: ", what,
         "\n  expected: ", paste(format(expected), collapse = ", "),
         "\n  got:      ", paste(format(actual), collapse = ", "), call. = FALSE)
  }
}

# >> makes a few made-up sets of one exercise on one day (same columns as workouts.csv)
fake_sets <- function(date, exercise, weights, reps = 8, category = "Upper") {
  data.frame(date = as.Date(date), category = category, exercise = exercise,
             set_no = seq_along(weights), weight_kg = weights, reps = reps,
             rpe = NA_real_, duration_min = NA_real_, distance_km = NA_real_)
}

# >> a small made-up log with the kind of mess I found in my real data
log <- rbind(
  fake_sets("2026-09-28", "Bench press", c(80, 80, 80)),
  fake_sets("2026-09-28", "Incline bench press", c(70, 70)),
  fake_sets("2026-10-01", "Bench press", c(85, 90)),
  fake_sets("2026-10-01", "Incline bench press", c(26, 26)),                # >> 63% lighter: dumbbells under the barbell name
  fake_sets("2026-10-01", "ABS", 20, reps = 25),                            # >> name in capitals
  fake_sets("2026-10-02", "Leg extension", c(30, 30, 65), reps = 10, category = "Lower"),
  fake_sets("2026-10-05", "Leg extension", c(30, 65), reps = 10, category = "Lower"), # >> 30 kg warm-up = normal
  fake_sets("2026-10-05", "leg extensions", 65, reps = 10, category = "Lower")        # >> same exercise, other spelling
)

# ---- calculations.R --------------------------------------------------------------

check("Epley 1RM of 100 kg x 10", round(estimate_1rm(100, 10), 1), 133.3)
check("Epley 1RM of 80 kg x 1", round(estimate_1rm(80, 1), 2), 82.67)
check("a Wednesday belongs to the week of Monday 28 Sep", week_start(as.Date("2026-09-30")), as.Date("2026-09-28"))
check("a Sunday belongs to the Monday BEFORE it", week_start(as.Date("2026-10-04")), as.Date("2026-09-28"))
check("a Monday stays the same day", week_start(as.Date("2026-09-28")), as.Date("2026-09-28"))

cardio <- data.frame(date = as.Date("2026-10-03"), category = "Cardio", exercise = "Running", set_no = 1,
                     weight_kg = NA, reps = NA, rpe = NA, duration_min = 30, distance_km = 5)
check("strength_sets() drops cardio rows", nrow(strength_sets(rbind(log, cardio))), nrow(log))

volume <- weekly_volume(log)
upper_week1 <- volume$volume_kg[volume$category == "Upper" & volume$week == as.Date("2026-09-28")]
lower_week2 <- volume$volume_kg[volume$category == "Lower" & volume$week == as.Date("2026-10-05")]
check("weekly volume Upper, week of 28 Sep (kg x reps added up)", upper_week1, 1920 + 1120 + 1400 + 416 + 500)
check("weekly volume Lower, week of 5 Oct", lower_week2, 950 + 650)

bench <- best_1rm_per_week(log, "Bench press")
check("best bench 1RM of the week = the 90 kg x 8 set", bench$best_1rm, 114)
check("3 personal records in the made-up log", sum(mark_prs(log)), 3)
check("most-trained lifts first (most sets), A-Z when tied", head(lift_ranking(log), 3),
      c("Bench press", "Leg extension", "Incline bench press"))

# ---- summaries.R -----------------------------------------------------------------

check("training days per week (last 2 weeks)",
      training_days_per_week(log, as.Date("2026-10-06"), weeks = 2)$days, c(3, 1))
check("goal streak with a goal of 3 days", goal_streak(log, as.Date("2026-10-06"), goal = 3), 1)

# ---- format.R --------------------------------------------------------------------

check("short date", short_date(as.Date("2026-09-23")), "23 Sep")
check("big volume as 18.2k", format_volume(18240), "18.2k")
check("normal volume with a comma", format_volume(6240), "6,240")
check("plus sign in front of a gain", signed(2.46, "kg"), "+2.5 kg")

# ---- data_quality.R --------------------------------------------------------------

check("name key: small letters, single spaces, no plural s", name_key("  Hex  Squats "), "hex squat")
variants <- name_variants(log)
check("one exercise is written in 2 ways", nrow(variants), 1)
check("... and it's the leg extension", variants$spellings, "Leg extension / leg extensions")
style <- name_style_issues(log)
check("2 names in another style", sort(style$exercise), c("ABS", "leg extensions"))

check("26 kg after a 70 kg session = 63% less", round(range_change(26, c(70, 70)), 2), -0.63)
check("a 30 kg warm-up after a 30-65 kg session is normal", range_change(30, c(30, 65)), 0)
check("90 kg after 80 kg = 12.5% more", range_change(90, c(80, 80)), 0.125)
check("body-weight sets (0 kg) are never called a jump", range_change(10, c(0, 0)), 0)

jumps <- weight_jumps(log)
check("only the incline bench jump is flagged", jumps$exercise, "Incline bench press")
check("... with a change of -63%", jumps$change_pct, -63)

bad <- rbind(log, fake_sets("2026-10-06", "Squat", 900, reps = 0, category = "Lower"))
check("900 kg x 0 reps is impossible", nrow(impossible_values(bad)), 1)
check("the clean log has no impossible values", nrow(impossible_values(log)), 0)
check("a set saved twice shows up (both copies)", nrow(duplicate_sets(rbind(log, log[1, ]))), 2)
check("no duplicates in the clean log", nrow(duplicate_sets(log)), 0)

missing <- missing_values(log)
check("RPE is empty in every made-up set", missing$percent[missing$column == "rpe"], 100)
check("weight is never empty", missing$missing[missing$column == "weight_kg"], 0)

report <- quality_report(log)
check("quality report: the right status for each check", report$status,
      c("OK", "Check", "Check", "Check", "OK", "OK", "Info"))

check("'bench press' is saved as the known 'Bench press'",
      match_known_name("bench press", c("Bench press", "Squat")), "Bench press")
check("'  calf   raises ' matches the starter 'Calf raise'",
      match_known_name("  calf   raises ", starter_exercises$Lower), "Calf raise")
check("a brand-new name stays as typed", match_known_name("Cable row", c("Bench press")), "Cable row")

warning_text <- jump_warning(log, "Incline bench press", 26, as.Date("2026-09-30"))
check("a 63% drop gives a warning", grepl("63% less", warning_text), TRUE)
check("a normal warm-up gives no warning", is.null(jump_warning(log, "Leg extension", 30, as.Date("2026-10-09"))), TRUE)
check("a first-ever lift gives no warning", is.null(jump_warning(log, "Squat", 100, as.Date("2026-10-09"))), TRUE)
check("no weight (cardio) gives no warning", is.null(jump_warning(log, "Bench press", NA, as.Date("2026-10-09"))), TRUE)

# ---- storage.R: save a set, load it back ------------------------------------------

folder <- file.path(tempdir(), "ironlog_test_user")    # >> a throw-away folder, deleted when R closes
unlink(folder, recursive = TRUE)                       # >> start empty, also when the tests run twice
save_workout_set(log[1:2, ], folder)
loaded <- load_workouts(folder)
check("2 saved sets come back", nrow(loaded), 2)
check("dates come back as real dates", class(loaded$date), "Date")

save_workout_set(log[log$exercise == "Incline bench press", ], folder)  # >> 2 sets on 28 Sep (70 kg) + 2 on 1 Oct (26 kg)
changed <- suppressMessages(rename_exercise(folder, "Incline bench press", "Incline dumbbell press", on_date = "2026-10-01"))
renamed <- load_workouts(folder)
check("rename on one day changes only that day's 2 sets", changed, 2)
check("... the 28 Sep sets keep the old name", sum(renamed$exercise == "Incline bench press"), 2)
check("... and a backup file was made", length(list.files(folder, pattern = "^workouts_backup_")), 1)
check("renaming a name that isn't there changes nothing", suppressMessages(rename_exercise(folder, "Nope", "X")), 0)

# ---- accounts.R (needs the sodium package) -------------------------------------------

no_accounts <- load_accounts(tempfile())               # >> a file that doesn't exist = nobody signed up yet
check("username too short", signup_problem("ab", "Test", "password1", "password1", 4, no_accounts),
      "Username: 3-20 characters, only letters, numbers and . _ -")
check("a folder trick like ../x is not a valid username",
      is.null(signup_problem("../x", "Test", "password1", "password1", 4, no_accounts)), FALSE)
check("a correct sign-up has no problem",
      is.null(signup_problem("tester", "Test", "password1", "password1", 4, no_accounts)), TRUE)

accounts <- tempfile(fileext = ".csv")
invisible(create_account("tester", "Test Person", "secret-password", 4, file = accounts))   # >> invisible = don't print it
invisible(create_account("tester2", "Other Person", "secret-password", 3, file = accounts))
check("right password logs in", check_login("Tester ", "secret-password", file = accounts)$username, "tester")
check("wrong password does not", is.null(check_login("tester", "wrong-password", file = accounts)), TRUE)
check("the password itself is never in the file", any(grepl("secret-password", readLines(accounts))), FALSE)
saved <- load_accounts(accounts)
check("same password, different hash (because of the salt)", saved$password_hash[1] != saved$password_hash[2], TRUE)

cat("All", passed, "checks passed.\n")
