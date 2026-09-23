# ============================================================
# summaries.R - the small summaries for the dashboard and sidebar
# ============================================================
# Simple Sum-Up:
# These functions answer quick questions about my log:
#   - which days did I train this week? how many weeks in a row did I hit my goal?
#   - what did my last sessions look like? what are my best lifts?
#   - how does my latest scale reading compare with an older one?
#   - which rows belong to the last 4 / 12 weeks?
# ============================================================

# >> which days of this week (Mon-Sun) I trained: 7 TRUE/FALSE values
days_this_week <- function(workouts, today) {
  this_week <- week_start(today) + 0:6                     # >> the 7 dates of this week
  this_week %in% workouts$date                             # >> TRUE if there's at least one set that day
}

# >> how many different days I trained, week by week (the last `weeks` weeks, empty weeks count as 0)
training_days_per_week <- function(workouts, today, weeks = 12) {
  mondays <- week_start(today) - 7 * ((weeks - 1):0)       # >> the Monday of each of those weeks
  trained <- unique(workouts$date)                         # >> every day with at least one set
  counts <- table(factor(format(week_start(trained)), levels = format(mondays))) # >> days per week
  data.frame(week = mondays, days = as.integer(counts))
}

# >> how many weeks in a row I hit my weekly goal (this week counts as soon as it's reached)
goal_streak <- function(workouts, today, goal = 4) {
  per_week <- training_days_per_week(workouts, today, weeks = 104)
  n <- nrow(per_week)
  streak <- if (per_week$days[n] >= goal) 1 else 0         # >> this week, if already done
  i <- n - 1
  while (i >= 1 && per_week$days[i] >= goal) {             # >> walk back week by week until I missed one
    streak <- streak + 1
    i <- i - 1
  }
  streak
}

# >> which week of training this is (week 1 = the week of my first logged set)
weeks_of_training <- function(workouts, today) {
  if (nrow(workouts) == 0) return(0)
  as.integer(as.numeric(week_start(today) - week_start(min(workouts$date))) / 7) + 1
}

# >> one line per training day (newest first) for the "Recent sessions" table
session_summaries <- function(workouts, n = 5) {
  if (nrow(workouts) == 0) return(data.frame())
  workouts$is_pr <- mark_prs(workouts)
  days <- head(sort(unique(workouts$date), decreasing = TRUE), n) # >> the last n training days
  rows <- lapply(days, function(day) {
    sets <- workouts[workouts$date == day, ]
    lifts <- strength_sets(sets)
    if (nrow(lifts) > 0) {
      one_rm <- estimate_1rm(lifts$weight_kg, lifts$reps)
      prs <- lifts$is_pr
      # >> show the best PR of the day, or else just the best set
      pick <- if (any(prs)) which(prs)[which.max(one_rm[prs])] else which.max(one_rm)
      highlight <- paste0(if (any(prs)) "PR · " else "",
                          lifts$exercise[pick], " ", lifts$weight_kg[pick], " × ", lifts$reps[pick])
      kind <- if (any(prs)) "pr" else "mut"
    } else {
      run <- sets[1, ]                                     # >> a cardio-only day
      highlight <- paste0(run$exercise, " · ", run$duration_min, " min",
                          if (!is.na(run$distance_km)) paste0(" · ", run$distance_km, " km") else "")
      kind <- "blue"
    }
    data.frame(date = day,
               session = paste(unique(sets$category), collapse = " + "),
               sets = nrow(lifts),
               volume_kg = sum(lifts$weight_kg * lifts$reps),
               highlight = highlight,
               kind = kind)
  })
  do.call(rbind, rows)
}

# >> my best set ever (highest estimated 1RM) for my most-trained lifts
best_lifts <- function(workouts, n = 5) {
  lifts <- strength_sets(workouts)
  top <- head(lift_ranking(workouts), n)
  if (length(top) == 0) return(data.frame())
  rows <- lapply(top, function(lift) {
    sets <- lifts[lifts$exercise == lift, ]
    one_rm <- estimate_1rm(sets$weight_kg, sets$reps)
    best <- which.max(one_rm)                              # >> the first time I hit my best
    data.frame(exercise = lift, best_1rm = round(one_rm[best], 1),
               weight_kg = sets$weight_kg[best], reps = sets$reps[best], date = sets$date[best])
  })
  do.call(rbind, rows)
}

# >> the latest scale reading + an older one to compare it with (at least `days` days older)
compare_readings <- function(body, days = 28) {
  if (nrow(body) == 0) return(NULL)
  body <- body[order(body$date), ]                         # >> oldest -> newest
  latest <- body[nrow(body), ]
  older <- body[body$date <= latest$date - days, ]
  base <- if (nrow(older) > 0) older[nrow(older), ] else if (nrow(body) > 1) body[1, ] else NULL
  list(latest = latest, base = base, exact = nrow(older) > 0) # >> exact = FALSE -> compared with my first reading
}

# >> keep only the rows of the chosen period: "4W", "12W" or "All"
in_period <- function(table, today, period) {
  days <- c("4W" = 28, "12W" = 84, "All" = Inf)[[period]]
  if (is.infinite(days)) return(table)
  table[table$date > today - days & table$date <= today, ]
}
