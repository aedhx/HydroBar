import Foundation
import SwiftUI
import AppKit
import UserNotifications
import WidgetKit
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
    // Sert au repère d'allure de l'anneau, et servira à borner les rappels (F19).

    @AppStorage("activeHoursStart") var activeHoursStart: Int = HydrationPace.defaultStartHour {
        willSet { objectWillChange.send() }
    }

    @AppStorage("activeHoursEnd") var activeHoursEnd: Int = HydrationPace.defaultEndHour {
        willSet { objectWillChange.send() }
    }

    @AppStorage("menuBarIconStyle") var menuBarIconStyle: MenuBarIconStyle = .pieRing {
        willSet { objectWillChange.send() }
    }
    
    // MARK: - Published Properties
    @Published var currentMl: Double = 0.0 {
        didSet {
            // Immédiat : UserDefaults est la source de vérité du jour en cours.
            // Un crash avant l'écriture différée ne perd donc rien — au lancement
            // suivant, la valeur est reprise d'ici.
            storedCurrentMl = currentMl
            schedulePersist()
        }
    }
    
    // MARK: - Journalisation et diagnostic

    private static let logger = Logger(subsystem: "com.adxcool.HydroBar", category: "hydration")

    /// Dernier problème de persistance rencontré, affiché en mode debug.
    /// Mieux vaut un message visible qu'un historique disparu sans trace.
    @Published private(set) var lastDataIssue: String?

    /// Historique complet, une entrée par jour, avec l'objectif de ce jour-là.
    /// Unique source de vérité : un second store (`DailyEntry`, history.json,
    /// sans objectif, 7 jours) était écrit en parallèle à chaque mutation
    /// (cf. AUDIT § P1-2).
    @Published var historyEntries: [HistoryEntry] = []

    /// Vrai une fois les fichiers d'historique lus. Écrire avant, c'est écraser
    /// le fichier avec un tableau partiel — la cause exacte de la perte
    /// d'historique au lancement. Voir `ensureHistoryLoaded()`.
    private var isHistoryLoaded = false
    @Published var showReminderBadge: Bool = false
    
    // MARK: - Undo Stack

    /// Privée : `MainContentView` y ajoutait directement ses entrées, avec sa
    /// propre copie de la limite de taille (cf. AUDIT § P1-3). Les vues passent
    /// désormais par `beginHoldSession()` / `endHoldSession()`.
    /// `amount` est la quantité à retirer pour annuler : positive pour un ajout,
    /// négative pour un reset (annuler un reset rend la quantité effacée).
    private var undoStack: [(amount: Double, timestamp: Date)] = []
    private let maxUndoStackSize = 50

    private func pushUndo(_ amount: Double) {
        undoStack.append((amount: amount, timestamp: Date()))
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

    func addHeldWater(_ ml: Double) {
        guard let total = holdSessionTotal else { return }
        holdSessionTotal = total + ml
        holdTotalMl = total + ml
        addWater(amount: ml, skipUndo: true)
    }

    /// Clôt l'appui : une seule entrée d'annulation pour tout le geste, une seule
    /// reprogrammation des notifications, une seule écriture.
    func endHoldSession() {
        guard let total = holdSessionTotal else { return }
        holdSessionTotal = nil
        holdTotalMl = 0
        if total > 0 { pushUndo(total) }
        if notificationsEnabled { scheduleNotifications() }
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
    private init() {
        // Avant toute lecture de `doNotDisturb` (programmation des rappels).
        Self.migrateFocusOwnedDoNotDisturb()

        // L'historique DOIT être chargé avant la bascule de jour : celle-ci archive
        // la veille dans `historyEntries`. Dans l'ordre d'origine, inverse,
        // `historyEntries` était encore vide au moment de l'archivage — qui
        // réécrivait alors historyEntries.json avec la seule journée d'hier.
        // Résultat : tout l'historique était effacé à chaque lancement un jour
        // différent du dernier reset (Mac éteint la nuit, redémarrage, app quittée).
        loadHistory()
        restoreTodayOnLaunch()
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
    
    // MARK: - Changement de jour

    /// Au lancement : bascule si le jour a changé depuis la dernière session,
    /// sinon reprend la consommation du jour là où elle s'était arrêtée.
    private func restoreTodayOnLaunch() {
        guard !lastResetDateString.isEmpty,
              DateFormat.iso8601.date(from: lastResetDateString) != nil
        else {
            // Premier lancement, ou date illisible : on repart proprement d'ici.
            updateLastResetDate()
            return
        }
        if !rollOverIfNewDay() {
            currentMl = storedCurrentMl
        }
    }

    /// Archive la journée précédente et repart de zéro si la date a changé.
    ///
    /// Appelé au lancement, par le minuteur, **et avant tout ajout ou annulation**.
    /// Avant, seul un minuteur de 60 s s'en chargeait, et `addWater` sautait
    /// volontairement la vérification « pour la performance » : un verre logué
    /// juste après minuit — ou au réveil du Mac, avant que le minuteur ne tourne —
    /// s'ajoutait au total de la veille, puis était archivé sous la date d'hier.
    ///
    /// Le même jour, cette fonction ne touche à rien. L'ancienne version
    /// réassignait `currentMl` à chaque appel, ce qui réécrivait les fichiers
    /// d'historique toutes les minutes, 24 h/24.
    ///
    /// - Returns: `true` si un changement de jour a eu lieu.
    @discardableResult
    private func rollOverIfNewDay() -> Bool {
        guard let lastReset = DateFormat.iso8601.date(from: lastResetDateString) else { return false }
        let calendar = Calendar.current
        let lastResetDay = calendar.startOfDay(for: lastReset)
        guard lastResetDay < calendar.startOfDay(for: Date()) else { return false }

        saveHistoryEntry(date: lastResetDay, amountMl: storedCurrentMl, targetMl: targetMl)
        currentMl = 0.0
        undoStack.removeAll()
        updateLastResetDate()
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
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.rollOverIfNewDay()
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
        guard notificationsEnabled else {
            showReminderBadge = false
            return
        }
        
        let intervalMinutes = reminderIntervalMinutes
        
        // Vérifier si l'intervalle est écoulé depuis la dernière consommation
        let now = Date()
        let lastWaterDate = getLastWaterAddedDate() ?? now // Si jamais de consommation, utiliser maintenant
        let timeSinceLastWater = now.timeIntervalSince(lastWaterDate)
        let intervalInSeconds = TimeInterval(intervalMinutes * 60)
        
        if timeSinceLastWater >= intervalInSeconds {
            // L'intervalle est écoulé
            if isQuietMode {
                // Mode DnD actif : afficher le badge au lieu de la notification
                showReminderBadge = true
            } else {
                // Mode DnD inactif : la notification système sera gérée par scheduleNotifications
                showReminderBadge = false
            }
        } else {
            // L'intervalle n'est pas encore écoulé
            showReminderBadge = false
        }
    }
    
    private func updateLastResetDate() {
        lastResetDateString = DateFormat.iso8601.string(from: Date())
    }
    
    // MARK: - Public Methods
    
    /// Ajoute de l'eau (amount toujours en ml)
    /// Optimisée pour être appelée très fréquemment (ex: toutes les 0.05s pour "Hold to Add")
    /// - Parameter amount: Quantité en ml à ajouter
    /// - Parameter skipUndo: Si true, n'enregistre pas l'action dans le stack undo (pour regroupement)
    func addWater(amount: Double, skipUndo: Bool = false) {
        // Un verre bu après minuit appartient à la nouvelle journée. Comparer deux
        // dates coûte quelques nanosecondes : l'« optimisation » qui sautait cette
        // vérification attribuait des prises à la mauvaise journée.
        rollOverIfNewDay()

        
        if amount > 0 && !skipUndo {
            pushUndo(amount)
        }

        currentMl += amount
        updateLastWaterAddedDate()
        showReminderBadge = false

        // Repousser le prochain rappel — sauf pendant un appui long, où ce serait
        // fait 20 fois par seconde : endHoldSession() s'en charge une seule fois.
        if notificationsEnabled && holdSessionTotal == nil {
            scheduleNotifications()
        }

        syncToAppGroup()
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
    
    /// Annule la dernière action : un ajout, ou un reset de la journée.
    /// - Returns: true si une action a été annulée, false si le stack est vide
    @discardableResult
    func undo() -> Bool {
        // Pas d'annulation par-dessus minuit : la bascule vide la pile, et on ne
        // retire pas d'une journée neuve un verre bu la veille.
        rollOverIfNewDay()
        guard !undoStack.isEmpty else { return false }
        
        let lastAction = undoStack.removeLast()

        // Retirer la quantité ajoutée
        currentMl = max(0, currentMl - lastAction.amount)

        // NEW: sync updated state to App Group
        syncToAppGroup()

        return true
    }
    
    /// Vérifie si une action peut être annulée
    var canUndo: Bool {
        return !undoStack.isEmpty
    }
    
    /// Remet la consommation du jour à zéro.
    ///
    /// Annulable : le bouton « Reset my day » agit sur un simple clic, et vidait
    /// en plus la pile d'annulation — un clic malheureux effaçait la journée
    /// sans retour possible. L'annulation rend la quantité effacée.
    func resetDay() {
        let erased = currentMl
        currentMl = 0.0
        if erased > 0 { pushUndo(-erased) }
        updateLastResetDate()
        // Seul chemin de mutation qui oubliait de propager l'état : le widget
        // gardait l'ancienne valeur après un reset (bouton ou hydrobar://reset).
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
    
    // MARK: - History Management
    
    /// Chemin vers le fichier d'historique complet (avec targetMl)
    private var historyEntriesFileURL: URL {
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolderURL = appSupportURL.appendingPathComponent("HydroBar", isDirectory: true)
        
        // Créer le dossier s'il n'existe pas
        try? fileManager.createDirectory(at: appFolderURL, withIntermediateDirectories: true)
        
        return appFolderURL.appendingPathComponent("historyEntries.json")
    }
    
    /// Sauvegarde l'entrée du jour actuel
    private func saveTodayEntry() {
        let today = Calendar.current.startOfDay(for: Date())
        saveHistoryEntry(date: today, amountMl: currentMl, targetMl: targetMl)
    }

    /// Défense en profondeur : aucune écriture ne part d'un historique non chargé.
    /// L'ordre d'`init` est corrigé, mais un futur réordonnancement ne doit pas
    /// pouvoir effacer à nouveau l'historique.
    private func ensureHistoryLoaded() {
        if !isHistoryLoaded { loadHistory() }
    }

    /// Sauvegarde une HistoryEntry avec targetMl historique
    private func saveHistoryEntry(date: Date, amountMl: Double, targetMl: Double) {
        ensureHistoryLoaded()
        let calendar = Calendar.current
        let dateStart = calendar.startOfDay(for: date)
        
        // Charger l'historique complet
        var entries = historyEntries
        
        // Retirer l'ancienne entrée pour cette date si elle existe
        entries.removeAll { entry in
            calendar.isDate(entry.date, inSameDayAs: dateStart)
        }
        
        // Ajouter la nouvelle entrée avec targetMl historique
        let historyEntry = HistoryEntry(date: dateStart, amountMl: amountMl, targetMl: targetMl)
        entries.append(historyEntry)
        
        // Trier par date (plus ancien en premier)
        entries.sort { $0.date < $1.date }
        
        historyEntries = entries
        saveHistoryEntries()
    }
    
    /// Charge l'historique. Il est conservé **en entier** : l'ancienne version le
    /// tronquait à 30 jours au chargement comme à l'écriture, si bien que les
    /// données plus anciennes étaient détruites, pas archivées (cf. AUDIT § P1-2).
    /// Une année d'historique pèse environ 30 Ko ; chaque vue filtre la période
    /// qu'elle affiche.
    ///
    /// L'ancien fichier history.json n'est ni lu ni supprimé : son contenu est un
    /// sous-ensemble strict d'historyEntries.json, et on ne détruit pas un fichier
    /// utilisateur sans nécessité.
    private func loadHistory() {
        defer { isHistoryLoaded = true }
        historyEntries = (readJSON([HistoryEntry].self,
                                   from: historyEntriesFileURL,
                                   label: "historyEntries.json") ?? [])
            .sorted { $0.date < $1.date }
    }

    /// Sauvegarde l'historique complet (HistoryEntry) dans le fichier JSON
    private func saveHistoryEntries() {
        writeJSON(historyEntries, to: historyEntriesFileURL, label: "historyEntries.json")
    }

    // MARK: - Persistance JSON

    /// Écrit en **atomique** : les données passent par un fichier temporaire
    /// renommé à la fin. Sans cette option, une coupure en pleine écriture
    /// laissait un JSON tronqué, que `readJSON` interprétait comme « pas
    /// d'historique » — et le prochain enregistrement l'écrasait pour de bon.
    private func writeJSON<T: Encodable>(_ value: T, to url: URL, label: String) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(value)
            try data.write(to: url, options: [.atomic])
        } catch {
            Self.logger.error("Échec d'écriture de \(label, privacy: .public): \(error.localizedDescription, privacy: .public)")
            report(issue: String(format: String(localized: "Could not save %@.",
                                                comment: "Data issue: write failure, %@ is a file name"),
                                 label))
        }
    }

    /// Lit un fichier JSON en distinguant deux cas que l'ancien code confondait :
    /// le fichier **absent** (premier lancement, normal) et le fichier **présent
    /// mais illisible** (corruption, anormal). Dans le second cas, le fichier est
    /// mis de côté plutôt qu'écrasé en silence.
    private func readJSON<T: Decodable>(_ type: T.Type, from url: URL, label: String) -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil // premier lancement
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(type, from: data)
        } catch {
            quarantine(url, label: label, error: error)
            return nil
        }
    }

    /// Renomme un fichier illisible en `<nom>.corrupt-<date>` pour que son contenu
    /// reste récupérable à la main. Perdre un mois d'historique sans trace était le
    /// pire scénario de l'ancienne implémentation.
    private func quarantine(_ url: URL, label: String, error: Error) {
        let stamp = DateFormat.iso8601.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backup = url.appendingPathExtension("corrupt-\(stamp)")
        do {
            try FileManager.default.moveItem(at: url, to: backup)
            Self.logger.error("\(label, privacy: .public) illisible, mis de côté dans \(backup.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            report(issue: String(format: String(localized: "%@ was unreadable and has been set aside as %@.",
                                                comment: "Data issue: corrupt file quarantined; %@ are file names"),
                                 label, backup.lastPathComponent))
        } catch {
            Self.logger.error("\(label, privacy: .public) illisible et impossible à mettre de côté: \(error.localizedDescription, privacy: .public)")
            report(issue: String(format: String(localized: "%@ is unreadable.",
                                                comment: "Data issue: unreadable file"),
                                 label))
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
        
        // Catégorie avec action
        let category = UNNotificationCategory(
            identifier: "HYDRATION_REMINDER",
            actions: [drinkAction],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([category])
    }
    
    /// Programme les notifications locales répétées
    func scheduleNotifications() {
        guard notificationsEnabled else {
            // Annuler toutes les notifications si désactivées
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            showReminderBadge = false
            return
        }
        
        // Si mode Ne pas déranger est activé, ne pas programmer de notifications système
        // Le badge sera géré par checkReminderStatus()
        if isQuietMode {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            // Vérifier immédiatement le statut du badge
            checkReminderStatus()
            return
        }
        
        // Annuler les anciennes notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        let intervalMinutes = reminderIntervalMinutes
        
        // Créer le contenu de la notification
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Hydrobar", comment: "Notification title")
        content.body = String(localized: "Time to hydrate!", comment: "Notification body message")
        content.sound = .default
        content.categoryIdentifier = "HYDRATION_REMINDER"
        content.userInfo = ["presetIndex": 0] // Index du premier preset
        
        // Créer le trigger répétitif
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(intervalMinutes * 60),
            repeats: true
        )
        
        // Créer la requête
        let request = UNNotificationRequest(
            identifier: "HYDRATION_REMINDER",
            content: content,
            trigger: trigger
        )
        
        // Programmer la notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Self.logger.error("Échec de programmation de la notification: \(error.localizedDescription, privacy: .public)")
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

    /// Toute écriture — historique JSON et instantané du widget — passe par un
    /// délai unique. Avant, chaque gorgée de « Hold to Add » réécrivait les deux
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
        saveTodayEntry()
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
    /// l'historique : jamais compilé dans une version publiée.
    func generateFakeHistoryData() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Générer des données pour les 30 derniers jours
        var fakeEntries: [HistoryEntry] = []
        
        for i in stride(from: 29, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            
            // Pour aujourd'hui, utiliser les données actuelles
            if calendar.isDate(date, inSameDayAs: today) {
                let todayEntry = HistoryEntry(date: date, amountMl: currentMl, targetMl: targetMl)
                fakeEntries.append(todayEntry)
                continue
            }
            
            // Générer des données aléatoires mais réalistes
            // Variation entre 50% et 150% de l'objectif
            let randomFactor = Double.random(in: 0.5...1.5)
            let fakeAmount = targetMl * randomFactor
            
            // Ajouter quelques jours avec 0% (pour tester les cas vides)
            let isEmptyDay = Int.random(in: 1...10) == 1 // 10% de chance d'avoir un jour vide
            let finalAmount = isEmptyDay ? 0.0 : fakeAmount
            
            let entry = HistoryEntry(date: date, amountMl: finalAmount, targetMl: targetMl)
            fakeEntries.append(entry)
        }
        
        // Sauvegarder les fausses données
        historyEntries = fakeEntries
        saveHistoryEntries()
        
        // Notifier le changement
        objectWillChange.send()
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
