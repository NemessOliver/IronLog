# ============================================================
# components.R - the building blocks of the page (cards, tiles, tables)
# ============================================================
# Simple Sum-Up:
# Instead of writing the same HTML over and over, every look from the
# design is one small function: a card with a title, a big number tile,
# a small tile, a table, a "PR" label... app.R just stacks these blocks
# like LEGO. The colours and rounded corners come from www/style.css.
# ============================================================

# >> the title bar of a page: big title, grey line under it, buttons on the right
page_top <- function(title, subtitle = NULL, ...) {
  div(class = "il-top",
      div(h1(title), if (!is.null(subtitle)) div(class = "il-sub", subtitle)),
      div(class = "il-actions", ...))
}

# >> a card with an icon + title on top and anything you like inside
panel <- function(title, icon_name, ..., hint = NULL) {
  div(class = "il-card",
      div(class = "il-card-h",
          h3(icon(icon_name), title),
          if (!is.null(hint)) div(class = "il-hint", hint)),
      ...)
}

# >> a big number tile (the row of 3-4 boxes at the top of a page)
kpi_tile <- function(label, icon_name, value, unit = NULL, note = NULL) {
  div(class = "il-kpi",
      div(class = "t", icon(icon_name), label),
      div(class = "v", value, if (!is.null(unit)) tags$small(unit)),
      note)
}

# >> a smaller tile (used inside cards)
mini_tile <- function(label, value, unit = NULL, note = NULL) {
  div(class = "il-tile",
      div(class = "t", label),
      div(class = "v", value, if (!is.null(unit)) tags$small(unit)),
      note)
}

# >> "up-arrow 2.5 kg vs last week": neon when it's good news, red when it's bad news
# >> good_when = "up" (more is better), "down" (less is better) or "none" (just show it)
change_line <- function(change, text = "", good_when = "up", unit = "") {
  if (is.null(change) || length(change) == 0 || is.na(change)) return(div(class = "d", text))
  change <- round(change, 1)
  direction <- if (change > 0) "up" else if (change < 0) "down" else "flat"
  mood <- if (direction == "flat" || good_when == "none") "" else if (direction == good_when) "good" else "bad"
  arrow <- c(up = "arrow-up", down = "arrow-down", flat = "minus")[[direction]]
  amount <- format(abs(change), big.mark = ",", trim = TRUE)    # >> 5500 -> "5,500"
  div(class = paste("d", mood), icon(arrow), tags$b(class = "amt", trimws(paste(amount, unit))), text)
}

# >> a note without an arrow, e.g. "Goal reached"
note_line <- function(text, good = FALSE, icon_name = NULL) {
  div(class = paste("d", if (good) "good" else ""),
      if (!is.null(icon_name)) icon(icon_name),
      if (good) tags$b(text) else text)
}

# >> a small rounded label like "PR" (kind = "pr", "mut" or "blue")
pill <- function(text, kind = "pr") {
  span(class = paste("il-pill", kind), text)
}

# >> a simple table: headers + rows (each row = a list of cells)
# >> num = which column numbers hold numbers (those get right-aligned)
ui_table <- function(headers, rows, num = integer(0)) {
  align <- function(j) if (j %in% num) "num" else NULL
  tags$table(class = "il-table",
    tags$thead(tags$tr(lapply(seq_along(headers), function(j) tags$th(class = align(j), headers[j])))),
    tags$tbody(lapply(rows, function(row) {
      tags$tr(lapply(seq_along(row), function(j) tags$td(class = align(j), row[[j]])))
    })))
}

# >> one earlier training day as its own card ("bubble"): date + kind on top, one line per exercise
# >> sets = all sets of that day, with the is_pr column from mark_prs()
session_card <- function(day, sets) {
  kinds <- unique(sets$category)                           # >> e.g. "Upper", or "Upper" + "Cardio"
  icon_name <- if (length(kinds) == 1) switch(kinds, Upper = "angles-up", Lower = "angles-down",
                                              Cardio = "heart-pulse", "dumbbell") else "dumbbell"
  lifts <- strength_sets(sets)
  hint <- if (nrow(lifts) > 0) paste(nrow(lifts), if (nrow(lifts) == 1) "set" else "sets", "·",
                                     format_volume(sum(lifts$weight_kg * lifts$reps)), "kg")
  exercises <- day_exercises(sets)
  div(class = "il-bubble",
      panel(paste(short_day(day), "·", paste(kinds, collapse = " + ")), icon_name,
            ui_table(c("Exercise", "Sets", "Best set", "Est. 1RM", ""),
                     lapply(seq_len(nrow(exercises)), function(i) list(
                       span(class = "strong", exercises$exercise[i]),
                       exercises$sets[i],
                       exercises$best[i],
                       if (is.na(exercises$one_rm[i])) "-" else paste(exercises$one_rm[i], "kg"),
                       if (exercises$pr[i]) pill("PR", "pr") else "")),
                     num = 2:4),
            hint = hint))
}

# >> the "This week" box in the sidebar: X / goal workouts + one little bar per day
week_card <- function(trained_days, goal) {
  div(class = "il-week",
      div(class = "t", "This week"),
      div(class = "v", span(sum(trained_days)), paste(" /", goal, "workouts")),
      div(class = "il-days", lapply(trained_days, function(on) span(class = if (on) "on" else NULL))))
}

# >> a body tile that compares the latest scale reading with an older one
body_tile <- function(label, comparison, column, unit, good_when = "none") {
  now <- comparison$latest[[column]]
  before <- if (is.null(comparison$base)) NA else comparison$base[[column]]
  note <- if (is.na(before) || is.na(now)) div(class = "d", if (is.na(now)) "not filled in" else "first reading")
          else change_line(now - before, "", good_when, unit)
  mini_tile(label, if (is.na(now)) "-" else now, if (is.na(now)) NULL else unit, note)
}

# >> the title line above a sparkline: label on the left, latest value on the right
spark_head <- function(label, values, unit) {
  values <- values[!is.na(values)]
  div(class = "il-spark-h",
      span(label),
      span(class = "val", if (length(values)) paste(values[length(values)], unit) else "-"))
}
