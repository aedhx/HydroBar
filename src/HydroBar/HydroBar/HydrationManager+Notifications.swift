//
//  HydrationManager+Notifications.swift
//  HydroBar
//
//  Rappels : programmation, actions et ménage.
//
//  Une notification sert à agir sans ouvrir l'app : ses boutons sont les
//  presets de l'utilisateur (ou les niveaux de la gourde), plus une quantité
//  libre et une pause. Son texte dit où l'on en est (cf. ReminderContent).
//

import Foundation
import UserNotifications

extension HydrationManager {

    enum NotificationID {
        static let reminderCategory = "HYDRATION_REMINDER"
        static let bottleCategory = "BOTTLE_REMINDER"
        static let presetActionPrefix = "DRINK_PRESET_"
        static let bottleActionPrefix = "BOTTLE_"
        static let customAction = "DRINK_CUSTOM"
        static let snoozeAction = "SNOOZE_ACTION"
        /// Ancienne action « Boire un verre », encore présente sur les
        /// notifications livrées avant la mise à jour.
        static let legacyDrinkAction = "DRINK_ACTION"
        static let lastCall = "LAST_CALL"
        static let afterCall = "AFTER_CALL"
        static let thread = "hydration-reminders"
    }

    /// Nombre de presets proposés en boutons : au-delà, le menu des actions
    /// devient une liste qu'on ne lit plus.
    private static let presetActionCount = 3

    // MARK: - Catégories

    /// Reconstruit les boutons des notifications. À rappeler quand les presets,
    /// l'unité ou le mode gourde changent : les libellés en dépendent.
    func refreshNotificationCategories() {
        let snooze = UNNotificationAction(
            identifier: NotificationID.snoozeAction,
            title: String(localized: "Snooze 1 Hour", comment: "Notification action button"),
            options: []
        )

        let presets = presetsMl.prefix(Self.presetActionCount).enumerated().map { index, amount in
            UNNotificationAction(identifier: NotificationID.presetActionPrefix + String(index),
                                 title: "+" + displayValue(for: amount),
                                 options: [])
        }
        let custom = UNTextInputNotificationAction(
            identifier: NotificationID.customAction,
            title: String(localized: "Other Amount…", comment: "Notification action: type an amount"),
            options: [],
            textInputButtonTitle: String(localized: "Log", comment: "Notification text input button: log the typed amount"),
            textInputPlaceholder: selectedUnit.symbol
        )
        let reminder = UNNotificationCategory(identifier: NotificationID.reminderCategory,
                                              actions: presets + [custom, snooze],
                                              intentIdentifiers: [], options: [])

        let marks = Bottle.marks.map { mark in
            UNNotificationAction(identifier: NotificationID.bottleActionPrefix + String(Int(mark * 100)),
                                 title: Self.bottleActionTitle(mark),
                                 options: [])
        }
        let bottle = UNNotificationCategory(identifier: NotificationID.bottleCategory,
                                            actions: marks + [snooze],
                                            intentIdentifiers: [], options: [])

        UNUserNotificationCenter.current().setNotificationCategories([reminder, bottle])
    }

    private static func bottleActionTitle(_ mark: Double) -> String {
        guard mark < 1 else {
            return String(localized: "Bottle Finished", comment: "Notification action: the bottle is empty")
        }
        return String(format: String(localized: "Bottle at %@", comment: "Notification action; %@ is ¼, ½ or ¾"),
                      mark == 0.25 ? "¼" : mark == 0.5 ? "½" : "¾")
    }

    private var reminderCategory: String {
        bottleModeEnabled ? NotificationID.bottleCategory : NotificationID.reminderCategory
    }

    // MARK: - Actions

    /// Réponse à un bouton d'une notification. `typedText` : texte saisi pour
    /// l'action « Autre quantité ».
    func handleNotificationAction(_ identifier: String, typedText: String?) {
        switch identifier {
        case NotificationID.snoozeAction:
            snoozeReminders(.oneHour)
        case NotificationID.customAction:
            guard let typedText,
                  let amount = ReminderContent.amountMl(fromTyped: typedText, unit: selectedUnit)
            else { return }
            addWater(amount: amount)
        case NotificationID.legacyDrinkAction:
            if let first = presetsMl.first { addWater(amount: first) }
        case let id where id.hasPrefix(NotificationID.presetActionPrefix):
            guard let index = Int(id.dropFirst(NotificationID.presetActionPrefix.count)),
                  presetsMl.indices.contains(index)
            else { return }
            addWater(amount: presetsMl[index])
        case let id where id.hasPrefix(NotificationID.bottleActionPrefix):
            guard let percent = Int(id.dropFirst(NotificationID.bottleActionPrefix.count)) else { return }
            setBottleLevel(Double(percent) / 100)
        default:
            break
        }
    }

    // MARK: - Programmation

    /// Programme les prochains rappels et le dernier appel du soir.
    func scheduleNotifications() {
        removePendingReminders()

        // Mode Ne pas déranger : la pastille remplace la notification. En
        // appel, les rappels attendent la fin de l'appel.
        guard notificationsEnabled, !isQuietMode, !isUserAway, !isInCall else {
            nextPlannedReminder = nil
            checkReminderStatus()
            return
        }
        showReminderBadge = false

        let now = Date()
        let calendar = Calendar.current
        let context = reminderContext(now: now)
        var dates = ReminderPlanner.upcoming(context, limit: Self.maxPlannedReminders)

        let rules = todayRules
        let day = ReminderContent.Day(currentMl: log.total(on: now, calendar: calendar), targetMl: targetMl,
                                      startHour: rules.startHour, endHour: rules.endHour)

        var lastCall: Date?
        if lastCallEnabled, rules.remindersEnabled,
           let date = ReminderContent.lastCallDate(now: now, day: day, calendar: calendar),
           remindersSnoozedUntil.map({ date > $0 }) ?? true {
            lastCall = date
            // Pas deux notifications à quelques minutes d'écart.
            dates.removeAll { abs($0.timeIntervalSince(date)) < 20 * 60 }
        }
        nextPlannedReminder = (dates + [lastCall].compactMap { $0 }).min()

        for (index, date) in dates.enumerated() {
            let message = ReminderContent.message(at: date, now: now, day: day, calendar: calendar,
                                                  format: displayValue(for:))
            add(reminder: message.body, at: date, now: now,
                identifier: "\(Self.reminderIdentifierPrefix)_\(index)",
                sound: message.isBehind)
        }
        if let lastCall {
            add(reminder: ReminderContent.lastCallBody(day: day, format: displayValue(for:)), at: lastCall, now: now,
                identifier: NotificationID.lastCall, sound: true,
                title: String(localized: "Last Call", comment: "Last call notification title"))
        }
    }

    /// - Parameter sound: seulement quand le rappel compte (retard, dernier
    ///   appel) ; dans les temps, il s'affiche sans bruit.
    private func add(reminder body: String, at date: Date, now: Date, identifier: String,
                     sound: Bool, title: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title ?? String(localized: "Hydrobar", comment: "Notification title")
        content.body = body
        content.sound = sound ? .default : nil
        content.categoryIdentifier = reminderCategory
        content.threadIdentifier = NotificationID.thread

        // Déclencheurs non répétitifs : un intervalle fixe répété ignorait
        // la plage active et l'objectif atteint.
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(date.timeIntervalSince(now), 1),
                                                        repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Self.logger.error("Échec de programmation d'un rappel: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func removePendingReminders() {
        let ids = [Self.reminderIdentifierPrefix, NotificationID.lastCall, NotificationID.afterCall]
            + (0..<Self.maxPlannedReminders).map { "\(Self.reminderIdentifierPrefix)_\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Ménage

    private static func isReminder(_ identifier: String) -> Bool {
        identifier.hasPrefix(reminderIdentifierPrefix)
            || identifier == NotificationID.lastCall
            || identifier == NotificationID.afterCall
    }

    /// Après une prise, les rappels restés dans le Centre de notifications
    /// n'ont plus lieu d'être.
    func clearDeliveredReminders() {
        let center = UNUserNotificationCenter.current()
        center.getDeliveredNotifications { delivered in
            let ids = delivered.map(\.request.identifier).filter(HydrationManager.isReminder)
            center.removeDeliveredNotifications(withIdentifiers: ids)
        }
    }

    /// Un seul rappel visible à la fois : le plus récent remplace les autres.
    func keepOnlyLatestDeliveredReminder() {
        let center = UNUserNotificationCenter.current()
        center.getDeliveredNotifications { delivered in
            let reminders = delivered
                .filter { HydrationManager.isReminder($0.request.identifier) }
                .sorted { $0.date < $1.date }
            let stale = reminders.dropLast().map(\.request.identifier)
            guard !stale.isEmpty else { return }
            center.removeDeliveredNotifications(withIdentifiers: stale)
        }
    }

    // MARK: - Appels

    /// Fin d'un appel : si un rappel est tombé pendant, il part maintenant,
    /// avec une minute de battement pour raccrocher.
    func callDidEnd() {
        scheduleNotifications()
        guard notificationsEnabled, !isQuietMode, !isUserAway,
              ReminderPlanner.isDue(reminderContext(now: Date()))
        else { return }
        let now = Date()
        add(reminder: String(localized: "Call's over. Time for a glass?", comment: "Reminder sent right after a call"),
            at: now.addingTimeInterval(60), now: now, identifier: NotificationID.afterCall, sound: true)
    }
}
