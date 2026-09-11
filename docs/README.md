# Documentation technique — HydroBar

| Document | Contenu |
|---|---|
| [**AUDIT_TECHNIQUE.md**](AUDIT_TECHNIQUE.md) | Revue de code complète : 32 points classés P0 → P4, avec référence fichier:ligne, impact et correctif proposé. Se termine par un plan d'action en 6 lots. |
| [**ROADMAP_FONCTIONNALITES.md**](ROADMAP_FONCTIONNALITES.md) | 16 propositions de fonctionnalités classées valeur / effort, séquencées en versions v1.3 → v1.6. Inclut ce qu'il vaut mieux **ne pas** faire. |
| [**specs/DEEP_LINKS.md**](specs/DEEP_LINKS.md) | Spécification implémentable du schéma d'URL `hydrobar://` : grammaire, sécurité, `x-callback-url`, codes d'erreur, code Swift et tests. |

## Par où commencer

1. **Le résumé exécutif** de l'audit (3 paragraphes) donne l'état des lieux.
2. **Les 6 points P0** sont les seuls à traiter en urgence — dont trois
   fonctionnalités documentées qui ne fonctionnent pas, et un crash potentiel
   déclenchable depuis les réglages.
3. **La spec deep links** est directement exécutable : c'est le lot 2 de l'audit et
   la fonctionnalité F1 de la roadmap — le même chantier, vu des deux côtés.

## Conventions

- Les références de code sont au format `Fichier.swift:ligne`, sur le commit
  `c84b203` (v1.2).
- Les renvois croisés entre documents sont des liens : un point d'audit cité dans la
  roadmap pointe vers son explication détaillée.
- Ces documents sont un **état des lieux daté**, pas une vérité permanente. À
  actualiser au fil des corrections — un audit périmé est pire que pas d'audit.
