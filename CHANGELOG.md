# Changelog

All notable changes to this project will be documented in this file.

Reconstructed from this repository's git history: each release lists the
feature and fix commits it carried. Version bumps, screenshot additions
and CI syncs are left out.

## [1.6.3] - 2026-11-12

### Changed
- Picks up game-common 1.16.0: games for two readers (new Two readers
  category) and the shared Start / Join dialog.

## [1.6.2] - 2026-11-09

### Fixed
- A language tried once no longer sticks for good: the Quiz and
  Quiz · multiplayer now start in KOReader's language (French when KOReader
  is in French), and a language picked in the game holds until KOReader's
  language changes. Multiplayer keeps its own choice, and follows the
  Quiz's until it has one.

## [1.6.1] - 2026-11-04

### Fixed
- A game no longer crashes when an outdated plugin is installed alongside:
  shared modules left behind by an older plugin are replaced by this
  plugin's own copy instead of being used as they are.

## [1.6.0] - 2026-11-04

### Added
- **Quiz · multiplayer** (« Quiz · à plusieurs »), listed under Tools →
  Games → Party & quiz next to Quiz, with two rules chosen in its menu,
  **Rule: Classic / Double or nothing** (« Règle : Classique / Quitte ou
  double »):
  - **Classic**: the Quiz's own game (question, timer, reveal, +1 for each
    player who got it), with player names you type once, a Scores entry, a
    final scoreboard on New game, and scores kept when you close the quiz.
  - **Double or nothing**: it replaces the separate **Double or Nothing**
    plugin (« Quitte ou double »), which is retired. Same rules and scoring:
    teams take turns, a correct answer wins the pot (1 point, then doubled),
    the team banks it or risks it on a harder question (level 1–2 to open a
    turn, one level up per Double, up to 5), a wrong answer loses it. Now
    with team names, the standings on the "your turn" screen, and the match
    kept when you close the quiz (also a turn in progress).
- Double or nothing questions: Double or Nothing's 600 French and 600
  English questions rated 1–5, plus the Quiz's questions placed on the
  ladder (easy → level 2, medium → 3, hard → 4): 3,764 French and 2,131
  English questions. Questions asked under either rule (or in Quiz) are
  remembered together, so a question does not come back under the other
  rule. Your own file `quiz_double_<lang>.json` or `quiz_double.json` in the
  documents folder (questions with a `"difficulty"` 1–5) replaces them all;
  a file named for Double or Nothing (`doubleornothing_questions_<lang>.json`,
  `doubleornothing_questions.json`) still works.
- On the first start, Double or Nothing's language, number of teams, timer,
  category and question history are imported, unless the Quiz already has
  a value of its own (Double or Nothing's settings file is only read), and
  its play statistics are added to the Quiz's (as multiplayer sessions).
  Double or Nothing did not keep a match in progress, so there is none to
  bring over.

### Changed
- The Rules entry has a button to the multiplayer rules (and back).
- The question history now remembers up to 4,000 questions per language
  (was 3,200), to cover the Quiz and Double or nothing questions together.
- Uses less memory: the game loads when you open it, not when KOReader
  starts, so it no longer takes memory or startup time while unplayed.

## [1.5.0] - 2026-11-03

### Changed
- Questions no longer come back from one evening to the next: the quiz
  remembers the questions already shown (per question language, up to 3,200
  — the whole French bank) and asks the ones not seen yet first. A question
  returns only once every question of the chosen categories has been played.
  This also works with your own question file.
- Needs game-common 1.11.0.

## [1.4.0] - 2026-11-02

### Added
- A bundled English question bank: 1,602 questions written for English speakers, in 32 categories (about 50 each) and three difficulty levels. Choosing English no longer shows "No questions loaded".

### Changed
- Six French questions about dictators and a conqueror (Hitler, Mussolini,
  Mao Zedong, Kadhafi, Genghis Khan) were removed, per the content guidelines.
- Renamed from "Quiz Party" to "Quiz": it is listed under Tools → Games → Party & quiz, so "Party" said nothing. The plugin id and settings are unchanged.
- The question language now defaults to the reader's interface language (English or French) instead of always French. A language already chosen in the menu is kept.

### Fixed
- A question file you put in KOReader's documents folder (`quiz_questions_fr.json`, `quiz_questions_en.json` or `quiz_questions.json`) now replaces the bundled questions, as the README said it would. Before, a bundled `.lua` bank took priority over any JSON file there.

## [1.3.1] - 2026-11-02

### Changed
- Listed under **Tools → Games**, grouped by category, instead of its own
  entry in the Tools menu (game-common 1.9.1).

## [1.3.0] - 2026-10-30

### Changed
- Redesigned play screen. The question card fills the room the controls
  leave, in portrait and landscape. "Reveal answer", then one score button per
  player above "Next question", sit in a full-width action bar under the
  status line rather than inside the card.
- The "Settings" submenu is gone. The title-bar menu lists the settings
  directly, with their current value: New game, Language, Players, Timer,
  Categories (e.g. "Categories: 3/12"), Reload file, then Rules.
- "New game" replaces "Reset scores": it sets every score back to zero and
  moves on to a fresh question.
- Interface text now follows KOReader's language (with French, Spanish and
  German translations). Only the questions keep their own Language setting.
- The status line puts the question counter first ("Q3/40 · Player 1: 2 ·
  …"), so a long list of players no longer cuts it off.

### Fixed
- Question, answer and timer text came out about twice too big on high-DPI
  readers and ran off the screen edges. They are now sized to the screen.

## [1.2.13] - 2026-10-07

### Fixed
- The Tools menu entry is translated again. `main.lua` took `_` from
  KOReader's `gettext`, which knows nothing of this plugin's strings, so the
  menu label stayed English while the game's own screen, which goes through
  `i18n`, was translated. `_` now comes from `i18n` here too.
- `i18n_fr.lua` shipped to the device but was never loaded: nothing called
  `i18n.extend()` on it, so the whole table was dead weight. main.lua now
  merges it in before the menu entry is built.


## [1.2.12] - 2026-10-01

### Fixed
- Picks up game-common v1.5.0. Play statistics were recorded under a key no
  tool could match: `ReaderUI`/`FileManager:registerModule()` rewrite a plugin
  instance's `name` to `reader<id>` / `filemanager<id>` right after it is
  built, so this game's sessions were split across two rows and neither
  carried its plugin id. Rows written under the old keys are merged back on
  first read. The same release brings the `stopPlugin()` /
  `deletePluginSettings()` hooks KOReader 2026.07 calls when a plugin is
  deleted from the device (PR #15240).

  No change to this plugin's own code -- it inherits all of it from the
  shared library.

## [1.2.11] - 2026-09-30

### Fixed
- De-duplicate 36 questions filed under two categories at once, 10 of which
  gave two different answers ("3" and "Trois" for an octopus's hearts). With
  both categories selected the same question could come up twice in a game.
  Each is replaced by a new question in the same category at the same
  difficulty rather than deleted, so the bank stays 32 categories of exactly
  100.

### Added
- A spec over the whole 3,200-question bank: shape, no array holes, non-empty
  question and answer, each question's `category` matching its key, one
  difficulty vocabulary, and no repeats. The loader only type-checks the first
  entry it reads, so a malformed one further down used to load fine and fail
  when a player drew it.

## [1.2.10] - 2026-08-05

### Added
- Add ES and DE translations

### Changed
- Add issue/PR templates and CONTRIBUTING.md

## [1.2.9] - 2026-08-04

### Changed
- Symlink common/ to shared game-common

## [1.2.8] - 2026-07-29

### Fixed
- Drop deprecated name field from _meta.lua

## [1.2.5] - 2026-07-28

### Changed
- Add GPL-3.0 LICENSE

## [1.2.0] - 2026-07-15

### Added
- Bundle 3200-question FR bank with category picker

## [1.1.1] - 2026-07-15

### Added
- Adopt TitleBar header + vendor missing common/ dependency

### Changed
- Remove ../game-common/ fallback from package.path

## [1.1.0] - 2026-07-08

### Added
- I18n FR/EN translation + bump to 1.1.0

## [1.0.0] - 2026-06-24

### Added
- Initial release of quiz.koplugin v1.0.0

### Changed
- Add Rules section to README; style: minor formatting cleanup
