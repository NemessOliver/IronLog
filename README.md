# IronLog

**Track every set. See every gain.**

IronLog is my personal project for the Data Dynamics module (year 2, semester 3, Computer Science at NHL Stenden). It's a gym progress app built in R. I log my workouts and my smart-scale readings, and the app turns them into charts that show if I'm actually getting stronger and leaner.

> **Status:** version 0.4 (October 2026, mid-term). Accounts with login / logout, plus Dashboard, Workout, Body and Progress with the dark neon design from my concept presentation. New in 0.4: data-quality checks (in the app while logging + an EDA script for my report) and automatic tests. The forecast and the plateau check come later.

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
| **Data checks** | While logging: a name I typed before in other capitals ("bench press") is saved as the known name ("Bench press"), and a weight that is more than 40% off my last session gets a heads-up (typo? other equipment?) | Done (v0.4) |
| **Progress** | Forecast for the next 4 weeks and a plateau check | Planned (December) |

## The data science part

- **Estimated 1RM (Epley):** `weight × (1 + reps / 30)`
- **Weekly volume:** sets × reps × kg, per week, split into Upper and Lower
- **Plateau flag:** no new 1RM for 3 weeks or more *(planned)*
- **Forecast:** a straight-line trend with `lm()` for the next 4 weeks, checked later against what really happened (MAE) *(planned)*
- **Data quality (v0.4):** `R/data_quality.R` checks my log for empty cells, one exercise under two spellings, names in ALL CAPS / all small letters, weight jumps of more than 40% between sessions, impossible values (0 reps, 900 kg) and sets saved twice. The checks only point at problems, they never change data
- **EDA script (v0.4):** `analysis/midterm_eda.R` prints the basic numbers of my log, runs the data checks and saves 5 charts for my report into `output/` (private, not on GitHub)

## How I log (data dictionary)

One row in `workouts.csv` = one set. A few rules so the numbers stay comparable:

| Column | Meaning | Rule |
|---|---|---|
| `date` | day of the session | `2026-10-01` format |
| `category` | Upper, Lower or Cardio | |
| `exercise` | name of the exercise | one name per exercise AND per piece of equipment: barbell and dumbbells are different exercises ("Incline bench press" vs "Incline dumbbell press") |
| `set_no` | 1st, 2nd, 3rd... set of that exercise that day | filled in by the app |
| `weight_kg` | weight of the set | dumbbells: the weight of ONE dumbbell. Dips: my body weight + the extra plates |
| `reps` | repetitions | 1 to 50 |
| `rpe` | how hard it felt, 1-10 | optional |
| `duration_min`, `distance_km` | cardio only | |

`body.csv` has one row per smart-scale reading (weight, BMI, body fat %, muscle, protein, visceral fat, bone, water). Smart scales estimate body fat with electrical resistance, so I read those numbers as a trend, not as exact values.

If something was logged under the wrong name, fix it with `rename_exercise()` (in `R/storage.R`): it makes a backup first and tells you how many sets it changed.

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
│   ├── data_quality.R  checks for messy data (also used while logging)
│   └── exercises.R     exercise lists for Upper / Lower / Cardio
├── analysis/
│   └── midterm_eda.R   explores my log: numbers, data checks, 5 charts for the report
├── tests/
│   └── run_tests.R     automatic checks for the helper functions (made-up data)
├── www/style.css       extra styling for the neon look
├── data/               real data, not uploaded to GitHub:
│   ├── accounts.csv    the accounts (username, name, goal, password hash)
│   ├── users/<name>/   each user's own workouts.csv and body.csv
│   └── sample/         fake example data that's safe to share (this one IS uploaded)
├── output/             charts + numbers from analysis/ (made from real data, so NOT uploaded)
├── docs/               screenshots, diagrams and presentation stuff
└── .vscode/            editor settings + recommended extensions
```

## Privacy

This repo is public, so real data stays on the laptop: `.gitignore` blocks every CSV directly in `data/` (including `accounts.csv`), the whole `data/users/` folder and the `output/` folder with charts of my real data. Only the fake data in `data/sample/` goes online, so anyone can still try the app.

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

## Run the tests

In the Mac Terminal, inside the IronLog folder:

```bash
Rscript tests/run_tests.R
```

It ends with `All 54 checks passed.` If a check fails, it stops and shows which one, what it expected and what it got.

## Explore my data (EDA)

```bash
Rscript analysis/midterm_eda.R nemessoliver   # my own log
Rscript analysis/midterm_eda.R sample         # the fake demo data
```

It prints the numbers and the data checks, and saves the charts in `output/<name>/figures/`, the numbers in `output/<name>/midterm_numbers.txt` and the R + package versions in `output/<name>/session_info.txt`.

**Demo data:** want to see the charts without logging 10 weeks first? Flip the *Demo data* switch at the bottom of the sidebar. The app then shows the fake data from `data/sample/` and doesn't save anything. Flip it back to log for real. (`demo_mode <- TRUE` in `app.R` makes the switch start in the on position.)

## Roadmap

| When | Milestone |
|---|---|
| Sept | Topic pitch, start logging workouts, first version of the app, redesign, accounts (done) |
| Oct | Use it every session, first progress presentation, data checks + tests + EDA script (v0.4) |
| 1 Nov | Mid-term: Progress charts working on real data, report draft with the first EDA |
| Dec | Plateau detection, forecast, evaluation with real data |
| Jan | Final presentation, report, demo video, oral exam |

## AI use

I'm on the "AI used" route for this module. Most of the code (v0.1 to v0.4) was written by Claude (an AI assistant made by Anthropic), based on my ideas, my design and my feedback. I run every version on my own laptop, check the results, and commit and push the code myself. Every AI session is listed in my AI record in my personal portfolio, with what I used it for and how I checked the result.
