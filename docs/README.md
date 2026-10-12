# Documentation technique — HydroBar

| Document | Contenu |
|---|---|
| [**AUDIT_TECHNIQUE.md**](AUDIT_TECHNIQUE.md) | Revue de code complète : 32 points classés P0 → P4, plus une **revue n°2** (octobre 2026) de 13 points sur l'ensemble du code, y compris le code ajouté depuis. Référence fichier:ligne, impact et correctif. Les points corrigés sont marqués ✅ et conservés, pas effacés. |
| [**ROADMAP_FONCTIONNALITES.md**](ROADMAP_FONCTIONNALITES.md) | 21 propositions classées valeur / effort, séquencées v1.3 → v1.6, avec **ce qui est intégrable aujourd'hui** et ce qui bloque le reste. Inclut ce qu'il vaut mieux **ne pas** faire. |
| [**specs/DEEP_LINKS.md**](specs/DEEP_LINKS.md) | Spécification du schéma d'URL `hydrobar://` — **implémentée** : grammaire, sécurité, `x-callback-url`, codes d'erreur, code Swift et tests. |

## Par où commencer

1. **Le résumé exécutif** de l'audit (3 paragraphes) donne l'état des lieux.
2. **Les points P0 sont tous traités.** P0-1 (deep links), P0-2 (crash), P0-3
   (Focus Mode) et P0-6 (cible macOS du widget) sont corrigés ; P0-4 et P0-5 se
   sont révélés erronés ou sans impact à la vérification du `.pbxproj`, et sont
   conservés barrés plutôt qu'effacés pour que la correction reste traçable.
   P0-3 demande encore **une étape manuelle** : activer la capability
   Communication Notifications dans Xcode.
3. **La roadmap** : F1, F3 et F18 sont livrées. Les meilleurs rapports valeur /
   effort encore ouverts sont F19 (snooze, ~3 h) et F20 (raccourcis globaux, ~4 h) ;
   F2 (App Intents) est le prochain gros morceau. F12 (Sparkle) et F13 (Homebrew)
   sont débloquées dès que le certificat Developer ID est en place.

## Conventions

- Les références de code sont au format `Fichier.swift:ligne`, recalées sur l'état
  courant de la branche. Elles se périment au premier refactor : les vérifier avant
  de s'y fier, et les recaler en même temps que le code.
- Les renvois croisés entre documents sont des liens : un point d'audit cité dans la
  roadmap pointe vers son explication détaillée.
- Ces documents sont un **état des lieux daté**, pas une vérité permanente. À
  actualiser au fil des corrections — un audit périmé est pire que pas d'audit.
