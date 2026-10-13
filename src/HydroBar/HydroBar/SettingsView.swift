//
//  SettingsView.swift
//  HydroBar
//
//  Created by Antoine DX on 13/01/2026.
//
//  Réglages : les onglets et les briques communes aux pages. Chaque page a
//  son fichier (GeneralSettingsPage, HydrationSettingsPage,
//  RemindersSettingsPage, ShortcutsSettingsPage), les aperçus sont dans
//  SettingsPreviews.swift et la fenêtre dans SettingsWindowController.swift.
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

    /// Chaque langue dans sa propre langue, comme dans Réglages Système.
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

// MARK: - Page

enum SettingsLayout {
    /// Largeur de la fenêtre, la même pour toutes les pages : seule la
    /// hauteur suit le contenu.
    static let pageWidth: CGFloat = 540
    static let pageMargin: CGFloat = 18
    static let cardSpacing: CGFloat = 12
    /// Retrait du contenu d'une carte, et des titres au-dessus d'elle.
    static let rowInset: CGFloat = 14
    static let rowPadding: CGFloat = 6
    static let rowMinHeight: CGFloat = 32
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

/// Une page de réglages : des cartes de verre empilées sur le matériau de la
/// fenêtre, avec les contrôles natifs teintés du bleu de l'eau.
struct SettingsPage<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.settingsPageMetrics) private var metrics
    @State private var isScrolled = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsLayout.cardSpacing) {
                content
            }
            .padding(SettingsLayout.pageMargin)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .labeledContentStyle(SettingsRowStyle())
        .toggleStyle(SettingsSwitchStyle())
        .tint(Theme.water)
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

// MARK: - Verre

/// Surface d'une carte : une vitre plus claire posée sur le matériau de la
/// fenêtre, coins continus, et le liseré du verre de HydroBar (reflet clair
/// en haut, filet intérieur, ombre douce). Les valeurs sont dans `Theme.Glass`.
///
/// Le flou vient de la fenêtre (NSVisualEffectView, derrière la fenêtre) :
/// la carte ne le refait pas. Un `Material` SwiftUI par-dessus floutait une
/// seconde fois ce qui l'est déjà et ramenait sa propre teinte grise ; un
/// simple voile laisse passer la couleur du bureau, comme le verre du site.
struct GlassSurface: ViewModifier {
    var cornerRadius: CGFloat = Theme.Radius.card

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                // L'ombre ne tombe qu'autour de la carte : sous un voile
                // translucide, elle l'assombrirait de l'intérieur.
                shape
                    .fill(.black)
                    .shadow(color: Theme.Glass.shadow, radius: Theme.Glass.shadowRadius, y: Theme.Glass.shadowOffset)
                    .mask {
                        Rectangle()
                            .padding(-3 * Theme.Glass.shadowRadius)
                            .overlay(shape.blendMode(.destinationOut))
                            .compositingGroup()
                    }
                shape.fill(Theme.Glass.veil)
            }
            .overlay {
                shape.strokeBorder(Theme.Glass.rimHairline, lineWidth: Theme.Glass.rimWidth)
            }
            .overlay {
                // Le reflet ne tient que le bord supérieur : il s'éteint dans
                // le premier tiers de la carte.
                shape
                    .strokeBorder(LinearGradient(colors: [Theme.Glass.rimHighlight, Theme.Glass.rimHighlight.opacity(0)],
                                                 startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.35)),
                                  lineWidth: Theme.Glass.rimWidth)
            }
    }
}

/// Une carte de réglages : un titre discret, des lignes séparées par un
/// filet, un texte d'aide dessous.
struct SettingsCard<Content: View>: View {
    var title: Text?
    var footer: Text?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                title
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, SettingsLayout.rowInset)
            }

            VStack(alignment: .leading, spacing: 0) {
                Group(subviews: content) { rows in
                    ForEach(rows) { row in
                        if row.id != rows.first?.id {
                            Rectangle()
                                .fill(Theme.Glass.separator)
                                .frame(height: 1)
                                .padding(.horizontal, SettingsLayout.rowInset)
                        }
                        row
                            .padding(.horizontal, SettingsLayout.rowInset)
                            .padding(.vertical, SettingsLayout.rowPadding)
                            .frame(maxWidth: .infinity, minHeight: SettingsLayout.rowMinHeight, alignment: .leading)
                    }
                }
            }
            .modifier(GlassSurface())

            if let footer {
                footer
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, SettingsLayout.rowInset)
            }
        }
    }
}

// MARK: - Lignes

/// Ligne d'une carte : libellé à gauche, contrôle à droite. Un second texte
/// dans le libellé devient le sous-titre de la ligne.
struct SettingsRowStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Group(subviews: configuration.label) { parts in
                    if let title = parts.first {
                        title
                        ForEach(parts.dropFirst()) { detail in
                            detail
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            configuration.content
        }
    }
}

/// Interrupteur d'une carte : le libellé à gauche, l'interrupteur natif au
/// bout de la ligne.
struct SettingsSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        LabeledContent {
            Toggle(isOn: configuration.$isOn) {
                EmptyView()
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .labelsHidden()
        } label: {
            configuration.label
        }
        // Un seul élément pour VoiceOver : le libellé de la ligne, porté par
        // l'interrupteur.
        .accessibilityElement(children: .combine)
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
    var fieldWidth = SettingsLayout.amountFieldWidth
    var showsUnit = true
    var isBordered = true
    let onCommit: (Double) -> Void

    var body: some View {
        let unit = manager.selectedUnit
        ValidatedNumberField(
            value: unit.fromMl(valueMl),
            range: unit.fromMl(rangeMl.lowerBound)...unit.fromMl(rangeMl.upperBound),
            format: { NumberInput.fieldText($0, fractionDigits: unit.inputFractionDigits) },
            alignment: .trailing,
            fieldWidth: fieldWidth,
            suffix: showsUnit ? unit.symbol : nil,
            isBordered: isBordered,
            onCommit: { onCommit(manager.mlValue(from: $0)) }
        )
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
    static func label(for hour: Int) -> String {
        // 24 = minuit de fin de journée, affiché comme 0 h.
        let normalized = hour == 24 ? 0 : hour
        guard let date = Calendar.current.date(bySettingHour: normalized, minute: 0, second: 0, of: Date()) else {
            return String(format: "%02d:00", normalized)
        }
        return date.formatted(.dateTime.hour().minute())
    }
}
