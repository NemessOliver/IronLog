# IronLog

**Track every set. See every gain.**

IronLog is my personal project for the Data Dynamics module (year 2, semester 3, Computer Science at NHL Stenden). It's a gym progress app built in R. I log my workouts and my smart-scale readings, and the app turns them into charts that show if I'm actually getting stronger and leaner.

> **Status:** version 0.3 (September 2026). Accounts with login / logout, plus Dashboard, Workout, Body and Progress with the dark neon design from my concept presentation. The forecast and the plateau check come later.

## Why

I train 4–5 times a week, but my sets live in a notes app, so I can't really tell if I'm improving. IronLog should answer three questions:

1. **Am I getting stronger?** Estimated 1RM per lift over time
2. **Am I getting leaner?** Body fat % vs muscle mass over time
3. **Where am I stuck?** Lifts without a new 1RM for 3+ weeks

## Features

| Menu | What it does | Status |
|---|---|---|
| **Login** | Log in, or create an account (name, username, password, weekly goal). Every user only sees their own logs | Done |
| **Sidebar** | Menu, "this week X / goal workouts" with a bar per day, who is logged in, goal streak, *Log out* button and a *Demo data* switch | Done |
| **Dashboard** | Workouts this week, volume of the last 7 days, top lift, body fat, strength trend of my 3 main lifts, personal records, recent sessions, body snapshot | Done |
| **Workout** | Pick Upper, Lower or Cardio, pick or type the exercise, log weight × reps (several identical sets at once). The form stays in view; next to it the session table marks new PRs, tiles show volume vs last session and the best set, and earlier sessions follow as cards (*Show more* for older ones) | Done |
| **Body** | Log a smart-scale reading: weight, BMI, body fat, muscle mass, protein mass, visceral fat, bone mass, body water. Sparklines, latest vs 4 weeks ago, full history | Done |
| **Progress** | Pick 4 weeks / 12 weeks / all: estimated 1RM of up to 3 lifts, weekly volume (Upper vs Lower), weight / body fat / muscle mass, and training days per week vs my goal | Done |
| **Progress** | Forecast for the next 4 weeks and a plateau check | Planned (December) |

## The data science part

- **Estimated 1RM (Epley):** `weight × (1 + reps / 30)`
- **Weekly volume:** sets × reps × kg, per week, split into Upper and Lower
- **Plateau flag:** no new 1RM for 3 weeks or more *(planned)*
- **Forecast:** a straight-line trend with `lm()` for the next 4 weeks, checked later against what really happened (MAE) *(planned)*

## Tech stack

Kept simple on purpose:

- **R** for everything
- **Shiny** for the app (menus, forms, buttons), with a dark theme from `bslib::bs_theme()`
- **ggplot2** for the charts
- **CSV files** for storage (`read.csv()` / `write.csv()`)
- **sodium** for the passwords: it turns a password into a salted scrypt hash (a fingerprint that can't be turned back)
- **VS Code** as the editor

## Folder structure

```text
IronLog/
├── app.R               the app: what you see (ui) + what happens (server)
├── R/                  helper functions (Shiny loads these automatically)
│   ├── accounts.R      create an account, check a login (passwords as hashes)
│   ├── storage.R       load and save the CSV files
│   ├── calculations.R  1RM, best 1RM per week, volume, personal records
│   ├── summaries.R     this week, streak, recent sessions, best lifts, body comparison
│   ├── format.R        nice dates and numbers ("Wed 23 Sep", "18.2k", "+2.5 kg")
│   ├── components.R    the building blocks: cards, tiles, tables, pills
│   ├── charts.R        dark chart theme and all the charts
│   └── exercises.R     exercise lists for Upper / Lower / Cardio
├── www/style.css       extra styling for the neon look
├── data/               real data, not uploaded to GitHub:
│   ├── accounts.csv    the accounts (username, name, goal, password hash)
│   ├── users/<name>/   each user's own workouts.csv and body.csv
│   └── sample/         fake example data that's safe to share (this one IS uploaded)
├── docs/               screenshots, diagrams and presentation stuff
└── .vscode/            editor settings + recommended extensions
```

## Privacy

This repo is public, so real data stays on the laptop: `.gitignore` blocks every CSV directly in `data/` (including `accounts.csv`) and the whole `data/users/` folder. Only the fake data in `data/sample/` goes online, so anyone can still try the app.

Passwords are never saved as text. `accounts.csv` only holds a salted scrypt hash made by the sodium package, so even someone who opens the file can't read a password.

## Setup (macOS + VS Code)

1. Install **R** from <https://cran.r-project.org/>
2. Open this folder in VS Code and install the **R** extension when VS Code suggests it
3. Install the packages once, in an R console:

   ```r
   install.packages(c("shiny", "ggplot2", "sodium", "languageserver"))
   ```

## Run the app

- **In VS Code:** open an R terminal (Command Palette → *R: Create R Terminal*) and run `shiny::runApp()`
- **In the Mac Terminal**, inside the IronLog folder: `R -e "shiny::runApp(launch.browser = TRUE)"`

The first time, the login screen opens on *Create account*. After that, everyone logs in with their username and password; the button next to your name in the sidebar logs you out. Your first saved set creates `data/users/<username>/workouts.csv` (and `body.csv` for scale readings).

**Demo data:** want to see the charts without logging 10 weeks first? Flip the *Demo data* switch at the bottom of the sidebar. The app then shows the fake data from `data/sample/` and doesn't save anything. Flip it back to log for real. (`demo_mode <- TRUE` in `app.R` makes the switch start in the on position.)

## Roadmap

| When | Milestone |
|---|---|
| Sept | Topic pitch, start logging workouts, first version of the app, redesign, accounts (done) |
| Oct | Use it every session, first progress presentation |
| 1 Nov | Mid-term: Progress charts working on real data |
| Dec | Plateau detection, forecast, evaluation with real data |
| Jan | Final presentation, report, demo video, oral exam |

## AI use

I'm on the "AI used" route for this module. The project setup (folders, README, VS Code settings) was made with help from Claude, and anything else I build with AI help goes into my AI record.
