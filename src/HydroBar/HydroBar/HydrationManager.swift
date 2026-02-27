import Foundation
import SwiftUI
import UserNotifications
import WidgetKit

// MARK: - DailyEntry (legacy, pour compatibilité)
struct DailyEntry: Codable, Identifiable {
    let id: String
    let date: Date
    let amount: Double // en ml
    
    init(date: Date, amount: Double) {
        self.id = ISO8601DateFormatter().string(from: date)
        self.date = date
        self.amount = amount
    }
}

// MARK: - HistoryEntry
struct HistoryEntry: Codable, Identifiable {
    let id: String
    let date: Date
    let amountMl: Double
    let targetMl: Double
    
    init(date: Date, amountMl: Double, targetMl: Double) {
        self.id = ISO8601DateFormatter().string(from: date)
        self.date = date
        self.amountMl = amountMl
        self.targetMl = targetMl
    }
}

// MARK: - MenuBarIconStyle Enum
enum MenuBarIconStyle: String, CaseIterable, Codable {
    case pieRing = "Pie Ring"
    case percentage = "Percentage"
}

// MARK: - AppUnit Enum
enum AppUnit: String, CaseIterable, Codable {
    case cl = "cl"
    case liter = "L"
    case oz = "oz"
    
    // Conversion vers cl (unité de base interne)
    func toCl(_ value: Double) -> Double {
        switch self {
        case .cl:
            return value
        case .liter:
            return value * 100.0 // 1 L = 100 cl
        case .oz:
            return value * 2.957 // 1 oz = 29.57 ml = 2.957 cl
        }
    }
    
    // Conversion depuis cl (unité de base interne)
    func fromCl(_ valueInCl: Double) -> Double {
        switch self {
        case .cl:
            return valueInCl
        case .liter:
            return valueInCl / 100.0
        case .oz:
            return valueInCl / 2.957
        }
    }
    
    // Conversion vers ml (pour compatibilité interne - stockage toujours en ml)
    func toMl(_ value: Double) -> Double {
        return toCl(value) * 10.0 // 1 cl = 10 ml
    }
    
    // Conversion depuis ml (pour compatibilité interne)
    func fromMl(_ valueInMl: Double) -> Double {
        return fromCl(valueInMl / 10.0)
    }
}

// MARK: - Extension pour Array<Double> avec AppStorage
extension Array: @retroactive RawRepresentable where Element == Double {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let array = try? JSONDecoder().decode([Double].self, from: data) else {
            return nil
        }
        self = array
    }
    
    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
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
    @AppStorage("notificationsEnabled") var notificationsEnabled: Bool = false {
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
    @AppStorage("customNotificationMinutes") var customNotificationMinutes: Int = 60
    @AppStorage("doNotDisturb") var doNotDisturb: Bool = false {
        didSet {
            // IMPORTANT: Ne jamais modifier notificationsEnabled ici
            // Le mode DnD ne désactive pas les notifications, il change juste leur comportement
            if notificationsEnabled {
                scheduleNotifications()
                checkReminderStatus()
            }
            // Notifier le changement pour la synchronisation
            objectWillChange.send()
        }
    }
    
    @AppStorage("focusModeAutoSync") var focusModeAutoSync: Bool = false {
        didSet {
            // Éviter les appels récursifs
            guard oldValue != focusModeAutoSync else { return }
            
            if focusModeAutoSync {
                FocusModeMonitor.shared.setAutoSync(true)
            } else {
                FocusModeMonitor.shared.setAutoSync(false)
            }
        }
    }
    
    @AppStorage("appLanguage") var appLanguage: String = "system" {
        didSet {
            // Mettre à jour la langue de l'application
            updateAppLanguage()
        }
    }
    
    @AppStorage("debugModeEnabled") var debugModeEnabled: Bool = false
    
    /// Met à jour la langue de l'application
    private func updateAppLanguage() {
        // La langue sera appliquée au prochain démarrage de l'app
        // Pour une mise à jour immédiate, on notifie le changement
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    @AppStorage("menuBarIconStyle") var menuBarIconStyle: MenuBarIconStyle = .pieRing {
        didSet {
            // Notifier le changement pour mettre à jour l'icône
            objectWillChange.send()
        }
    }
    
    // MARK: - Published Properties
    @Published var currentMl: Double = 0.0 {
        didSet {
            storedCurrentMl = currentMl
            saveTodayEntry()
        }
    }
    
    @Published var history: [DailyEntry] = []
    @Published var historyEntries: [HistoryEntry] = []
    @Published var showReminderBadge: Bool = false
    
    // MARK: - Undo Stack
    var undoStack: [(amount: Double, timestamp: Date)] = []
    private let maxUndoStackSize = 50 // Limiter la taille pour éviter la consommation mémoire
    
    // MARK: - Timer pour vérification quotidienne
    private var dailyCheckTimer: Timer?
    
    // MARK: - Timer pour vérification des rappels
    private var reminderCheckTimer: Timer?
    @AppStorage("lastWaterAddedDate") private var lastWaterAddedDateString: String = ""
    
    // MARK: - Computed Properties
    var targetMl: Double {
        get { storedTargetMl }
        set { storedTargetMl = newValue }
    }
    
    var selectedUnit: AppUnit {
        get {
            AppUnit(rawValue: storedSelectedUnitRaw) ?? .cl
        }
        set {
            storedSelectedUnitRaw = newValue.rawValue
        }
    }
    
    var presetsMl: [Double] {
        get {
            Array(rawValue: storedPresetsMlRaw) ?? [200.0, 500.0, 750.0]
        }
        set {
            storedPresetsMlRaw = newValue.rawValue
        }
    }
    
    var notificationInterval: NotificationInterval {
        get {
            NotificationInterval(rawValue: storedNotificationInterval) ?? .thirtyMinutes
        }
        set {
            storedNotificationInterval = newValue.rawValue
            if notificationsEnabled {
                scheduleNotifications()
                checkReminderStatus()
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        checkAndResetIfNeeded()
        loadHistory()
        setupNotificationCategories()
        
        // Initialiser la date de dernière consommation si elle n'existe pas
        if getLastWaterAddedDate() == nil {
            updateLastWaterAddedDate()
        }
        
        if notificationsEnabled {
            scheduleNotifications()
        }
        setupDailyResetTimer()
        setupReminderCheckTimer()
        
        // Démarrer la surveillance du Focus Mode
        FocusModeMonitor.shared.startMonitoring(manager: self)
        
        // Activer la synchronisation automatique si elle était activée
        if focusModeAutoSync {
            FocusModeMonitor.shared.setAutoSync(true)
        }
    }
    
    deinit {
        dailyCheckTimer?.invalidate()
        reminderCheckTimer?.invalidate()
    }
    
    // MARK: - Reset Logic
    private func checkAndResetIfNeeded() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastResetDateString = lastResetDateString.isEmpty ? nil : lastResetDateString,
           let lastResetDate = ISO8601DateFormatter().date(from: lastResetDateString) {
            let lastResetDay = calendar.startOfDay(for: lastResetDate)
            
            if lastResetDay < today {
                // Nouveau jour : sauvegarder l'entrée du jour précédent avant de reset
                saveHistoryEntry(date: lastResetDay, amountMl: storedCurrentMl, targetMl: targetMl)
                // Reset à 0 pour le nouveau jour
                currentMl = 0.0
                clearUndoStack() // Vider le stack undo pour le nouveau jour
                updateLastResetDate()

                // NEW: sync reset state to App Group
                syncToAppGroup()

                // Notifier le changement
                DispatchQueue.main.async {
                    self.objectWillChange.send()
                }
            } else {
                // Même jour, récupérer la valeur sauvegardée
                currentMl = storedCurrentMl
            }
        } else {
            // Première ouverture, reset à 0
            currentMl = 0.0
            updateLastResetDate()
        }
    }
    
    /// Configure un timer pour vérifier périodiquement si on a changé de jour
    private func setupDailyResetTimer() {
        // Vérifier toutes les minutes si on a passé minuit
        dailyCheckTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.checkAndResetIfNeeded()
        }
        
        // S'assurer que le timer fonctionne même quand l'app est en arrière-plan
        RunLoop.current.add(dailyCheckTimer!, forMode: .common)
    }
    
    /// Configure un timer pour vérifier périodiquement si un rappel doit être affiché
    private func setupReminderCheckTimer() {
        // Vérifier toutes les minutes si un rappel doit être affiché
        reminderCheckTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.checkReminderStatus()
        }
        
        // S'assurer que le timer fonctionne même quand l'app est en arrière-plan
        RunLoop.current.add(reminderCheckTimer!, forMode: .common)
        
        // Vérifier immédiatement
        checkReminderStatus()
    }
    
    /// Vérifie si un rappel doit être affiché (badge ou notification)
    func checkReminderStatus() {
        guard notificationsEnabled else {
            showReminderBadge = false
            return
        }
        
        // Calculer l'intervalle en minutes
        let intervalMinutes: Int
        switch notificationInterval {
        case .thirtyMinutes:
            intervalMinutes = 30
        case .twoHours:
            intervalMinutes = 120
        case .custom:
            intervalMinutes = customNotificationMinutes
        }
        
        // Vérifier si l'intervalle est écoulé depuis la dernière consommation
        let now = Date()
        let lastWaterDate = getLastWaterAddedDate() ?? now // Si jamais de consommation, utiliser maintenant
        let timeSinceLastWater = now.timeIntervalSince(lastWaterDate)
        let intervalInSeconds = TimeInterval(intervalMinutes * 60)
        
        if timeSinceLastWater >= intervalInSeconds {
            // L'intervalle est écoulé
            if doNotDisturb {
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
        let formatter = ISO8601DateFormatter()
        lastResetDateString = formatter.string(from: Date())
    }
    
    // MARK: - Public Methods
    
    /// Ajoute de l'eau (amount toujours en ml)
    /// Optimisée pour être appelée très fréquemment (ex: toutes les 0.05s pour "Hold to Add")
    /// - Parameter amount: Quantité en ml à ajouter
    /// - Parameter skipUndo: Si true, n'enregistre pas l'action dans le stack undo (pour regroupement)
    func addWater(amount: Double, skipUndo: Bool = false) {
        // amount est toujours en ml
        // Optimisation : pas de vérification de reset ici pour performance
        // Le reset est géré à l'initialisation et peut être déclenché manuellement
        
        // Enregistrer l'action pour undo (seulement si amount > 0 et skipUndo = false)
        if amount > 0 && !skipUndo {
            undoStack.append((amount: amount, timestamp: Date()))
            
            // Limiter la taille du stack
            if undoStack.count > maxUndoStackSize {
                undoStack.removeFirst()
            }
        }
        
        currentMl += amount

        // Mettre à jour la date de dernière consommation d'eau
        updateLastWaterAddedDate()

        // Réinitialiser le badge de rappel
        showReminderBadge = false

        // Repousser le prochain rappel après avoir ajouté de l'eau
        if notificationsEnabled {
            scheduleNotifications()
        }

        // NEW: sync state to App Group for widget and trigger widget refresh
        syncToAppGroup()
    }
    
    /// Met à jour la date de dernière consommation d'eau
    private func updateLastWaterAddedDate() {
        let formatter = ISO8601DateFormatter()
        lastWaterAddedDateString = formatter.string(from: Date())
    }
    
    /// Récupère la date de dernière consommation d'eau
    private func getLastWaterAddedDate() -> Date? {
        guard !lastWaterAddedDateString.isEmpty,
              let date = ISO8601DateFormatter().date(from: lastWaterAddedDateString) else {
            return nil
        }
        return date
    }
    
    /// Annule la dernière action d'ajout d'eau
    /// - Returns: true si une action a été annulée, false si le stack est vide
    @discardableResult
    func undo() -> Bool {
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
    
    /// Vide le stack undo (appelé lors du reset du jour)
    private func clearUndoStack() {
        undoStack.removeAll()
    }
    
    /// Remet la consommation du jour à zéro
    func resetDay() {
        // Sauvegarder l'entrée actuelle (qui sera 0) avant de reset
        // Le didSet de currentMl sauvegardera automatiquement
        currentMl = 0.0
        clearUndoStack() // Vider le stack undo lors du reset
        updateLastResetDate()
    }
    
    // MARK: - UI Helper Methods
    
    /// Convertit une valeur en ml vers l'unité choisie et la formate pour l'affichage
    /// - Parameter ml: Valeur en millilitres
    /// - Returns: String formatée avec l'unité (ex: "25.0 cl", "2.5 L", "8.5 oz")
    func displayValue(for ml: Double) -> String {
        let convertedValue = selectedUnit.fromMl(ml)
        
        // Formatage selon l'unité
        switch selectedUnit {
        case .cl:
            // Pour cl, afficher sans décimales si entier, sinon 1 décimale
            if convertedValue.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.0f cl", convertedValue)
            } else {
                return String(format: "%.1f cl", convertedValue)
            }
        case .liter:
            // Pour L, afficher 1-2 décimales si < 1L, sinon sans décimales si entier
            if convertedValue < 1.0 {
                return String(format: "%.2f L", convertedValue)
            } else if convertedValue.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.0f L", convertedValue)
            } else {
                return String(format: "%.1f L", convertedValue)
            }
        case .oz:
            // Pour oz, toujours 1 décimale
            return String(format: "%.1f oz", convertedValue)
        }
    }
    
    /// Convertit une valeur d'affichage (dans l'unité choisie) vers ml
    /// - Parameter display: Valeur dans l'unité actuellement sélectionnée
    /// - Returns: Valeur équivalente en millilitres
    func mlValue(from display: Double) -> Double {
        return selectedUnit.toMl(display)
    }
    
    // MARK: - History Management
    
    /// Chemin vers le fichier d'historique dans Application Support
    private var historyFileURL: URL {
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolderURL = appSupportURL.appendingPathComponent("HydroBar", isDirectory: true)
        
        // Créer le dossier s'il n'existe pas
        try? fileManager.createDirectory(at: appFolderURL, withIntermediateDirectories: true)
        
        return appFolderURL.appendingPathComponent("history.json")
    }
    
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
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        saveEntry(date: today, amount: currentMl)
        // saveHistoryEntry est appelé dans saveEntry, donc pas besoin de l'appeler ici
    }
    
    /// Sauvegarde une entrée pour une date donnée
    private func saveEntry(date: Date, amount: Double) {
        let calendar = Calendar.current
        let dateStart = calendar.startOfDay(for: date)
        
        // Mettre à jour ou créer l'entrée DailyEntry (legacy)
        let entry = DailyEntry(date: dateStart, amount: amount)
        
        // Charger l'historique actuel
        var entries = history
        
        // Retirer l'ancienne entrée pour cette date si elle existe
        entries.removeAll { entry in
            calendar.isDate(entry.date, inSameDayAs: dateStart)
        }
        
        // Ajouter la nouvelle entrée
        entries.append(entry)
        
        // Garder seulement les 7 derniers jours
        let today = calendar.startOfDay(for: Date())
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        entries = entries.filter { $0.date >= sevenDaysAgo }
        
        // Trier par date (plus ancien en premier)
        entries.sort { $0.date < $1.date }
        
        history = entries
        saveHistory()
        
        // Sauvegarder aussi dans HistoryEntry avec targetMl
        saveHistoryEntry(date: dateStart, amountMl: amount, targetMl: targetMl)
    }
    
    /// Sauvegarde une HistoryEntry avec targetMl historique
    private func saveHistoryEntry(date: Date, amountMl: Double, targetMl: Double) {
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
        
        // Garder seulement les 30 derniers jours
        let today = calendar.startOfDay(for: Date())
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today)!
        entries = entries.filter { $0.date >= thirtyDaysAgo }
        
        // Trier par date (plus ancien en premier)
        entries.sort { $0.date < $1.date }
        
        historyEntries = entries
        saveHistoryEntries()
    }
    
    /// Sauvegarde l'historique dans le fichier JSON
    private func saveHistory() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(history)
            try data.write(to: historyFileURL)
        } catch {
            print("Erreur lors de la sauvegarde de l'historique: \(error)")
        }
    }
    
    /// Charge l'historique depuis le fichier JSON
    private func loadHistory() {
        // Charger DailyEntry (legacy)
        do {
            let data = try Data(contentsOf: historyFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let entries = try decoder.decode([DailyEntry].self, from: data)
            
            // Garder seulement les 7 derniers jours
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today)!
            
            history = entries.filter { $0.date >= sevenDaysAgo }.sorted { $0.date < $1.date }
        } catch {
            // Fichier n'existe pas encore ou erreur de lecture
            history = []
        }
        
        // Charger HistoryEntry (avec targetMl)
        do {
            let data = try Data(contentsOf: historyEntriesFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let entries = try decoder.decode([HistoryEntry].self, from: data)
            
            // Garder seulement les 30 derniers jours
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today)!
            
            historyEntries = entries.filter { $0.date >= thirtyDaysAgo }.sorted { $0.date < $1.date }
        } catch {
            // Fichier n'existe pas encore ou erreur de lecture
            historyEntries = []
        }
    }
    
    /// Sauvegarde l'historique complet (HistoryEntry) dans le fichier JSON
    private func saveHistoryEntries() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(historyEntries)
            try data.write(to: historyEntriesFileURL)
        } catch {
            print("Erreur lors de la sauvegarde de l'historique complet: \(error)")
        }
    }
    
    /// Retourne les 7 derniers jours avec leurs pourcentages d'objectif
    func getLast7DaysData() -> [(date: Date, percentage: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var result: [(date: Date, percentage: Double)] = []
        
        // Générer les 7 derniers jours
        for i in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            
            // Chercher l'entrée correspondante dans l'historique
            if let entry = history.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                let percentage = targetMl > 0 ? min((entry.amount / targetMl) * 100, 100) : 0
                result.append((date: date, percentage: percentage))
            } else {
                // Pas d'entrée pour ce jour, 0%
                result.append((date: date, percentage: 0))
            }
        }
        
        // Inverser pour avoir du plus ancien au plus récent
        return result.reversed()
    }
    
    /// Calcule la série actuelle (streak) de jours consécutifs où l'objectif a été atteint
    func calculateStreak() -> Int {
        return currentStreak
    }
    
    // MARK: - Computed Properties for Statistics
    
    /// Somme des 7 derniers jours (aujourd'hui inclus)
    var weeklyTotal: Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        _ = calendar.date(byAdding: .day, value: -6, to: today)! // -6 pour avoir 7 jours au total (aujourd'hui + 6 jours passés)
        
        var total: Double = 0
        
        // Parcourir les 7 derniers jours (aujourd'hui inclus)
        for i in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            
            if calendar.isDate(date, inSameDayAs: today) {
                // Aujourd'hui : utiliser currentMl
                total += currentMl
            } else {
                // Jours passés : chercher dans l'historique
                if let entry = historyEntries.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                    total += entry.amountMl
                }
                // Si pas d'entrée, c'est 0 (jour sans consommation)
            }
        }
        
        return total
    }
    
    /// Moyenne sur les 7 derniers jours (aujourd'hui inclus)
    /// Divise par 7 pour avoir la vraie moyenne quotidienne
    var dailyAverage: Double {
        // Toujours diviser par 7 jours pour avoir la moyenne réelle
        return weeklyTotal / 7.0
    }
    
    /// Calcule la série de jours consécutifs (en comptant aujourd'hui si > 0, sinon en partant d'hier)
    /// où amountMl >= targetMl
    var currentStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var currentDate: Date
        
        // Vérifier si aujourd'hui a des données ou si currentMl > 0
        let todayEntry = historyEntries.first { calendar.isDate($0.date, inSameDayAs: today) }
        let todayAmount = todayEntry?.amountMl ?? currentMl
        
        if todayAmount > 0 {
            // Commencer par aujourd'hui
            currentDate = today
            let todayTarget = todayEntry?.targetMl ?? targetMl
            if todayAmount >= todayTarget {
                streak = 1
            } else {
                // Aujourd'hui n'a pas atteint l'objectif, streak = 0
                return 0
            }
        } else {
            // Pas de données aujourd'hui, commencer par hier
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }
            currentDate = yesterday
        }
        
        // Compter les jours consécutifs où l'objectif est atteint
        while true {
            // Passer au jour précédent
            guard let previousDate = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
            currentDate = previousDate
            
            if let entry = historyEntries.first(where: { calendar.isDate($0.date, inSameDayAs: currentDate) }) {
                if entry.amountMl >= entry.targetMl {
                    streak += 1
                } else {
                    break
                }
            } else {
                // Pas de données pour ce jour, arrêter le streak
                break
            }
        }
        
        return streak
    }
    
    /// Pourcentage global de réussite sur les 30 derniers jours
    var completionRate: Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today)!
        
        let relevantEntries = historyEntries
            .filter { $0.date >= thirtyDaysAgo && $0.date < today } // Exclure aujourd'hui
        
        guard !relevantEntries.isEmpty else { return 0 }
        
        let successfulDays = relevantEntries.filter { $0.amountMl >= $0.targetMl }.count
        return (Double(successfulDays) / Double(relevantEntries.count)) * 100
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
        if doNotDisturb {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            // Vérifier immédiatement le statut du badge
            checkReminderStatus()
            return
        }
        
        // Annuler les anciennes notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // Calculer l'intervalle en minutes
        let intervalMinutes: Int
        switch notificationInterval {
        case .thirtyMinutes:
            intervalMinutes = 30
        case .twoHours:
            intervalMinutes = 120
        case .custom:
            intervalMinutes = customNotificationMinutes
        }
        
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
                print("Erreur lors de la programmation de la notification: \(error)")
            }
        }
    }
    
    // MARK: - App Group Sync

    /// Writes the current hydration state to the shared App Group container for widget access.
    /// Must be called after every state mutation (addWater, undo, daily reset, target change).
    /// This is a lightweight write (~200 bytes) — safe to call at 20Hz during Hold-to-Add.
    private func syncToAppGroup() {
        let last7Days = getLast7DaysSnapshotsForWidget()
        let snapshot = HydrationSnapshot(
            currentMl: currentMl,
            targetMl: targetMl,
            unit: selectedUnit.rawValue,
            lastUpdated: Date(),
            weekHistory: last7Days
        )
        AppGroupStore.write(snapshot)

        // Trigger widget timeline refresh — widget process reads from AppGroupStore
        // reloadTimelines(ofKind:) is throttled by WidgetKit — call it after every mutation;
        // WidgetKit will debounce if called too frequently
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

    /// Génère de fausses données d'historique pour les tests
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
                print("Erreur lors de l'envoi de la notification de test: \(error)")
            } else {
                print("Notification de test envoyée avec succès")
            }
        }
    }
}
