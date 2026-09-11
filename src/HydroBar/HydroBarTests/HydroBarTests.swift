//
//  HydroBarTests.swift
//  HydroBarTests
//
//  Created by Antoine DX on 13/01/2026.
//
//  Les suites réelles vivent dans des fichiers dédiés :
//  - DeepLinkParserTests    : parsing du schéma hydrobar://
//  - HydrationPaceTests     : calcul de l'allure attendue
//
//  Reste à couvrir (cf. docs/AUDIT_TECHNIQUE.md § P3-1) : les conversions
//  d'unités, la série de jours consécutifs et le reset quotidien. Ils
//  demandent d'abord d'injecter UserDefaults, FileManager et Date() dans
//  HydrationManager, aujourd'hui un singleton qui les lit en dur.
//
