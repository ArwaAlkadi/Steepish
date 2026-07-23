const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");

admin.initializeApp();
setGlobalOptions({ maxInstances: 10 });

// =========================
// Config
// =========================

const NOTIFICATION_COOLDOWN_MINUTES = 120;

// =========================
// Helpers
// =========================

function playerRef(uid) {
  return admin.firestore().collection("players").doc(uid);
}

async function getPlayerDoc(uid) {
  return playerRef(uid).get();
}

async function getToken(uid) {
  const doc = await getPlayerDoc(uid);
  return doc.data()?.fcmToken ?? null;
}

async function getPlayerName(uid) {
  if (!uid) return "Someone";
  const doc = await getPlayerDoc(uid);
  return doc.data()?.name ?? "Someone";
}

async function getChallenge(challengeId) {
  const doc = await admin.firestore().collection("challenges").doc(challengeId).get();
  if (!doc.exists) return null;
  return { id: doc.id, ...doc.data() };
}

async function getChallengeName(challengeId) {
  const doc = await admin.firestore().collection("challenges").doc(challengeId).get();
  return doc.data()?.name ?? "your challenge";
}

async function getChallengeParticipants(challengeId) {
  const snapshot = await admin
    .firestore()
    .collection("challenges")
    .doc(challengeId)
    .collection("participants")
    .get();

  return snapshot.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  }));
}

function activeParticipantsOnly(list) {
  return list.filter((p) => !p.leftAt);
}

function minutesSince(date) {
  if (!date) return Infinity;
  return (Date.now() - date.getTime()) / (1000 * 60);
}

async function canSendNotification(uid, type) {
  const doc = await getPlayerDoc(uid);
  const data = doc.data() || {};

  const fieldMap = {
    attacked: "lastAttackedNotificationAt",
    lazy: "lastLazyNotificationAt",
    overtaken: "lastOvertakenNotificationAt",
    attackOpportunity: "lastAttackOpportunityNotificationAt",
  };

  const field = fieldMap[type];
  if (!field) return true;

  const lastAt = data[field]?.toDate?.() ?? null;
  return minutesSince(lastAt) >= NOTIFICATION_COOLDOWN_MINUTES;
}

async function markNotificationSent(uid, type) {
  const fieldMap = {
    attacked: "lastAttackedNotificationAt",
    lazy: "lastLazyNotificationAt",
    overtaken: "lastOvertakenNotificationAt",
    attackOpportunity: "lastAttackOpportunityNotificationAt",
  };

  const field = fieldMap[type];
  if (!field) return;

  await playerRef(uid).set(
    {
      [field]: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

function isSameDay(a, b) {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  );
}

// =========================
// Visible Push
// =========================

async function sendNotification(token, title, body, challengeId) {
  if (!token) {
    console.log("No token found");
    return;
  }

  try {
    const response = await admin.messaging().send({
      token,
      notification: {
        title,
        body,
      },
      data: {
        challengeId: challengeId ?? "",
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });

    console.log("Notification sent:", response);
  } catch (error) {
    console.error("FCM send failed:", JSON.stringify(error, null, 2));
    throw error;
  }
}

// =========================
// Silent Push
// =========================

async function sendSilentPush(token) {
  if (!token) {
    console.log("No token for silent push");
    return;
  }

  try {
    const response = await admin.messaging().send({
      token,
      apns: {
        headers: {
          "apns-push-type": "background",
          "apns-priority": "5",
        },
        payload: {
          aps: {
            "content-available": 1,
          },
        },
      },
    });

    console.log("Silent push sent:", response);
  } catch (error) {
    console.error("Silent push failed:", JSON.stringify(error, null, 2));
  }
}

// =========================
// Overtake Logic
// =========================

function getUsersOvertakenByUpdater(beforeList, afterList, updaterUid) {
  const beforeActive = activeParticipantsOnly(beforeList);
  const afterActive = activeParticipantsOnly(afterList);

  const updaterBefore = beforeActive.find(
    (p) => (p.playerId || p.id) === updaterUid
  );
  const updaterAfter = afterActive.find(
    (p) => (p.playerId || p.id) === updaterUid
  );

  if (!updaterBefore || !updaterAfter) return [];

  const updaterBeforeSteps = updaterBefore.steps || 0;
  const updaterAfterSteps = updaterAfter.steps || 0;

  const overtakenUserIds = [];

  for (const playerBefore of beforeActive) {
    const targetUid = playerBefore.playerId || playerBefore.id;
    if (targetUid === updaterUid) continue;

    const targetAfter = afterActive.find(
      (p) => (p.playerId || p.id) === targetUid
    );
    if (!targetAfter) continue;

    const targetBeforeSteps = playerBefore.steps || 0;
    const targetAfterSteps = targetAfter.steps || 0;

    const wasBehindBefore = updaterBeforeSteps < targetBeforeSteps;
    const isAheadNow = updaterAfterSteps > targetAfterSteps;

    if (wasBehindBefore && isAheadNow) {
      overtakenUserIds.push(targetUid);
    }
  }

  return overtakenUserIds;
}

// =========================
// Attack Opportunity Logic
// =========================

function isPlayerEligibleToAttack(participants, currentUid, challengeData, now = new Date()) {
  if (!challengeData) return false;

  const activeParticipants = activeParticipantsOnly(participants).sort(
    (a, b) => (b.steps || 0) - (a.steps || 0)
  );

  if (activeParticipants.length <= 1) return false;
  if (challengeData.status !== "active") return false;

  const me = activeParticipants.find((p) => (p.playerId || p.id) === currentUid);
  if (!me) return false;

  const goal = Math.max(challengeData.goalSteps || 1, 1);

  const startDateRaw = challengeData.startedAt || challengeData.startDate;
  const startDate = startDateRaw?.toDate
    ? startDateRaw.toDate()
    : startDateRaw
    ? new Date(startDateRaw)
    : null;

  if (!startDate || isNaN(startDate.getTime())) return false;

  const hoursElapsed = (now.getTime() - startDate.getTime()) / (1000 * 60 * 60);
  if (hoursElapsed < 3) return false;

  const iFinished = !!me.finishedAt || (me.steps || 0) >= goal;
  if (iFinished) return false;

  // Read from puzzleHistory nested object
  const attackAttemptedAtRaw = me.puzzleHistory?.groupAttackAttemptedAt;
  const attackAttemptedAt = attackAttemptedAtRaw?.toDate
    ? attackAttemptedAtRaw.toDate()
    : attackAttemptedAtRaw
    ? new Date(attackAttemptedAtRaw)
    : null;

  if (attackAttemptedAt && isSameDay(attackAttemptedAt, now)) {
    return false;
  }

  const myIndex = activeParticipants.findIndex(
    (p) => (p.playerId || p.id) === currentUid
  );
  if (myIndex <= 0) return false;

  const playerAbove = activeParticipants[myIndex - 1];
  if (!playerAbove) return false;

  const targetFinished = !!playerAbove.finishedAt || (playerAbove.steps || 0) >= goal;
  if (targetFinished) return false;

  const sabotageExpiresAt = playerAbove.sabotageExpiresAt?.toDate
    ? playerAbove.sabotageExpiresAt.toDate()
    : playerAbove.sabotageExpiresAt
    ? new Date(playerAbove.sabotageExpiresAt)
    : null;

  if (sabotageExpiresAt && now < sabotageExpiresAt) return false;

  if (playerAbove.characterState === "lazy") return false;

  return true;
}

// =========================
// Main Trigger
// =========================

exports.onChallengeParticipantUpdated = onDocumentUpdated(
  "challenges/{challengeId}/participants/{uid}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    const uid = event.params.uid;
    const challengeId = event.params.challengeId;

    const myToken = await getToken(uid);
    const challengeName = await getChallengeName(challengeId);

    // 1) Attacked notification
    try {
      if (myToken) {
        const wasAttacked = !before?.sabotageExpiresAt && after?.sabotageExpiresAt;

        if (wasAttacked) {
          const allowed = await canSendNotification(uid, "attacked");
          if (allowed) {
            const attackerName = await getPlayerName(after?.sabotageByPlayerId);
            await sendNotification(
              myToken,
              "You've been attacked",
              `${attackerName} sabotaged your character in ${challengeName} — fight back!`,
              challengeId
            );
            await markNotificationSent(uid, "attacked");
          }
        }
      }
    } catch (error) {
      console.error("Attacked notification failed:", error);
    }

    // 2) Lazy notification
    try {
      if (myToken) {
        const becameLazy =
          before?.characterState !== "lazy" && after?.characterState === "lazy";

        const isLazyFromSabotage = after?.sabotageExpiresAt != null;

        if (becameLazy && !isLazyFromSabotage) {
          const allowed = await canSendNotification(uid, "lazy");
          if (allowed) {
            await sendNotification(
              myToken,
              "Your character is lazy!",
              `You're falling behind in ${challengeName} — walk more to get back on track`,
              challengeId
            );
            await markNotificationSent(uid, "lazy");
          }
        }
      }
    } catch (error) {
      console.error("Lazy notification failed:", error);
    }

    // 3) Overtaken notification
    try {
      const currentParticipants = await getChallengeParticipants(challengeId);

      const beforeList = currentParticipants.map((p) => {
        if ((p.playerId || p.id) === uid) {
          return { ...p, ...before };
        }
        return p;
      });

      const afterList = currentParticipants.map((p) => {
        if ((p.playerId || p.id) === uid) {
          return { ...p, ...after };
        }
        return p;
      });

      const overtakenUsers = getUsersOvertakenByUpdater(beforeList, afterList, uid);

      if (overtakenUsers.length > 0) {
        const overtakerName = await getPlayerName(uid);

        for (const targetUid of overtakenUsers) {
          const allowed = await canSendNotification(targetUid, "overtaken");
          if (!allowed) {
            console.log(`Skip overtaken notification for ${targetUid} cooldown`);
            continue;
          }

          const targetToken = await getToken(targetUid);
          if (!targetToken) continue;

          await sendNotification(
            targetToken,
            "Someone passed you!",
            `${overtakerName} passed you in ${challengeName}. Walk more to take your place back`,
            challengeId
          );

          await markNotificationSent(targetUid, "overtaken");
        }
      }
    } catch (error) {
      console.error("Overtaken notification failed:", error);
    }

    // 4) Attack opportunity notification
    try {
      const challengeData = await getChallenge(challengeId);
      const currentParticipants = await getChallengeParticipants(challengeId);

      const beforeList = currentParticipants.map((p) => {
        if ((p.playerId || p.id) === uid) {
          return { ...p, ...before };
        }
        return p;
      });

      const afterList = currentParticipants.map((p) => {
        if ((p.playerId || p.id) === uid) {
          return { ...p, ...after };
        }
        return p;
      });

      const couldAttackBefore = isPlayerEligibleToAttack(beforeList, uid, challengeData);
      const canAttackNow = isPlayerEligibleToAttack(afterList, uid, challengeData);

      if (!couldAttackBefore && canAttackNow) {
        const allowed = await canSendNotification(uid, "attackOpportunity");
        if (allowed) {
          const token = await getToken(uid);
          if (token) {
            await sendNotification(
              token,
              "Attack opportunity!",
              `Open the app and sabotage your friend's character in ${challengeName}`,
              challengeId
            );
            await markNotificationSent(uid, "attackOpportunity");
          }
        }
      }
    } catch (error) {
      console.error("Attack opportunity notification failed:", error);
    }
  }
);

// =========================
// Daily Silent Push
// =========================

exports.dailySilentSync = onSchedule(
  {
    schedule: "every 6 hours",
    timeZone: "Asia/Riyadh",
  },
  async () => {
    console.log("Starting daily silent sync...");

    const challengesSnapshot = await admin
      .firestore()
      .collection("challenges")
      .where("status", "==", "active")
      .get();

    const activePlayerIds = new Set();

    for (const challengeDoc of challengesSnapshot.docs) {
      const participantsSnapshot = await admin
        .firestore()
        .collection("challenges")
        .doc(challengeDoc.id)
        .collection("participants")
        .get();

      for (const participantDoc of participantsSnapshot.docs) {
        const participant = participantDoc.data();
        if (participant.leftAt) continue;
        activePlayerIds.add(participantDoc.id);
      }
    }

    console.log(`Found ${activePlayerIds.size} active players`);

    for (const uid of activePlayerIds) {
      const token = await getToken(uid);
      if (!token) continue;
      await sendSilentPush(token);
    }

    console.log("Daily silent sync finished");
  }
);
