import Foundation
import SwiftUI
import AppKit
import UserNotifications
import WidgetKit
import Combine
import os

// MARK: - Formatage de dates

/// Formateur ISO 8601 partagé. `ISO8601DateFormatter()` est coûteux à instancier
/// et il était recréé à chaque appel — y compris dans le chemin chaud d'`addWater`,
/// donc 20 fois par seconde pendant « Hold to Add »
/// (cf. docs/AUDIT_TECHNIQUE.md § P2-5).
enum DateFormat {
    static let iso8601 = ISO8601DateFormatter()
}

// MARK: - HistoryEntry
struct HistoryEntry: Codable, Identifiable {
    let id: String
    let date: Date
    let amountMl: Double
    let targetMl: Double
    
    init(date: Date, amountMl: Double, targetMl: Double) {
        self.id = DateFormat.iso8601.string(from: date)
        self.date = date
        self.amountMl = amountMl
        self.targetMl = targetMl
    }
}

// MARK: - MenuBarIconStyle Enum
enum MenuBarIconStyle: String, CaseIterable, Codable {
    // Valeurs brutes stockées dans les préférences : ne pas les traduire ni
    // les renommer. L'affichage passe par `localizedName`.
    case pieRing = "Pie Ring"
    case percentage = "Percentage"

    var localizedName: String {
        switch self {
        case .pieRing:    return String(localized: "Pie Ring", comment: "Menu bar icon style: progress ring")
        case .percentage: return String(localized: "Percentage", comment: "Menu bar icon style: percentage text")
        }
    }
}

// `AppUnit` est défini dans AppGroupStore.swift, partagé avec le widget.

// MARK: - Presets

/// Encodage des presets dans UserDefaults. Remplace une conformance rétroactive
/// `Array: RawRepresentable` — qui changeait la sémantique de *tout* `[Double]`
/// du projet et pouvait entrer en conflit avec une future conformance d'Apple
/// (cf. AUDIT_TECHNIQUE.md § P1-6).
enum PresetStorage {
    static let defaults: [Double] = [200, 500, 750]

    static func decode(_ raw: String) -> [Double] {
        guard let data = raw.data(using: .utf8),
              let values = try? JSONDecoder().decode([Double].self, from: data),
              !values.isEmpty
        else { return defaults }
        return values
    }

    static func encode(_ values: [Double]) -> String {
        guard let data = try? JSONEncoder().encode(values),
              let raw = String(data: data, encoding: .utf8)
        else { return "[]" }
        return raw
    }
}

// MARK: - HydrationManager
class HydrationManager: ObservableObject {
    static let shared = HydrationManager()
    
    // MARK: - AppStorage Properties
    @AppStorage("targetMl") private var storedTargetMl: Double = 2000.0
    @AppStorage("selectedUnit") private var storedSelectedUnitRaw: String = AppUnit.cl.rawValue
    @AppStorage("presetsMl") private var storedPresetsMlRaw: String = "[200.0, 500.0, 750.0]" // Toujours en ml en interne
    @AppStorage("lastResetDate") private var lastResetDateString: String = ""
    /// Total du jour de la v1. Lu une seule fois, par la migration vers le journal.
    @AppStorage("currentMl") private var storedCurrentMl: Double = 0.0
    // MARK: - Réglages publiés
    //
    // `@AppStorage` est conçu pour les vues : dans un `ObservableObject`, il lit et
    // écrit correctement UserDefaults mais n'émet AUCUN `objectWillChange`. Les
    // vues ne voyaient donc pas les changements de réglages, et l'app compensait
    // par des minuteurs de rafraîchissement — dont celui qui reconstruisait
    // l'icône de la barre de menu deux fois par seconde (cf. AUDIT § P1-1, P2-1).
    // Chaque réglage lu par une vue émet donc explicitement, AVANT le changement,
    // comme l'exige le contrat d'ObservableObject.

    @AppStorage("notificationsEnabled") var notificationsEnabled: Bool = false {
        willSet { objectWillChange.send() }
        didSet {
            scheduleNotifications()
            if notificationsEnabled {
                checkReminderStatus()
            } else {
                showReminderBadge = false
            }
        }
    }
    @AppStorage("notificationInterval") private var storedNotificationInterval: String = NotificationInterval.thirtyMinutes.rawValue
    @AppStorage("customNotificationMinutes") var customNotificationMinutes: Int = 60 {
        willSet { objectWillChange.send() }
    }
    /// Mode « Ne pas déranger » choisi par l'utilisateur. C'est une intention :
    /// la synchronisation avec Concentration ne l'écrit jamais. L'état effectif
    /// est `isQuietMode` (cf. AUDIT § P1-7).
    @AppStorage("doNotDisturb") var doNotDisturb: Bool = false {
        willSet { objectWillChange.send() }
        didSet {
            guard oldValue != doNotDisturb else { return }
            quietModeDidChange()
        }
    }

    /// Un mode de concentration macOS est actif. Renseigné par
    /// `FocusModeMonitor` quand la synchronisation est activée, jamais persisté.
    @Published private(set) var focusIsActive = false

    /// Les rappels prennent la forme d'une pastille plutôt que d'une
    /// notification système. Le mode DnD ne désactive pas les rappels.
    var isQuietMode: Bool {
        doNotDisturb || (focusModeAutoSync && focusIsActive)
    }

    /// Jusqu'ici la synchro Concentration écrivait `doNotDisturb`, et
    /// l'interrupteur manuel était désactivé pendant ce temps : avec la synchro
    /// active, la valeur stockée vient du Focus, pas de l'utilisateur. On la
    /// remet à zéro une fois, sinon un Focus en cours lors de la mise à jour
    /// laisserait le DnD allumé indéfiniment.
    private static func migrateFocusOwnedDoNotDisturb() {
        let defaults = UserDefaults.standard
        let key = "migration.focusOwnedDoNotDisturb"
        guard !defaults.bool(forKey: key) else { return }
        if defaults.bool(forKey: "focusModeAutoSync") {
            defaults.set(false, forKey: "doNotDisturb")
        }
        defaults.set(true, forKey: key)
    }

    /// Point d'entrée unique de `FocusModeMonitor`. Auparavant le moniteur
    /// écrivait `doNotDisturb` — le réglage de l'utilisateur — en coupant puis
    /// rétablissant la synchronisation pour éviter une cascade de didSet ; la fin
    /// d'une concentration effaçait aussi un DnD activé à la main.
    func setFocusActive(_ active: Bool) {
        guard focusIsActive != active else { return }
        let wasQuiet = isQuietMode
        focusIsActive = active
        if isQuietMode != wasQuiet { quietModeDidChange() }
    }

    private func quietModeDidChange() {
        guard notificationsEnabled else { return }
        scheduleNotifications()
        checkReminderStatus()
    }

    @AppStorage("focusModeAutoSync") var focusModeAutoSync: Bool = false {
        willSet { objectWillChange.send() }
        didSet {
            guard oldValue != focusModeAutoSync else { return }
            // Lu avant setAutoSync, qui remet focusIsActive à false à la désactivation.
            let focusWasSilencing = focusIsActive && !doNotDisturb
            FocusModeMonitor.shared.setAutoSync(focusModeAutoSync)
            if focusWasSilencing { quietModeDidChange() }
        }
    }

    /// La langue s'applique au prochain lancement : l'app lit `AppleLanguages`
    /// au démarrage. Voir le sélecteur de langue dans les réglages.
    @AppStorage("appLanguage") var appLanguage: String = "system" {
        willSet { objectWillChange.send() }
        didSet { Self.applyLanguagePreference(appLanguage) }
    }

    /// Écrit la préférence que le système lit au lancement. Revenir à « Système »
    /// doit effacer la surcharge : l'ancien code ne l'effaçait jamais, et l'app
    /// restait dans la dernière langue choisie.
    static func applyLanguagePreference(_ language: String) {
        if language == "system" {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([language], forKey: "AppleLanguages")
        }
    }

    @AppStorage("debugModeEnabled") var debugModeEnabled: Bool = false {
        willSet { objectWillChange.send() }
    }

    /// Autorise `hydrobar://reset` et `hydrobar://set-goal` à s'exécuter sans alerte
    /// de confirmation. Désactivé par défaut : n'importe quelle page web peut
    /// déclencher un schéma d'URL. Voir docs/specs/DEEP_LINKS.md § 4.1.
    @AppStorage("allowDestructiveDeepLinks") var allowDestructiveDeepLinks: Bool = false {
        willSet { objectWillChange.send() }
    }

    // MARK: - Plage horaire active
    // Sert au repère d'allure de l'anneau et borne les rappels (F6).

    @AppStorage("activeHoursStart") var activeHoursStart: Int = HydrationPace.defaultStartHour {
        willSet { objectWillChange.send() }
        didSet { scheduleNotifications() }
    }

    @AppStorage("activeHoursEnd") var activeHoursEnd: Int = HydrationPace.defaultEndHour {
        willSet { objectWillChange.send() }
        didSet { scheduleNotifications() }
    }

    // MARK: - Autorisation des notifications

    /// Active ou coupe les rappels. À l'activation, demande l'autorisation des
    /// notifications si elle n'a jamais été demandée — au moment où
    /// l'utilisateur en exprime le besoin, et non plus au premier lancement,
    /// avant qu'il ait compris à quoi sert l'app (roadmap F8).
    ///
    /// - Parameter completion: `false` si le système a refusé ; les rappels
    ///   restent alors coupés.
    func setRemindersEnabled(_ enabled: Bool, completion: ((Bool) -> Void)? = nil) {
        guard enabled else {
            notificationsEnabled = false
            completion?(true)
            return
        }
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            let finish: (Bool) -> Void = { granted in
                DispatchQueue.main.async {
                    self.notificationsEnabled = granted
                    completion?(granted)
                }
            }
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in finish(granted) }
            case .denied:
                finish(false)
            default:
                finish(true)
            }
        }
    }

    /// Ouvre les réglages de notifications de HydroBar dans Réglages Système.
    func openNotificationSettings() {
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(bundleID)") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Pause des rappels (F19)

    /// Fin de la pause, en secondes depuis 1970 ; 0 sans pause.
    @AppStorage("remindersSnoozedUntil") private var snoozedUntilTimestamp: Double = 0

    /// Fin de la pause en cours, ou `nil`.
    var remindersSnoozedUntil: Date? {
        snoozedUntilTimestamp > Date().timeIntervalSince1970
            ? Date(timeIntervalSince1970: snoozedUntilTimestamp)
            : nil
    }

    func snoozeReminders(_ option: SnoozeOption) {
        objectWillChange.send()
        snoozedUntilTimestamp = option.endDate(from: Date(),
                                               activeStartHour: activeHoursStart,
                                               activeEndHour: activeHoursEnd,
                                               calendar: .current).timeIntervalSince1970
        scheduleNotifications()
    }

    func resumeReminders() {
        objectWillChange.send()
        snoozedUntilTimestamp = 0
        scheduleNotifications()
    }

    /// Appelée par le minuteur et au réveil : la pause se termine seule.
    private func resumeRemindersIfSnoozeEnded() {
        guard snoozedUntilTimestamp > 0, snoozedUntilTimestamp <= Date().timeIntervalSince1970 else { return }
        resumeReminders()
    }

    /// Icône de barre de menu en couleur, comme avant la v2. Par défaut,
    /// l'icône est monochrome (« template ») et suit la barre de menu.
    @AppStorage("coloredMenuBarIcon") var coloredMenuBarIcon: Bool = false {
        willSet { objectWillChange.send() }
    }

    @AppStorage("menuBarIconStyle") var menuBarIconStyle: MenuBarIconStyle = .pieRing {
        willSet { objectWillChange.send() }
    }
    
    // MARK: - Journal des prises (F5)

    /// Source de vérité : un événement par prise. Tout le reste en est dérivé —
    /// le total du jour comme l'historique des statistiques.
    @Published private(set) var log = IntakeLog() {
        didSet { refreshDerivedState() }
    }

    private let store: IntakeLogStore

    /// Total du jour, dérivé du journal (plus l'appui long en cours). Ce n'est
    /// plus une valeur stockée : l'ancien total en cache était archivé à la
    /// bascule de jour, et c'est ce mécanisme qui a effacé l'historique au
    /// lancement et attribué des verres à la veille (cf. AUDIT § R3-1, R3-5).
    @Published private(set) var currentMl: Double = 0.0

    /// Émet la quantité de chaque prise ajoutée, quelle que soit sa source
    /// (popover, raccourci, intent, widget, deep link). L'AppDelegate s'en sert
    /// pour confirmer visuellement un ajout fait sans ouvrir le popover.
    let intakeAdded = PassthroughSubject<Double, Never>()

    /// Prises du jour, de la plus récente à la plus ancienne.
    var todayEvents: [IntakeEvent] {
        log.events(on: Date(), calendar: .current).reversed()
    }

    private func refreshDerivedState() {
        let calendar = Calendar.current
        historyEntries = log.dailyEntries(calendar: calendar, defaultGoal: targetMl)
        currentMl = log.total(on: Date(), calendar: calendar) + (holdSessionTotal ?? 0)
    }
    
    // MARK: - Journalisation et diagnostic

    private static let logger = Logger(subsystem: "com.adxcool.HydroBar", category: "hydration")

    /// Dernier problème de persistance rencontré, affiché en mode debug.
    /// Mieux vaut un message visible qu'un historique disparu sans trace.
    @Published private(set) var lastDataIssue: String?

    /// Une entrée par jour, avec l'objectif de ce jour-là. Dérivé du journal,
    /// jamais écrit directement.
    @Published private(set) var historyEntries: [HistoryEntry] = []
    @Published var showReminderBadge: Bool = false
    
    // MARK: - Undo Stack

    /// Ce qu'annuler veut dire, action par action. Privée : `MainContentView` y
    /// ajoutait directement ses entrées (cf. AUDIT § P1-3).
    private enum UndoAction {
        /// Annuler retire cette prise.
        case added(UUID)
        /// Annuler remet ces prises (suppression à l'unité, ou reset du jour).
        case removed([IntakeEvent])
    }

    private var undoStack: [UndoAction] = []
    private let maxUndoStackSize = 50

    private func pushUndo(_ action: UndoAction) {
        undoStack.append(action)
        if undoStack.count > maxUndoStackSize {
            undoStack.removeFirst()
        }
    }

    // MARK: - Session « Hold to Add »

    /// Total ajouté depuis le début de l'appui en cours ; `nil` hors appui.
    /// Pendant un appui, les effets coûteux — reprogrammation des notifications,
    /// entrée d'annulation, écriture sur disque — sont reportés à la fin, au lieu
    /// d'être répétés 20 fois par seconde (cf. AUDIT § P2-2).
    private var holdSessionTotal: Double?

    /// Total de l'appui en cours, affiché sur le bouton pendant l'appui.
    @Published private(set) var holdTotalMl: Double = 0

    func beginHoldSession() {
        holdSessionTotal = 0
        holdTotalMl = 0
    }

    /// Pendant l'appui, rien n'est écrit dans le journal : seul l'affichage
    /// suit. Le geste entier devient une seule prise à la fin.
    func addHeldWater(_ ml: Double) {
        guard let total = holdSessionTotal else { return }
        holdSessionTotal = total + ml
        holdTotalMl = total + ml
        refreshDerivedState()
    }

    /// Clôt l'appui : une seule prise dans le journal, une seule entrée
    /// d'annulation, une seule reprogrammation des notifications.
    func endHoldSession() {
        guard let total = holdSessionTotal else { return }
        holdSessionTotal = nil
        holdTotalMl = 0
        if total > 0 {
            addWater(amount: total)
        } else {
            refreshDerivedState()
        }
        flushPendingWrites()
    }

    // MARK: - Minuteurs

    /// Un seul minuteur, au lieu de deux minuteurs de 60 s distincts — chacun
    /// empêchait l'App Nap de son côté (cf. AUDIT § P2-4).
    private var minuteTimer: Timer?
    @AppStorage("lastWaterAddedDate") private var lastWaterAddedDateString: String = ""
    
    // MARK: - Computed Properties
    /// Borné à la lecture aussi : un objectif de 0 stocké par une version
    /// antérieure (cf. AUDIT § P0-2) diviserait par zéro partout où l'on
    /// calcule une progression.
    var targetMl: Double {
        get { min(max(storedTargetMl, HydrationLimits.goal.lowerBound), HydrationLimits.goal.upperBound) }
        set {
            objectWillChange.send()
            storedTargetMl = newValue
            // Le jour se juge contre l'objectif qu'il avait : on le note.
            log.setGoal(targetMl, on: Date(), calendar: .current)
            persistLog()
            syncToAppGroup()
        }
    }

    var selectedUnit: AppUnit {
        get {
            AppUnit(rawValue: storedSelectedUnitRaw) ?? .cl
        }
        set {
            objectWillChange.send()
            storedSelectedUnitRaw = newValue.rawValue
            syncToAppGroup()
        }
    }
    
    var presetsMl: [Double] {
        get {
            PresetStorage.decode(storedPresetsMlRaw)
        }
        set {
            objectWillChange.send()
            storedPresetsMlRaw = PresetStorage.encode(newValue)
            // Le widget affiche les presets de l'utilisateur.
            syncToAppGroup()
        }
    }
    
    var notificationInterval: NotificationInterval {
        get {
            NotificationInterval(rawValue: storedNotificationInterval) ?? .thirtyMinutes
        }
        set {
            objectWillChange.send()
            storedNotificationInterval = newValue.rawValue
            if notificationsEnabled {
                scheduleNotifications()
                checkReminderStatus()
            }
        }
    }
    
    // MARK: - Initialization
    private init(store: IntakeLogStore = .applicationSupport()) {
        self.store = store
        // Avant toute lecture de `doNotDisturb` (programmation des rappels).
        Self.migrateFocusOwnedDoNotDisturb()

        loadLog()
        if lastResetDateString.isEmpty || DateFormat.iso8601.date(from: lastResetDateString) == nil {
            updateLastResetDate()
        } else {
            rollOverIfNewDay()
        }
        refreshDerivedState()
        setupNotificationCategories()
        
        // Initialiser la date de dernière consommation si elle n'existe pas
        if getLastWaterAddedDate() == nil {
            updateLastWaterAddedDate()
        }
        
        if notificationsEnabled {
            scheduleNotifications()
        }
        setupTimers()

        // Démarrer la surveillance du Focus Mode
        FocusModeMonitor.shared.startMonitoring(manager: self)

        // Activer la synchronisation automatique si elle était activée
        if focusModeAutoSync {
            FocusModeMonitor.shared.setAutoSync(true)
        }

        // Apply any water added via widget buttons while the app was closed
        applyPendingWidgetDelta()
        // Observe future widget taps while the app is running in background
        setupAppGroupObserver()
    }
    
    deinit {
        minuteTimer?.invalidate()
    }
    
    // MARK: - Chargement du journal

    /// Charge le journal, ou le construit depuis l'ancien format au premier
    /// lancement de la v2.
    private func loadLog() {
        switch store.load() {
        case .loaded(let loaded):
            log = loaded
        case .missing:
            log = migratedLegacyLog()
            persistLog()
            // Le total en cours est désormais dans le journal. Laissé en place, il
            // serait repris une seconde fois par une migration de secours.
            storedCurrentMl = 0
        case .corrupt(let backupName):
            Self.logger.error("Journal illisible, mis de côté sous \(backupName ?? "—", privacy: .public)")
            if let backupName {
                report(issue: String(format: String(localized: "%@ was unreadable and has been set aside as %@.",
                                                    comment: "Data issue: corrupt file quarantined; %@ are file names"),
                                     IntakeLogStore.fileName, backupName))
            } else {
                report(issue: String(format: String(localized: "%@ is unreadable.",
                                                    comment: "Data issue: unreadable file"),
                                     IntakeLogStore.fileName))
            }
            // L'ancien historique, s'il existe, vaut mieux qu'un journal vide.
            log = migratedLegacyLog()
            persistLog()
        }
    }

    /// Reprend historyEntries.json et le total en cours stocké dans
    /// UserDefaults. Les journées passées deviennent un événement agrégé
    /// chacune ; l'ancien fichier reste en place.
    private func migratedLegacyLog() -> IntakeLog {
        let pendingDay = DateFormat.iso8601.date(from: lastResetDateString)
        return IntakeLog.migrating(history: store.loadLegacyHistory() ?? [],
                                   pendingDay: pendingDay,
                                   pendingMl: pendingDay == nil ? 0 : storedCurrentMl,
                                   defaultGoal: targetMl,
                                   calendar: .current)
    }

    // MARK: - Changement de jour

    /// Passe à la nouvelle journée si la date a changé.
    ///
    /// Avec le journal, il n'y a plus rien à archiver : les prises de la veille
    /// sont déjà enregistrées avec leur date. La bascule se contente de vider la
    /// pile d'annulation — on ne retire pas d'une journée neuve un verre bu la
    /// veille — et de rafraîchir le total affiché. Toujours appelée avant un
    /// ajout ou une annulation.
    ///
    /// - Returns: `true` si un changement de jour a eu lieu.
    @discardableResult
    private func rollOverIfNewDay() -> Bool {
        guard let lastReset = DateFormat.iso8601.date(from: lastResetDateString) else { return false }
        let calendar = Calendar.current
        guard calendar.startOfDay(for: lastReset) < calendar.startOfDay(for: Date()) else { return false }

        undoStack.removeAll()
        updateLastResetDate()
        refreshDerivedState()
        syncToAppGroup()
        return true
    }

    /// Planifie les vérifications périodiques et s'abonne aux événements système
    /// qui les rendent précises.
    private func setupTimers() {
        // Une vérification par minute suffit pour les rappels. La tolérance laisse
        // macOS regrouper ce réveil avec d'autres — l'ancien code n'en avait pas.
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            self?.rollOverIfNewDay()
            self?.resumeRemindersIfSnoozeEnded()
            self?.replanRemindersIfNeeded()
            // Filet de sécurité si une notification Darwin du widget s'est perdue.
            self?.applyPendingWidgetDelta()
            self?.checkReminderStatus()
        }
        timer.tolerance = 10
        RunLoop.main.add(timer, forMode: .common)
        minuteTimer = timer

        let center = NotificationCenter.default
        // Le système signale le changement de jour à minuit pile : la bascule
        // n'attend plus jusqu'à 60 s.
        center.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            self?.rollOverIfNewDay()
        }
        // Après une veille, les minuteurs repartent en retard : on rattrape tout
        // de suite. Avant, une nuit de veille laissait l'anneau sur la veille
        // jusqu'au premier tick.
        // Écran en veille, session verrouillée ou changée : plus de rappels
        // jusqu'au retour (F6). Ils s'empilaient dans le centre de notifications.
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            workspaceCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.isUserAway = true
                self?.scheduleNotifications()
            }
        }
        for name in [NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            workspaceCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.isUserAway = false
                self?.scheduleNotifications()
            }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.rollOverIfNewDay()
            self?.resumeRemindersIfSnoozeEnded()
            self?.checkReminderStatus()
        }

        checkReminderStatus()
    }
    
    /// Intervalle effectif des rappels, en minutes.
    ///
    /// La valeur personnalisée est bornée ici aussi, et pas seulement dans le
    /// champ de saisie : une valeur stockée par une version antérieure (0, ou
    /// négative) ferait planter `UNTimeIntervalNotificationTrigger`, qui refuse
    /// un déclencheur répétitif de moins de 60 secondes.
    var reminderIntervalMinutes: Int {
        switch notificationInterval {
        case .thirtyMinutes:
            return 30
        case .twoHours:
            return 120
        case .custom:
            return min(max(customNotificationMinutes, HydrationLimits.reminderMinutes.lowerBound),
                       HydrationLimits.reminderMinutes.upperBound)
        }
    }

    /// Vérifie si un rappel doit être affiché (badge ou notification)
    func checkReminderStatus() {
        // La pastille remplace la notification en mode Ne pas déranger : elle
        // suit les mêmes règles que les rappels (plage active, objectif atteint).
        guard notificationsEnabled, isQuietMode, remindersSnoozedUntil == nil else {
            showReminderBadge = false
            return
        }
        showReminderBadge = ReminderPlanner.isDue(reminderContext(now: Date()))
    }

    // MARK: - Rappels intelligents (F6)

    /// Cadence adaptative : resserrer les rappels quand l'utilisateur est en
    /// retard sur son allure. Activée par défaut.
    @AppStorage("adaptiveReminders") var adaptiveReminders: Bool = true {
        willSet { objectWillChange.send() }
        didSet { scheduleNotifications() }
    }

    /// Écran en veille ou session inactive : inutile de rappeler quelqu'un qui
    /// n'est pas devant son Mac. Les rappels reprennent au réveil.
    private var isUserAway = false

    /// Premier rappel programmé. Une fois passé, le minuteur replanifie : la
    /// série programmée est finie, et l'allure a pu changer depuis.
    private var nextPlannedReminder: Date?

    private static let reminderIdentifierPrefix = "HYDRATION_REMINDER"
    private static let maxPlannedReminders = 6

    private func reminderContext(now: Date) -> ReminderPlanner.Context {
        let calendar = Calendar.current
        let today = log.total(on: now, calendar: calendar)
        let behind = HydrationPace.deficitMl(currentMl: today,
                                             targetMl: targetMl,
                                             expectedFraction: expectedProgress) != nil
        return ReminderPlanner.Context(
            now: now,
            lastDrink: getLastWaterAddedDate() ?? now,
            intervalMinutes: reminderIntervalMinutes,
            activeStartHour: activeHoursStart,
            activeEndHour: activeHoursEnd,
            goalReachedToday: targetMl > 0 && today >= targetMl,
            behindPace: adaptiveReminders && behind,
            notBefore: remindersSnoozedUntil,
            calendar: calendar
        )
    }

    private func removePendingReminders() {
        let ids = [Self.reminderIdentifierPrefix]
            + (0..<Self.maxPlannedReminders).map { "\(Self.reminderIdentifierPrefix)_\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func replanRemindersIfNeeded() {
        guard let next = nextPlannedReminder, next <= Date() else { return }
        scheduleNotifications()
    }

    // MARK: - Objectif atteint

    /// Jour de la dernière célébration, pour n'en envoyer qu'une par jour même
    /// si l'utilisateur annule puis repasse la barre.
    @AppStorage("lastGoalCelebrationDay") private var lastGoalCelebrationDay: String = ""

    private func celebrateIfGoalJustReached(previousTotal: Double) {
        let calendar = Calendar.current
        let now = Date()
        let dayKey = IntakeLog.dayKey(for: now, calendar: calendar)
        guard notificationsEnabled, !isQuietMode,
              targetMl > 0, previousTotal < targetMl, currentMl >= targetMl,
              lastGoalCelebrationDay != dayKey
        else { return }
        lastGoalCelebrationDay = dayKey

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Goal reached!", comment: "Goal celebration notification title")
        let streak = currentStreak
        content.body = streak > 1
            ? String(format: String(localized: "%lld days in a row. Well done!",
                                    comment: "Goal celebration body; %lld is the streak length"), streak)
            : String(localized: "You reached your daily goal. Well done!",
                     comment: "Goal celebration body without a streak")
        content.sound = .default
        let request = UNNotificationRequest(identifier: "GOAL_REACHED", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func updateLastResetDate() {
        lastResetDateString = DateFormat.iso8601.string(from: Date())
    }
    
    // MARK: - Public Methods
    
    /// Ajoute une prise, en ml.
    func addWater(amount: Double) {
        // Un verre bu après minuit appartient à la nouvelle journée.
        rollOverIfNewDay()
        guard amount > 0, amount.isFinite else { return }

        let now = Date()
        let previousTotal = currentMl
        let event = IntakeEvent(date: now, amountMl: amount)
        log.add(event)
        log.setGoal(targetMl, on: now, calendar: .current)
        pushUndo(.added(event.id))
        persistLog()

        updateLastWaterAddedDate()
        showReminderBadge = false
        // Replanifier les rappels à partir de cette prise.
        scheduleNotifications()
        celebrateIfGoalJustReached(previousTotal: previousTotal)
        syncToAppGroup()
        intakeAdded.send(amount)
    }

    /// Ajoute une prise oubliée, à une date passée (« j'ai oublié de noter
    /// hier »). Annulable. Une journée passée n'était jusqu'ici plus modifiable.
    func addPastDrink(amount: Double, at date: Date) {
        rollOverIfNewDay()
        let now = Date()
        guard amount > 0, amount.isFinite, date <= now else { return }

        let calendar = Calendar.current
        let event = IntakeEvent(date: date, amountMl: amount)
        log.add(event)
        // Une journée sans objectif noté prend l'objectif actuel.
        if log.goal(on: date, calendar: calendar) == nil {
            log.setGoal(targetMl, on: date, calendar: calendar)
        }
        pushUndo(.added(event.id))
        persistLog()
        if let last = getLastWaterAddedDate(), date > last {
            lastWaterAddedDateString = DateFormat.iso8601.string(from: date)
        }
        scheduleNotifications()
        syncToAppGroup()
    }

    /// Supprime une prise du jour (journal du jour, F17). Annulable.
    func removeEvent(id: UUID) {
        rollOverIfNewDay()
        guard let removed = log.remove(id: id) else { return }
        pushUndo(.removed([removed]))
        persistLog()
        scheduleNotifications()
        syncToAppGroup()
    }
    
    /// Fusionne une sauvegarde importée (F4). Seules les prises absentes sont
    /// ajoutées : importer deux fois la même sauvegarde ne change rien.
    /// - Returns: le nombre de prises ajoutées.
    @discardableResult
    func importBackup(_ backup: IntakeLog) -> Int {
        var merged = log
        let added = merged.merge(backup)
        guard added > 0 || merged != log else { return 0 }
        log = merged
        persistLog()
        syncToAppGroup()
        return added
    }

    /// Met à jour la date de dernière consommation d'eau
    private func updateLastWaterAddedDate() {
        lastWaterAddedDateString = DateFormat.iso8601.string(from: Date())
    }
    
    /// Récupère la date de dernière consommation d'eau
    private func getLastWaterAddedDate() -> Date? {
        guard !lastWaterAddedDateString.isEmpty,
              let date = DateFormat.iso8601.date(from: lastWaterAddedDateString) else {
            return nil
        }
        return date
    }
    
    /// Annule la dernière action : un ajout, une suppression ou un reset.
    /// - Returns: true si une action a été annulée, false si la pile est vide
    @discardableResult
    func undo() -> Bool {
        // Pas d'annulation par-dessus minuit : la bascule vide la pile.
        rollOverIfNewDay()
        guard let action = undoStack.popLast() else { return false }

        switch action {
        case .added(let id):
            log.remove(id: id)
        case .removed(let events):
            log.restore(events)
        }
        persistLog()
        scheduleNotifications()
        syncToAppGroup()
        return true
    }

    /// Vérifie si une action peut être annulée
    var canUndo: Bool {
        !undoStack.isEmpty
    }

    /// Remet la journée à zéro en retirant ses prises. Annulable : l'annulation
    /// les remet toutes.
    func resetDay() {
        rollOverIfNewDay()
        let removed = log.removeEvents(on: Date(), calendar: .current)
        if !removed.isEmpty { pushUndo(.removed(removed)) }
        persistLog()
        scheduleNotifications()
        syncToAppGroup()
    }
    
    // MARK: - UI Helper Methods
    
    /// Quantité formatée dans l'unité choisie, selon la locale.
    /// Délègue au formateur partagé avec le widget — voir `AppUnit.format(ml:)`.
    func displayValue(for ml: Double) -> String {
        selectedUnit.format(ml: ml)
    }

    /// Convertit une valeur d'affichage (dans l'unité choisie) vers ml
    /// - Parameter display: Valeur dans l'unité actuellement sélectionnée
    /// - Returns: Valeur équivalente en millilitres
    func mlValue(from display: Double) -> Double {
        return selectedUnit.toMl(display)
    }
    
    // MARK: - Persistance du journal

    /// Écrit le journal immédiatement : une prise est un geste rare, et une
    /// écriture différée exposerait le dernier verre à un crash. L'appui long
    /// ne passe ici qu'une fois, à la fin.
    private func persistLog() {
        do {
            try store.save(log)
        } catch {
            Self.logger.error("Échec d'écriture du journal: \(error.localizedDescription, privacy: .public)")
            report(issue: String(format: String(localized: "Could not save %@.",
                                                comment: "Data issue: write failure, %@ is a file name"),
                                 IntakeLogStore.fileName))
        }
    }

    private func report(issue: String) {
        DispatchQueue.main.async { [weak self] in
            // Une écriture qui échoue en boucle (disque plein, pendant
            // « Hold to Add ») republierait sinon le même texte 20 fois par seconde.
            guard let self, self.lastDataIssue != issue else { return }
            self.lastDataIssue = issue
        }
    }
    
    // MARK: - Computed Properties for Statistics
    
    private var todayForStats: HydrationStats.Today {
        HydrationStats.Today(date: Date(), amountMl: currentMl, targetMl: targetMl)
    }

    /// Somme des 7 derniers jours, aujourd'hui inclus.
    var weeklyTotal: Double {
        HydrationStats.total(lastDays: 7, history: historyEntries, today: todayForStats)
    }

    /// Moyenne quotidienne sur 7 jours : un jour sans consommation compte pour zéro.
    var dailyAverage: Double {
        weeklyTotal / 7.0
    }

    /// Jours consécutifs où l'objectif est atteint (cf. `HydrationStats.streak`).
    var currentStreak: Int {
        HydrationStats.streak(history: historyEntries, today: todayForStats)
    }

    // MARK: - Allure

    /// Fraction de l'objectif attendue à cet instant, au prorata de la plage active.
    /// `nil` avant le début de la plage : rien n'est encore attendu.
    var expectedProgress: Double? {
        HydrationPace.expectedFraction(at: Date(),
                                       startHour: activeHoursStart,
                                       endHour: activeHoursEnd)
    }

    /// Phrase complète pour VoiceOver : progression, quantités et allure. Partagée
    /// par l'anneau du popover et l'icône de la barre de menu.
    var progressAccessibilitySummary: String {
        let percentage = targetMl > 0 ? Int(currentMl / targetMl * 100) : 0
        let base = String(
            format: String(localized: "Hydration: %lld percent, %@ of %@",
                           comment: "VoiceOver description of the progress ring"),
            percentage, displayValue(for: currentMl), displayValue(for: targetMl)
        )
        guard expectedProgress != nil else { return base }
        if let deficit = paceDeficitMl {
            let behind = String(format: String(localized: "%@ behind",
                                               comment: "Pace caption when the user is behind schedule"),
                                displayValue(for: deficit))
            return "\(base). \(behind)"
        }
        return "\(base). " + String(localized: "On track", comment: "Pace caption when the user is on schedule")
    }

    /// Quantité manquante, en ml, pour être dans les temps. `nil` si à jour ou hors plage.
    var paceDeficitMl: Double? {
        HydrationPace.deficitMl(currentMl: currentMl,
                                targetMl: targetMl,
                                expectedFraction: expectedProgress)
    }

    /// Retourne un tableau complet de 30 jours avec HistoryEntry
    /// Génère des entrées avec amountMl: 0 pour les jours sans données
    func getLast30DaysData() -> [HistoryEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var result: [HistoryEntry] = []
        
        // Générer les 30 derniers jours (du plus ancien au plus récent)
        for i in stride(from: 29, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            
            // Pour aujourd'hui, utiliser les données actuelles
            if calendar.isDate(date, inSameDayAs: today) {
                let todayEntry = HistoryEntry(date: date, amountMl: currentMl, targetMl: targetMl)
                result.append(todayEntry)
            } else if let entry = historyEntries.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                // Chercher l'entrée correspondante dans l'historique
                result.append(entry)
            } else {
                // Pas de données pour ce jour, créer une entrée avec amountMl: 0
                // Utiliser le targetMl actuel comme valeur par défaut
                let emptyEntry = HistoryEntry(date: date, amountMl: 0, targetMl: targetMl)
                result.append(emptyEntry)
            }
        }
        
        return result
    }
    
    /// Retourne les 7 derniers jours avec HistoryEntry (pour le graphique hebdomadaire)
    func getLast7DaysHistoryData() -> [HistoryEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var result: [HistoryEntry] = []
        
        // Générer les 7 derniers jours (du plus ancien au plus récent)
        for i in stride(from: 6, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            
            // Pour aujourd'hui, utiliser les données actuelles
            if calendar.isDate(date, inSameDayAs: today) {
                let todayEntry = HistoryEntry(date: date, amountMl: currentMl, targetMl: targetMl)
                result.append(todayEntry)
            } else if let entry = historyEntries.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                // Chercher l'entrée correspondante dans l'historique
                result.append(entry)
            } else {
                // Pas de données pour ce jour, créer une entrée avec amountMl: 0
                // Utiliser le targetMl actuel comme valeur par défaut
                let emptyEntry = HistoryEntry(date: date, amountMl: 0, targetMl: targetMl)
                result.append(emptyEntry)
            }
        }
        
        return result
    }
    
    // MARK: - Notifications
    
    /// Configure les catégories de notifications avec actions
    private func setupNotificationCategories() {
        let center = UNUserNotificationCenter.current()
        
        // Action "Boire un verre"
        let drinkAction = UNNotificationAction(
            identifier: "DRINK_ACTION",
            title: String(localized: "Drink a glass", comment: "Notification action button"),
            options: []
        )
        
        // Pause d'une heure, depuis la notification elle-même (F19).
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_ACTION",
            title: String(localized: "Snooze 1 Hour", comment: "Notification action button"),
            options: []
        )

        // Catégorie avec actions
        let category = UNNotificationCategory(
            identifier: "HYDRATION_REMINDER",
            actions: [drinkAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([category])
    }
    
    /// Programme les notifications locales répétées
    func scheduleNotifications() {
        removePendingReminders()

        // Mode Ne pas déranger : la pastille remplace la notification.
        guard notificationsEnabled, !isQuietMode, !isUserAway else {
            nextPlannedReminder = nil
            checkReminderStatus()
            return
        }
        showReminderBadge = false

        let now = Date()
        let context = reminderContext(now: now)
        let dates = ReminderPlanner.upcoming(context, limit: Self.maxPlannedReminders)
        nextPlannedReminder = dates.first
        let calendar = Calendar.current

        for (index, date) in dates.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Hydrobar", comment: "Notification title")
            // Le retard ne vaut que pour aujourd'hui : demain repart de zéro.
            content.body = context.behindPace && calendar.isDate(date, inSameDayAs: now)
                ? String(localized: "You're behind your pace for today. Time for a glass!",
                         comment: "Reminder body when the user is behind schedule")
                : String(localized: "Time to hydrate!", comment: "Notification body message")
            content.sound = .default
            content.categoryIdentifier = "HYDRATION_REMINDER"

            // Déclencheurs non répétitifs : un intervalle fixe répété ignorait
            // la plage active et l'objectif atteint.
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(date.timeIntervalSince(now), 1),
                                                            repeats: false)
            let request = UNNotificationRequest(identifier: "\(Self.reminderIdentifierPrefix)_\(index)",
                                                content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { error in
                if let error {
                    Self.logger.error("Échec de programmation d'un rappel: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    // MARK: - Widget → App Sync

    /// Écoute la notification Darwin que le widget poste après un ajout (cf.
    /// `AppGroupStore.widgetDidAddWaterNotification`). Le rappel C ne peut rien
    /// capturer : il passe par le singleton, qui vit autant que l'app.
    private func setupAppGroupObserver() {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    HydrationManager.shared.applyPendingWidgetDelta()
                }
            },
            AppGroupStore.widgetDidAddWaterNotification as CFString,
            nil,
            .deliverImmediately
        )
    }

    /// Consumes ml queued by widget `AddWaterIntent` and applies it to HydrationManager.
    func applyPendingWidgetDelta() {
        let delta = AppGroupStore.consumePendingDelta()
        guard delta > 0 else { return }
        addWater(amount: delta)
    }

    // MARK: - Persistance différée

    /// L'instantané du widget passe par un délai unique (le journal, lui, est
    /// écrit à chaque prise). Avant, chaque gorgée de « Hold to Add » réécrivait les deux
    /// fichiers d'historique, encodait l'instantané du widget et le stockait,
    /// 20 fois par seconde ; seul le rechargement du widget était différé
    /// (cf. AUDIT § P2-2). Les écritures atomiques de P3-3 rendaient le problème
    /// plus coûteux encore : chaque écriture ajoute un fichier temporaire et un
    /// renommage.
    private var pendingPersist: DispatchWorkItem?
    private static let persistDelay: TimeInterval = 0.5

    /// Conservé sous ce nom : c'est l'appel des points de mutation (objectif,
    /// unité, bascule de jour, ajout, annulation, reset).
    private func syncToAppGroup() {
        schedulePersist()
    }

    private func schedulePersist() {
        pendingPersist?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.flushPendingWrites() }
        pendingPersist = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.persistDelay, execute: work)
    }

    /// Écrit immédiatement tout ce qui attend. Appelé à la fin d'un appui long et
    /// à la fermeture de l'app : un délai ne doit jamais coûter une donnée.
    func flushPendingWrites() {
        pendingPersist?.cancel()
        pendingPersist = nil
        writeWidgetSnapshot()
    }

    private func writeWidgetSnapshot() {
        AppGroupStore.write(HydrationSnapshot(
            currentMl: currentMl,
            targetMl: targetMl,
            unit: selectedUnit.rawValue,
            lastUpdated: Date(),
            weekHistory: getLast7DaysSnapshotsForWidget(),
            presetsMl: presetsMl
        ))
        WidgetCenter.shared.reloadTimelines(ofKind: "HydroBarWidget")
    }

    /// Builds the last 7 days of HistoryEntrySnapshot values for the widget.
    /// Uses historyEntries (30-day canonical source). Synthesizes today's entry from
    /// currentMl + targetMl since today's write may not yet be flushed to historyEntries.
    private func getLast7DaysSnapshotsForWidget() -> [HistoryEntrySnapshot] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var snapshots: [HistoryEntrySnapshot] = []

        for dayOffset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }

            if calendar.isDate(date, inSameDayAs: today) {
                // Today: use live currentMl (not yet in historyEntries)
                snapshots.append(HistoryEntrySnapshot(
                    date: date,
                    amountMl: currentMl,
                    targetMl: targetMl
                ))
            } else if let entry = historyEntries.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                snapshots.append(HistoryEntrySnapshot(
                    date: entry.date,
                    amountMl: entry.amountMl,
                    targetMl: entry.targetMl
                ))
            }
            // Days with no recorded data are omitted (widget handles empty weekHistory gracefully)
        }

        return snapshots
    }

    // MARK: - Debug Functions

    #if DEBUG
    /// Génère de fausses données d'historique pour les tests. Remplace tout
    /// l'historique passé : jamais compilé dans une version publiée.
    func generateFakeHistoryData() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var fake = IntakeLog(events: log.events(on: today, calendar: calendar))

        for offset in 1...29 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            fake.setGoal(targetMl, on: day, calendar: calendar)
            // Un jour sur dix vide ; sinon 3 à 8 prises, de 50 à 150 % de l'objectif.
            guard Int.random(in: 1...10) != 1 else { continue }
            let count = Int.random(in: 3...8)
            let dayTotal = targetMl * Double.random(in: 0.5...1.5)
            for index in 0..<count {
                let hour = 8 + index * 14 / count
                guard let date = calendar.date(byAdding: .hour, value: hour, to: day) else { continue }
                fake.add(IntakeEvent(date: date, amountMl: (dayTotal / Double(count)).rounded()))
            }
        }
        undoStack.removeAll()
        log = fake
        persistLog()
        syncToAppGroup()
    }
    #endif

    /// Teste l'envoi d'une notification immédiatement
    func testNotification() {
        let center = UNUserNotificationCenter.current()
        
        // Créer le contenu de la notification de test
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Hydrobar", comment: "Notification title")
        content.body = String(localized: "Test notification - Time to hydrate!", comment: "Test notification body")
        content.sound = .default
        content.categoryIdentifier = "HYDRATION_REMINDER"
        content.userInfo = ["presetIndex": 0, "isTest": true]
        
        // Créer une requête pour une notification immédiate (dans 1 seconde)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "TEST_NOTIFICATION_\(UUID().uuidString)", content: content, trigger: trigger)
        
        // Envoyer la notification
        center.add(request) { error in
            if let error = error {
                Self.logger.error("Échec de la notification de test: \(error.localizedDescription, privacy: .public)")
            } else {
                Self.logger.debug("Notification de test envoyée")
            }
        }
    }
}
