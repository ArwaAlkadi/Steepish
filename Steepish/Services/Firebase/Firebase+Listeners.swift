//
//  Firebase+Listeners.swift
//  StepGame
//

import Foundation
import FirebaseFirestore

extension FirebaseService {

    /// Listens to all challenges the player is part of.
    func listenMyChallenges(uid: String, onChange: @escaping ([Challenge]) -> Void) -> ListenerRegistration {
        db.collection("challenges")
            .whereField("playerIds", arrayContains: uid)
            .addSnapshotListener { snap, _ in
                let list: [Challenge] = (snap?.documents ?? []).compactMap { try? $0.data(as: Challenge.self) }
                onChange(list.sorted { $0.createdAt > $1.createdAt })
            }
    }

    /// Listens to a single challenge document.
    func listenChallenge(challengeId: String, onChange: @escaping (Challenge?) -> Void) -> ListenerRegistration {
        db.collection("challenges")
            .document(challengeId)
            .addSnapshotListener { snap, _ in
                guard let snap else { onChange(nil); return }
                onChange(try? snap.data(as: Challenge.self))
            }
    }

    /// Listens to all participants in a challenge.
    func listenParticipants(challengeId: String, onChange: @escaping ([ChallengeParticipant]) -> Void) -> ListenerRegistration {
        db.collection("challenges")
            .document(challengeId)
            .collection("participants")
            .addSnapshotListener { snap, _ in
                let list: [ChallengeParticipant] = (snap?.documents ?? []).compactMap { try? $0.data(as: ChallengeParticipant.self) }
                onChange(list)
            }
    }

    /// Listens to a single participant document.
    func listenMyParticipant(
        challengeId: String,
        uid: String,
        onChange: @escaping (ChallengeParticipant?) -> Void
    ) -> ListenerRegistration {
        db.collection("challenges")
            .document(challengeId)
            .collection("participants")
            .document(uid)
            .addSnapshotListener { snap, _ in
                guard let snap, snap.exists else { onChange(nil); return }
                onChange(try? snap.data(as: ChallengeParticipant.self))
            }
    }
}
