//
//  WidgetStore.swift
//  Steepish
//

import Foundation
import WidgetKit

// MARK: - Widget Store

/// Writes the shared step/challenge snapshot to the app group so the home screen widget can read it.
enum WidgetStore {

    static let suite = "group.com.2026.StepGame.shared"
    static let payloadKey = "widget_payload"
    static let widgetKind = "SteepishWidget"

    /// The data shape shared between the app and the widget extension via the app group.
    struct Payload: Codable {
        let challengeName: String

        let userName: String
        let userSteps: Int
        let userGoal: Int
        let userImage: String

        let friendName: String
        let friendSteps: Int
        let friendGoal: Int
        let friendImage: String

        let isSoloChallenge: String?

        let startDate: Date
        let effectiveEndDate: Date
    }

    /// Encodes and saves the current snapshot, then reloads the widget's timeline.
    static func save(
        challengeName: String,
        userName: String,
        userSteps: Int,
        userGoal: Int,
        userImage: String,
        friendName: String,
        friendSteps: Int,
        friendGoal: Int,
        friendImage: String,
        isSoloChallenge: String?,
        startDate: Date,
        effectiveEndDate: Date
    ) {
        let payload = Payload(
            challengeName: challengeName,
            userName: userName,
            userSteps: userSteps,
            userGoal: userGoal,
            userImage: userImage,
            friendName: friendName,
            friendSteps: friendSteps,
            friendGoal: friendGoal,
            friendImage: friendImage,
            isSoloChallenge: isSoloChallenge,
            startDate: startDate,
            effectiveEndDate: effectiveEndDate
        )

        guard let data = try? JSONEncoder().encode(payload) else { return }

        UserDefaults(suiteName: suite)?.set(data, forKey: payloadKey)
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }
}

