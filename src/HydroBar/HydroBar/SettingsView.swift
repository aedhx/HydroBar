//
//  SettingsView.swift
//  HydroBar
//
//  Created by Antoine DX on 13/01/2026.
//
//  Réglages : les onglets et les briques communes aux pages. Chaque page a
//  son fichier (GeneralSettingsPage, HydrationSettingsPage,
//  RemindersSettingsPage, ShortcutsSettingsPage) ; la fenêtre est dans
//  SettingsWindowController.swift.
//
import SwiftUI

// MARK: - AppLanguage Enum
enum AppLanguage: String, CaseIterable {
    case system = "system"
    case english = "en"
    case french = "fr"
    case spanish = "es"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case dutch = "nl"
    case japanese = "ja"
    case chinese = "zh-Hans"
    
    var displayName: String {
        switch self {
        case .system:
            return String(localized: "System", comment: "System language option")
        case .english:
            return "English"
        case .french:
            return "Français"
        case .spanish:
            return "Español"
        case .german:
            return "Deutsch"
        case .italian:
            return "Italiano"
        case .portuguese:
            return "Português"
        case .dutch:
            return "Nederlands"
        case .japanese:
            return "日本語"
        case .chinese:
            return "简体中文"
        }
    }
    
    var flagEmoji: String {
        switch self {
        case .system:
            return "🌐"
        case .english:
            return "🇬🇧"
        case .french:
            return "🇫🇷"
        case .spanish:
            return "🇪🇸"
        case .german:
            return "🇩🇪"
        case .italian:
            return "🇮🇹"
        case .portuguese:
            return "🇵🇹"
        case .dutch:
            return "🇳🇱"
        case .japanese:
            return "🇯🇵"
        case .chinese:
            return "🇨🇳"
        }
    }
    
    var countryName: String {
        switch self {
        case .system:
            return String(localized: "System", comment: "System language option")
        case .english:
            return "United Kingdom"
        case .french:
            return "France"
        case .spanish:
            return "España"
        case .german:
            return "Deutschland"
        case .italian:
            return "Italia"
        case .portuguese:
            return "Portugal"
        case .dutch:
            return "Nederland"
        case .japanese:
            return "日本"
        case .chinese:
            return "中国"
        }
    }
    
    var fullDisplayName: String {
        if self == .system {
            return "\(flagEmoji) \(countryName)"
        }
        return "\(flagEmoji) \(countryName) (\(displayName))"
    }
}

enum NotificationInterval: String, CaseIterable {
    case thirtyMinutes = "30 min"
    case twoHours = "2 h"
    case custom = "Perso"
    
    var localizedString: String {
        switch self {
        case .thirtyMinutes:
            return String(localized: "30 min", comment: "30 minutes notification interval")
        case .twoHours:
            return String(localized: "2 h", comment: "2 hours notification interval")
        case .custom:
            return String(localized: "Custom", comment: "Custom notification interval")
        }
    }
}

// MARK: - Onglets

/// Onglets de la fenêtre de réglages. Sept onglets de texte ne tenaient plus
/// dans la barre : il en reste quatre, avec icône, comme dans Safari ou Mail.
enum SettingsTab: String, CaseIterable {
    case general, hydration, reminders, shortcuts

    /// Onglet mémorisé à la dernière fermeture. Il peut porter le nom d'un
    /// des sept anciens onglets : on ouvre alors celui qui a repris son contenu.
    init(storedValue: String?) {
        switch storedValue {
        case "data":         self = .general
        case "days":         self = .reminders
        case "integrations": self = .shortcuts
        default:             self = storedValue.flatMap(SettingsTab.init(rawValue:)) ?? .general
        }
    }

    var title: String {
        switch self {
        case .general:   return String(localized: "General", comment: "Settings tab")
        case .hydration: return String(localized: "Hydration", comment: "Settings tab")
        case .reminders: return String(localized: "Reminders", comment: "Settings tab")
        case .shortcuts: return String(localized: "Shortcuts", comment: "Settings tab: keyboard shortcuts and integrations")
        }
    }

    var symbolName: String {
        switch self {
        case .general:   return "gearshape"
        case .hydration: return "drop"
        case .reminders: return "bell"
        case .shortcuts: return "keyboard"
        }
    }

    @ViewBuilder
    func page(manager: HydrationManager) -> some View {
        switch self {
        case .general:   GeneralSettingsPage(manager: manager)
        case .hydration: HydrationSettingsPage(manager: manager)
        case .reminders: RemindersSettingsPage(manager: manager)
        case .shortcuts: ShortcutsSettingsPage(manager: manager)
        }
    }
}

// MARK: - Briques communes aux pages

enum SettingsLayout {
    /// Largeur de la fenêtre, la même pour toutes les pages : seule la
    /// hauteur suit le contenu.
    static let pageWidth: CGFloat = 540
    static let amountFieldWidth: CGFloat = 72
}

/// Pont SwiftUI → AppKit : la page annonce la hauteur de son contenu au
/// contrôleur, qui ajuste celle de la fenêtre.
final class SettingsPageMetrics {
    var onContentHeightChange: ((CGFloat) -> Void)?
}

private struct SettingsPageMetricsKey: EnvironmentKey {
    static let defaultValue: SettingsPageMetrics? = nil
}

extension EnvironmentValues {
    var settingsPageMetrics: SettingsPageMetrics? {
        get { self[SettingsPageMetricsKey.self] }
        set { self[SettingsPageMetricsKey.self] = newValue }
    }
}

/// Une page de réglages : formulaire groupé, comme dans Réglages Système,
/// posé sur le matériau de la fenêtre.
struct SettingsPage<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.settingsPageMetrics) private var metrics
    @State private var isScrolled = false

    var body: some View {
        Form {
            content
        }
        .formStyle(.grouped)
        // Le fond opaque du formulaire masquerait le matériau de la fenêtre.
        .scrollContentBackground(.hidden)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentSize.height
        } action: { _, height in
            metrics?.onContentHeightChange?(height)
        }
        // La barre d'outils est transparente : dès que la page défile, un
        // filet marque l'endroit où le contenu disparaît.
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 0.5
        } action: { _, scrolled in
            isScrolled = scrolled
        }
        .overlay(alignment: .top) {
            Divider().opacity(isScrolled ? 1 : 0)
        }
        .frame(width: SettingsLayout.pageWidth)
    }
}

/// Texte d'aide sous une section. Sans cadre, macOS l'aligne à droite.
struct SettingsFooter: View {
    let text: Text

    init(_ text: Text) {
        self.text = text
    }

    var body: some View {
        text
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Le retrait du texte des lignes, dans leur cadre.
            .padding(.horizontal, 10)
    }
}

extension View {
    /// Centre un contrôle sur le libellé de sa ligne. Un formulaire aligne les
    /// deux sur leur ligne de base, et celle d'un champ de saisie à bordure
    /// tombe quelques points trop bas : le libellé remontait, et la ligne
    /// devenait plus haute que ses voisines.
    func centeredOnRowLabel() -> some View {
        alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
    }
}

/// Ligne qui ouvre un réglage du système. `isWarning` : quelque chose empêche
/// une option de fonctionner, et le lien mène à l'endroit où le corriger.
struct SettingsLink: View {
    let title: Text
    var isWarning = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if isWarning {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.warning)
                }
                title
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .buttonStyle(.link)
    }
}

/// Avertissement sans action possible : le message du système, tel quel.
struct SettingsWarning: View {
    let message: String

    var body: some View {
        Label {
            Text(message)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .foregroundStyle(Theme.warning)
    }
}

/// Quantité saisie dans l'unité affichée, suivie de son symbole. Les bornes
/// et la valeur validée sont en millilitres.
struct AmountField: View {
    @ObservedObject var manager: HydrationManager
    let valueMl: Double
    let rangeMl: ClosedRange<Double>
    let onCommit: (Double) -> Void

    var body: some View {
        let unit = manager.selectedUnit
        ValidatedNumberField(
            value: unit.fromMl(valueMl),
            range: unit.fromMl(rangeMl.lowerBound)...unit.fromMl(rangeMl.upperBound),
            format: { NumberInput.fieldText($0, fractionDigits: unit.inputFractionDigits) },
            alignment: .trailing,
            fieldWidth: SettingsLayout.amountFieldWidth,
            suffix: unit.symbol,
            onCommit: { onCommit(manager.mlValue(from: $0)) }
        )
        .centeredOnRowLabel()
    }
}

/// Plage horaire : deux menus, l'heure de fin toujours après celle de début.
struct HourRangePicker: View {
    @Binding var start: Int
    @Binding var end: Int

    var body: some View {
        HStack(spacing: 8) {
            Picker(selection: $start) {
                ForEach(HydrationPace.selectableStartHours, id: \.self) { hour in
                    Text(verbatim: Self.label(for: hour)).tag(hour)
                }
            } label: {
                EmptyView()
            }
            Text("to", comment: "Separator between start and end hour")
                .foregroundStyle(.secondary)
            Picker(selection: $end) {
                ForEach(HydrationPace.selectableEndHours.filter { $0 > start }, id: \.self) { hour in
                    Text(verbatim: Self.label(for: hour)).tag(hour)
                }
            } label: {
                EmptyView()
            }
        }
        .labelsHidden()
        .fixedSize()
    }

    /// Heure formatée selon la locale (« 8 AM » ou « 08:00 » selon la région).
    private static func label(for hour: Int) -> String {
        // 24 = minuit de fin de journée, affiché comme 0 h.
        let normalized = hour == 24 ? 0 : hour
        guard let date = Calendar.current.date(bySettingHour: normalized, minute: 0, second: 0, of: Date()) else {
            return String(format: "%02d:00", normalized)
        }
        return date.formatted(.dateTime.hour().minute())
    }
}
