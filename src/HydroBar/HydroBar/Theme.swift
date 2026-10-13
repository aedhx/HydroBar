//
//  Theme.swift
//  HydroBar
//
//  Jetons de design : couleurs sémantiques, typographie, rayons, animations.
//  Avant, 127 tailles de police et une vingtaine de couleurs étaient écrites en
//  dur dans les vues, avec deux bleus différents pour la même eau. Une valeur
//  se change désormais ici, une fois.
//
//  Les couleurs sont celles du système : elles s'adaptent au mode sombre et au
//  contraste augmenté, contrairement aux valeurs RVB qu'elles remplacent.
//

import SwiftUI
import AppKit

enum Theme {

    // MARK: - Couleurs

    /// L'eau : progression, presets, graphiques.
    static let water = Color.blue
    static let waterLight = Color.cyan
    /// Objectif atteint.
    static let goal = Color.green
    static let goalLight = Color.mint
    /// En retard sur l'allure, avertissements.
    static let warning = Color.orange
    /// Pastille de rappel.
    static let alert = Color.red
    /// Piste vide de l'anneau.
    static let track = Color.gray.opacity(0.3)
    /// Fond des boutons de preset.
    static let presetFill = water.opacity(0.1)

    /// Équivalents AppKit, pour les vues dessinées à la main.
    enum NS {
        static let water = NSColor.systemBlue
        static let goal = NSColor.systemGreen
    }

    // MARK: - Typographie
    //
    // Valeurs reprises à l'identique des vues : l'introduction des jetons ne
    // change rien à l'écran. Les noms disent le rôle, pas la taille.

    enum Font {
        /// Gros chiffre au centre de l'anneau.
        static let ringValue = SwiftUI.Font.system(size: 32, weight: .bold, design: .rounded)
        /// Valeur des cartes de statistiques.
        static let kpiValue = SwiftUI.Font.system(size: 24, weight: .bold, design: .rounded)
        /// Légendes sous le chiffre de l'anneau.
        static let ringCaption = SwiftUI.Font.system(size: 11, weight: .medium, design: .rounded)
        static let ringFootnote = SwiftUI.Font.system(size: 10, weight: .medium, design: .rounded)

        static let control = SwiftUI.Font.system(size: 14)
        static let controlMedium = SwiftUI.Font.system(size: 14, weight: .medium)

        static let body = SwiftUI.Font.system(size: 13)
        static let bodyMedium = SwiftUI.Font.system(size: 13, weight: .medium)
        static let bodyEmphasis = SwiftUI.Font.system(size: 13, weight: .semibold)

        static let callout = SwiftUI.Font.system(size: 12)
        static let calloutMedium = SwiftUI.Font.system(size: 12, weight: .medium)
        static let calloutEmphasis = SwiftUI.Font.system(size: 12, weight: .semibold)

        static let caption = SwiftUI.Font.system(size: 11)
        static let captionMedium = SwiftUI.Font.system(size: 11, weight: .medium)
        /// Titres de section en capitales des réglages.
        static let sectionTitle = SwiftUI.Font.system(size: 11, weight: .semibold)

        static let footnote = SwiftUI.Font.system(size: 10)
        static let footnoteEmphasis = SwiftUI.Font.system(size: 10, weight: .semibold)
        static let micro = SwiftUI.Font.system(size: 9)

        static let mono = SwiftUI.Font.system(size: 12, design: .monospaced)
    }

    // MARK: - Formes

    enum Radius {
        static let control: CGFloat = 8
        static let row: CGFloat = 6
        static let card: CGFloat = 12
        static let popover: CGFloat = 16
    }

    // MARK: - Espacements
    //
    // Une marge et un rythme vertical, d'abord pour les statistiques : leurs
    // blocs avaient chacun leur retrait (16 ou 20 pt) et leurs écarts (de 2 à
    // 16 pt), et rien ne tombait sur la même ligne.

    enum Spacing {
        /// Marge du contenu : tout bloc commence et finit là.
        static let inset: CGFloat = 20
        /// Entre deux sections.
        static let section: CGFloat = 20
        /// Entre un titre de section et son contenu, ou entre deux éléments
        /// d'un même bloc (grille et légende, phrase et graphique).
        static let title: CGFloat = 8
        /// Entre deux tuiles côte à côte.
        static let tile: CGFloat = 12
        /// Entre les cases de la heatmap. Avec la marge ci-dessus, le contenu
        /// fait 280 pt : 7 cases de 34 pt et 6 écarts de 7 pt, au pixel près
        /// même sur un écran non Retina. À 4 pt, la largeur ne se divisait pas :
        /// les cases faisaient 36 ou 37 pt selon la colonne.
        static let cell: CGFloat = 7
    }

    // MARK: - Animations
    //
    // Toutes passent par `motion(_:reduceMotion:)` : avec « Réduire les
    // animations », elles deviennent instantanées.

    enum Motion {
        /// Remplissage de l'anneau : léger dépassement à l'arrivée.
        static let ring = Animation.spring(response: 0.55, dampingFraction: 0.68)
        /// Chiffres qui roulent, lignes du journal.
        static let snappy = Animation.snappy(duration: 0.35)
        static let quick = Animation.easeOut(duration: 0.2)
    }

    static func motion(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}
