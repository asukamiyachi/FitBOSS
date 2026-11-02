"use strict";
const test=require("node:test");
const assert=require("node:assert/strict");
const fs=require("node:fs");
const path=require("node:path");
const rulesFile=(name)=>fs.readFileSync(path.join(__dirname,"..","..","firebase",name),"utf8");
const {initializeTestEnvironment,assertFails,assertSucceeds}=require("@firebase/rules-unit-testing");
let env;
test.before(async()=>{
  env=await initializeTestEnvironment({
    projectId:"demo-fitboss-rules",
    database:{rules:rulesFile("database.rules.json")},
    firestore:{rules:rulesFile("firestore.rules")}
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
  const own=alice.ref("presence/alice/connections/device-A");
  await assertSucceeds(own.set(true));
  await assertFails(bob.ref("presence/alice/connections/device-B").set(true));
  await assertFails(anon.ref("presence/alice/connections/device-C").set(true));
  await assertFails(alice.ref("presence/alice/connections/device-B").set("offline"));
  await assertFails(alice.ref("presence/alice/connections/bad:path").set(true));
  assert.throws(() => alice.ref("presence/alice/connections/bad.path"), /invalid path/i);
  await assertSucceeds(own.remove());
});
test("RTDB team presence, private summary and room progress are not exposed to clients",async()=>{
  const alice=google("alice").database();
  await assertFails(alice.ref("presence/alice/connections").once("value"));
  await assertFails(alice.ref("presence/bob/connections").once("value"));
  await assertFails(alice.ref("presence/bob/summary").once("value"));
  await assertFails(alice.ref("presence/alice/summary").set({lastOfflineAt:1}));
  await assertFails(alice.ref("roomProgress/room1").once("value"));
  await assertFails(alice.ref("roomProgress/room1/alice").set({value:9999}));
});
