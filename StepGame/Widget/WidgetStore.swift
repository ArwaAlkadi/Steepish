//
//  WidgetStore.swift
//  StepGame
//

import Foundation
import WidgetKit

enum WidgetStore {

    static let suite = "group.com.2026.StepGame.shared"
    static let payloadKey = "widget_payload"
    static let widgetKind = "SteepishWidget"

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
    }

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
        isSoloChallenge: String?
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
            isSoloChallenge: isSoloChallenge
        )

        guard let data = try? JSONEncoder().encode(payload) else { return }

        UserDefaults(suiteName: suite)?.set(data, forKey: payloadKey)
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }
}
