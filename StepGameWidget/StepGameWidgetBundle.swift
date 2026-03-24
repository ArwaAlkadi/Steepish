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
        .description("Track your steps and compete")
        .supportedFamilies([.systemMedium])
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
    let isSoloChallenge: Bool
    let startDate: Date
    let effectiveEndDate: Date
}

// MARK: - Custom Font

extension Font {
    static func russo(_ size: CGFloat) -> Font {
        .custom("RussoOne-Regular", size: size)
    }
}

// MARK: - Steps Formatter

private func formatSteps(_ steps: Int) -> String {
    guard steps >= 1000 else { return "\(steps)" }
    let k = Double(steps) / 1000.0
    if k.truncatingRemainder(dividingBy: 1) == 0 {
        return "\(Int(k))k"
    } else {
        return String(format: "%.1fk", k)
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
        let isSoloChallenge: String?
        let startDate: Date
        let effectiveEndDate: Date
    }

    func placeholder(in context: Context) -> StepEntry {
        StepEntry(
            date: Date(),
            challengeName: "No Challenge",
            userImage: "character1_normal",
            userSteps: 0,
            userGoal: 0,
            userName: "You",
            friendImage: "character2_normal",
            friendSteps: 0,
            friendGoal: 0,
            friendName: "Friend",
            isSoloChallenge: true,
            startDate: Date(),
            effectiveEndDate: Date().addingTimeInterval(7 * 86400)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (StepEntry) -> Void) {
        completion(loadEntry() ?? placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StepEntry>) -> Void) {
        let entry = loadEntry() ?? placeholder(in: context)
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60))))
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
            friendName: payload.friendName,
            isSoloChallenge: payload.isSoloChallenge == "solo",
            startDate: payload.startDate,
            effectiveEndDate: payload.effectiveEndDate
        )
    }
}

// MARK: - Player Card

private struct PlayerCardView: View {

    @Environment(\.widgetRenderingMode) private var renderingMode

    let challengeName: String
    let imageName: String
    let steps: Int
    let goal: Int
    let displayName: String
    var isSolo: Bool = false
    let startDate: Date
    let effectiveEndDate: Date

    private var isEnded: Bool {
        Date() >= effectiveEndDate
    }

    private var elapsedDays: Int {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: startDate)
        let today = calendar.startOfDay(for: Date())
        
        let diff = calendar.dateComponents([.day], from: startDay, to: today).day ?? 0
        let elapsed = max(1, diff + 1)
        return min(elapsed, totalDays)
    }

    private var totalDays: Int {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: effectiveEndDate)
        
        let diff = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
        return max(1, diff)
    }

    private var stepsDurationText: String {
        "\(formatSteps(steps)) steps in \(elapsedDays) of \(totalDays) days"
    }

    var body: some View {
        VStack(spacing: 6) {

            HStack(spacing: 4) {
                Text(challengeName)
                    .font(.russo(11))
                    .foregroundColor(.light1)
                    .widgetAccentable()
                    .lineLimit(1)

                if isEnded {
                    Text("Ended")
                        .font(.russo(8))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.red1))
                }
            }
            .offset(y: 50)

            Text("\(goal)")
                .font(.russo(28))
                .foregroundColor(.light2.opacity(0.4))
                .widgetAccentable()
                .padding(.horizontal, 3)
                .offset(y: 40)

            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(height: 100)
                .offset(y: 7)

            Text(displayName)
                .font(.russo(11))
                .foregroundColor(.light1)
                .widgetAccentable()

            HStack(spacing: 2) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.light2)
                    .widgetAccentable()

                Text(stepsDurationText)
                    .font(.russo(10))
                    .foregroundColor(.light2)
                    .widgetAccentable()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .offset(y: -10)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .frame(width: isSolo ? 320 : 160, height: 145)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    renderingMode == .accented
                    ? Color.clear
                    : Color.light3
                )
        )
    }
}

// MARK: - Entry View

struct StepGameWidgetEntryView: View {

    let entry: StepEntry
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        ZStack { content }
            .padding(10)
            .containerBackground(for: .widget) {
                renderingMode == .accented
                ? Color.clear
                : Color.light1
            }
    }

    @ViewBuilder
    private var content: some View {
        if entry.isSoloChallenge {
            PlayerCardView(
                challengeName: entry.challengeName,
                imageName: entry.userImage,
                steps: entry.userSteps,
                goal: entry.userGoal,
                displayName: "Me",
                isSolo: true,
                startDate: entry.startDate,
                effectiveEndDate: entry.effectiveEndDate
            )
        } else {
            HStack(spacing: 12) {
                PlayerCardView(
                    challengeName: entry.challengeName,
                    imageName: entry.userImage,
                    steps: entry.userSteps,
                    goal: entry.userGoal,
                    displayName: "Me",
                    isSolo: false,
                    startDate: entry.startDate,
                    effectiveEndDate: entry.effectiveEndDate
                )

                PlayerCardView(
                    challengeName: entry.challengeName,
                    imageName: entry.friendImage,
                    steps: entry.friendSteps,
                    goal: entry.friendGoal,
                    displayName: entry.friendName,
                    isSolo: false,
                    startDate: entry.startDate,
                    effectiveEndDate: entry.effectiveEndDate
                )
            }
        }
    }
}
