# Documentation technique — HydroBar

| Document | Contenu |
|---|---|
| [**AUDIT_TECHNIQUE.md**](AUDIT_TECHNIQUE.md) | Revue de code complète : 32 points classés P0 → P4, une **revue n°2** (octobre 2026) de 13 points, et la **revue n°3** — la passe de corrections, avec les 14 défauts qu'elle a trouvés. Chaque point porte son statut et le commit qui le corrige ; les points corrigés sont conservés, pas effacés. |
| [**ROADMAP_FONCTIONNALITES.md**](ROADMAP_FONCTIONNALITES.md) | 21 propositions classées valeur / effort, séquencées v1.3 → v1.6, avec **ce qui est intégrable aujourd'hui** et ce qui bloque le reste. Inclut ce qu'il vaut mieux **ne pas** faire. |
| [**specs/DEEP_LINKS.md**](specs/DEEP_LINKS.md) | Spécification du schéma d'URL `hydrobar://` — **implémentée** : grammaire, sécurité, `x-callback-url`, codes d'erreur, code Swift et tests. |

## Par où commencer

1. **La revue n°3** de l'audit donne l'état actuel : tous les constats sont
   corrigés, sauf l'injection de dépendances de `HydrationManager` (seconde
   moitié de P3-1) et les étapes liées au compte Apple.
2. **Étapes manuelles restantes** : capability Communication Notifications dans
   Xcode (P0-3), certificat Developer ID et notarisation (P3-6), vérification de
   l'App Group avec le Team ID (R3-3).
3. **Périmètre** : macOS uniquement. iOS et l'intégration Santé sont hors
   périmètre pour l'instant.
4. **La roadmap** : F1, F3 et F18 sont livrées. Les meilleurs rapports valeur /
   effort encore ouverts sont F19 (snooze, ~3 h) et F20 (raccourcis globaux, ~4 h) ;
   F2 (App Intents) est le prochain gros morceau. F12 (Sparkle) et F13 (Homebrew)
   sont débloquées dès que le certificat Developer ID est en place.

## Conventions

- Les références de code sont au format `Fichier.swift:ligne`. Pour un point
  **corrigé**, elles désignent le code tel qu'il était au moment du constat — le
  commit cité dans son statut montre ce qui l'a remplacé. Pour un point ouvert,
  les vérifier avant de s'y fier.
- Les renvois croisés entre documents sont des liens : un point d'audit cité dans la
  roadmap pointe vers son explication détaillée.
- Ces documents sont un **état des lieux daté**, pas une vérité permanente. À
  actualiser au fil des corrections — un audit périmé est pire que pas d'audit.
