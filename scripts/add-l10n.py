#!/usr/bin/env python3
"""Adds new messages to every app/lib/l10n/app_*.arb at once, safely when several people do it at the same time.

    python scripts/add-l10n.py new_messages.json

The JSON file maps a message key to its texts, one per language, and optionally the "@key" metadata
(placeholders, description) which goes into app_en.arb only:

    {
      "dnsPickerTitle": {
        "en": "DNS servers", "fa": "...", "ru": "...", "zh": "...", "ar": "...", "es": "...", "hi": "...",
        "fr": "...", "pt": "...", "ur": "...", "id": "...", "tr": "...", "vi": "...",
        "meta": {"description": "Title of the DNS settings row"}
      }
    }

A language that is missing falls back to the English text (and is reported). A key that already exists
is left alone when the English text is the same and is an error when it differs. Run `flutter gen-l10n`
afterwards (in app/).
"""
import json
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIR = os.path.join(ROOT, "app", "lib", "l10n")
LANGS = ["en", "fa", "ru", "zh", "ar", "es", "hi", "fr", "pt", "ur", "id", "tr", "vi"]
LOCK = os.path.join(DIR, ".add-l10n.lock")


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    new = json.load(open(sys.argv[1], encoding="utf-8"))
    # One writer at a time: the lock file is created exclusively and removed at the end.
    for _ in range(600):
        try:
            fd = os.open(LOCK, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            os.close(fd)
            break
        except FileExistsError:
            time.sleep(0.1)
    else:
        sys.exit("could not get the lock %s (remove it if no one else is running this)" % LOCK)
    try:
        files = {}
        for lang in LANGS:
            path = os.path.join(DIR, "app_%s.arb" % lang)
            files[lang] = json.load(open(path, encoding="utf-8"))
        added = 0
        for key, texts in new.items():
            if "en" not in texts:
                sys.exit("%s: the English text is required" % key)
            if key in files["en"]:
                if files["en"][key] != texts["en"]:
                    sys.exit("%s already exists with other English text" % key)
                continue
            for lang in LANGS:
                text = texts.get(lang)
                if not text:
                    print("%s: no %s text, English used" % (key, lang), file=sys.stderr)
                    text = texts["en"]
                files[lang][key] = text
            meta = texts.get("meta")
            if meta:
                files["en"]["@" + key] = meta
            added += 1
        for lang in LANGS:
            path = os.path.join(DIR, "app_%s.arb" % lang)
            with open(path, "w", encoding="utf-8", newline="\n") as f:
                f.write(json.dumps(files[lang], ensure_ascii=False, indent=2) + "\n")
        print("added %d messages to %d files" % (added, len(LANGS)))
    finally:
        os.remove(LOCK)


if __name__ == "__main__":
    main()
