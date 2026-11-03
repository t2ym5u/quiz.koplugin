#!/usr/bin/env python3
"""Merge questions/quiz_questions_<lang>_*.json → quiz_questions_<lang>.lua (category-keyed dict).

Builds every bundled language (fr, en) unless languages are given on the
command line, e.g. `python3 gen/to_lua.py en`.

The Lua format is faster to load on e-readers than JSON because loadfile()
uses the native C Lua parser instead of a pure-Lua JSON decoder. Each card
keeps its "category" field (used both as the dict key and for the on-screen
badge), so the flat-JSON fallback path in screen.lua still works unchanged.
"""
import glob, json, os, sys

LANGS = ["fr", "en"]
DEFAULT_CATEGORY   = {"fr": "Autres", "en": "Other"}
DEFAULT_DIFFICULTY = {"fr": "moyen",  "en": "medium"}

def lua_str(s):
    s = s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    return '"' + s + '"'

script_dir = os.path.dirname(os.path.abspath(__file__))

def build(lang):
    src_glob = os.path.join(script_dir, "..", "questions", f"quiz_questions_{lang}_*.json")
    dst      = os.path.join(script_dir, "..", f"quiz_questions_{lang}.lua")

    categories = {}
    for path in sorted(glob.glob(src_glob)):
        with open(path, encoding="utf-8") as f:
            questions = json.load(f)
        for q in questions:
            cat = q.get("category", DEFAULT_CATEGORY[lang])
            categories.setdefault(cat, []).append(q)

    ordered_keys = sorted(categories.keys())

    with open(dst, "w", encoding="utf-8") as f:
        f.write("return {\n")
        for cat in ordered_keys:
            f.write(f"  [{lua_str(cat)}]={{\n")
            for q in categories[cat]:
                question = lua_str(q.get("question", ""))
                answer   = lua_str(q.get("answer", ""))
                category = lua_str(q.get("category", ""))
                diff     = lua_str(q.get("difficulty", DEFAULT_DIFFICULTY[lang]))
                f.write(f"    {{question={question},answer={answer},category={category},difficulty={diff}}},\n")
            f.write("  },\n")
        f.write("}\n")

    total = sum(len(v) for v in categories.values())
    print(f"{total} questions -> {os.path.relpath(dst)}")
    for cat in ordered_keys:
        print(f"  {cat:<30} {len(categories[cat]):>4} questions")

for lang in (sys.argv[1:] or LANGS):
    build(lang)
