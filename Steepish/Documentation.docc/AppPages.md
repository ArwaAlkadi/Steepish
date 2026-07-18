# Pages

Overview of all screens and their responsibilities in Steepish.

## Topics

### Splash

Shown on launch while the app bootstraps Firebase authentication, fetches the player profile, and checks the minimum app version. It stays visible for at least 1.8 seconds before transitioning.

- ``SplashView``
- ``SplashViewModel``
- ``LottieAnimationViewRepresentable``

### Onboarding

Shown once on first launch. Walks the user through the app concept before they enter their name.

- ``OnboardingView``
- ``OnboardingViewModel``

### Enter Name

Shown when no player profile exists. The user enters a display name, which is saved to Firestore under `players/{uid}`.

- ``EnterNameView``
- ``EnterNameViewModel``
- ``KeyboardObserver``

### Start

The home screen. Shown when the player has no active challenge or when HealthKit is not authorized. Allows the player to create a new challenge or join one using a code.

- ``StartView``
- ``StartViewModel``
- ``JoinCodePopup``

### Setup Challenge

A sheet where the player configures a new challenge, including its name, mode, step goal, and duration.

- ``SetupChallengeView``
- ``SetupChallengeViewModel``
- ``ModeOption``
- ``DateRangePicker``

### Waiting Room

Shown to all players in a group challenge before the host starts it. Displays the join code and a list of players who have joined.

- ``WaitingRoomView``
- ``WaitingRoomViewModel``
- ``LobbyPlayer``
- ``ActivityView``

### Map

The main game screen. Shows all players on an animated map path, a live leaderboard HUD, step progress, and the number of days remaining. It also triggers puzzle popups for solo extensions, group attacks, and group defenses.

- ``MapView``
- ``MapViewModel``
- ``MapPopupType``

### Challenges Sheet

A bottom sheet listing all of the player's active and ended challenges. Includes rename, delete confirmation, and challenge result popups.

- ``ChallengesSheet``
- ``ChallengesCard``
- ``RenamePopup``
- ``ConfirmPopup``
- ``ChallengeResultPopup``
- ``ChallengeResultPopupViewModel``

### Puzzle

The wiring puzzle mini-game. It is used in three contexts: solo extension, group attack, and group defense. The outcome is written to `puzzleHistory` in Firestore.

- ``PuzzleWiringView``
- ``WiringBoardView``
- ``WavyLinePath``
- ``WireNodeCircle``
- ``WiringGameViewModel``
- ``WiringGameState``
- ``WireColor``
- ``WiringCircle``
- ``WiringLine``
- ``PuzzleRequest``
- ``PuzzleContext``
- ``PuzzleEndReason``
- ``PuzzleResult``
- ``SoloLatePopupView``
- ``GroupAttackPopupView``
- ``GroupDefensePopupView``
- ``PuzzleResultPopup``

### Profile

Allows the player to update their display name and character skin. Changes are saved to Firestore immediately.

- ``ProfileView``
- ``ProfileViewModel``
