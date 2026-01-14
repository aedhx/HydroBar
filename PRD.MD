PARTIE 1 : PRD - Product Requirements Document (Mise à jour v2.0)

Application : Hydrobar
Version : 2.0
Date : 13 Janvier 2026
Type : Application macOS Native (SwiftUI / AppKit)

1. Vue d'ensemble (Scope Update)

Hydrobar est une application de barre de menu "furtive" (sans Dock icon). La version 2.0 met l'accent sur la personnalisation (unités, taille des verres) et introduit des interactions ludiques ("Hold to add") tout en conservant les fonctionnalités de suivi statistique.

2. Exigences Fonctionnelles (Mises à jour)

2.1. Cœur de l'application & Données

Unités Multiples : L'utilisateur peut choisir entre Millilitres (ml), Centilitres (cl) et Onces (oz).

Vérité Terrain : Toutes les données sont stockées en ml en interne. La conversion est purement visuelle.

Persistance :

Paramètres simples (Unités, Objectif, Presets) -> UserDefaults / @AppStorage.

Historique de consommation -> Fichier JSON local dans Application Support.

2.2. Interface Principale (Main Popover)

Jauge Circulaire : Affiche la progression du jour et le pourcentage.

Navigation : Header minimaliste avec boutons pour aller aux "Stats" (gauche) et "Réglages" (droite).

Grille d'Actions Rapides : 3 boutons correspondant aux presets configurés par l'utilisateur.

Interaction "Hold to Add" : Un bouton large situé sous la grille. Tant que l'utilisateur maintient le clic, la jauge se remplit progressivement (ex: +5ml toutes les 0.05s) avec un retour haptique.

Reset Rapide : Un bouton textuel discret avec icône ("Reset my day") situé tout en bas de la vue. Demande confirmation avant remise à zéro.

2.3. Réglages (Settings View)

Sélecteur d'Unité : Segmented Control (ML / CL / OZ).

Configuration Objectif : Champ numérique pour l'objectif quotidien.

Configuration Presets : 3 champs numériques pour modifier la valeur des boutons rapides de la vue principale.

Notifications :

Toggle général "Activer les rappels".

Sélecteur d'intervalle : "30 min", "2 heures", "Personnalisé" (champ libre).

Toggle "Mode Ne pas déranger" (DND).

2.4. Statistiques (Stats View)

Graphique Hebdomadaire : Bar chart simple des 7 derniers jours.

Indicateurs : Barre verte si objectif atteint, bleue sinon.

Streak : Affichage de la série de jours consécutifs atteints.