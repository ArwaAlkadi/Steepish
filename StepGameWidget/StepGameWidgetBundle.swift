//
//  StepGameWidget.swift
//  StepGameWidgetExtension
//

import WidgetKit
import SwiftUI

@main
struct StepGameWidget: Widget {

    let kind: String = "SteepishWidget" 

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StepGameWidgetProvider()) { entry in
            StepGameWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Steepish")
        .description("Track your steps and compete.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Entry Model

struct StepEntry: TimelineEntry {
    let date: Date

    let challengeName: String

    let userImage: String
    let userSteps: Int
    let userGoal: Int
    let userName: String

    let friendImage: String
    let friendSteps: Int
    let friendGoal: Int
    let friendName: String
}

// MARK: - Custom Font

extension Font {
    static func russo(_ size: CGFloat) -> Font {
        .custom("RussoOne-Regular", size: size)
    }
}

// MARK: - Provider

struct StepGameWidgetProvider: TimelineProvider {

    private let suite = "group.com.2026.StepGame.shared"
    private let payloadKey = "widget_payload"

    private struct Payload: Codable {
        let challengeName: String

        let userName: String
        let userSteps: Int
        let userGoal: Int
        let userImage: String

        let friendName: String
        let friendSteps: Int
        let friendGoal: Int
        let friendImage: String
    }

    func placeholder(in context: Context) -> StepEntry { demoEntry }

    func getSnapshot(in context: Context, completion: @escaping (StepEntry) -> Void) {
        completion(loadEntry() ?? demoEntry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StepEntry>) -> Void) {
        let entry = loadEntry() ?? demoEntry
        let timeline = Timeline(entries: [entry],
                                policy: .after(Date().addingTimeInterval(60 * 15)))
        completion(timeline)
    }

    private func loadEntry() -> StepEntry? {
        guard
            let data = UserDefaults(suiteName: suite)?.data(forKey: payloadKey),
            let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else { return nil }

        return StepEntry(
            date: Date(),
            challengeName: payload.challengeName,
            userImage: payload.userImage,
            userSteps: payload.userSteps,
            userGoal: payload.userGoal,
            userName: payload.userName,
            friendImage: payload.friendImage,
            friendSteps: payload.friendSteps,
            friendGoal: payload.friendGoal,
            friendName: payload.friendName
        )
    }

    private var demoEntry: StepEntry {
        StepEntry(
            date: Date(),
            challengeName: "Desert Run",
            userImage: "character1_normal",
            userSteps: 2666,
            userGoal: 3000,
            userName: "You",
            friendImage: "character2_lazy",
            friendSteps: 1500,
            friendGoal: 3000,
            friendName: "Friend"
        )
    }
}

// MARK: - UI Components

private struct PlayerCardView: View {

    let challengeName: String
  
    let steps: Int
    let goal: Int
    let displayName: String

    var body: some View {
        VStack(spacing: 6) {

            // Top: Goal number
            Text("\(goal)")
                .font(.russo(24))
                .foregroundColor(.brown)
                .opacity(0.9)
                .padding(.top, 8)

            Spacer()

            // Avatar
            Image("character1_active")
                .resizable()
                .scaledToFit()
                .frame(height: 50)

            Spacer()

            // Bottom info
            VStack(spacing: 3) {

                // Challenge name + steps
                HStack(spacing: 4) {
                    Text(challengeName)
                        .font(.russo(10))
                        .foregroundColor(.brown)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Spacer(minLength: 0)

                    HStack(spacing: 2) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.brown)
                        Text("\(steps)")
                            .font(.russo(11))
                            .foregroundColor(.brown)
                    }
                }

                Text(displayName)
                    .font(.russo(10))
                    .foregroundColor(.brown)
                    .opacity(0.85)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
          
        }
        .frame(width: 160, height: 140)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    .light3
                )
            
        )
    }
}

// MARK: - Entry View

struct StepGameWidgetEntryView: View {

    let entry: StepEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            content
        }
        .padding(10)
        .containerBackground(for: .widget) {
            Color.light1
        }
    }

    @ViewBuilder
    private var content: some View {
        if family == .systemSmall {

            PlayerCardView(
                challengeName: entry.challengeName,
                steps: entry.userSteps,
                goal: entry.userGoal,
                displayName: "Me"
            )

        } else {

            HStack(spacing: 12) {

                PlayerCardView(
                    challengeName: entry.challengeName,
                    steps: entry.userSteps,
                    goal: entry.userGoal,
                    displayName: "Me" 
                )

                PlayerCardView(
                    challengeName: entry.challengeName,
                    steps: entry.friendSteps,
                    goal: entry.friendGoal,
                    displayName: entry.friendName
                )
            }
        }
    }
}
