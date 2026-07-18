# ``Steepish``
A competitive step challenge app that turns daily walking into a multiplayer game.

## Overview

Steepish is an iOS fitness app built with SwiftUI and Firebase. Players create or join step challenges, track their progress in real time via HealthKit, and compete on a live leaderboard. The app includes a sabotage mechanic where players can solve wiring puzzles to attack competitors or defend themselves, a home screen widget showing their character's current state, and push notifications for key in-game events.

## App Store

[View on App Store ↗](https://apps.apple.com/app/id6759177856)

## Repository

[View on GitHub ↗](https://github.com/ArwaAlkadi/Steepish)

## Data Storage Strategy

All game state is stored in Firestore and read in real time via snapshot listeners. HealthKit is the single source of truth for step counts — steps are fetched locally and synced to Firestore every 30 seconds while the app is active, and on foreground via `applicationWillEnterForeground`.

Puzzle timestamps are grouped under a nested `puzzleHistory` object inside each participant document to keep the data organized and reduce flat field clutter.

Notification cooldown timestamps are stored directly on the player document and checked by Cloud Functions before sending any push notification.

## Firestore Structure

```
players/{uid}
  name, characterType, fcmToken, createdAt
  lastAttackedNotificationAt, lastLazyNotificationAt,
  lastOvertakenNotificationAt, lastAttackOpportunityNotificationAt

challenges/{challengeId}
  name, joinCode, mode, originalMode, status
  goalSteps, durationDays, startDate, endDate, extensionSeconds
  createdBy, playerIds, nextPlace
  createdAt, startedAt, winnerId, winnerFinishedAt

challenges/{challengeId}/participants/{uid}
  playerId, steps, progress, characterState, lastSyncedAt
  sabotageState, sabotageExpiresAt, sabotageByPlayerId,
  sabotageAttackTimeSeconds, sabotageAppliedAt
  finishedAt, place, didShowResultPopup
  leftAt, leftAtSteps, createdAt, lastUpdated
  puzzleHistory: {
    soloAttemptedAt, soloDismissedAt, soloPuzzleFailedAt,
    groupAttackAttemptedAt, groupAttackDismissedAt,
    groupAttackPuzzleFailedAt, groupAttackSucceededAt,
    groupDefenseAttemptedAt, groupDefenseDismissedAt
  }
```

## Cloud Functions

| Function | Trigger | Description |
|---|---|---|
| `onChallengeParticipantUpdated` | Firestore document update | Sends push notifications for attack, lazy, overtaken, and attack opportunity events |
| `dailySilentSync` | Scheduled every 6 hours | Sends silent push to all active players to trigger background step sync |
| `runMigration` | HTTP (run once) | Migrates flat puzzle fields to nested `puzzleHistory` object — delete after use |

## Terms & Conditions and Privacy Policy

[View Privacy Policy ↗](https://steepish-policy.carrd.co)

## Topics

### App
- ``SteepishApp``
- ``AppDelegate``
- ``RootView``
- ``UserSession``

### Models
- ``Player``
- ``CharacterType``
- ``CharacterState``
- ``Challenge``
- ``ChallengeMode``
- ``ChallengeStatus``
- ``ChallengeParticipant``
- ``PuzzleHistory``
- ``PuzzleMode``
- ``AppConfig``

### Services — Firebase
- ``FirebaseService``

### Services — HealthKit
- ``HealthKitManager``

### Pages
- <doc:AppPages>

### Helpers
- ``ConnectivityMonitor``
- ``MapPathEditorHelper``
- ``OfflineBanner``
- ``WindTumbleweed``
- ``WindTumbleweedView``
- ``StatefulPreviewWrapper``

### Widget
- ``WidgetStore``

### Other
- <doc:Other>
