# Changelog

All notable changes to this project will be documented in this file.

Reconstructed from this repository's git history: each release lists the
feature and fix commits it carried. Version bumps, screenshot additions
and CI syncs are left out.

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
