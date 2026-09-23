# ============================================================
# IronLog - my gym progress app
# Personal project, Data Dynamics (year 2, semester 3)
# Start it with: shiny::runApp()
# ============================================================
# Simple Sum-Up:
# A Shiny app has two halves:
#   ui     = what you SEE (menus, forms, buttons, empty spots for tables/charts)
#   server = what HAPPENS (saving a set, filling the tables, drawing the charts)
# Think of a restaurant: the ui is the menu card and the tables,
# the server is the kitchen that cooks whatever you order.
# The helper functions live in the R/ folder - Shiny loads them automatically
# before this file runs, so they can be used everywhere below.
# ============================================================

library(shiny)    # >> the app framework
library(ggplot2)  # >> the charts

# ---- Settings ----------------------------------------------------------------

demo_mode <- FALSE                                    # >> TRUE = show the fake data in data/sample (nothing gets saved)
data_dir <- if (demo_mode) "data/sample" else "data"  # >> the folder with workouts.csv and body.csv

neon_theme <- bslib::bs_theme(                        # >> the whole dark look in one setting (bslib comes with Shiny)
  bg = "#0A0D0B",                                     # >> near-black background
  fg = "#EEF3EC",                                     # >> off-white text
  primary = "#C6FF3D"                                 # >> neon green buttons and highlights
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

ui <- navbarPage(
  title = "IronLog",
  theme = neon_theme,
  header = tags$head(tags$link(rel = "stylesheet", href = "style.css")), # >> my extra styling (www/style.css)

  # ---- Menu 1: Workout ----
  tabPanel("Workout",
    fluidRow(
      column(4,
        wellPanel(
          h4("Log a set"),
          radioButtons("category", NULL, choices = c("Upper", "Lower", "Cardio"), inline = TRUE),
          dateInput("workout_date", "Date", value = Sys.Date()),
          selectizeInput("exercise", "Exercise", choices = NULL,          # >> the server fills in the list
                         options = list(create = TRUE,                    # >> lets me type a brand-new exercise
                                        placeholder = "Pick or type an exercise")),
          conditionalPanel("input.category != 'Cardio'",                  # >> only shown for Upper/Lower
            fluidRow(
              column(6, numericInput("weight", "Weight (kg)", value = 20, min = 0, step = 2.5)),
              column(6, numericInput("reps", "Reps", value = 8, min = 1, step = 1))
            ),
            numericInput("rpe", "RPE (optional, 1-10)", value = NA, min = 1, max = 10, step = 0.5)
          ),
          conditionalPanel("input.category == 'Cardio'",                  # >> only shown for Cardio
            fluidRow(
              column(6, numericInput("duration", "Minutes", value = 30, min = 1)),
              column(6, numericInput("distance", "Distance (km)", value = NA, min = 0, step = 0.1))
            )
          ),
          actionButton("add_set", "Add set", class = "btn-primary w-100")
        )
      ),
      column(8,
        uiOutput("session_tiles"),                                        # >> the number boxes (sets, volume, best 1RM)
        h4("Sets on this date"),
        tableOutput("session_table")
      )
    )
  ),

  # ---- Menu 2: Body ----
  tabPanel("Body",
    fluidRow(
      column(4,
        wellPanel(
          h4("New scale reading"),
          dateInput("body_date", "Date", value = Sys.Date()),
          fluidRow(                                                       # >> one number box per metric, two per row
            lapply(names(body_metrics), function(label) {
              column(6, numericInput(paste0("b_", body_metrics[[label]]), label,
                                     value = NA, min = 0, step = 0.1))
            })
          ),
          actionButton("save_body", "Save reading", class = "btn-primary w-100")
        )
      ),
      column(8,
        uiOutput("body_tiles"),                                           # >> latest weight / fat / muscle
        h4("History"),
        tableOutput("body_table")
      )
    )
  ),

  # ---- Menu 3: Progress ----
  tabPanel("Progress",
    fluidRow(
      column(4, selectInput("progress_exercise", "Exercise", choices = NULL)),
      column(4, selectInput("progress_metric", "Body metric", choices = body_metrics,
                            selected = "body_fat_pct"))
    ),
    uiOutput("progress_tiles"),
    fluidRow(
      column(6, wellPanel(h4("How much stronger?"), plotOutput("plot_strength", height = "300px"))),
      column(6, wellPanel(h4("How much work?"), plotOutput("plot_volume", height = "300px")))
    ),
    wellPanel(h4("How much leaner?"), plotOutput("plot_body", height = "300px"))
  )
)

# ---- Server: what happens -------------------------------------------------------

server <- function(input, output, session) {

  # >> my data, loaded once at the start. A reactiveVal is a box that tells every
  # >> table and chart to redraw itself as soon as its content changes.
  workouts <- reactiveVal(load_workouts(data_dir))
  body <- reactiveVal(load_body(data_dir))

  # >> in demo mode nothing is saved, so the sample data stays clean
  demo_warning <- function() {
    showNotification("Demo mode is on, so nothing gets saved (demo_mode in app.R).", type = "warning")
  }

  # ======================= Workout menu =======================

  # >> when I switch Upper / Lower / Cardio, refresh the exercise list
  observeEvent(input$category, {
    updateSelectizeInput(session, "exercise",
                         choices = exercise_choices(workouts(), input$category),
                         selected = "")
  })

  # >> the "Add set" button
  observeEvent(input$add_set, {
    if (demo_mode) return(demo_warning())
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
    new_set <- data.frame(                                               # >> one new row for workouts.csv
      date = input$workout_date,
      category = input$category,
      exercise = exercise,
      set_no = next_set_number(workouts(), input$workout_date, exercise),
      weight_kg = if (is_cardio) NA else input$weight,
      reps = if (is_cardio) NA else input$reps,
      rpe = if (is_cardio) NA else input$rpe,
      duration_min = if (is_cardio) input$duration else NA,
      distance_km = if (is_cardio) input$distance else NA
    )
    save_workout_set(new_set, data_dir)                                  # >> write it into the CSV file
    workouts(load_workouts(data_dir))                                    # >> reload, so every table/chart redraws
    updateSelectizeInput(session, "exercise",                            # >> keep the exercise picked for the next set
                         choices = exercise_choices(workouts(), input$category),
                         selected = exercise)
    showNotification(paste0("Saved: ", exercise, ", set ", new_set$set_no), type = "message")
  })

  # >> all sets on the date that's picked in the form
  session_sets <- reactive({
    all_sets <- workouts()
    all_sets[which(all_sets$date == input$workout_date), ]
  })

  output$session_tiles <- renderUI({
    sets <- session_sets()
    lifts <- strength_sets(sets)
    volume <- sum(lifts$weight_kg * lifts$reps)                          # >> total kg x reps on that day
    best <- if (nrow(lifts) > 0) max(estimate_1rm(lifts$weight_kg, lifts$reps)) else NA
    tile_row(
      stat_tile("Sets", nrow(sets)),
      stat_tile("Volume", paste(format(round(volume), big.mark = ","), "kg")),
      stat_tile("Best est. 1RM", if (is.na(best)) "-" else paste(round(best, 1), "kg"))
    )
  })

  output$session_table <- renderTable({
    sets <- session_sets()
    if (nrow(sets) == 0) return(data.frame(Info = "No sets on this date yet."))
    data.frame(
      Exercise = sets$exercise,
      Set = as.integer(sets$set_no),
      `Weight (kg)` = sets$weight_kg,
      Reps = as.integer(sets$reps),
      `Est. 1RM (kg)` = round(estimate_1rm(sets$weight_kg, sets$reps), 1),
      Minutes = sets$duration_min,
      check.names = FALSE                                                # >> allow spaces and brackets in the column names
    )
  }, digits = 1, na = "")

  # ======================= Body menu =======================

  # >> the "Save reading" button
  observeEvent(input$save_body, {
    if (demo_mode) return(demo_warning())
    reading <- data.frame(date = input$body_date)                        # >> start the new row with the date
    for (column in body_metrics) {                                       # >> copy every number box into the row
      value <- input[[paste0("b_", column)]]
      reading[[column]] <- if (is.null(value)) NA else value
    }
    if (is.na(reading$weight_kg)) {
      return(showNotification("Body weight is required.", type = "error"))
    }
    save_body_reading(reading, data_dir)
    body(load_body(data_dir))                                            # >> reload, so the tiles/table/chart redraw
    showNotification("Scale reading saved.", type = "message")
  })

  output$body_tiles <- renderUI({
    readings <- body()
    if (nrow(readings) == 0) {
      return(p(class = "text-muted", "No readings yet. Add your first one on the left."))
    }
    readings <- readings[order(readings$date), ]                         # >> oldest -> newest
    latest <- readings[nrow(readings), ]
    before <- if (nrow(readings) > 1) readings[nrow(readings) - 1, ] else NULL
    tile_row(
      change_tile("Body weight", latest$weight_kg, before$weight_kg, "kg"),
      change_tile("Body fat", latest$body_fat_pct, before$body_fat_pct, "%"),
      change_tile("Muscle mass", latest$muscle_kg, before$muscle_kg, "kg")
    )
  })

  output$body_table <- renderTable({
    readings <- body()
    if (nrow(readings) == 0) return(NULL)
    readings <- readings[order(readings$date, decreasing = TRUE), ]      # >> newest on top
    readings$date <- format(readings$date, "%d %b %Y")                   # >> e.g. 23 Sep 2026
    names(readings) <- c("Date", names(body_metrics))                    # >> readable column names
    readings
  }, digits = 1, na = "")

  # ======================= Progress menu =======================

  # >> keep the exercise dropdown up to date with the lifts I've logged
  observeEvent(workouts(), {
    lifts <- sort(unique(strength_sets(workouts())$exercise))
    current <- input$progress_exercise
    selected <- if (isTRUE(current %in% lifts)) current else if (length(lifts) > 0) lifts[1] else NULL
    updateSelectInput(session, "progress_exercise", choices = lifts, selected = selected)
  })

  output$progress_tiles <- renderUI({
    req(input$progress_metric)
    exercise <- input$progress_exercise
    weekly <- best_1rm_per_week(workouts(), if (isTruthy(exercise)) exercise else "")
    readings <- body()[order(body()$date), ]
    metric <- input$progress_metric
    values <- readings[[metric]][!is.na(readings[[metric]])]            # >> that metric, oldest -> newest
    label <- names(body_metrics)[body_metrics == metric]
    tile_row(
      stat_tile("Best est. 1RM",
                if (nrow(weekly) == 0) "-" else paste(max(weekly$best_1rm), "kg"),
                exercise),
      stat_tile("Stronger since week 1",
                if (nrow(weekly) < 2) "-" else signed(weekly$best_1rm[nrow(weekly)] - weekly$best_1rm[1], "kg"),
                "best week now vs first week"),
      stat_tile(label,
                if (length(values) < 2) "-" else signed(values[length(values)] - values[1]),
                "latest vs first reading")
    )
  })

  output$plot_strength <- renderPlot({
    exercise <- input$progress_exercise
    if (!isTruthy(exercise)) return(empty_plot("Log some lifts in the Workout menu first"))
    plot_1rm_trend(best_1rm_per_week(workouts(), exercise), exercise)
  })

  output$plot_volume <- renderPlot({
    plot_weekly_volume(weekly_volume(workouts()))
  })

  output$plot_body <- renderPlot({
    req(input$progress_metric)
    label <- names(body_metrics)[body_metrics == input$progress_metric]
    plot_body_trend(body(), input$progress_metric, label)
  })
}

shinyApp(ui, server)   # >> glue the two halves together and start the app
