# ============================================================
# charts.R - the charts and stat tiles for the Progress menu
# ============================================================
# Simple Sum-Up:
# theme_ironlog() is the "outfit" every chart wears: dark background,
# light text, quiet grid lines. The plot_... functions each draw one chart
# with ggplot2, and stat_tile() makes the small number boxes at the top.
# If there's no data yet, a chart shows a friendly message instead of an error.
# ============================================================

# >> the colours of the app (same as in www/style.css)
card_colour  <- "#131A15"   # >> background of the cards/charts
grid_colour  <- "#222D26"   # >> quiet grid lines
text_colour  <- "#EEF3EC"   # >> off-white text
muted_colour <- "#8B978F"   # >> grey for axis labels and hints
neon         <- "#C6FF3D"   # >> the IronLog accent colour (one-line charts)
upper_colour <- "#73A40A"   # >> Upper in the volume chart (checked for colour-blind safety)
lower_colour <- "#3093DB"   # >> Lower in the volume chart

# >> the dark "outfit" for every chart
theme_ironlog <- function() {
  theme_minimal(base_size = 14) +                               # >> start from a clean, minimal look
    theme(
      plot.background  = element_rect(fill = card_colour, colour = NA),
      panel.background = element_rect(fill = card_colour, colour = NA),
      panel.grid.major = element_line(colour = grid_colour),    # >> faint grid
      panel.grid.minor = element_blank(),                       # >> no extra in-between lines
      text             = element_text(colour = text_colour),
      axis.text        = element_text(colour = muted_colour),
      legend.position  = "top",
      legend.title     = element_blank()
    )
}

# >> shown instead of a chart when there's nothing to draw yet
empty_plot <- function(message) {
  ggplot() +
    annotate("text", x = 0, y = 0, label = message, colour = muted_colour, size = 5) +
    theme_void() +                                              # >> no axes, no grid
    theme(plot.background = element_rect(fill = card_colour, colour = NA))
}

# >> "How much stronger?" - best estimated 1RM per week for one exercise
plot_1rm_trend <- function(weekly, exercise) {
  if (nrow(weekly) == 0) return(empty_plot("No sets for this exercise yet"))
  ggplot(weekly, aes(x = week, y = best_1rm)) +
    geom_line(colour = neon, linewidth = 0.9) +                 # >> the trend line
    geom_point(colour = neon, size = 3) +                       # >> one dot per week
    scale_x_date(date_labels = "%d %b") +                       # >> dates like "14 Sep"
    labs(x = NULL, y = "Estimated 1RM (kg)", subtitle = exercise) +
    theme_ironlog()
}

# >> "How much work?" - weekly volume, Upper and Lower stacked on top of each other
plot_weekly_volume <- function(volume) {
  if (nrow(volume) == 0) return(empty_plot("No lifting sets logged yet"))
  ggplot(volume, aes(x = week, y = volume_kg, fill = category)) +
    geom_col(colour = card_colour, linewidth = 0.8) +           # >> the card-coloured outline makes a small gap between blocks
    scale_fill_manual(values = c(Upper = upper_colour, Lower = lower_colour)) +
    scale_x_date(date_labels = "%d %b") +
    scale_y_continuous(labels = function(kg) format(kg, big.mark = ",", scientific = FALSE, trim = TRUE)) + # >> 10,000 instead of 1e+04
    labs(x = NULL, y = "Volume (kg x reps)") +
    theme_ironlog()
}

# >> "How much leaner?" - one body metric over time (the one picked in the dropdown)
plot_body_trend <- function(body, metric, label) {
  body <- body[!is.na(body[[metric]]), ]                        # >> skip readings where this number is empty
  if (nrow(body) == 0) return(empty_plot("No body readings yet"))
  ggplot(body, aes(x = date, y = .data[[metric]])) +            # >> .data[[metric]] = "the column whose name is in metric"
    geom_line(colour = neon, linewidth = 0.9) +
    geom_point(colour = neon, size = 3) +
    scale_x_date(date_labels = "%d %b") +
    labs(x = NULL, y = label) +
    theme_ironlog()
}

# >> a small box with a label, a big number and an optional note underneath
stat_tile <- function(label, value, note = NULL) {
  div(class = "stat-tile",
      div(class = "stat-label", label),
      div(class = "stat-value", value),
      if (!is.null(note)) div(class = "stat-note", note))
}

# >> a stat tile that also says how much the number changed since the reading before
change_tile <- function(label, now, before, unit) {
  if (is.na(now)) return(stat_tile(label, "-", "not filled in"))      # >> this box was left empty
  note <- if (is.null(before) || is.na(before)) {
    "first reading"                                                   # >> nothing to compare with yet
  } else {
    paste(signed(now - before, unit), "since last")                   # >> e.g. "-0.3 kg since last"
  }
  stat_tile(label, paste(now, unit), note)
}

# >> puts stat tiles next to each other
tile_row <- function(...) {
  div(class = "tile-row", ...)
}
