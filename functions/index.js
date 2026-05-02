const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.onNewAlert = functions.firestore
    .document("alerts/{alertId}")
    .onCreate((snap, context) => {
      const data = snap.data();

      if (data.severity === "High" || data.severity === "Critical") {
        const message = {
          topic: "disaster_alerts",

          notification: {
            title: "⚠️ EMERGENCY",
            body: data.title || "Critical Alert",
          },

          data: {
            type: "high_risk",
            title: "⚠️ EMERGENCY",
            body: data.title || "Critical Alert",
          },

          android: {
            priority: "high",
            notification: {
              channel_id: "high_risk_alerts",
              priority: "high",
              sound: "default",
            },
          },
        };

        return admin.messaging().send(message);
      }

      return null;
    });
