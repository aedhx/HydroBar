# Documentation technique — HydroBar

| Document | Contenu |
|---|---|
| [**AUDIT_TECHNIQUE.md**](AUDIT_TECHNIQUE.md) | Revue de code complète : 32 points classés P0 → P4, avec référence fichier:ligne, impact et correctif proposé. Se termine par un plan d'action en 6 lots. |
| [**ROADMAP_FONCTIONNALITES.md**](ROADMAP_FONCTIONNALITES.md) | 21 propositions de fonctionnalités classées valeur / effort, séquencées en versions v1.3 → v1.6. Inclut ce qu'il vaut mieux **ne pas** faire. |
| [**specs/DEEP_LINKS.md**](specs/DEEP_LINKS.md) | Spécification du schéma d'URL `hydrobar://` — **implémentée** : grammaire, sécurité, `x-callback-url`, codes d'erreur, code Swift et tests. |

## Par où commencer

1. **Le résumé exécutif** de l'audit (3 paragraphes) donne l'état des lieux.
2. **Les points P0** sont les seuls à traiter en urgence. Sur les 6 d'origine :
   P0-1 (deep links) et P0-2 (crash) sont corrigés ; P0-4 et P0-5 se sont révélés
   erronés ou sans impact à la vérification du `.pbxproj`, et sont conservés barrés
   plutôt qu'effacés pour que la correction reste traçable. Restent **P0-3**
   (Focus Mode sans autorisation) et **P0-6** (cible macOS du widget).
3. **La roadmap** : F1, F3 et F18 sont livrées. Les meilleurs rapports valeur /
   effort encore ouverts sont F19 (snooze, ~3 h) et F20 (raccourcis globaux, ~4 h) ;
   F2 (App Intents) est le prochain gros morceau.

## Conventions

- Les références de code sont au format `Fichier.swift:ligne`, recalées sur l'état
  courant de la branche. Elles se périment au premier refactor : les vérifier avant
  de s'y fier, et les recaler en même temps que le code.
- Les renvois croisés entre documents sont des liens : un point d'audit cité dans la
  roadmap pointe vers son explication détaillée.
- Ces documents sont un **état des lieux daté**, pas une vérité permanente. À
  actualiser au fil des corrections — un audit périmé est pire que pas d'audit.
