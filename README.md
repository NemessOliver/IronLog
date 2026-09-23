# IronLog

**Track every set. See every gain.**

IronLog is my personal project for the Data Dynamics module (year 2, semester 3, Computer Science at NHL Stenden). It's a gym progress app built in R. I log my workouts and my smart-scale readings, and the app turns them into charts that show if I'm actually getting stronger and leaner.

> **Status:** just set up (September 2026). Folders and README only, no code yet.

## Why

I train 4–5 times a week, but my sets live in a notes app, so I can't really tell if I'm improving. IronLog should answer three questions:

1. **Am I getting stronger?** Estimated 1RM per lift over time
2. **Am I getting leaner?** Body fat % vs muscle mass over time
3. **Where am I stuck?** Lifts without a new 1RM for 3+ weeks

## Planned features

| Menu | What it does |
|---|---|
| **Workout** | Pick Upper, Lower or Cardio, type the exercise, log weight × reps for every set |
| **Body** | Log a smart-scale reading: weight, BMI, body fat, muscle mass, protein mass, visceral fat, bone mass, body water |
| **Progress** | Charts: strength trend + forecast, weekly volume per muscle group, body fat vs muscle mass, plateau check |

## The data science part

- **Estimated 1RM (Epley):** `weight × (1 + reps / 30)`
- **Weekly volume:** sets × reps × kg, per muscle group
- **Plateau flag:** no new 1RM for 3 weeks or more
- **Forecast:** a straight-line trend with `lm()` for the next 4 weeks, checked later against what really happened (MAE)

## Tech stack

Kept simple on purpose:

- **R** for everything
- **Shiny** for the app (menus, forms, buttons), with a dark theme from `bslib::bs_theme()`
- **ggplot2** for the charts
- **CSV files** for storage (`read.csv()` / `write.csv()`)
- **VS Code** as the editor

## Folder structure

```text
IronLog/
├── R/             helper functions (Shiny loads these automatically)
├── data/          my real logs, not uploaded to GitHub (see Privacy)
│   └── sample/    fake example data that's safe to share
├── www/           CSS and images for the app
├── docs/          screenshots, diagrams and presentation stuff
├── .vscode/       editor settings + recommended extensions
└── README.md
```

## Privacy

This repo is public, so my real body data stays on my laptop: `.gitignore` blocks every CSV in `data/`. Only the fake data in `data/sample/` goes online, so anyone can still try the app.

## Setup (macOS + VS Code)

1. Install **R** from <https://cran.r-project.org/>
2. Open this folder in VS Code and install the **R** extension when VS Code suggests it
3. Install the packages once, in an R console:

   ```r
   install.packages(c("shiny", "ggplot2", "languageserver"))
   ```

4. Once `app.R` exists, start the app with `shiny::runApp()`

## Roadmap

| When | Milestone |
|---|---|
| Sept | Topic pitch, start logging workouts |
| Oct | Workout + Body menus save to CSV, first progress presentation |
| 1 Nov | Mid-term: Progress charts working |
| Dec | Plateau detection, forecast, evaluation with real data |
| Jan | Final presentation, report, demo video, oral exam |

## AI use

I'm on the "AI used" route for this module. The project setup (folders, README, VS Code settings) was made with help from Claude, and anything else I build with AI help goes into my AI record.
