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
        
        let isSoloChallenge: String?
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
            isSoloChallenge: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (StepEntry) -> Void) {
        if let entry = loadEntry() {
            completion(entry)
        } else {
            completion(placeholder(in: context))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StepEntry>) -> Void) {
        if let entry = loadEntry() {
            let timeline = Timeline(entries: [entry],
                                    policy: .after(Date().addingTimeInterval(60 * 1)))
            completion(timeline)
        } else {
            let placeholder = placeholder(in: context)
            let timeline = Timeline(entries: [placeholder],
                                    policy: .after(Date().addingTimeInterval(60 * 1)))
            completion(timeline)
        }
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
            isSoloChallenge: payload.isSoloChallenge == "solo"
        )
    }
}

// MARK: - UI Components

private struct PlayerCardView: View {

    let challengeName: String
    let imageName: String

    let steps: Int
    let goal: Int
    let displayName: String
    
    var isSolo: Bool = false

    var body: some View {
        VStack(spacing: 6) {

            Text("\(challengeName)")
                .font(.russo(11))
                .foregroundColor(.light1)
                .offset(x: 0, y: 40)
                .lineLimit(1)
              
            
            Text("\(goal)")
                .font(.russo(28))
                .foregroundColor(.light2.opacity(0.5))
                .padding(.horizontal, 3)
                .offset(x: 0, y: 28)
                .lineLimit(1)
           

            Image("\(imageName)")
                .resizable()
                .scaledToFit()
                .frame(height: 100)

            HStack {
                
                Text(displayName)
                    .font(.russo(11))
                    .foregroundColor(.light1)
                    
                HStack(spacing: 2) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.light2)
                    Text("\(steps)")
                        .font(.russo(10))
                        .foregroundColor(.light2)
                

                    }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)

           

        }
        .frame(width: isSolo ? 320 : 160, height: 145)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.light3)
        )
        
    }
}



private struct NoActiveGroupChallengeView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.light3)

            VStack(spacing: 6) {
                Image(systemName: "person.2.slash")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.brown)

                Text("No active group challenge")
                    .font(.russo(10))
                    .foregroundColor(.brown)
                    .multilineTextAlignment(.center)

                Text("Join or start one to compete")
                    .font(.russo(10))
                    .foregroundColor(.brown)
                    .opacity(0.85)
            }
            .padding()
        }
        .frame(height: 140)
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
        /// If Solo Challenge - show single player only
        if entry.isSoloChallenge {
            PlayerCardView(
                challengeName: entry.challengeName,
                imageName: entry.userImage,
                steps: entry.userSteps,
                goal: entry.userGoal,
                displayName: "Me",
                isSolo: true
            )
        } else {
            /// Group Challenge - show both players
            HStack(spacing: 12) {

                PlayerCardView(
                    challengeName: entry.challengeName,
                    imageName: entry.userImage,
                    steps: entry.userSteps,
                    goal: entry.userGoal,
                    displayName: "Me",
                    isSolo: false
                )
                
                PlayerCardView(
                    challengeName: entry.challengeName,
                    imageName: entry.friendImage,
                    steps: entry.friendSteps,
                    goal: entry.friendGoal,
                    displayName: entry.friendName,
                    isSolo: false
                )
            }
        }
    }
}


#Preview(as: .systemMedium) {
    StepGameWidget()
} timeline: {
    StepEntry(
        date: Date(),
        challengeName: "Desert Run",
        userImage: "character1_normal",
        userSteps: 2000666,
        userGoal: 3000000,
        userName: "Me",
        friendImage: "character2_lazy",
        friendSteps: 1500,
        friendGoal: 3000,
        friendName: "Friend",
        isSoloChallenge: true
    )
}
