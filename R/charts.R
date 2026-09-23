# ============================================================
# charts.R - every chart in the app (ggplot2)
# ============================================================
# Simple Sum-Up:
# theme_ironlog() is the "outfit" every chart wears: dark card background,
# light text, only faint horizontal grid lines. The neon glow is a trick:
# each line is drawn 3 times - wide and see-through underneath, thin on top -
# so it looks like it's glowing. If there's no data yet, a chart shows a
# friendly message instead of an error.
# ============================================================

# >> the colours of the app (same as in www/style.css)
card_colour  <- "#131A15"   # >> background of the cards/charts
tile_colour  <- "#182019"   # >> background of the small tiles (sparklines)
grid_colour  <- "#222D26"   # >> quiet grid lines
text_colour  <- "#EEF3EC"   # >> off-white text
muted_colour <- "#8B978F"   # >> grey for axis labels and hints
neon         <- "#C6FF3D"   # >> the IronLog accent colour (one-line charts)
lift_colours <- c("#73A40A", "#3093DB", "#D4599B")   # >> up to 3 lifts at once (checked for colour-blind safety)
upper_colour <- lift_colours[1]                      # >> Upper in the volume chart
lower_colour <- lift_colours[2]                      # >> Lower in the volume chart

# >> the dark "outfit" for every chart
theme_ironlog <- function() {
  theme_minimal(base_size = 12) +                              # >> start from a clean, minimal look
    theme(
      plot.background    = element_rect(fill = card_colour, colour = NA),
      panel.background   = element_rect(fill = card_colour, colour = NA),
      panel.grid.major.y = element_line(colour = grid_colour, linewidth = 0.4), # >> faint horizontal lines
      panel.grid.major.x = element_blank(),                    # >> no vertical lines
      panel.grid.minor   = element_blank(),
      text               = element_text(colour = text_colour),
      axis.text          = element_text(colour = muted_colour, size = 10),
      axis.title         = element_text(colour = muted_colour, size = 10),
      legend.position    = "top",
      legend.justification = "right",
      legend.title       = element_blank(),
      legend.text        = element_text(colour = muted_colour, size = 10),
      legend.key.size    = unit(12, "pt"),
      legend.margin      = margin(0, 0, 0, 0),
      strip.text         = element_text(colour = text_colour, face = "bold", hjust = 0, size = 11),
      plot.margin        = margin(6, 10, 4, 4)
    )
}

# >> shown instead of a chart when there's nothing to draw yet
empty_plot <- function(message) {
  ggplot() +
    annotate("text", x = 0, y = 0, label = message, colour = muted_colour, size = 4.5) +
    theme_void() +                                             # >> no axes, no grid
    theme(plot.background = element_rect(fill = card_colour, colour = NA))
}

# >> the last point of every line (gets a ring, like in the design)
last_points <- function(data, date_column, group_column) {
  pieces <- split(data, data[[group_column]], drop = TRUE)     # >> one table per line
  do.call(rbind, lapply(pieces, function(piece) piece[which.max(piece[[date_column]]), ]))
}

# >> "How much stronger?" - best estimated 1RM per week, up to 3 lifts, glowing lines
plot_strength <- function(trends, lifts) {
  if (nrow(trends) == 0) return(empty_plot("No lifts logged in this period"))
  trends$exercise <- factor(trends$exercise, levels = lifts)   # >> keeps the colours in the order I picked
  ends <- last_points(trends, "week", "exercise")
  ggplot(trends, aes(x = week, y = best_1rm, colour = exercise, group = exercise)) +
    geom_line(linewidth = 3.6, alpha = 0.10, show.legend = FALSE) +  # >> glow, wide layer
    geom_line(linewidth = 2.0, alpha = 0.20, show.legend = FALSE) +  # >> glow, middle layer
    geom_line(linewidth = 0.9) +                                     # >> the sharp line on top
    geom_point(data = ends, shape = 21, fill = card_colour, size = 2.6, stroke = 1.6, show.legend = FALSE) +
    scale_colour_manual(values = setNames(lift_colours[seq_along(lifts)], lifts)) +
    scale_x_date(labels = short_date) +                            # >> "14 Sep" style dates
    labs(x = NULL, y = "kg") +
    theme_ironlog()
}

# >> "How much work?" - weekly volume, Upper and Lower stacked on top of each other
plot_weekly_volume <- function(volume) {
  if (nrow(volume) == 0) return(empty_plot("No lifting sets in this period"))
  ggplot(volume, aes(x = week, y = volume_kg, fill = category)) +
    geom_col(colour = card_colour, linewidth = 0.8) +          # >> card-coloured outline = small gap between blocks
    scale_fill_manual(values = c(Upper = upper_colour, Lower = lower_colour)) +
    scale_x_date(labels = short_date, breaks = scales::breaks_pretty(n = 4)) +
    scale_y_continuous(labels = function(kg) ifelse(kg >= 1000, paste0(kg / 1000, "k"), kg)) + # >> 10000 -> "10k"
    labs(x = NULL, y = "kg × reps") +
    theme_ironlog()
}

# >> "How much leaner?" - weight, body fat and muscle mass as three small charts side by side
plot_body_trends <- function(body) {
  metrics <- c("Body weight (kg)" = "weight_kg", "Body fat (%)" = "body_fat_pct", "Muscle mass (kg)" = "muscle_kg")
  parts <- lapply(names(metrics), function(label) {
    values <- body[[metrics[[label]]]]
    keep <- !is.na(values)
    if (!any(keep)) return(NULL)
    data.frame(date = body$date[keep], value = values[keep], metric = label)
  })
  long <- do.call(rbind, Filter(Negate(is.null), parts))       # >> one long table: date, value, metric
  if (is.null(long) || nrow(long) == 0) return(empty_plot("No body readings in this period"))
  long$metric <- factor(long$metric, levels = names(metrics))
  ends <- last_points(long, "date", "metric")
  ggplot(long, aes(x = date, y = value)) +
    geom_line(colour = neon, linewidth = 3.6, alpha = 0.10) +
    geom_line(colour = neon, linewidth = 2.0, alpha = 0.20) +
    geom_line(colour = neon, linewidth = 0.9) +
    geom_point(data = ends, shape = 21, colour = neon, fill = card_colour, size = 2.6, stroke = 1.6) +
    facet_wrap(~metric, nrow = 1, scales = "free_y") +         # >> 3 mini charts, each with its own scale
    scale_x_date(labels = short_date, breaks = scales::breaks_pretty(n = 3)) +
    labs(x = NULL, y = NULL) +
    theme_ironlog()
}

# >> "How consistent?" - how many days I trained each week, with my goal as a dashed line
plot_consistency <- function(per_week, goal) {
  if (sum(per_week$days) == 0) return(empty_plot("No workouts in this period"))
  per_week$status <- ifelse(per_week$days >= goal, "Goal reached", "Below goal")
  ggplot(per_week, aes(x = week, y = days, fill = status)) +
    geom_col(width = 5, colour = card_colour, linewidth = 0.6) +
    geom_hline(yintercept = goal, linetype = "dashed", colour = muted_colour, linewidth = 0.5) + # >> the goal line
    scale_fill_manual(values = c("Goal reached" = neon, "Below goal" = "#3A4A3F")) +
    scale_y_continuous(breaks = 0:7, limits = c(0, 7)) +
    scale_x_date(labels = short_date, breaks = scales::breaks_pretty(n = 4)) +
    labs(x = NULL, y = "days") +
    theme_ironlog()
}

# >> a tiny line without axes (the sparklines on the Body page)
plot_sparkline <- function(values, colour = neon) {
  values <- values[!is.na(values)]
  blank <- theme_void() + theme(plot.background = element_rect(fill = tile_colour, colour = NA))
  if (length(values) < 2) return(ggplot() + blank)              # >> need at least 2 points for a line
  line <- data.frame(i = seq_along(values), v = values)
  bottom <- min(values) - 0.15 * diff(range(values))           # >> where the soft area under the line stops
  ggplot(line, aes(x = i, y = v)) +
    geom_ribbon(aes(ymin = bottom, ymax = v), fill = colour, alpha = 0.18) +
    geom_line(colour = colour, linewidth = 0.9) +
    geom_point(data = line[nrow(line), ], shape = 21, colour = colour, fill = tile_colour, size = 2, stroke = 1.2) +
    blank +
    theme(plot.margin = margin(4, 6, 2, 2))
}
