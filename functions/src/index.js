"use strict";
// Privileged server facade. Never deploy without emulator permission tests and Blaze approval.
const {onCall,HttpsError}=require("firebase-functions/v2/https");
const {onValueWritten}=require("firebase-functions/v2/database");
const {initializeApp}=require("firebase-admin/app");
const {getFirestore,FieldValue}=require("firebase-admin/firestore");
const {getDatabase}=require("firebase-admin/database");
const d=require("./domain");
const {reconcilePresence}=require("./presence");
initializeApp();
const fs=getFirestore();
const REGION="asia-southeast1"; // RTDB location must be independently confirmed before deploy.
const MAX_TEAM_MEMBERS=100;
const opts={region:REGION,timeoutSeconds:30,maxInstances:5};
const callable=(fn)=>onCall(opts,async request=>{try{return await fn(request,d.googleUID(request))}catch(e){if(e instanceof HttpsError)throw e;const code=typeof e.code==="string"&&/^(unauthenticated|invalid-argument|permission-denied|failed-precondition|resource-exhausted|already-exists|not-found)$/.test(e.code)?e.code:"internal";throw new HttpsError(code,code==="internal"?"処理に失敗しました":e.message)}});
const requireString=(x,label)=>{if(typeof x!=="string"||!x.length||x.length>128||/[\/.#$\[\]]/.test(x))d.fail("invalid-argument",label+"が不正です");return x};
const memberRef=(teamId,uid)=>fs.doc("teams/"+teamId+"/members/"+uid);
async function requireMember(teamId,uid){
  requireString(teamId,"チーム");
  if(!(await memberRef(teamId,uid).get()).exists)d.fail("permission-denied","チームに所属していません");
}
function roomCodeRef(code){return fs.doc("roomCodes/"+d.hash(code))}
function teamCodeRef(code){return fs.doc("teamCodes/"+d.hash(code))}
async function makeRoom(teamId,uid,exerciseId,invitees){
  if(exerciseId!=="push_up")d.fail("invalid-argument","未対応の種目です");
  await requireMember(teamId,uid);
  const invited=d.invitedUids(invitees,uid);
  for(const target of invited)await requireMember(teamId,target);
  const id=fs.collection("rooms").doc().id;
  const secret=d.code(), now=Date.now(), expiresAt=now+24*3600000;
  await fs.runTransaction(async tx=>{
    const checks=await Promise.all([uid,...invited].map(member=>tx.get(memberRef(teamId,member))));
    if(checks.some(member=>!member.exists))d.fail("permission-denied","チームに所属していません");
    tx.create(fs.doc("rooms/"+id),{teamId,hostUid:uid,exerciseId,phase:"waiting",capacity:6,
      participantUids:[uid],invitedUids:invited,createdAt:now,expiresAt,completedAt:null});
    tx.create(roomCodeRef(secret),{roomId:id,teamId,expiresAt});
  });
  return {roomId:id,inviteCode:secret,expiresAt,invitedUids:invited};
}
exports.createTeam=callable(async({data},uid)=>{
  const name=d.teamName(data?.name),id=fs.collection("teams").doc().id,secret=d.code();
  const batch=fs.batch(),now=Date.now();
  batch.create(fs.doc("teams/"+id),{name,ownerUid:uid,createdAt:now,memberCount:1});
  batch.create(memberRef(id,uid),{role:"owner",joinedAt:now,displayName:""});
  batch.create(teamCodeRef(secret),{teamId:id,expiresAt:now+7*86400000});
  await batch.commit();return {teamId:id,inviteCode:secret};
});
exports.joinTeam=callable(async({data},uid)=>{
  const code=data?.inviteCode;const ref=teamCodeRef(code);
  return fs.runTransaction(async tx=>{
    const invitation=await tx.get(ref);
    if(!invitation.exists||invitation.data().expiresAt<=Date.now())d.fail("permission-denied","招待が無効です");
    const teamId=invitation.data().teamId,teamRef=fs.doc("teams/"+teamId),userRef=memberRef(teamId,uid);
    const [team,member]=await Promise.all([tx.get(teamRef),tx.get(userRef)]);
    if(!team.exists)d.fail("not-found","チームがありません");
    if(member.exists)return {teamId,joined:false};
    if(team.data().memberCount>=MAX_TEAM_MEMBERS)d.fail("resource-exhausted","チームが満員です");
    tx.create(userRef,{role:"member",joinedAt:Date.now(),displayName:""});
    tx.update(teamRef,{memberCount:FieldValue.increment(1)});
    return {teamId,joined:true};
  });
});
exports.leaveTeam=callable(async({data},uid)=>{
  const teamId=requireString(data?.teamId,"チーム"),team=fs.doc("teams/"+teamId);
  await fs.runTransaction(async tx=>{
    const [t,m]=await Promise.all([tx.get(team),tx.get(memberRef(teamId,uid))]);
    if(!t.exists||!m.exists)d.fail("permission-denied","チームに所属していません");
    if(t.data().ownerUid===uid)d.fail("failed-precondition","オーナーは退会できません");
    tx.delete(memberRef(teamId,uid));
    tx.update(team,{memberCount:FieldValue.increment(-1)});
  });
  return {left:true};
});
exports.createRoom=callable(async({data},uid)=>{
  const teamId=requireString(data?.teamId,"チーム");
  return makeRoom(teamId,uid,data?.exerciseId,data?.invitedUids||[]);
});
exports.joinRoom=callable(async({data},uid)=>{
  const invitationRef=roomCodeRef(data?.inviteCode);
  return fs.runTransaction(async tx=>{
    const inv=await tx.get(invitationRef);
    if(!inv.exists||inv.data().expiresAt<=Date.now())d.fail("permission-denied","招待が無効です");
    const {teamId,roomId}=inv.data();
    const room=fs.doc("rooms/"+roomId);
    const [snapshot,member]=await Promise.all([tx.get(room),tx.get(memberRef(teamId,uid))]);
    if(!member.exists)d.fail("permission-denied","チームに所属していません");
    if(!snapshot.exists)d.fail("not-found","ルームがありません");
    const item=snapshot.data();
    if(item.teamId!==teamId||item.phase!=="waiting"||item.expiresAt<=Date.now())
      d.fail("failed-precondition","ルームに参加できません");
    const joined=d.joinRoom(item.participantUids,uid,item.invitedUids,item.capacity);
    if(joined.length!==item.participantUids.length)tx.update(room,{participantUids:joined});
    return {roomId,participantUids:joined};
  });
});
exports.getRoom=callable(async({data},uid)=>{
  const roomId=requireString(data?.roomId,"ルーム"),snap=await fs.doc("rooms/"+roomId).get();
  if(!snap.exists)d.fail("not-found","ルームがありません");
  const r=snap.data();
  await requireMember(r.teamId,uid);
  if(!r.participantUids.includes(uid))d.fail("permission-denied","参加者ではありません");
  return {roomId,teamId:r.teamId,exerciseId:r.exerciseId,phase:r.phase,
    participantUids:r.participantUids,hostUid:r.hostUid,createdAt:r.createdAt};
});
exports.startRoom=callable(async({data},uid)=>{
  const room=fs.doc("rooms/"+requireString(data?.roomId,"ルーム"));
  await fs.runTransaction(async tx=>{
    const snap=await tx.get(room);
    if(!snap.exists||snap.data().hostUid!==uid)d.fail("permission-denied","ホストではありません");
    if(snap.data().phase!=="waiting")d.fail("failed-precondition","開始できません");
    if(snap.data().expiresAt<=Date.now())d.fail("failed-precondition","期限切れです");
    const m=await tx.get(memberRef(snap.data().teamId,uid));
    if(!m.exists)d.fail("permission-denied","チームを脱退しています");
    tx.update(room,{phase:"active",startedAt:Date.now()});
  });
  return {phase:"active"};
});
exports.updateRoomProgress=callable(async({data},uid)=>{
  const roomId=requireString(data?.roomId,"ルーム"),value=data?.value;
  if(!Number.isSafeInteger(value)||value<0||value>500)d.fail("invalid-argument","計測数が不正です");
  const snapshot=await fs.doc("rooms/"+roomId).get();
  if(!snapshot.exists||snapshot.data().phase!=="active")d.fail("failed-precondition","対戦は開始されていません");
  const room=snapshot.data();
  await requireMember(room.teamId,uid);
  if(!room.participantUids.includes(uid))d.fail("permission-denied","参加者ではありません");
  const progress=getDatabase().ref("roomProgress/"+roomId+"/"+uid);
  const now=Date.now();
  const result=await progress.transaction(current=>{
    if(current&&now-current.updatedAt<950)return;
    if(current&&value<current.value)return;
    if(current&&value-current.value>20)return;
    return {value,updatedAt:now};
  },undefined,false);
  if(!result.committed)d.fail("resource-exhausted","計測送信の頻度が高すぎるか、不正な変更です");
  return {accepted:true};
});
exports.getRoomProgress=callable(async({data},uid)=>{
  const roomId=requireString(data?.roomId,"ルーム"),snap=await fs.doc("rooms/"+roomId).get();
  if(!snap.exists)d.fail("not-found","ルームがありません");
  const room=snap.data();await requireMember(room.teamId,uid);
  if(!room.participantUids.includes(uid))d.fail("permission-denied","参加者ではありません");
  const result=await getDatabase().ref("roomProgress/"+roomId).get();
  const values=result.val()||{};
  return {roomId,phase:room.phase,participants:room.participantUids.map(id=>({
    uid:id,value:Number.isSafeInteger(values[id]?.value)?values[id].value:0,
    updatedAt:values[id]?.updatedAt||null
  }))};
});
exports.finishRoom=callable(async({data},uid)=>{
  const room=fs.doc("rooms/"+requireString(data?.roomId,"ルーム"));
  await fs.runTransaction(async tx=>{
    const snap=await tx.get(room);
    if(!snap.exists||snap.data().hostUid!==uid)d.fail("permission-denied","ホストではありません");
    if(!["waiting","active"].includes(snap.data().phase))d.fail("failed-precondition","終了済みです");
    const check=await tx.get(memberRef(snap.data().teamId,uid));
    if(!check.exists)d.fail("permission-denied","脱退済みです");
    tx.update(room,{phase:"finished",completedAt:Date.now()});
  });
  return {finished:true};
});
exports.rematchRoom=callable(async({data},uid)=>{
  const roomId=requireString(data?.roomId,"ルーム"),snap=await fs.doc("rooms/"+roomId).get();
  if(!snap.exists)d.fail("not-found","ルームがありません");
  const old=snap.data();await requireMember(old.teamId,uid);
  const requested=d.rematch(old,uid),actual=[];
  for(const member of requested)if((await memberRef(old.teamId,member).get()).exists)actual.push(member);
  return makeRoom(old.teamId,uid,old.exerciseId,actual);
});
exports.submitWorkout=callable(async({data},uid)=>{
  const input=d.checkedSession(data||{}),teamId=requireString(data?.teamId,"チーム");
  await requireMember(teamId,uid);
  const target=fs.doc("workoutSessions/"+input.sessionId);
  const dateRef=fs.doc("teams/"+teamId+"/dailyParticipation/"+input.dateKey+"/members/"+uid);
  return fs.runTransaction(async tx=>{
    const [record,member,day]=await Promise.all([tx.get(target),tx.get(memberRef(teamId,uid)),tx.get(dateRef)]);
    if(!member.exists)d.fail("permission-denied","チームを脱退しています");
    if(record.exists){
      if(record.data().uid!==uid||record.data().teamId!==teamId)d.fail("already-exists","セッションIDが重複しています");
      return {created:false,dateKey:record.data().dateKey};
    }
    tx.create(target,{...input,uid,teamId,receivedAt:Date.now(),verificationStatus:"unverified"});
    if(!day.exists)tx.create(dateRef,{uid,dateKey:input.dateKey,firstCompletedAt:input.completedAt});
    return {created:true,dateKey:input.dateKey};
  });
});
function periodKeys(period, now=Date.now()){
  if(!["week","month"].includes(period))d.fail("invalid-argument","期間が不正です");
  const day=new Date(now),fmt=new Intl.DateTimeFormat("en-US",{timeZone:"Asia/Tokyo",year:"numeric",month:"numeric",day:"numeric"});
  const parts=Object.fromEntries(fmt.formatToParts(day).map(x=>[x.type,Number(x.value)]));
  const utc=new Date(Date.UTC(parts.year,parts.month-1,parts.day));
  const first=period==="month"?new Date(Date.UTC(parts.year,parts.month-1,1)):
    new Date(utc.getTime()-((utc.getUTCDay()+6)%7)*86400000);
  const keys=[];
  for(let cursor=first;cursor<=utc;cursor=new Date(cursor.getTime()+86400000))
    keys.push(cursor.toISOString().slice(0,10));
  return keys;
}
exports.getTeamOverview=callable(async({data},uid)=>{
  const teamId=requireString(data?.teamId,"チーム");await requireMember(teamId,uid);
  const members=await fs.collection("teams/"+teamId+"/members").limit(MAX_TEAM_MEMBERS).get();
  const ids=members.docs.map(x=>x.id);
  const database=getDatabase();
  const results=await Promise.all(ids.map(async memberId=>{
    const state=(await database.ref("presence/"+memberId).get()).val();
    const count=Object.keys(state?.connections||{}).length;
    return {uid:memberId,...d.offline(count,state?.summary?.lastOfflineAt)};
  }));
  return {teamId,members:results};
});
exports.getTeamRanking=callable(async({data},uid)=>{
  const teamId=requireString(data?.teamId,"チーム");await requireMember(teamId,uid);
  const period=data?.period;
  const members=await fs.collection("teams/"+teamId+"/members").limit(MAX_TEAM_MEMBERS).get();
  const memberUids=members.docs.map(doc=>doc.id);
  const keys=periodKeys(period);
  const snapshots=await Promise.all(keys.map(key=>fs.collection("teams/"+teamId+"/dailyParticipation/"+key+"/members").limit(MAX_TEAM_MEMBERS).get()));
  const rows=snapshots.flatMap((snapshot,i)=>snapshot.docs.map(doc=>({uid:doc.id,dateKey:keys[i]})));
  return {teamId,period,ranks:d.ranking(rows,memberUids),lastUpdatedAt:Date.now(),unverifiedClientCounts:true};
});
exports.listPastRooms=callable(async({data},uid)=>{
  const teamId=requireString(data?.teamId,"チーム");await requireMember(teamId,uid);
  // Filter before limiting: unrelated teams/history must not evict own matches.
  const records=await fs.collection("rooms")
    .where("teamId","==",teamId)
    .where("phase","==","finished")
    .where("participantUids","array-contains",uid)
    .orderBy("completedAt","desc")
    .limit(20).get();
  return {rooms:records.docs
    .map(x=>({roomId:x.id,exerciseId:x.data().exerciseId,completedAt:x.data().completedAt,participantUids:x.data().participantUids}))};
});
// RTDB client can only mutate its own ephemeral connections; no client can read any other path.
// This trigger is deployed in the RTDB instance's own region, not Firestore's.
// The local RTDB emulator exposes its default namespace in us-central1.
const databaseRegion=process.env.FUNCTIONS_EMULATOR==="true"?"us-central1":REGION;
exports.updatePresence=onValueWritten({region:databaseRegion,ref:"/presence/{uid}/connections"},async event=>{
  if (!event.data.before.exists() || event.data.after.exists()) return;
  await reconcilePresence(event.data.after.ref.database,event.params.uid,Date.parse(event.time));
});
