# ============================================================
# format.R - turning numbers and dates into nice text
# ============================================================
# Simple Sum-Up:
# Tiny helpers that make numbers and dates readable, like "+2.5 kg",
# "18.2k" or "Wed 23 Sep". The day and month names are written out here
# in English, so the app looks the same whatever language your Mac uses.
# ============================================================

day_names <- c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")

# >> 2026-09-23 -> "Wednesday, 23 September 2026"
nice_date <- function(date) {
  paste0(day_names[as.integer(format(date, "%u"))], ", ",       # >> %u = weekday number, 1 = Monday
         as.integer(format(date, "%d")), " ",                     # >> day of the month without a leading 0
         month.name[as.integer(format(date, "%m"))], " ",         # >> month.name is R's built-in English month list
         format(date, "%Y"))
}

# >> 2026-09-23 -> "23 Sep" (works on a whole vector, so charts can use it for their axis)
short_date <- function(date) {
  text <- paste(as.integer(format(date, "%d")), month.abb[as.integer(format(date, "%m"))])
  ifelse(is.na(date), "", text)                                  # >> empty label instead of "NA NA"
}

# >> 2026-09-23 -> "Wed 23 Sep"
short_day <- function(date) {
  paste(substr(day_names[as.integer(format(date, "%u"))], 1, 3), short_date(date))
}

# >> how long ago a date was, in words: "today", "yesterday", "5 days ago", "3 weeks ago"
days_ago_text <- function(date, today) {
  days <- as.integer(today - date)
  if (days <= 0) "today"
  else if (days == 1) "yesterday"
  else if (days < 14) paste(days, "days ago")
  else paste(days %/% 7, "weeks ago")                            # >> %/% = whole-number division
}

# >> 18240 -> "18.2k", 6240 -> "6,240"
format_volume <- function(kg) {
  if (is.na(kg)) return("-")
  if (kg >= 10000) paste0(round(kg / 1000, 1), "k") else format(round(kg), big.mark = ",", trim = TRUE)
}

# >> turns a number into "+2.5 kg" / "-0.3 %" style text
signed <- function(x, unit = "") {
  x <- round(x, 1)
  sign <- if (x > 0) "+" else ""                                 # >> negative numbers already have their "-"
  trimws(paste0(sign, x, " ", unit))
}

# >> "Good morning" / "Good afternoon" / "Good evening" depending on the hour
greeting <- function(hour) {
  if (hour < 12) "Good morning" else if (hour < 18) "Good afternoon" else "Good evening"
}

# >> "Nemess Oliver" -> "Nemess"
first_name <- function(full_name) {
  strsplit(full_name, " ")[[1]][1]
}

# >> "Nemess Oliver" -> "NO" (for the round avatar in the sidebar)
initials <- function(full_name) {
  toupper(paste(substr(strsplit(full_name, " ")[[1]], 1, 1), collapse = ""))
}
