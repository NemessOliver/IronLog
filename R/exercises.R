# ============================================================
# exercises.R - the exercise lists for Upper, Lower and Cardio
# ============================================================
# Simple Sum-Up:
# The exercise box in the Workout menu suggests exercises from these lists
# PLUS everything I've logged before. If an exercise isn't in the list,
# I can just type a new one and it gets remembered after I save it.
# ============================================================

starter_exercises <- list(
  Upper = c("Bench press", "Incline bench press", "Overhead press", "Lat pulldown",
            "Pull-up", "Barbell row", "Dumbbell row", "Biceps curl",
            "Triceps pushdown", "Lateral raise"),
  Lower = c("Squat", "Hack squat", "Deadlift", "Romanian deadlift", "Leg press",
            "Leg curl", "Leg extension", "Hip thrust", "Calf raise", "Lunges"),
  Cardio = c("Running", "Cycling", "Rowing", "Stair climber", "Incline walking")
)

# >> the choices for the exercise box: my own exercises + the starter list, A-Z
exercise_choices <- function(workouts, category) {
  used_before <- workouts$exercise[workouts$category == category] # >> what I logged in this category
  sort(unique(c(used_before, starter_exercises[[category]])))     # >> merge, remove doubles, sort A-Z
}
