# Steepish

**Turn your daily steps into a race.**

Steepish is an iOS fitness game that turns step counting into real-time competitive challenges. Steps sync automatically from HealthKit and move an animated character across a map — fall behind and it goes *lazy*, walk more and it powers up. Race friends, sabotage the player ahead of you, and defend yourself through a fast-paced wiring puzzle.


## Features

- **Solo & group challenges** (up to 4 players) with a shareable join code
- **Automatic step tracking** via HealthKit — no manual input
- **Live map race** updated in real time through Firestore listeners
- **Dynamic character states**: `active`, `normal`, `lazy`, `win`
- **Sabotage system** — attack the player directly above you on the leaderboard
- **Wiring puzzle mini-game** powering attacks, defenses, and solo rewards
- **Smart push notifications** with per-player cooldowns
- **Home Screen widget** showing your character, your rival, and live progress
- **Offline banner** and graceful sync recovery, plus a remote forced-update gate

<img width="1920" height="1080" alt="Steepish" src="https://github.com/user-attachments/assets/744e1fc0-9a8a-4158-934f-534d8981d535" />
<img width="7680" height="4320" alt="Widget copy" src="https://github.com/user-attachments/assets/7c8f8f63-8056-4e71-ac86-74a6b6d16d73" />

## How the Game Works

Each challenge has a **step goal** and a **duration**. In group mode, the host creates it, players join by code, and the host starts the race. If everyone else leaves, it degrades gracefully into a solo challenge. The first player to hit the goal claims the win **atomically** via a Firestore transaction — one winner, no race conditions.

Character appearance reflects your real pace: consistent walking keeps it active, slacking makes it lazy — and open to attacks. Sabotage temporarily overrides your state until it expires or you defend it.

### The Wiring Puzzle
A 7-second shuffled color-matching puzzle that drives three mechanics:

| Context | Trigger | Outcome |
|---|---|---|
| **Solo Extension** | Falling behind your goal | Solve it → **+1 day** extension |
| **Group Attack** | Player above you is vulnerable | Solve it → they go lazy for a while |
| **Group Defense** | You've been attacked | Solve it *faster than your attacker* → cancel the sabotage |

Attack vs. defense is decided by **solve time**, with attempt limits and cooldowns per puzzle type to keep it fair.


## Architecture

MVVM with a clear split between UI, state, and services:

```
Steepish
├── StepGame/            # Main iOS app
│   ├── App/             # Entry, RootView router, GameSession
│   ├── Models/          # Player, Challenge, ChallengeParticipant
│   ├── Pages/           # Feature screens (View + ViewModel):
│   │                    # Map, Puzzle, SetupChallenge, Challenges,
│   │                    # Onboarding, Splash, Start, Profile, Waiting
│   ├── Services/        # Firebase, HealthKit, Notifications, AppConfig
│   └── Widget/          # WidgetStore (App Group bridge)
├── StepGameWidget/      # WidgetKit extension
└── functions/           # Firebase Cloud Functions (Node.js)
```

- **`GameSession`** — single `@MainActor` object owning auth, player, challenges, and participants, kept live via Firestore listeners
- **`FirebaseService`** — anonymous sign-in, challenge CRUD, atomic winner claiming, sabotage writes, real-time listeners
- **`HealthKitManager`** — verifies authorization by *actually attempting a read*, not trusting the status API
- **`RootView`** — state-driven router rebuilt from a composite key (player → HealthKit → challenge status)
- **`WidgetStore`** — serializes the race snapshot into a shared App Group for the widget


## Backend — Cloud Functions

- **`onChallengeParticipantUpdated`** — Firestore trigger powering four notifications, each with a **2-hour per-player cooldown**: **Attacked**, **Lazy** (inactivity, not sabotage), **Overtaken**, and **Attack opportunity**.
- **`dailySilentSync`** — runs every 6 hours (`Asia/Riyadh`), sending silent pushes to active participants so the app syncs fresh HealthKit steps in the background and leaderboards/widgets stay accurate.


## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift · JavaScript (Node.js) |
| UI | SwiftUI · Lottie |
| Health & Widget | HealthKit (read-only) · WidgetKit + App Groups |
| Backend | Firebase — Auth, Firestore, FCM, Cloud Functions v2 |
| Architecture | MVVM + centralized session state |
| Dependencies | firebase-ios-sdk 12.8+ · lottie-ios 4.6+ (SPM) |
