//
//  HydroBarTests.swift
//  HydroBarTests
//
//  Created by Antoine DX on 13/01/2026.
//
//  Les suites réelles vivent dans des fichiers dédiés :
//  - AppUnitTests           : conversions et formatage des unités
//  - DeepLinkParserTests    : parsing du schéma hydrobar://
//  - HydrationPaceTests     : calcul de l'allure attendue
//  - HydrationStatsTests    : série de jours consécutifs, total hebdomadaire
//  - NumberInputTests       : lecture des nombres saisis selon la locale
//  - UpdateAndWidgetTests   : comparaison de versions, instantané du widget
//
//  Reste à couvrir (cf. docs/AUDIT_TECHNIQUE.md § P3-1) : la bascule de jour
//  et la persistance. Elles demandent d'injecter UserDefaults, FileManager et
//  Date() dans HydrationManager, un singleton qui les lit en dur.
//
