#!/usr/bin/env python3
"""Vérifie la fiche App Store (src/fastlane/metadata) avant l'envoi.

App Store Connect refuse une fiche dont un champ dépasse sa limite, mais ne
le dit qu'au moment de l'envoi, champ par champ. Ce script le dit tout de
suite, pour toutes les langues.

Usage : python3 src/fastlane/check_metadata.py
"""

from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).parent / "metadata"

# Limites d'App Store Connect, en caractères.
LIMITS = {
    "name": 30,
    "subtitle": 30,
    "keywords": 100,
    "promotional_text": 170,
    "description": 4000,
    "release_notes": 4000,
}
REQUIRED = ["name", "subtitle", "keywords", "description", "support_url", "privacy_url"]
LOCALES = ["en-US", "fr-FR", "de-DE", "es-ES", "it", "ja", "nl-NL", "pt-BR", "zh-Hans"]


def read(locale: str, field: str) -> str | None:
    path = ROOT / locale / f"{field}.txt"
    return path.read_text(encoding="utf-8").strip() if path.exists() else None


def check() -> list[str]:
    errors = []
    for locale in LOCALES:
        for field in REQUIRED:
            if not read(locale, field):
                errors.append(f"{locale}/{field} : manquant")
        for field, limit in LIMITS.items():
            value = read(locale, field)
            if value and len(value) > limit:
                errors.append(f"{locale}/{field} : {len(value)} caractères, limite {limit}")

        keywords = read(locale, "keywords") or ""
        words = [word.strip().lower() for word in keywords.split(",")]
        if any(not word for word in words):
            errors.append(f"{locale}/keywords : mot-clé vide (virgule en trop)")
        if len(set(words)) != len(words):
            errors.append(f"{locale}/keywords : mot-clé en double")
        # Le nom et le sous-titre sont déjà indexés : y répéter un mot dans les
        # mots-clés gâche de la place. Une expression de plusieurs mots aussi :
        # l'App Store combine lui-même les mots séparés par des virgules.
        indexed = f"{read(locale, 'name') or ''} {read(locale, 'subtitle') or ''}".lower()
        indexed_words = set(re.findall(r"\w+", indexed))
        for word in words:
            if " " in word:
                errors.append(f"{locale}/keywords : « {word} » en plusieurs mots, à séparer par des virgules")
            elif word in indexed_words or (locale in ("ja", "zh-Hans") and len(word) > 1 and word in indexed):
                errors.append(f"{locale}/keywords : « {word} » est déjà dans le nom ou le sous-titre")

        description = read(locale, "description") or ""
        if "<" in description:
            errors.append(f"{locale}/description : pas de HTML dans une description")
    return errors


if __name__ == "__main__":
    problems = check()
    for problem in problems:
        print(f"✗ {problem}")
    if problems:
        sys.exit(1)
    print(f"✓ Fiche App Store valide pour {len(LOCALES)} langues")
