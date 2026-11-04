# quiz.koplugin

A **Quiz** display plugin for [KOReader](https://github.com/koreader/koreader) — general knowledge quiz for a crowd, no app required.

## Screenshot

![Screenshot](images/quiz.png)

## Concept

Everyone grabs a sheet of paper. The question appears on screen, the timer ticks. Everyone writes their answer. When time runs out (or the host taps *Reveal*), the answer appears. The host reads answers aloud and taps the score button for each correct player.

Two entries under Tools → Games → Party & quiz: **Quiz** (described below) and **Quiz · multiplayer** (« Quiz · à plusieurs »), which adds named players or teams and a choice of two rules, Classic or Double or nothing (see [Quiz · multiplayer](#quiz--multiplayer)).

The plugin ships with **3,200 French questions** and **1,602 English questions**, each in 32 categories, built in — no setup required. The question language follows KOReader's interface language and can be changed from the menu (*Language*). You can also drop your own JSON file into KOReader's documents folder to replace the bundled questions.

## Rules

- The question is displayed; everyone writes their answer on paper before time runs out.
- The host taps **Reveal** to show the answer, then awards **+1** to each correct player.
- Questions not seen yet come first, even from one evening to the next: a question only comes back once every question of the chosen categories has been asked.
- First player to reach the agreed score wins (or play all questions and compare totals).

## Features

- **Question + answer in two phases** — question visible during writing time, answer revealed on demand
- **Optional countdown timer** — 20 s / 30 s / 45 s / 1 min, or disabled for self-paced play
- **Per-player score buttons** — tap a player's button to give them +1 after each reveal
- **Category badge** — displayed above the question when provided
- **Category picker** — enable/disable individual categories from Options (multi-select, per language)
- **Question counter** — shows current position in the deck (e.g. *3 / 42*)
- **2–8 players** — configurable player count
- **French and English question banks** — 3,200 FR and 1,602 EN questions bundled; only the bank for the language in play is loaded
- **FR + EN UI**
- **Reload** — refresh the question file without restarting
- **E-ink friendly** — only the timer digit refreshes in fast/A2 mode

## Bringing your own questions

To replace the bundled questions with your own set, create a file named
`quiz_questions_fr.json` (or `quiz_questions_en.json`, or `quiz_questions.json`) and copy it to
KOReader's **documents** folder (`/sdcard/koreader/` on most devices). A file placed there takes
priority over the bundled deck, in this order: `quiz_questions_<lang>.lua` (same format as the
bundled banks), `quiz_questions_<lang>.json`, then `quiz_questions.json` (used for any language).

```json
[
  {
    "question": "Quelle est la capitale de l'Australie ?",
    "answer": "Canberra",
    "category": "Géographie"
  },
  {
    "question": "En quelle année a eu lieu la Révolution française ?",
    "answer": "1789",
    "category": "Histoire"
  }
]
```

Each question object must have:
- `"question"` — the question text
- `"answer"` — the revealed answer
- `"category"` *(optional)* — shown as a badge above the question

Questions are shuffled, and the ones already asked in earlier sessions (remembered per language, also for your own file) go last; once every question has been asked, a new cycle starts.

## Controls

| Button | Action |
|--------|--------|
| **Révéler la réponse / Reveal answer** | Stop timer and show answer + score buttons |
| **+Player (score)** | Award +1 to that player |
| **Question suivante / Next question** | Advance to next question + restart timer |
| **Options** | Language, categories, players, timer, reset, reload file |
| **Rules** | Show rules + JSON format reminder |
| **Close** | Exit |

## Quiz · multiplayer

Named players or teams (typed once in the menu, remembered), a **Scores** entry, the final standings on **New game**, and the match kept when you close the quiz. The ☰ menu's **Rule** picks the game:

- **Rule: Classic** (« Classique ») — the Quiz above: everyone writes, reveal, tap each player who got it right (+1). 2–8 players. Uses the Quiz questions and the same categories.
- **Rule: Double or nothing** (« Quitte ou double ») — formerly the separate Double or Nothing plugin, same rules and scoring. 2–6 teams take turns. On your turn a question is shown; confer, then reveal:
  - **✗ Wrong** — the team loses everything in the pot; turn ends.
  - **✓ Correct** — the pot is won (1 point the first time, then doubled). Then either **Bank** (the pot goes to the team's score, turn ends) or **Double** (a new, harder question to double the pot again).
  - The first question of a turn is level 1 or 2; each Double climbs one level, up to 5. Optional thinking timer (15–45 s), one category or all.

### Double or nothing questions

The rated Double-or-nothing bank (`double_questions_fr.lua`, `double_questions_en.lua`: 600 questions per language, 12 categories, 10 per level 1–5 in each, the French one written for a French table) plus the Quiz questions placed on the ladder: easy/facile → level 2, medium/moyen → 3, hard/difficile → 4, so the easiest and hardest levels stay hand-rated. That is 3,764 French and 2,131 English questions (a question in both banks counts once):

| Level | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| French | 120 | 1,157 | 1,195 | 1,172 | 120 |
| English | 120 | 609 | 655 | 627 | 120 |

At each level a question is drawn at random, preferring questions not seen yet (if a level is used up during a session, the nearest level serves). The history of questions asked is shared by both rules and the Quiz entry, per language: a question asked one evening under Classic will not come back under Double or nothing before the rest.

Your own file replaces them all: `quiz_double_fr.json` (or `quiz_double_en.json`, or `quiz_double.json`) in KOReader's documents folder. A file named for the old plugin (`doubleornothing_questions_fr.json`, `doubleornothing_questions.json`) is still read.

```json
[
  { "question": "What is the capital of Portugal?", "answer": "Lisbon",
    "category": "Geography", "difficulty": 1, "alt": "Lisboa" }
]
```

`"difficulty"` is 1 to 5 (or `"easy"`, `"medium"`, `"hard"`); without it a question counts as level 3. `"alt"` (optional) lists other accepted answers, shown under the answer.

### Coming from Double or Nothing

On its first start, Quiz imports Double or Nothing's question language, number of teams, timer, category and question history (a value Quiz already has is kept), and Double or Nothing's play statistics (sessions, play time, last played) are added to Quiz's, as multiplayer sessions. Quiz · multiplayer then opens on the Double or nothing rule. Double or Nothing's own settings file is only read; the plugin can be removed afterwards.

## Installation

### Via KOReader Plugin Manager

```
quiz.koplugin/ → KOReader plugins/ folder
game-common/    → alongside plugins/ (shared library)
```

### Manual

1. Download `quiz.zip` from [Releases](../../releases).
2. Extract to your KOReader `plugins/` directory.
3. Restart KOReader — **Quiz** appears under Tools → Games → Party & quiz, ready to play with the bundled English or French questions.
4. Optionally copy your own `quiz_questions_fr.json` (or `quiz_questions_en.json`) to KOReader's documents folder to replace the bundled questions.

## Development

`quiz.koplugin/` lives inside the
[koreader-plugins](https://github.com/t2ym5u/koreader-plugins) monorepo.

`quiz_questions_fr.lua` and `quiz_questions_en.lua` are the bundled question
banks. They are generated — do not edit them by hand, the next build would
overwrite the change. They are built from the per-category files in
`questions/` (`quiz_questions_fr_*.json`, `quiz_questions_en_*.json`) by
`gen/to_lua.py`. Regenerate them after editing any of those files:

```
python3 gen/to_lua.py        # both languages
python3 gen/to_lua.py en     # one language
```

Each question has `question`, `answer`, `category` and `difficulty`
(`facile`/`moyen`/`difficile` in French, `easy`/`medium`/`hard` in English).
The English bank was written for English speakers, not translated: answers
are short enough for a table to judge, accepted variants go in brackets
(`Beetroot (beet)`), and only stable facts are used — no records,
office holders, populations or anything "current".

`quiz_bank.lua` decides where questions come from (documents folder first,
then the bundled bank). The multiplayer mode is `party_screen.lua` (Classic)
and `double_screen.lua` (Double or nothing, with `double_deck.lua` and
`double_round.lua`); `quiz_migrate.lua` is the one-time import from Double or
Nothing. The rated Double-or-nothing banks are hand-written Lua, not generated.
Run the specs with `busted test_*_spec.lua`.

## License

GPL-3.0
