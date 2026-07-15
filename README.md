# quiz.koplugin

A **Quiz Party** display plugin for [KOReader](https://github.com/koreader/koreader) — general knowledge quiz for a crowd, no app required.

## Concept

Everyone grabs a sheet of paper. The question appears on screen, the timer ticks. Everyone writes their answer. When time runs out (or the host taps *Reveal*), the answer appears. The host reads answers aloud and taps the score button for each correct player.

The plugin ships with **3200 French questions across 32 categories** built in — no setup required. You can also drop your own JSON file into KOReader's documents folder to add or replace questions (e.g. for an English deck).

## Rules

- The question is displayed; everyone writes their answer on paper before time runs out.
- The host taps **Reveal** to show the answer, then awards **+1** to each correct player.
- Questions are shuffled and wrap around automatically.
- First player to reach the agreed score wins (or play all questions and compare totals).

## Features

- **Question + answer in two phases** — question visible during writing time, answer revealed on demand
- **Optional countdown timer** — 20 s / 30 s / 45 s / 1 min, or disabled for self-paced play
- **Per-player score buttons** — tap a player's button to give them +1 after each reveal
- **Category badge** — displayed above the question when provided
- **Category picker** — enable/disable individual categories from Options (multi-select, per language)
- **Question counter** — shows current position in the deck (e.g. *3 / 42*)
- **2–8 players** — configurable player count
- **FR + EN UI** — 3200 bundled FR questions load automatically; EN needs your own file (see below)
- **Reload** — refresh the question file without restarting
- **E-ink friendly** — only the timer digit refreshes in fast/A2 mode

## Bringing your own questions

To add or replace questions (e.g. an English deck, or your own French set), create a file named
`quiz_questions_fr.json` (or `quiz_questions_en.json`, or `quiz_questions.json`) and copy it to
KOReader's **documents** folder (`/sdcard/koreader/` on most devices). A file placed there takes
priority over the bundled deck.

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

Questions are shuffled on load and wrap around automatically.

## Controls

| Button | Action |
|--------|--------|
| **Révéler la réponse / Reveal answer** | Stop timer and show answer + score buttons |
| **+Player (score)** | Award +1 to that player |
| **Question suivante / Next question** | Advance to next question + restart timer |
| **Options** | Language, categories, players, timer, reset, reload file |
| **Rules** | Show rules + JSON format reminder |
| **Close** | Exit |

## Installation

### Via KOReader Plugin Manager

```
quiz.koplugin/ → KOReader plugins/ folder
game-common/    → alongside plugins/ (shared library)
```

### Manual

1. Download `quiz.zip` from [Releases](../../releases).
2. Extract to your KOReader `plugins/` directory.
3. Restart KOReader — **Quiz Party** appears in the Tools menu, ready to play with the bundled French questions.
4. Optionally copy your own `quiz_questions_fr.json` (or `quiz_questions_en.json`) to KOReader's documents folder to add or replace questions.

## Development

`quiz.koplugin/` lives inside the
[koreader-plugins](https://github.com/t2ym5u/koreader-plugins) monorepo.

`quiz_questions_fr.lua` is the bundled question bank, generated from the
per-category files in `questions/` by `gen/to_lua.py`. Regenerate it after
editing any `questions/quiz_questions_fr_*.json` file:

```
python3 gen/to_lua.py
```

## License

GPL-3.0
