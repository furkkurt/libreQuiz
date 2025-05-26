const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

initializeApp();
const db = getFirestore();

// Cleanup old game rooms every hour
exports.cleanupOldRooms = onSchedule({
  schedule: "every 1 hours",
  region: "us-central1"
}, async () => {
  // Disable cleanup completely
  console.log("Room cleanup disabled");
  return null;
});

// Cleanup completed or empty rooms
exports.cleanupRoom = onDocumentUpdated({
  document: "gameRooms/{roomId}",
  region: "us-central1"
}, async (event) => {
  const roomData = event.data.after.data();
  const roomId = event.params.roomId;

  try {
    // Log room updates instead of deleting
    console.log(`Room ${roomId} updated:`, roomData);
    return null;
  } catch (error) {
    console.error(`Error in room ${roomId}:`, error);
    return null;
  }
});
