# ============================================================
# midterm_eda.R - exploring my own gym data for the mid-term report
# ============================================================
# Simple Sum-Up:
# EDA = exploratory data analysis = "get to know your data before you trust it".
# Like checking a second-hand car before you buy it: count the kilometres,
# look for scratches, test the brakes - THEN decide what it's worth.
# This script:
#   1. loads my real logs (workouts.csv + body.csv)
#   2. prints the basic numbers (sessions, sets, exercises, dates)
#   3. runs the data-quality checks from R/data_quality.R
#   4. saves 5 charts as PNG files (for my report and slides)
#   5. saves the numbers, the R and package versions and ready-to-paste APA references as text files
#
# Run it from the IronLog folder, in the terminal:
#   Rscript analysis/midterm_eda.R nemessoliver     <- my own data (data/users/nemessoliver)
#   Rscript analysis/midterm_eda.R sample           <- the fake demo data (data/sample)
#
# Everything is saved in output/ - that folder is in .gitignore, because
# charts of my real data are private, just like the data itself.
# Nothing in data/ is changed: the checks only POINT at problems.
# ============================================================

library(ggplot2)  # >> the charts

# >> load my helper functions (1RM, weekly volume, data checks, nice dates...)
for (file in list.files("R", pattern = "\\.R$", full.names = TRUE)) source(file)

# ---- 1. Which data? ---------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)               # >> the words typed after the script name
who <- if (length(args) > 0) args[1] else "nemessoliver"
folder <- if (who == "sample") "data/sample" else user_folder(who)  # >> user_folder() comes from R/accounts.R
if (!file.exists(file.path(folder, "workouts.csv"))) {
  stop("No workouts.csv in ", folder, " - check the username.", call. = FALSE)
}

workouts <- load_workouts(folder)                      # >> from R/storage.R: right column types + real dates
body <- load_body(folder)
goal <- 4                                              # >> my weekly goal (PDP goal 2: gym 4 times a week)

out_dir <- file.path("output", who)                    # >> output/nemessoliver/ or output/sample/
dir.create(file.path(out_dir, "figures"), recursive = TRUE, showWarnings = FALSE)

# ---- 2. The basic numbers ----------------------------------------------------------

lifts <- strength_sets(workouts)                       # >> lifting sets only (Upper/Lower with weight + reps)
sessions <- sort(unique(workouts$date))                # >> every day I trained, oldest first
first_day <- min(workouts$date)
last_day <- max(workouts$date)
weeks <- as.numeric(week_start(last_day) - week_start(first_day)) / 7 + 1 # >> calendar weeks from first to last log
per_week <- training_days_per_week(workouts, last_day, weeks = weeks)     # >> days trained in each of those weeks

numbers <- c(                                          # >> a named vector: "label" = value (as text)
  "Data"                         = if (who == "sample") "FAKE demo data (data/sample)" else paste("real log of", who),
  "First logged day"             = format(first_day),
  "Last logged day"              = format(last_day),
  "Calendar weeks covered"       = weeks,
  "Training sessions (days)"     = length(sessions),
  "Sets logged"                  = nrow(workouts),
  "  of which lifting sets"      = nrow(lifts),
  "  of which cardio entries"    = sum(workouts$category == "Cardio"),
  "Different exercise names"     = length(unique(workouts$exercise)),
  "Sets per session (average)"   = round(nrow(workouts) / length(sessions), 1),
  "Training days per week (avg)" = round(mean(per_week$days), 1),
  "Weeks with goal reached"      = paste0(sum(per_week$days >= goal), " of ", weeks, " (goal = ", goal, ")"),
  "Total volume (kg x reps)"     = format(round(sum(lifts$weight_kg * lifts$reps)), big.mark = ","),
  "Body-scale readings"          = nrow(body)
)

cat("\n==== IronLog EDA:", who, "====\n")
for (label in names(numbers)) cat(sprintf("%-30s %s\n", label, numbers[[label]])) # >> %-30s = text padded to 30 characters

# ---- 3. Data quality -------------------------------------------------------------------

report <- quality_report(workouts)
cat("\n---- Data-quality checks ----\n")
print(report, row.names = FALSE)

variants <- name_variants(workouts)
style <- name_style_issues(workouts)
jumps <- weight_jumps(workouts)
if (nrow(variants) > 0) { cat("\nSame exercise, different spellings:\n"); print(variants, row.names = FALSE) }
if (nrow(style) > 0)    { cat("\nNames in another style:\n");             print(style, row.names = FALSE) }
if (nrow(jumps) > 0)    { cat("\nWeight jumps > 40% between sessions:\n"); print(jumps, row.names = FALSE) }

missing_workouts <- missing_values(workouts)
missing_body <- missing_values(body)

# ---- 4. Charts (light theme, for a white report page) -----------------------------------

# >> colours checked for colour-blind safety on white (same hues as the app, a bit darker for paper)
upper_light <- "#4E8000"                               # >> green = Upper
lower_light <- "#2A78D6"                               # >> blue  = Lower
third_light <- "#D0558C"                               # >> pink  = 3rd lift in the strength chart
category_colours <- c(Upper = upper_light, Lower = lower_light, Cardio = "#8A8A8A")

# >> the "outfit" for every report chart: white, quiet grey grid, no clutter
theme_report <- function() {
  theme_minimal(base_size = 11) +
    theme(
      plot.background    = element_rect(fill = "white", colour = NA),
      panel.grid.major.x = element_blank(),            # >> no vertical grid lines
      panel.grid.minor   = element_blank(),
      panel.grid.major.y = element_line(colour = "#E6E6E3", linewidth = 0.4),
      axis.text          = element_text(colour = "#52514E"),
      axis.title         = element_text(colour = "#52514E", size = 10),
      plot.title         = element_text(face = "bold", size = 12),
      plot.subtitle      = element_text(colour = "#52514E", size = 9.5),
      legend.position    = "top",
      legend.justification = "left",
      legend.title       = element_blank()
    )
}

# >> saves one chart as a PNG, 16 cm wide (fits a Word page with normal margins)
save_chart <- function(chart, name, height_cm = 8) {
  path <- file.path(out_dir, "figures", name)
  ggsave(path, chart, width = 16, height = height_cm, units = "cm", dpi = 200, bg = "white")
  cat("saved", path, "\n")
}

cat("\n---- Charts ----\n")

# >> Figure 1: how many sets per exercise (shows what my data is made of)
sets_per_exercise <- aggregate(set_no ~ exercise + category, data = workouts, FUN = length) # >> count rows per exercise
names(sets_per_exercise)[3] <- "sets"
sets_per_exercise$exercise <- reorder(sets_per_exercise$exercise, sets_per_exercise$sets) # >> biggest bar on top
sets_per_exercise$category <- factor(sets_per_exercise$category, levels = c("Upper", "Lower", "Cardio")) # >> legend order
step <- max(1, round(max(sets_per_exercise$sets) / 5)) # >> about 5 whole-number ticks on the axis (no "2.5 sets")
chart1 <- ggplot(sets_per_exercise, aes(x = sets, y = exercise, fill = category)) +
  geom_col(width = 0.7) +
  scale_fill_manual(values = category_colours, drop = TRUE) +
  scale_x_continuous(breaks = seq(0, max(sets_per_exercise$sets) + step, by = step),
                     expand = expansion(mult = c(0, 0.05))) +   # >> bars start right at 0
  labs(title = "Sets per exercise", subtitle = paste(nrow(workouts), "sets in", length(sessions), "sessions"),
       x = "sets", y = NULL) +
  theme_report() +
  theme(panel.grid.major.y = element_blank(), panel.grid.major.x = element_line(colour = "#E6E6E3", linewidth = 0.4))
save_chart(chart1, "fig1_sets_per_exercise.png", height_cm = 3 + 0.55 * nrow(sets_per_exercise))

# >> Figure 2: training days per week vs my goal of 4
per_week$status <- ifelse(per_week$days >= goal, "Goal reached", "Below goal")
# >> the weeks as labels ("28 Sep") in the right order, so every week gets one equal-width bar
per_week$label <- factor(short_date(per_week$week), levels = short_date(per_week$week))
chart2 <- ggplot(per_week, aes(x = label, y = days, fill = status)) +
  geom_col(width = 0.6) +
  geom_hline(yintercept = goal, colour = "#52514E", linewidth = 0.5) +       # >> the goal line
  annotate("text", x = 0.55, y = goal + 0.3, label = paste("goal:", goal, "days"),
           hjust = 0, size = 3.2, colour = "#52514E") +
  scale_fill_manual(values = c("Goal reached" = upper_light, "Below goal" = "#B9C7A3")) +
  scale_y_continuous(breaks = 0:7, limits = c(0, 7), expand = expansion(mult = c(0, 0))) +
  labs(title = "Training days per week", subtitle = "week = Monday to Sunday", x = "week starting", y = "days") +
  theme_report()
save_chart(chart2, "fig2_days_per_week.png")

# >> Figure 3: estimated 1RM per session for the 3 lifts I trained on the most DAYS
# >> WHY days and not sets (like the dashboard)? A trend line needs points on 2+ different days.
# >> 9 sets of leg extensions in ONE session can't show a trend, bench press on 2 days can.
days_per_lift <- tapply(lifts$date, lifts$exercise, function(d) length(unique(d))) # >> on how many days I did each lift
sets_per_lift <- as.vector(table(lifts$exercise)[names(days_per_lift)])             # >> sets per lift, same order
top_lifts <- head(names(days_per_lift)[order(-days_per_lift, -sets_per_lift)], 3)  # >> most days first, then most sets
best_per_day <- aggregate(one_rm ~ date + exercise,     # >> best set of each lift on each day
                          data = transform(lifts[lifts$exercise %in% top_lifts, ],
                                           one_rm = estimate_1rm(weight_kg, reps)),
                          FUN = max)
best_per_day$exercise <- factor(best_per_day$exercise, levels = top_lifts) # >> fixed order = fixed colours
chart3 <- ggplot(best_per_day, aes(x = date, y = one_rm, colour = exercise)) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 2.6) +
  scale_colour_manual(values = setNames(c(upper_light, lower_light, third_light)[seq_along(top_lifts)], top_lifts)) +
  scale_x_date(labels = short_date) +
  labs(title = "Estimated 1RM per session (Epley)", subtitle = "best set of the day: weight x (1 + reps / 30)",
       x = NULL, y = "estimated 1RM (kg)") +
  theme_report()
save_chart(chart3, "fig3_strength_per_session.png")

# >> Figure 4: weekly volume, Upper vs Lower, side by side
volume <- weekly_volume(workouts)                      # >> from R/calculations.R
volume$label <- factor(short_date(volume$week), levels = short_date(sort(unique(volume$week)))) # >> "28 Sep", in date order
volume$category <- factor(volume$category, levels = c("Upper", "Lower"))
chart4 <- ggplot(volume, aes(x = label, y = volume_kg, fill = category)) +
  geom_col(position = position_dodge(width = 0.75), width = 0.7) + # >> Upper and Lower next to each other
  scale_fill_manual(values = category_colours) +
  scale_y_continuous(labels = function(kg) format(kg, big.mark = ","), expand = expansion(mult = c(0, 0.08))) +
  labs(title = "Weekly volume (kg x reps)", subtitle = "all lifting sets added up per week",
       x = "week starting", y = "kg x reps") +
  theme_report()
save_chart(chart4, "fig4_weekly_volume.png")

# >> Figure 5: empty cells per column - which fields do I actually fill in?
missing_workouts$kind <- ifelse(missing_workouts$column == "rpe", "optional",
                         ifelse(missing_workouts$column %in% c("duration_min", "distance_km"), "cardio only",
                                "always needed"))
missing_workouts$column <- factor(missing_workouts$column, levels = rev(names(workout_types))) # >> same order as the file
missing_workouts$kind <- factor(missing_workouts$kind, levels = c("always needed", "optional", "cardio only"))
chart5 <- ggplot(missing_workouts, aes(x = percent, y = column, fill = kind)) +
  geom_col(width = 0.7) +
  geom_text(aes(label = paste0(percent, "%")), hjust = -0.15, size = 3, colour = "#52514E") + # >> the % next to each bar (also "0%")
  scale_fill_manual(values = c("always needed" = upper_light, "optional" = third_light, "cardio only" = "#8A8A8A")) +
  scale_x_continuous(limits = c(0, 112), breaks = c(0, 25, 50, 75, 100), expand = expansion(mult = c(0, 0))) +
  labs(title = "Empty cells per column in workouts.csv", subtitle = "percentage of rows without a value",
       x = "% empty", y = NULL) +
  theme_report() +
  theme(panel.grid.major.y = element_blank(), panel.grid.major.x = element_line(colour = "#E6E6E3", linewidth = 0.4))
save_chart(chart5, "fig5_missing_values.png", height_cm = 7)

# ---- 5. Save the numbers and the versions --------------------------------------------

# >> the summary + every check in one text file, to copy into the report
summary_file <- file.path(out_dir, "midterm_numbers.txt")
sink(summary_file)                                     # >> sink = "send printed output to this file instead of the screen"
cat("IronLog EDA -", who, "- made on", format(Sys.Date()), "\n\n")
for (label in names(numbers)) cat(sprintf("%-30s %s\n", label, numbers[[label]]))
cat("\nData-quality checks\n"); print(report, row.names = FALSE)
cat("\nSame exercise, different spellings\n"); print(variants, row.names = FALSE)
cat("\nNames in another style\n"); print(style, row.names = FALSE)
cat("\nWeight jumps > 40% between sessions\n"); print(jumps, row.names = FALSE)
cat("\nEmpty cells in workouts.csv\n"); print(missing_workouts[, 1:3], row.names = FALSE)
cat("\nEmpty cells in body.csv\n"); print(missing_body, row.names = FALSE)
sink()                                                 # >> back to the screen
cat("saved", summary_file, "\n")

# >> one APA reference for an R package, with the version that is installed on THIS laptop
# >> packageDate() = the day that version was published, so the year always matches the version
apa_package <- function(package, authors, title) {
  if (!requireNamespace(package, quietly = TRUE)) return(paste(package, "is not installed"))
  year <- format(packageDate(package), "%Y")
  paste0(authors, " (", year, "). ", title, " (R package version ", packageVersion(package),
         ") [Computer software]. https://CRAN.R-project.org/package=", package)
}

# >> which R and package versions made these results + ready-to-paste references for the report
versions_file <- file.path(out_dir, "session_info.txt")
r_version <- paste(R.version$major, R.version$minor, sep = ".")   # >> e.g. "4.6.1"
references <- c(
  paste0("R Core Team. (", R.version$year, "). R: A language and environment for statistical computing (Version ",
         r_version, ") [Computer software]. R Foundation for Statistical Computing. https://www.R-project.org/"),
  apa_package("shiny", "Chang, W., Cheng, J., Allaire, J. J., Sievert, C., Schloerke, B., Xie, Y., Allen, J., McPherson, J., Dipert, A., & Borges, B.",
              "shiny: Web application framework for R"),
  apa_package("bslib", "Sievert, C., Cheng, J., & Aden-Buie, G.", "bslib: Custom 'Bootstrap' 'Sass' themes for 'shiny' and 'rmarkdown'"),
  apa_package("sodium", "Ooms, J.", "sodium: A modern and easy-to-use crypto library"),
  "Wickham, H. (2016). ggplot2: Elegant graphics for data analysis. Springer-Verlag New York. https://ggplot2.tidyverse.org"
)
writeLines(c("APA references for the software (copy these into the report):", "", references, "",
             "Full session info:", capture.output(sessionInfo())),
           versions_file)
cat("saved", versions_file, "\n")
