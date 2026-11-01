import AppKit
import Combine
import FitBOSSCore
import Foundation
#if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFunctions) && canImport(FirebaseDatabase) && canImport(GoogleSignIn)
import FirebaseCore
import FirebaseAuth
import FirebaseFunctions
import FirebaseDatabase
import GoogleSignIn
#endif

private struct PastRoom: Identifiable {
    let roomId: String
    let participantCount: Int
    var id: String { roomId }
}
private struct RoomProgress: Identifiable {
    let uid: String
    let repetitions: Int
    var id: String { uid }
}
/// API access is gated by Google auth and trusted callable functions.
@MainActor final class OnlineService: ObservableObject {
    @Published private(set) var configured = false
    @Published private(set) var signedIn = false
    @Published private(set) var uid: String?
    @Published private(set) var teamId: String?
    @Published private(set) var teamInviteCode: String?
    @Published private(set) var roomId: String?
    @Published private(set) var roomInviteCode: String?
    @Published private(set) var roomPhase: String?
    @Published private(set) var members: [TeamPresence] = []
    @Published private(set) var ranking: [TeamRank] = []
    @Published private(set) var pastRooms: [PastRoom] = []
    @Published private(set) var roomProgress: [RoomProgress] = []
    private var lastProgressSubmission: Date = .distantPast
    @Published private(set) var errorMessage: String?
    @Published private(set) var isWorking = false

    #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFunctions) && canImport(FirebaseDatabase) && canImport(GoogleSignIn)
    private var listener: AuthStateDidChangeListenerHandle?
    private var functions: Functions?
    private var connectionRef: DatabaseReference?
    private var connectedRef: DatabaseReference?
    private var connectionHandle: DatabaseHandle?
    #endif

    init() {
        #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFunctions) && canImport(FirebaseDatabase) && canImport(GoogleSignIn)
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: path),
              options.projectID == "fitboss-acde2" else {
            errorMessage = "fitboss-acde2 の最新 GoogleService-Info.plist をアプリに設定してください。"
            return
        }
        if FirebaseApp.app() == nil { FirebaseApp.configure(options: options) }
        functions = Functions.functions(region: "asia-southeast1")
        configured = true
        listener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.stopPresence()
                self.uid = user?.uid
                self.signedIn = user != nil && user?.providerData.contains(where: { $0.providerID == "google.com" }) == true
                if self.signedIn, let uid = user?.uid { self.startPresence(uid: uid) }
                else { self.teamId = nil; self.members = []; self.ranking = []; self.roomId = nil }
            }
        }
        #else
        errorMessage = "Firebase SDKなしのカメラ専用ビルドです。Firebaseビルドの有効化が必要です。"
        #endif
    }

    func signIn() {
        #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFunctions) && canImport(FirebaseDatabase) && canImport(GoogleSignIn)
        guard configured, let clientID = FirebaseApp.app()?.options.clientID,
              let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) else {
            errorMessage = "ログイン設定かウィンドウが見つかりません。"; return
        }
        isWorking = true
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.signIn(withPresenting: window) { [weak self] result, error in
            guard let idToken = result?.user.idToken?.tokenString else {
                Task { @MainActor [weak self] in
                    self?.isWorking = false
                    self?.errorMessage = error?.localizedDescription ?? "Google認証に失敗しました。"
                }
                return
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken, accessToken: result!.user.accessToken.tokenString
            )
            Auth.auth().signIn(with: credential) { [weak self] _, error in
                Task { @MainActor [weak self] in
                    self?.isWorking = false
                    self?.errorMessage = error?.localizedDescription
                }
            }
        }
        #endif
    }

    func signOut() {
        #if canImport(FirebaseAuth) && canImport(GoogleSignIn)
        stopPresence()
        do { try Auth.auth().signOut(); GIDSignIn.sharedInstance.signOut() }
        catch { errorMessage = error.localizedDescription }
        #endif
    }

    func createTeam(name: String) {
        call("createTeam", ["name": name]) { result in
            self.teamId = result["teamId"] as? String
            self.teamInviteCode = result["inviteCode"] as? String
            self.loadTeam()
        }
    }
    func joinTeam(code: String) {
        call("joinTeam", ["inviteCode": code]) { result in
            self.teamId = result["teamId"] as? String
            self.teamInviteCode = nil
            self.loadTeam()
        }
    }
    func leaveTeam() {
        guard let teamId else { return }
        call("leaveTeam", ["teamId":teamId]) { _ in
            self.teamId = nil; self.members = []; self.ranking = []; self.pastRooms = []; self.roomId = nil
        }
    }
    func loadTeam(period: String = "week") {
        guard let teamId else { return }
        call("getTeamOverview", ["teamId":teamId]) { result in
            let items = result["members"] as? [[String: Any]] ?? []
            self.members = items.compactMap { row in
                guard let id = row["uid"] as? String, let online = row["online"] as? Bool else { return nil }
                let ms = (row["lastOfflineAt"] as? NSNumber)?.doubleValue
                return TeamPresence(uid: id, online: online, lastOfflineAt: ms.map { Date(timeIntervalSince1970:$0/1000) })
            }
        }
        call("getTeamRanking", ["teamId":teamId, "period":period]) { result in
            let rows = result["ranks"] as? [[String: Any]] ?? []
            self.ranking = rows.compactMap { row in
                guard let id = row["uid"] as? String, let days = row["days"] as? Int else { return nil }
                return TeamRank(uid: id, participationDays: days)
            }
        }
        call("listPastRooms", ["teamId":teamId]) { result in
            let rows = result["rooms"] as? [[String: Any]] ?? []
            self.pastRooms = rows.compactMap { row in
                guard let id = row["roomId"] as? String else { return nil }
                return PastRoom(roomId:id,participantCount:(row["participantUids"] as? [String] ?? []).count)
            }
        }
    }
    func createRoom(invitedUids: [String]) {
        guard let teamId else { return }
        call("createRoom", ["teamId":teamId,"exerciseId":"push_up","invitedUids":invitedUids]) { result in
            self.roomId = result["roomId"] as? String
            self.roomInviteCode = result["inviteCode"] as? String
            self.roomPhase = "waiting"
            self.roomProgress = []
        }
    }
    func joinRoom(code: String) {
        call("joinRoom", ["inviteCode":code]) { result in
            self.roomId = result["roomId"] as? String
            self.roomInviteCode = nil; self.roomPhase = "waiting"
            self.roomProgress = []
        }
    }
    func startRoom() {
        guard let roomId else { return }
        call("startRoom", ["roomId": roomId]) { _ in self.roomPhase = "active"; self.refreshRoomProgress() }
    }
    func refreshRoomProgress() {
        guard let roomId else { return }
        call("getRoomProgress", ["roomId": roomId]) { result in
            self.roomPhase = result["phase"] as? String
            let rows = result["participants"] as? [[String: Any]] ?? []
            self.roomProgress = rows.compactMap { row in
                guard let uid = row["uid"] as? String,
                      let value = row["value"] as? Int else { return nil }
                return RoomProgress(uid: uid, repetitions: value)
            }
        }
    }
    func sendRoomProgress(_ value: Int) {
        guard roomPhase == "active", roomId != nil else { return }
        let now = Date()
        guard now.timeIntervalSince(lastProgressSubmission) >= 1.1 else { return }
        lastProgressSubmission = now
        guard let roomId else { return }
        call("updateRoomProgress", ["roomId":roomId, "value":value]) { _ in }
    }
    func finishRoom() {
        guard let roomId else { return }
        call("finishRoom", ["roomId":roomId]) { _ in
            self.roomPhase = "finished"; self.refreshRoomProgress(); self.loadTeam()
        }
    }
    func rematch(roomId: String) {
        call("rematchRoom", ["roomId":roomId]) { result in
            self.roomId = result["roomId"] as? String
            self.roomInviteCode = result["inviteCode"] as? String
            self.roomPhase = "waiting"
        }
    }
    func submitWorkout(_ session: SavedWorkout) {
        guard let teamId else { return }
        call("submitWorkout", [
            "teamId":teamId, "sessionId":session.id.uuidString.lowercased(),
            "exerciseId":session.exerciseID, "repetitions":session.repetitions,
            "completedAt":Int(session.completedAt.timeIntervalSince1970*1000)
        ]) { _ in self.loadTeam() }
    }
    private func call(_ name: String, _ data: [String: Any], onSuccess: @escaping ([String: Any])->Void) {
        guard signedIn else { errorMessage = "Googleログインが必要です。"; return }
        #if canImport(FirebaseFunctions)
        guard let functions else { errorMessage = "Firebase Functionsが未設定です。"; return }
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                let result = try await functions.httpsCallable(name).call(data)
                guard let object = result.data as? [String: Any] else { throw NSError(domain:"FitBOSS",code:0) }
                errorMessage = nil
                onSuccess(object)
            } catch { errorMessage = error.localizedDescription }
        }
        #endif
    }
    #if canImport(FirebaseDatabase)
    private func startPresence(uid: String) {
        guard let url = FirebaseApp.app()?.options.databaseURL, !url.isEmpty else {
            errorMessage = "FirebaseのRealtime Database URLが設定されていません。"; return
        }
        let database = Database.database(url: url)
        let connected = database.reference(withPath: ".info/connected")
        let own = database.reference(withPath: "presenceConnections/\(uid)").childByAutoId()
        connectionRef = own
        connectedRef = connected
        connectionHandle = connected.observe(.value) { [weak self] snap in
            guard snap.value as? Bool == true else { return }
            own.onDisconnectRemoveValue { error, _ in
                if error == nil { own.setValue(true) }
                else { Task { @MainActor [weak self] in self?.errorMessage = "オンライン状態の登録に失敗しました。" } }
            }
        }
    }
    #endif
    private func stopPresence() {
        #if canImport(FirebaseDatabase)
        if let connectedRef, let connectionHandle { connectedRef.removeObserver(withHandle:connectionHandle) }
        connectionRef?.cancelDisconnectOperations()
        connectionRef?.removeValue()
        connectionRef = nil; connectedRef = nil; connectionHandle = nil
        #endif
    }
}
