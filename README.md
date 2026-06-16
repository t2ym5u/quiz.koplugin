# quiz.koplugin

A **Quiz Party** display plugin for [KOReader](https://github.com/koreader/koreader) — general knowledge quiz for a crowd, no app required.

## Concept

Everyone grabs a sheet of paper. The question appears on screen, the timer ticks. Everyone writes their answer. When time runs out (or the host taps *Reveal*), the answer appears. The host reads answers aloud and taps the score button for each correct player.

The plugin loads your question bank from a JSON file you place in KOReader's documents folder.

## Features

- **Question + answer in two phases** — question visible during writing time, answer revealed on demand
- **Optional countdown timer** — 20 s / 30 s / 45 s / 1 min, or disabled for self-paced play
- **Per-player score buttons** — tap a player's button to give them +1 after each reveal
- **Category badge** — displayed above the question when provided in the JSON
- **Question counter** — shows current position in the deck (e.g. *3 / 42*)
- **2–8 players** — configurable player count
- **FR + EN UI** — loads `quiz_questions_fr.json` or `quiz_questions_en.json` automatically
- **Reload** — refresh the question file without restarting
- **E-ink friendly** — only the timer digit refreshes in fast/A2 mode

## Question JSON format

Create a file named `quiz_questions_fr.json` (or `quiz_questions_en.json`, or `quiz_questions.json`) and copy it to KOReader's **documents** folder (`/sdcard/koreader/` on most devices).

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
| **Options** | Language, players, timer, reset, reload file |
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
3. Copy your `quiz_questions_fr.json` (or `quiz_questions_en.json`) to KOReader's documents folder.
4. Restart KOReader — **Quiz Party** appears in the Tools menu.

## Development

`quiz.koplugin/` lives inside the
[koreader-plugins](https://github.com/t2ym5u/koreader-plugins) monorepo.
No bundled question bank — you supply the questions.

## License

GPL-3.0
