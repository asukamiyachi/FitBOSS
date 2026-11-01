"use strict";
const test=require("node:test");
const assert=require("node:assert/strict");
const fs=require("node:fs");
const {initializeTestEnvironment,assertFails,assertSucceeds}=require("@firebase/rules-unit-testing");
const {getDatabase,ref,set,get,remove}=require("firebase/database");
const {doc,getDoc,setDoc}=require("firebase/firestore");
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
  await assertFails(getDoc(doc(google("alice").firestore(),"teams/team1")));
  await assertFails(setDoc(doc(google("alice").firestore(),"teams/team1"),{ownerUid:"alice"}));
  await assertFails(setDoc(doc(env.unauthenticatedContext().firestore(),"workoutSessions/fake"),{uid:"alice"}));
  await assertFails(setDoc(doc(google("bob").firestore(),"teams/team1/members/alice"),{role:"owner"}));
});
test("RTDB connection updates are user-scoped and value-limited",async()=>{
  const alice=getDatabase(google("alice").app),bob=getDatabase(google("bob").app);
  const anon=getDatabase(env.unauthenticatedContext().app);
  const own=ref(alice,"presenceConnections/alice/device-A");
  await assertSucceeds(set(own,true));
  await assertFails(set(ref(bob,"presenceConnections/alice/device-B"),true));
  await assertFails(set(ref(anon,"presenceConnections/alice/device-C"),true));
  await assertFails(set(ref(alice,"presenceConnections/alice/device-B"),"offline"));
  await assertFails(set(ref(alice,"presenceConnections/alice/bad.path"),true));
  await assertSucceeds(remove(own));
});
test("RTDB team presence, private summary and room progress are not exposed to clients",async()=>{
  const alice=getDatabase(google("alice").app);
  await assertFails(get(ref(alice,"presenceConnections/alice")));
  await assertFails(get(ref(alice,"presenceConnections/bob")));
  await assertFails(get(ref(alice,"presenceSummary/bob")));
  await assertFails(set(ref(alice,"presenceSummary/alice"),{lastOfflineAt:1}));
  await assertFails(get(ref(alice,"roomProgress/room1")));
  await assertFails(set(ref(alice,"roomProgress/room1/alice"),{value:9999}));
});
