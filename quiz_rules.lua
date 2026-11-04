-- quiz_rules.lua — the Quiz's rules texts: the Quiz entry ("solo") and
-- Quiz · multiplayer with its two rules, Classic and Double or nothing
-- (shown by ScreenBase:makeModeRulesButtonConfig, each with a button to the
-- other).
local _ = require("i18n")

local SOLO_EN = _([[
Quiz — Rules

Everyone writes their answer on paper while the question is displayed. When time runs out (or the host taps "Reveal"), the answer appears.

• Each player with the correct answer scores +1.
• The host reads answers aloud and decides who scores.
• Questions are shuffled from the bundled bank for the question language (English or French, see Options → Language), or from your own file.

Your own questions (quiz_questions_en.json or quiz_questions.json in documents):
[
  {
    "question": "Capital of Australia?",
    "answer": "Canberra",
    "category": "Geography"
  }
]
]])

local SOLO_FR = [[
Quiz — Règles

Tout le monde écrit sa réponse sur papier pendant que la question est affichée. Quand le chrono sonne (ou que l'hôte appuie sur « Révéler »), la réponse apparaît.

• Chaque joueur avec la bonne réponse marque +1.
• L'hôte lit les réponses à voix haute et décide qui marque.
• Les questions sont tirées au hasard de la banque intégrée pour la langue choisie (français ou anglais, voir Options → Langue), ou de votre propre fichier.

Vos propres questions (quiz_questions_fr.json ou quiz_questions.json dans documents) :
[
  {
    "question": "Capitale de l'Australie ?",
    "answer": "Canberra",
    "category": "Géographie"
  }
]
]]

local PARTY_EN = _([[
Quiz · multiplayer — Rules

Two rules, chosen in the menu (Rule). The names of the players or teams are set in the menu too; the scores are kept until New game, even if you close the quiz.

CLASSIC
Everyone writes their answer on paper while the question is displayed. When time runs out (or the host taps "Reveal"), the answer appears; tap each player who got it right: +1. Then Next question.

DOUBLE OR NOTHING
Teams take turns. On your turn, a question is shown — confer with your team, then tap "Reveal" to see the answer.

• ✗ Wrong = you lose everything you were sitting on this turn. Turn ends, pot resets to 0.
• ✓ Correct = the pot is won (1 point first time, then doubled each time you keep going). Choose:
    – Bank it — add the pot to your score, turn ends.
    – Double or nothing — draw a new (harder) question and risk the pot to double it.

Difficulty: the first question of a turn is easy (level 1 or 2); every Double climbs one level, up to 5.
No question comes back until the whole deck has been played.

Teams swap after every turn (banked or busted).

Questions: the rated Double-or-nothing bank (levels 1–5) plus the Quiz questions (easy = level 2, medium = 3, hard = 4). Your own file (quiz_double_en.json or quiz_double.json in documents, each question with a "difficulty" from 1 to 5) replaces them all.
]])

local PARTY_FR = [[
Quiz · à plusieurs — Règles

Deux règles, au choix dans le menu (Règle). Les noms des joueurs ou des équipes se règlent aussi dans le menu ; les scores sont gardés jusqu'à Nouvelle partie, même si vous fermez le quiz.

CLASSIQUE
Tout le monde écrit sa réponse sur papier pendant que la question est affichée. Quand le chrono sonne (ou que l'hôte appuie sur « Révéler »), la réponse apparaît ; touchez chaque joueur qui a bon : +1. Puis Question suivante.

QUITTE OU DOUBLE
Les équipes jouent à tour de rôle. À votre tour, une question s'affiche — concertez-vous, puis appuyez sur « Révéler » pour voir la réponse.

• ✗ Faux = vous perdez tout ce que vous aviez en jeu ce tour-ci. Le tour s'arrête, la cagnotte repart à 0.
• ✓ Juste = la cagnotte est gagnée (1 point la première fois, puis doublée à chaque fois que vous continuez). Choisissez :
    – Encaisser — la cagnotte s'ajoute à votre score, le tour s'arrête.
    – Quitte ou double — une nouvelle question (plus dure) arrive, vous risquez la cagnotte pour la doubler.

Difficulté : la première question d'un tour est facile (palier 1 ou 2) ; chaque « Doubler » monte d'un palier, jusqu'à 5.
Aucune question ne revient avant que tout le paquet ait été joué.

Les équipes échangent leur tour après chaque manche (encaissée ou perdue).

Questions : la banque Quitte ou double notée par palier (1 à 5) plus les questions du Quiz (facile = palier 2, moyen = 3, difficile = 4). Votre propre fichier (quiz_double_fr.json ou quiz_double.json dans documents, chaque question avec une « difficulty » de 1 à 5) les remplace toutes.
]]

return {
    solo  = { SOLO_EN, SOLO_FR },
    party = { PARTY_EN, PARTY_FR },
}
