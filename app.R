# ============================================================
# IronLog - my gym progress app
# Personal project, Data Dynamics (year 2, semester 3)
# Start it with: shiny::runApp()
# ============================================================
# Simple Sum-Up:
# A Shiny app has two halves:
#   ui     = what you SEE (sidebar, pages, forms, empty spots for tables/charts)
#   server = what HAPPENS (saving a set, filling the tables, drawing the charts)
# Think of a restaurant: the ui is the menu card and the tables,
# the server is the kitchen that cooks whatever you order.
# The helper functions live in the R/ folder - Shiny loads them automatically
# before this file runs, so they can be used everywhere below.
# ============================================================

library(shiny)    # >> the app framework
library(ggplot2)  # >> the charts

# ---- Settings ----------------------------------------------------------------

user_name   <- "Nemess Oliver"   # >> shown in the sidebar
weekly_goal <- 4                 # >> my PDP goal: 4 gym sessions a week
demo_mode   <- FALSE             # >> TRUE = start with the fake demo data switched on

neon_theme <- bslib::bs_theme(   # >> the base dark look (bslib comes with Shiny); www/style.css adds the details
  bg = "#0A0D0B",
  fg = "#EEF3EC",
  primary = "#C6FF3D"
)

# >> the 8 smart-scale numbers: "label you see" = "column name in body.csv"
body_metrics <- c(
  "Body weight (kg)"     = "weight_kg",
  "BMI"                  = "bmi",
  "Body fat (%)"         = "body_fat_pct",
  "Muscle mass (kg)"     = "muscle_kg",
  "Protein mass (kg)"    = "protein_kg",
  "Visceral fat (level)" = "visceral_fat",
  "Bone mass (kg)"       = "bone_kg",
  "Body water (%)"       = "water_pct"
)

# ---- UI: what you see ----------------------------------------------------------

ui <- fluidPage(
  theme = neon_theme,
  title = "IronLog",
  tags$head(tags$link(rel = "stylesheet", href = "style.css")),        # >> my styling (www/style.css)

  div(class = "il-app",

    # ======================= Sidebar =======================
    div(class = "il-sidebar",
      div(class = "il-logo", span(class = "il-logo-mark", icon("bolt")), "IronLog"),

      # >> the menu is really a set of radio buttons dressed up as menu items:
      # >> only one page can be picked at a time, exactly like radio buttons
      div(class = "il-nav",
        radioButtons("page", NULL,
          choiceNames = list(tagList(icon("gauge-high"), "Dashboard"),
                             tagList(icon("dumbbell"), "Workout"),
                             tagList(icon("weight-scale"), "Body"),
                             tagList(icon("chart-line"), "Progress")),
          choiceValues = c("dashboard", "workout", "body", "progress"))),

      div(class = "il-sidebar-bottom",
        uiOutput("week_card"),                                          # >> "This week 3 / 4 workouts"
        div(class = "il-user",
            div(class = "il-avatar", initials(user_name)),
            div(div(class = "n", user_name),
                div(class = "s", textOutput("streak_text", inline = TRUE)))),
        div(class = "il-demo", bslib::input_switch("demo", "Demo data", value = demo_mode)))
    ),

    # ======================= Pages =======================
    div(class = "il-main",
      tabsetPanel(id = "pages", type = "hidden",                        # >> "hidden" = no tabs, the sidebar switches pages

        # ---------- Page 1: Dashboard ----------
        tabPanelBody("dashboard",
          page_top(textOutput("greeting", inline = TRUE), textOutput("dash_sub", inline = TRUE),
                   actionButton("go_body", "Log body", icon = icon("weight-scale"), class = "btn-ghost"),
                   actionButton("go_workout", "Log workout", icon = icon("plus"), class = "btn-primary")),
          uiOutput("dash_kpis"),
          fluidRow(
            column(8, panel("Strength trend · estimated 1RM", "arrow-trend-up",
                            plotOutput("dash_strength", height = "250px"), hint = "last 12 weeks")),
            column(4, panel("Personal records", "trophy", uiOutput("dash_records")))
          ),
          fluidRow(
            column(8, panel("Recent sessions", "clock-rotate-left", uiOutput("dash_sessions"))),
            column(4, panel("Body snapshot", "user", uiOutput("dash_body"), hint = "vs last reading"))
          )
        ),

        # ---------- Page 2: Workout ----------
        tabPanelBody("workout",
          page_top("Workout", textOutput("workout_sub", inline = TRUE)),
          div(class = "il-toolbar",
            div(class = "il-seg",                                         # >> Upper / Lower / Cardio switch
              radioButtons("category", NULL, inline = TRUE,
                choiceNames = list(tagList(icon("angles-up"), "Upper"),
                                   tagList(icon("angles-down"), "Lower"),
                                   tagList(icon("heart-pulse"), "Cardio")),
                choiceValues = c("Upper", "Lower", "Cardio")))),
          fluidRow(
            column(5, panel("Log a set", "circle-plus",
              dateInput("workout_date", "Date", value = Sys.Date()),
              selectizeInput("exercise", "Exercise", choices = NULL,        # >> the server fills in the list
                             options = list(create = TRUE,                  # >> lets me type a brand-new exercise
                                            placeholder = "Pick or type an exercise")),
              conditionalPanel("input.category != 'Cardio'",                # >> only for Upper/Lower
                fluidRow(
                  column(6, numericInput("weight", "Weight (kg)", value = 20, min = 0, step = 2.5)),
                  column(6, numericInput("reps", "Reps", value = 8, min = 1, step = 1))),
                fluidRow(
                  column(6, numericInput("sets", "Sets", value = 1, min = 1, max = 10, step = 1)),
                  column(6, numericInput("rpe", "RPE (optional)", value = NA, min = 1, max = 10, step = 0.5)))),
              conditionalPanel("input.category == 'Cardio'",                # >> only for Cardio
                fluidRow(
                  column(6, numericInput("duration", "Minutes", value = 30, min = 1)),
                  column(6, numericInput("distance", "Distance (km)", value = NA, min = 0, step = 0.1)))),
              actionButton("add_set", "Add set", icon = icon("plus"), class = "btn-primary w-100"),
              hint = textOutput("next_set_hint", inline = TRUE))),
            column(7, panel(textOutput("session_title", inline = TRUE), "list",
                            uiOutput("session_table"),
                            hint = textOutput("session_hint", inline = TRUE)))
          ),
          uiOutput("session_kpis")                                          # >> session volume, sets, best set
        ),

        # ---------- Page 3: Body ----------
        tabPanelBody("body",
          page_top("Body", "Log a smart-scale reading · 8 numbers, one entry"),
          fluidRow(
            column(8, panel("New measurement", "pen",
              fluidRow(column(4, dateInput("body_date", "Date", value = Sys.Date()))),
              fluidRow(                                                     # >> one number box per metric, four per row
                lapply(names(body_metrics), function(label) {
                  column(3, numericInput(paste0("b_", body_metrics[[label]]), label,
                                         value = NA, min = 0, step = 0.1))
                })),
              fluidRow(column(4, actionButton("save_body", "Save reading", icon = icon("floppy-disk"),
                                              class = "btn-primary w-100"))),
              fluidRow(
                column(6, div(class = "il-spark", uiOutput("spark_weight_head"),
                              plotOutput("spark_weight", height = "54px"))),
                column(6, div(class = "il-spark", uiOutput("spark_fat_head"),
                              plotOutput("spark_fat", height = "54px")))),
              hint = "Copy the numbers from your smart scale")),
            column(4, panel(textOutput("compare_title", inline = TRUE), "scale-balanced",
                            uiOutput("body_compare")))
          ),
          panel("History", "clock-rotate-left", uiOutput("body_history"),
                hint = textOutput("body_count", inline = TRUE))
        ),

        # ---------- Page 4: Progress ----------
        tabPanelBody("progress",
          page_top("Progress", textOutput("progress_sub", inline = TRUE),
                   div(class = "il-seg small",                              # >> 4 weeks / 12 weeks / everything
                       radioButtons("range", NULL, inline = TRUE,
                                    choices = c("4W", "12W", "All"), selected = "12W"))),
          uiOutput("progress_kpis"),
          fluidRow(
            column(8, panel("How much stronger? · estimated 1RM", "arrow-trend-up",
                            selectizeInput("progress_lifts", NULL, choices = NULL, multiple = TRUE,
                                           options = list(maxItems = 3, placeholder = "Pick up to 3 lifts")),
                            plotOutput("plot_strength", height = "260px"))),
            column(4, panel("How much work? · weekly volume", "layer-group",
                            plotOutput("plot_volume", height = "318px")))
          ),
          fluidRow(
            column(8, panel("How much leaner?", "user", plotOutput("plot_body", height = "240px"))),
            column(4, panel("How consistent? · days per week", "calendar-check",
                            plotOutput("plot_consistency", height = "240px")))
          )
        )
      )
    )
  )
)

# ---- Server: what happens -------------------------------------------------------

server <- function(input, output, session) {

  # ======================= The data =======================

  # >> which folder to read: the real data, or the fake demo data when the switch is on
  data_dir <- reactive(if (isTRUE(input$demo)) "data/sample" else "data")

  # >> my data. A reactiveVal is a box that tells every table and chart
  # >> to redraw itself as soon as its content changes.
  workouts <- reactiveVal(load_workouts("data"))
  body <- reactiveVal(load_body("data"))

  observeEvent(data_dir(), {                          # >> at the start + every time the demo switch flips
    workouts(load_workouts(data_dir()))
    body(load_body(data_dir()))
  })

  # >> "today" - with the demo data it's the last day in the fake log, so the demo looks alive
  today <- reactive({
    if (isTRUE(input$demo) && nrow(workouts()) > 0) max(workouts()$date) else Sys.Date()
  })

  # >> the demo data is read-only, so the sample files stay clean
  saving_blocked <- function() {
    if (!isTRUE(input$demo)) return(FALSE)
    showNotification("Demo data is on, so nothing gets saved. Switch it off in the sidebar.", type = "warning")
    TRUE
  }

  # ======================= Menu + sidebar =======================

  observeEvent(input$page, updateTabsetPanel(session, "pages", selected = input$page)) # >> menu click -> show that page
  observeEvent(input$go_workout, updateRadioButtons(session, "page", selected = "workout"))
  observeEvent(input$go_body, updateRadioButtons(session, "page", selected = "body"))

  output$week_card <- renderUI(week_card(days_this_week(workouts(), today()), weekly_goal))

  output$streak_text <- renderText({
    weeks <- goal_streak(workouts(), today(), weekly_goal)
    paste0(weeks, "-week streak")                     # >> weeks in a row with 4+ workouts
  })

  # ======================= Dashboard =======================

  output$greeting <- renderText({
    paste0(greeting(as.integer(format(Sys.time(), "%H"))), ", ", first_name(user_name))
  })

  output$dash_sub <- renderText({
    week <- weeks_of_training(workouts(), today())
    paste0(nice_date(today()), if (week > 0) paste0(" · week ", week, " of training") else "")
  })

  output$dash_kpis <- renderUI({
    all_sets <- workouts()
    day <- today()
    trained <- sum(days_this_week(all_sets, day))
    volume_now <- volume_between(all_sets, day - 6, day)          # >> the last 7 days
    volume_before <- volume_between(all_sets, day - 13, day - 7)  # >> the 7 days before that
    top_lift <- head(lift_ranking(all_sets), 1)                   # >> my most-trained lift
    weekly <- if (length(top_lift) == 1) best_1rm_per_week(all_sets, top_lift) else NULL
    scale <- compare_readings(body(), days = 1)                   # >> latest vs the reading before

    div(class = "il-kpis",
      kpi_tile("Workouts this week", "calendar-check", trained, paste("/", weekly_goal),
               if (trained >= weekly_goal) note_line("Goal reached", good = TRUE, icon_name = "circle-check")
               else note_line(paste(weekly_goal - trained, "more to hit your goal"), icon_name = "hourglass-half")),
      kpi_tile("Volume · last 7 days", "layer-group", format_volume(volume_now), "kg",
               if (volume_before > 0) change_line(round(100 * (volume_now - volume_before) / volume_before),
                                                  "vs the week before", "up", "%")
               else note_line("kg × reps, added up")),
      if (is.null(weekly) || nrow(weekly) == 0) {
        kpi_tile("Top lift · est. 1RM", "arrow-trend-up", "-", NULL, note_line("log a lift to see it"))
      } else {
        kpi_tile(paste(top_lift, "· est. 1RM"), "arrow-trend-up", weekly$best_1rm[nrow(weekly)], "kg",
                 if (nrow(weekly) > 1) change_line(weekly$best_1rm[nrow(weekly)] - weekly$best_1rm[1],
                                                   "since your first week", "up", "kg")
                 else note_line("your first week"))
      },
      if (is.null(scale) || is.na(scale$latest$body_fat_pct)) {
        kpi_tile("Body fat", "percent", "-", NULL, note_line("no reading yet"))
      } else {
        kpi_tile("Body fat", "percent", scale$latest$body_fat_pct, "%",
                 if (is.null(scale$base)) note_line("first reading")
                 else change_line(scale$latest$body_fat_pct - scale$base$body_fat_pct, "vs last reading", "down", "%"))
      })
  })

  output$dash_strength <- renderPlot({
    lifts <- head(lift_ranking(workouts()), 3)                    # >> my 3 most-trained lifts
    if (length(lifts) == 0) return(empty_plot("Log some lifts in the Workout menu first"))
    recent <- workouts()[workouts()$date > today() - 84, ]        # >> last 12 weeks
    plot_strength(strength_trends(recent, lifts), lifts)
  })

  output$dash_records <- renderUI({
    records <- best_lifts(workouts(), 5)
    if (nrow(records) == 0) return(div(class = "il-empty", "Your best lifts show up here."))
    ui_table(c("Lift", "Est. 1RM", ""),
      lapply(seq_len(nrow(records)), function(i) list(
        span(class = "strong", records$exercise[i]),
        paste(records$best_1rm[i], "kg"),
        pill(paste("PR ·", days_ago_text(records$date[i], today())), "pr"))),
      num = 2:3)
  })

  output$dash_sessions <- renderUI({
    sessions <- session_summaries(workouts(), 5)
    if (nrow(sessions) == 0) return(div(class = "il-empty", "No sessions yet. Log your first set in the Workout menu."))
    ui_table(c("Date", "Session", "Sets", "Volume", "Highlight"),
      lapply(seq_len(nrow(sessions)), function(i) list(
        span(class = "mut", short_day(sessions$date[i])),
        span(class = "strong", sessions$session[i]),
        if (sessions$sets[i] > 0) sessions$sets[i] else "-",
        if (sessions$volume_kg[i] > 0) paste(format_volume(sessions$volume_kg[i]), "kg") else "-",
        pill(sessions$highlight[i], sessions$kind[i]))),
      num = 3:5)
  })

  output$dash_body <- renderUI({
    scale <- compare_readings(body(), days = 1)
    if (is.null(scale)) return(div(class = "il-empty", "No scale readings yet."))
    div(class = "il-tiles",
        body_tile("Weight", scale, "weight_kg", "kg"),
        body_tile("Muscle mass", scale, "muscle_kg", "kg", "up"),
        body_tile("Body fat", scale, "body_fat_pct", "%", "down"),
        body_tile("Body water", scale, "water_pct", "%", "up"))
  })

  # ======================= Workout =======================

  output$workout_sub <- renderText({
    req(input$workout_date)
    paste("Log your session ·", nice_date(input$workout_date))
  })

  # >> when I switch Upper / Lower / Cardio (or the demo switch), refresh the exercise list
  observeEvent(list(input$category, input$demo), {
    updateSelectizeInput(session, "exercise",
                         choices = exercise_choices(workouts(), input$category),
                         selected = "")
  })

  output$next_set_hint <- renderText({
    req(input$workout_date)
    if (!isTruthy(input$exercise)) return("")
    exercise <- trimws(input$exercise)
    paste("Next: set", next_set_number(workouts(), input$workout_date, exercise), "of", exercise)
  })

  # >> the "Add set" button
  observeEvent(input$add_set, {
    if (saving_blocked()) return()
    is_cardio <- input$category == "Cardio"

    # >> check the form first, so no half-empty rows end up in the file
    if (!isTruthy(input$exercise)) {
      return(showNotification("Pick or type an exercise first.", type = "error"))
    }
    if (!isTruthy(input$workout_date)) {
      return(showNotification("Pick a date first.", type = "error"))
    }
    if (!is_cardio && (is.na(input$weight) || is.na(input$reps))) {
      return(showNotification("Fill in the weight and the reps.", type = "error"))
    }
    if (is_cardio && is.na(input$duration)) {
      return(showNotification("Fill in how many minutes.", type = "error"))
    }

    exercise <- trimws(input$exercise)
    how_many <- if (is_cardio || is.na(input$sets)) 1 else max(1, min(10, round(input$sets))) # >> 1-10 identical sets
    first_no <- next_set_number(workouts(), input$workout_date, exercise)
    new_sets <- data.frame(                                               # >> one row per set for workouts.csv
      date = input$workout_date,
      category = input$category,
      exercise = exercise,
      set_no = first_no + seq_len(how_many) - 1,                          # >> e.g. sets 3, 4, 5
      weight_kg = if (is_cardio) NA else input$weight,
      reps = if (is_cardio) NA else input$reps,
      rpe = if (is_cardio) NA else input$rpe,
      duration_min = if (is_cardio) input$duration else NA,
      distance_km = if (is_cardio) input$distance else NA
    )
    save_workout_set(new_sets, data_dir())                                # >> write it into the CSV file
    workouts(load_workouts(data_dir()))                                   # >> reload, so everything redraws
    updateSelectizeInput(session, "exercise",                             # >> keep the exercise picked for the next set
                         choices = exercise_choices(workouts(), input$category),
                         selected = exercise)
    last_no <- first_no + how_many - 1
    showNotification(paste0("Saved: ", exercise, ", set ",
                            if (how_many > 1) paste0(first_no, "-", last_no) else first_no),
                     type = "message")
  })

  # >> all sets on the date picked in the form (with a TRUE/FALSE "is it a PR?" column)
  session_sets <- reactive({
    req(input$workout_date)
    all_sets <- workouts()
    all_sets$is_pr <- mark_prs(all_sets)
    all_sets[which(all_sets$date == input$workout_date), ]
  })

  output$session_title <- renderText({
    req(input$workout_date)
    paste("Session ·", short_day(input$workout_date))
  })

  output$session_hint <- renderText({
    sets <- session_sets()
    if (nrow(sets) == 0) "" else paste(nrow(sets), if (nrow(sets) == 1) "set" else "sets")
  })

  output$session_table <- renderUI({
    sets <- session_sets()
    if (nrow(sets) == 0) return(div(class = "il-empty", "No sets on this date yet."))
    ui_table(c("Exercise", "Set", "Weight (kg)", "Reps", "Est. 1RM", ""),
      lapply(seq_len(nrow(sets)), function(i) {
        cardio <- sets$category[i] == "Cardio"
        list(span(class = "strong", sets$exercise[i]),
             sets$set_no[i],
             if (cardio) "-" else sets$weight_kg[i],
             if (cardio) "-" else sets$reps[i],
             if (cardio) "-" else paste(round(estimate_1rm(sets$weight_kg[i], sets$reps[i])), "kg"),
             if (cardio) pill(paste0(sets$duration_min[i], " min",
                                     if (!is.na(sets$distance_km[i])) paste0(" · ", sets$distance_km[i], " km") else ""), "blue")
             else if (isTRUE(sets$is_pr[i])) pill("PR", "pr") else "")
      }),
      num = 2:6)
  })

  output$session_kpis <- renderUI({
    req(input$workout_date, input$category)
    sets <- session_sets()
    lifts <- strength_sets(sets)
    volume <- sum(lifts$weight_kg * lifts$reps)
    before <- previous_session_volume(workouts(), input$workout_date, input$category)
    best <- if (nrow(lifts) > 0) which.max(estimate_1rm(lifts$weight_kg, lifts$reps)) else NULL

    div(class = "il-kpis three",
      kpi_tile("Session volume", "layer-group", format_volume(volume), "kg",
               if (!is.na(before) && volume > 0) change_line(volume - before, paste("vs last", input$category, "session"), "up", "kg")
               else note_line("kg × reps, added up")),
      kpi_tile("Sets done", "list-check", nrow(sets), NULL,
               note_line(paste(length(unique(sets$exercise)), "exercises"))),
      if (is.null(best)) {
        kpi_tile("Best set", "award", "-", NULL, note_line("log a set to see it"))
      } else {
        kpi_tile("Best set", "award", paste(lifts$weight_kg[best], "×", lifts$reps[best]), NULL,
                 note_line(paste0(lifts$exercise[best], " · ≈ ",
                                  round(estimate_1rm(lifts$weight_kg[best], lifts$reps[best])), " kg 1RM"),
                           good = TRUE, icon_name = "star"))
      })
  })

  # ======================= Body =======================

  # >> the "Save reading" button
  observeEvent(input$save_body, {
    if (saving_blocked()) return()
    reading <- data.frame(date = input$body_date)                         # >> start the new row with the date
    for (column in body_metrics) {                                        # >> copy every number box into the row
      value <- input[[paste0("b_", column)]]
      reading[[column]] <- if (is.null(value)) NA else value
    }
    if (is.na(reading$weight_kg)) {
      return(showNotification("Body weight is required.", type = "error"))
    }
    save_body_reading(reading, data_dir())
    body(load_body(data_dir()))                                           # >> reload, so everything redraws
    showNotification("Scale reading saved.", type = "message")
  })

  recent_body <- reactive(tail(body()[order(body()$date), ], 12))         # >> the last 12 readings

  output$spark_weight_head <- renderUI(spark_head("Body weight · last 12", recent_body()$weight_kg, "kg"))
  output$spark_weight <- renderPlot(plot_sparkline(recent_body()$weight_kg, neon))
  output$spark_fat_head <- renderUI(spark_head("Body fat · last 12", recent_body()$body_fat_pct, "%"))
  output$spark_fat <- renderPlot(plot_sparkline(recent_body()$body_fat_pct, lower_colour))

  output$compare_title <- renderText({
    scale <- compare_readings(body(), days = 28)
    if (!is.null(scale) && scale$exact) "Latest vs 4 weeks ago" else "Latest vs first reading"
  })

  output$body_compare <- renderUI({
    scale <- compare_readings(body(), days = 28)
    if (is.null(scale)) return(div(class = "il-empty", "Save your first reading to see changes here."))
    div(class = "il-tiles",
        body_tile("Body weight", scale, "weight_kg", "kg"),
        body_tile("Body fat", scale, "body_fat_pct", "%", "down"),
        body_tile("Muscle mass", scale, "muscle_kg", "kg", "up"),
        body_tile("Visceral fat", scale, "visceral_fat", "lvl", "down"),
        body_tile("Body water", scale, "water_pct", "%", "up"),
        body_tile("Bone mass", scale, "bone_kg", "kg"))
  })

  output$body_count <- renderText({
    n <- nrow(body())
    paste(n, if (n == 1) "reading" else "readings")
  })

  output$body_history <- renderUI({
    readings <- body()
    if (nrow(readings) == 0) return(div(class = "il-empty", "No readings yet."))
    readings <- readings[order(readings$date, decreasing = TRUE), ]       # >> newest on top
    show <- function(x, unit = "") if (is.na(x)) "-" else trimws(paste(x, unit))
    ui_table(c("Date", "Weight", "BMI", "Body fat", "Muscle", "Protein", "Visceral", "Bone", "Water"),
      lapply(seq_len(nrow(readings)), function(i) list(
        short_day(readings$date[i]),
        show(readings$weight_kg[i], "kg"), show(readings$bmi[i]), show(readings$body_fat_pct[i], "%"),
        show(readings$muscle_kg[i], "kg"), show(readings$protein_kg[i], "kg"), show(readings$visceral_fat[i]),
        show(readings$bone_kg[i], "kg"), show(readings$water_pct[i], "%"))),
      num = 2:9)
  })

  # ======================= Progress =======================

  # >> only the rows of the chosen period (4 weeks / 12 weeks / everything)
  period_workouts <- reactive({ req(input$range); in_period(workouts(), today(), input$range) })
  period_body <- reactive({ req(input$range); in_period(body(), today(), input$range) })

  # >> keep the lift picker up to date: my most-trained lifts, 3 picked by default
  observeEvent(workouts(), {
    lifts <- lift_ranking(workouts())
    keep <- intersect(input$progress_lifts, lifts)
    updateSelectizeInput(session, "progress_lifts", choices = lifts,
                         selected = if (length(keep) > 0) keep else head(lifts, 3))
  })

  output$progress_sub <- renderText({
    sets <- period_workouts()
    if (nrow(sets) == 0) return("No workouts in this period yet")
    first <- min(sets$date)
    last <- max(sets$date)
    weeks <- as.integer(as.numeric(week_start(last) - week_start(first)) / 7) + 1
    paste0(weeks, if (weeks == 1) " week" else " weeks", " of data · ",
           short_date(first), " – ", short_date(last), " ", format(last, "%Y"))
  })

  output$progress_kpis <- renderUI({
    lifts <- input$progress_lifts
    sets <- period_workouts()
    readings <- period_body()[order(period_body()$date), ]

    lift_tile <- function(k) {                                            # >> tile for the k-th picked lift
      if (length(lifts) < k) return(kpi_tile("Lift · est. 1RM", "arrow-trend-up", "-", NULL, note_line("pick a lift below")))
      weekly <- best_1rm_per_week(sets, lifts[k])
      if (nrow(weekly) == 0) return(kpi_tile(paste(lifts[k], "· est. 1RM"), "arrow-trend-up", "-", NULL, note_line("no sets in this period")))
      span_weeks <- as.integer(as.numeric(weekly$week[nrow(weekly)] - weekly$week[1]) / 7)
      kpi_tile(paste(lifts[k], "· est. 1RM"), "arrow-trend-up", weekly$best_1rm[nrow(weekly)], "kg",
               if (nrow(weekly) > 1) change_line(weekly$best_1rm[nrow(weekly)] - weekly$best_1rm[1],
                                                 paste("in", span_weeks, "weeks"), "up", "kg")
               else note_line("only one week so far"))
    }
    body_kpi <- function(label, icon_name, column, unit, good_when) {     # >> tile for one body metric
      values <- readings[[column]][!is.na(readings[[column]])]
      if (length(values) == 0) return(kpi_tile(label, icon_name, "-", NULL, note_line("no readings in this period")))
      kpi_tile(label, icon_name, values[length(values)], unit,
               if (length(values) > 1) change_line(values[length(values)] - values[1], "in this period", good_when, unit)
               else note_line("one reading so far"))
    }

    div(class = "il-kpis",
        lift_tile(1),
        lift_tile(2),
        body_kpi("Body fat", "percent", "body_fat_pct", "%", "down"),
        body_kpi("Muscle mass", "user", "muscle_kg", "kg", "up"))
  })

  output$plot_strength <- renderPlot({
    lifts <- head(input$progress_lifts, 3)
    if (length(lifts) == 0) return(empty_plot("Pick up to 3 lifts above"))
    plot_strength(strength_trends(period_workouts(), lifts), lifts)
  })

  output$plot_volume <- renderPlot(plot_weekly_volume(weekly_volume(period_workouts())))

  output$plot_body <- renderPlot(plot_body_trends(period_body()))

  output$plot_consistency <- renderPlot({
    req(input$range)
    weeks <- switch(input$range, "4W" = 4, "12W" = 12,
                    "All" = max(1, weeks_of_training(workouts(), today())))
    plot_consistency(training_days_per_week(workouts(), today(), weeks), weekly_goal)
  })
}

shinyApp(ui, server)   # >> glue the two halves together and start the app
