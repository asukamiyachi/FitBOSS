"use strict";

// Connections and the server-owned summary share one transaction boundary.
// The event timestamp is assigned by RTDB, so retries never move the time forward.
async function reconcilePresence(database, uid, disconnectedAt) {
  if (!Number.isFinite(disconnectedAt)) return;
  await database.ref("presence/" + uid).transaction(current => {
    current = current || {};
    if (Object.keys(current.connections || {}).length) return;
    if ((current.summary?.lastOfflineAt || 0) >= disconnectedAt) return;
    return {...current, summary: {lastOfflineAt: disconnectedAt}};
  }, undefined, false);
}
module.exports = {reconcilePresence};
