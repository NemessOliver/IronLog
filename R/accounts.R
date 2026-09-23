# ============================================================
# accounts.R - user accounts: create an account, check a login
# ============================================================
# Simple Sum-Up:
# Every user is one row in data/accounts.csv: username, name, weekly goal
# and a "password hash". A hash is like a fingerprint of the password:
# the app can check whether a typed password matches the fingerprint, but
# nobody can turn the fingerprint back into the password. So even someone
# who opens accounts.csv can't read anybody's password.
# The fingerprint is made by the sodium package (scrypt, built for passwords,
# with a random "salt" so two people with the same password still get
# different fingerprints).
# Each user also gets an own folder, data/users/<username>/, for their
# workouts.csv and body.csv - so nobody sees anyone else's logs.
# Both accounts.csv and data/users/ are in .gitignore: they never go online.
# ============================================================

accounts_file <- "data/accounts.csv"      # >> the list of users (stays on this computer)

# >> every column of accounts.csv and its type
account_types <- c(
  username = "character",       # >> what you log in with, e.g. "nemess"
  name = "character",           # >> shown in the app, e.g. "Nemess Oliver"
  weekly_goal = "numeric",      # >> how many workouts a week this user aims for
  password_hash = "character",  # >> the fingerprint of the password - never the password itself
  created = "character"         # >> the day the account was made, e.g. "2026-09-23"
)

# >> all accounts as a table (an empty table when nobody has signed up yet)
load_accounts <- function(file = accounts_file) {
  if (!file.exists(file)) {
    return(read.csv(text = paste(names(account_types), collapse = ","), colClasses = account_types))
  }
  read.csv(file, colClasses = account_types)
}

# >> "  Nemess " -> "nemess": usernames are saved in small letters, without spaces around them
clean_username <- function(username) {
  tolower(trimws(username))
}

# >> the folder with one user's own CSV files
user_folder <- function(username) {
  file.path("data", "users", username)
}

# >> checks the sign-up form: gives back what's wrong (a sentence), or NULL when all is fine
signup_problem <- function(username, name, password, password_again, weekly_goal, accounts) {
  # >> starts with a letter or number, then letters, numbers, . _ - (so it's also a safe folder name)
  if (!grepl("^[a-z0-9][a-z0-9._-]{2,19}$", username)) {
    return("Username: 3-20 characters, only letters, numbers and . _ -")
  }
  if (username %in% accounts$username) return("That username is already taken.")
  if (nchar(trimws(name)) == 0) return("Fill in your name.")
  if (nchar(password) < 8) return("Password: at least 8 characters.")
  if (!identical(password, password_again)) return("The two passwords are not the same.")
  if (is.null(weekly_goal) || is.na(weekly_goal) || weekly_goal < 1 || weekly_goal > 7) {
    return("Weekly goal: a number from 1 to 7.")
  }
  NULL
}

# >> makes a new account and saves it. Only the hash of the password is saved.
create_account <- function(username, name, password, weekly_goal, file = accounts_file) {
  account <- data.frame(
    username = username,
    name = trimws(name),
    weekly_goal = round(weekly_goal),
    password_hash = sodium::password_store(password),   # >> password -> fingerprint (scrypt + salt)
    created = format(Sys.Date())
  )
  dir.create(dirname(file), showWarnings = FALSE, recursive = TRUE)
  write.csv(rbind(load_accounts(file), account), file, row.names = FALSE)
  account
}

# >> the account of this username + password, or NULL when they don't match
check_login <- function(username, password, file = accounts_file) {
  accounts <- load_accounts(file)
  account <- accounts[accounts$username == clean_username(username), ]
  if (nrow(account) != 1 || !isTRUE(nzchar(password))) return(NULL)     # >> no such user (or no password typed)
  if (!sodium::password_verify(account$password_hash, password)) return(NULL) # >> wrong password
  account
}
