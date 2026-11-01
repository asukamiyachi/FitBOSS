"use strict";
const test=require("node:test");
const assert=require("node:assert/strict");
const fs=require("node:fs");
const {initializeTestEnvironment,assertFails,assertSucceeds}=require("@firebase/rules-unit-testing");
let env;
test.before(async()=>{
  env=await initializeTestEnvironment({
    projectId:"demo-fitboss-rules",
    database:{rules:fs.readFileSync("firebase/database.rules.json","utf8")},
    firestore:{rules:fs.readFileSync("firebase/firestore.rules","utf8")}
  });
});
test.after(async()=>{if(env)await env.cleanup()});
const google=(uid)=>env.authenticatedContext(uid,{firebase:{sign_in_provider:"google.com"}});
test("Firestore rejects every unauthenticated or forged direct team write",async()=>{
  await assertFails(google("alice").firestore().doc("teams/team1").get());
  await assertFails(google("alice").firestore().doc("teams/team1").set({ownerUid:"alice"}));
  await assertFails(env.unauthenticatedContext().firestore().doc("workoutSessions/fake").set({uid:"alice"}));
  await assertFails(google("bob").firestore().doc("teams/team1/members/alice").set({role:"owner"}));
});
test("RTDB connection updates are user-scoped and value-limited",async()=>{
  const alice=google("alice").database(),bob=google("bob").database();
  const anon=env.unauthenticatedContext().database();
  const own=alice.ref("presenceConnections/alice/device-A");
  await assertSucceeds(own.set(true));
  await assertFails(bob.ref("presenceConnections/alice/device-B").set(true));
  await assertFails(anon.ref("presenceConnections/alice/device-C").set(true));
  await assertFails(alice.ref("presenceConnections/alice/device-B").set("offline"));
  await assertFails(alice.ref("presenceConnections/alice/bad.path").set(true));
  await assertSucceeds(own.remove());
});
test("RTDB team presence, private summary and room progress are not exposed to clients",async()=>{
  const alice=google("alice").database();
  await assertFails(alice.ref("presenceConnections/alice").once("value"));
  await assertFails(alice.ref("presenceConnections/bob").once("value"));
  await assertFails(alice.ref("presenceSummary/bob").once("value"));
  await assertFails(alice.ref("presenceSummary/alice").set({lastOfflineAt:1}));
  await assertFails(alice.ref("roomProgress/room1").once("value"));
  await assertFails(alice.ref("roomProgress/room1/alice").set({value:9999}));
});
