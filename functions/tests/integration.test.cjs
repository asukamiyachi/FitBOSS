"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const {initializeApp, getApps, deleteApp: deleteAdminApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getDatabase} = require("firebase-admin/database");
const {initializeApp: clientApp, deleteApp} = require("firebase/app");
const {getAuth, connectAuthEmulator, signInWithCredential, GoogleAuthProvider, signInAnonymously} = require("firebase/auth");
const {getFunctions, connectFunctionsEmulator, httpsCallable} = require("firebase/functions");
const {getDatabase: clientDB, connectDatabaseEmulator, ref, set, onDisconnect, goOffline} = require("firebase/database");
const {reconcilePresence} = require("../src/presence");
for (const name of ["FIRESTORE_EMULATOR_HOST", "FIREBASE_DATABASE_EMULATOR_HOST", "FIREBASE_AUTH_EMULATOR_HOST"]) {
  assert.ok(process.env[name], `${name} is required; integration tests must run only in emulators`);
}
const projectId = "demo-fitboss-rules";
const app = initializeApp({projectId, databaseURL: `https://${projectId}.firebaseio.com`});
const fs = getFirestore(app), db = getDatabase(app), clients=[];
async function user(name, anonymous=false) {
  const app=clientApp({projectId, apiKey:"fake-key",authDomain:`${projectId}.firebaseapp.com`,databaseURL:`https://${projectId}.firebaseio.com`},name);
  clients.push(app);
  const auth=getAuth(app); connectAuthEmulator(auth,"http://127.0.0.1:9099",{disableWarnings:true});
  const token=JSON.stringify({sub:name,email:`${name}@example.test`,email_verified:true});
  const result=anonymous ? await signInAnonymously(auth) : await signInWithCredential(auth,GoogleAuthProvider.credential(token));
  const functions=getFunctions(app,"asia-southeast1"); connectFunctionsEmulator(functions,"127.0.0.1",5001);
  return {uid:result.user.uid,app,call:async (name,data={})=>(await httpsCallable(functions,name)(data)).data};
}
async function rejects(fn, code) { await assert.rejects(fn, e=>e.code===`functions/${code}`); }
async function eventually(fn) {
  const end=Date.now()+15000;
  while(Date.now()<end) { if(await fn()) return; await new Promise(r=>setTimeout(r,100)); }
  assert.fail("emulator state did not converge");
}
test.after(async()=>{
  await Promise.all(clients.map(deleteApp));
  await fs.terminate();
  await Promise.all(getApps().map(deleteAdminApp));
});
test("callable auth, cross-team isolation, invites, concurrent capacity, withdrawal and idempotency",async()=>{
  const host=await user("host"), outsider=await user("outsider"), anon=await user("anonymous",true);
  await rejects(()=>anon.call("createTeam",{name:"forbidden"}),"unauthenticated");
  const unauthenticatedApp=clientApp({projectId,apiKey:"fake-key"},"no-auth"); clients.push(unauthenticatedApp);
  const noAuth=getFunctions(unauthenticatedApp,"asia-southeast1");
  connectFunctionsEmulator(noAuth,"127.0.0.1",5001);
  await rejects(()=>httpsCallable(noAuth,"getTeamOverview")({teamId:"fake"}),"unauthenticated");
  const team=await host.call("createTeam",{name:"test"});
  const other=await outsider.call("createTeam",{name:"other"});
  for(const api of ["getTeamOverview","getTeamRanking","listPastRooms"]) {
    await rejects(()=>outsider.call(api,{teamId:team.teamId,period:"week",uid:host.uid}),"permission-denied");
    await rejects(()=>host.call(api,{teamId:other.teamId,period:"week"}),"permission-denied");
  }
  const guests=await Promise.all(Array.from({length:6},(_,i)=>user(`guest${i}`)));
  for(const g of guests) await g.call("joinTeam",{inviteCode:team.inviteCode});
  const room=await host.call("createRoom",{teamId:team.teamId,exerciseId:"push_up",invitedUids:guests.slice(0,5).map(g=>g.uid)});
  await rejects(()=>guests[5].call("joinRoom",{inviteCode:room.inviteCode}),"permission-denied");
  await rejects(()=>outsider.call("joinRoom",{inviteCode:room.inviteCode}),"permission-denied");
  // Seed a legacy/malformed invite list with six invitees to exercise actual
  // simultaneous sixth/seventh contention (normal createRoom permits only five).
  await fs.doc(`rooms/${room.roomId}`).update({invitedUids:guests.map(g=>g.uid)});
  for(const g of guests.slice(0,4)) await g.call("joinRoom",{inviteCode:room.inviteCode});
  const race=await Promise.allSettled(guests.slice(4).map(g=>g.call("joinRoom",{inviteCode:room.inviteCode})));
  assert.equal(race.filter(r=>r.status==="fulfilled").length,1);
  assert.equal(race.find(r=>r.status==="rejected").reason.code,"functions/resource-exhausted");
  assert.equal((await fs.doc(`rooms/${room.roomId}`).get()).data().participantUids.length,6);
  await host.call("startRoom",{roomId:room.roomId});
  await guests[0].call("updateRoomProgress",{roomId:room.roomId,value:1,uid:host.uid});
  assert.equal((await db.ref(`roomProgress/${room.roomId}/${host.uid}`).get()).exists(),false);
  await rejects(()=>outsider.call("updateRoomProgress",{roomId:room.roomId,value:1}),"permission-denied");
  await rejects(()=>guests[0].call("finishRoom",{roomId:room.roomId}),"permission-denied");
  const session={teamId:team.teamId,sessionId:crypto.randomUUID(),exerciseId:"push_up",repetitions:3,completedAt:Date.now()};
  const submissions=await Promise.all([guests[0].call("submitWorkout",session),guests[0].call("submitWorkout",session)]);
  assert.equal(submissions.filter(s=>s.created).length,1);
  await guests[0].call("submitWorkout",{...session,sessionId:crypto.randomUUID()});
  const ranks=await host.call("getTeamRanking",{teamId:team.teamId,period:"month"});
  assert.equal(ranks.ranks.find(r=>r.uid===guests[0].uid).days,1);
  await guests[0].call("leaveTeam",{teamId:team.teamId});
  for(const api of ["getTeamOverview","getTeamRanking","listPastRooms"]) await rejects(()=>guests[0].call(api,{teamId:team.teamId,period:"week"}),"permission-denied");
  for(const api of ["getRoom","getRoomProgress","updateRoomProgress","rematchRoom"]) await rejects(()=>guests[0].call(api,{roomId:room.roomId,value:2}),"permission-denied");
  await rejects(()=>guests[0].call("submitWorkout",session),"permission-denied");
  await host.call("finishRoom",{roomId:room.roomId});
  const rematch=await host.call("rematchRoom",{roomId:room.roomId});
  assert.notEqual(rematch.roomId,room.roomId);
  assert.deepEqual((await fs.doc(`rooms/${rematch.roomId}`).get()).data().participantUids,[host.uid]);
  await fs.doc(`roomCodes/${crypto.createHash("sha256").update(rematch.inviteCode).digest("hex")}`).update({expiresAt:1});
  await rejects(()=>guests[1].call("joinRoom",{inviteCode:rematch.inviteCode}),"permission-denied");
  await fs.doc(`teamCodes/${crypto.createHash("sha256").update(team.inviteCode).digest("hex")}`).update({expiresAt:1});
  await rejects(()=>outsider.call("joinTeam",{inviteCode:team.inviteCode}),"permission-denied");
});
test("two devices, final disconnect trigger, duplicates, delayed events, reconnect and onDisconnect",{timeout:45000},async()=>{
  const u=await user("presence-user"), root=db.ref(`presence/${u.uid}`);
  await root.set({connections:{a:true,b:true}});
  await root.child("connections/a").remove();
  await reconcilePresence(db,u.uid,100);
  assert.equal((await root.child("summary").get()).exists(),false);
  await root.child("connections/b").remove();
  await eventually(async()=> (await root.child("summary/lastOfflineAt").get()).exists());
  const first=(await root.child("summary/lastOfflineAt").get()).val();
  await reconcilePresence(db,u.uid,first-1);
  await reconcilePresence(db,u.uid,first);
  assert.equal((await root.child("summary/lastOfflineAt").get()).val(),first);
  await root.child("connections/c").set(true);
  await reconcilePresence(db,u.uid,first+100);
  assert.equal((await root.child("summary/lastOfflineAt").get()).val(),first);
  // Real client onDisconnect simulates abrupt socket close, without explicit remove.
  const client=clientDB(u.app);connectDatabaseEmulator(client,"127.0.0.1",9000);
  const connection=ref(client,`presence/${u.uid}/connections/device`);
  await onDisconnect(connection).remove();await set(connection,true);
  await root.child("connections/c").remove();
  goOffline(client);
  await eventually(async()=>!(await root.child("connections").get()).exists());
  await eventually(async()=>(await root.child("summary/lastOfflineAt").get()).val()>first);
  // Race a delayed server reconciliation with a new device write: common-parent
  // transaction must retry and preserve the newest connection.
  const racer=getDatabase(initializeApp({projectId,databaseURL:`https://${projectId}.firebaseio.com`},"racer"));
  await Promise.all([reconcilePresence(db,u.uid,Date.now()),racer.ref(`presence/${u.uid}/connections/new`).set(true)]);
  racer.goOffline();
  assert.equal((await root.child("connections/new").get()).val(),true);
});
