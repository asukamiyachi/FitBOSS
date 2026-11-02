import AppKit
import Combine
import FitBOSSCore
import Foundation
#if FITBOSS_FIREBASE_ENABLED
import FirebaseCore
import FirebaseAuth
import FirebaseFunctions
import FirebaseDatabase
import GoogleSignIn
#endif

struct PastRoom: Identifiable {
    let roomId: String
    let participantCount: Int
    var id: String { roomId }
}
struct RoomProgress: Identifiable {
    let uid: String
    let repetitions: Int
    var id: String { uid }
}
/// API access is gated by Google auth and trusted callable functions.
@MainActor final class OnlineService: ObservableObject {
    @Published private(set) var isSigningIn = false
    @Published private(set) var signInMessage: String?
    @Published private(set) var databaseStatus = "未接続"
    @Published private(set) var accountEmail: String?
    @Published private(set) var displayName: String?
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
    private var readsInFlight: Set<String> = []
    private var nextProgressRead = Date.distantPast
    private var progressBackoff: TimeInterval = 3
    private var uploadsInFlight: Set<UUID> = []
    private var lastProgressSubmission: Date = .distantPast
    @Published private(set) var errorMessage: String?
    @Published private(set) var isWorking = false
    private var mutatingRequests = OnlineMutationTracker()

    private func refreshWorkingState() {
        isWorking = isSigningIn || mutatingRequests.isWorking
    }

    /// Invalidate only the selected team; never delete the user's local workout history.
    private func clearStaleTeamSelection() {
        if let uid, let teamId {
            let key = "fitboss.lastTeamID." + uid
            if UserDefaults.standard.string(forKey: key) == teamId {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        teamId = nil; teamInviteCode = nil
        roomId = nil; roomInviteCode = nil; roomPhase = nil
        members = []; ranking = []; pastRooms = []; roomProgress = []
        nextProgressRead = .distantPast
        errorMessage = "チームへのアクセス権が失効しました。必要に応じて再参加してください。"
    }

    #if FITBOSS_FIREBASE_ENABLED
    private var listener: AuthStateDidChangeListenerHandle?
    private var functions: Functions?
    private var presenceGeneration = UUID()
    private var connectionRef: DatabaseReference?
    private var connectedRef: DatabaseReference?
    private var connectionHandle: DatabaseHandle?
    #endif

    init() {
        #if FITBOSS_FIREBASE_ENABLED
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: path),
              options.projectID == "fitboss-acde2",
              options.bundleID == "com.asukamiyachi.FitBOSS",
              options.clientID?.isEmpty == false,
              options.databaseURL?.isEmpty == false else {
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
                if self.uid != user?.uid {
                    self.teamId = nil; self.members = []; self.ranking = []; self.pastRooms = []
                    self.roomId = nil; self.roomProgress = []; self.roomPhase = nil
                    self.teamInviteCode = nil; self.roomInviteCode = nil
                }
                self.accountEmail = user?.email
                self.displayName = user?.displayName
                self.uid = user?.uid
                self.signedIn = user != nil && user?.providerData.contains(where: { $0.providerID == "google.com" }) == true
                if self.signedIn, let uid = user?.uid {
                    self.startPresence(uid: uid)
                    self.teamId = UserDefaults.standard.string(forKey: "fitboss.lastTeamID." + uid + "")
                    if self.teamId != nil { self.loadTeam() }
                }
                else { self.teamId = nil; self.members = []; self.ranking = []; self.pastRooms = []; self.roomId = nil; self.roomProgress = []; self.teamInviteCode = nil; self.roomInviteCode = nil; self.roomPhase = nil }
            }
        }
        #else
        errorMessage = "Firebase SDKなしのカメラ専用ビルドです。Firebaseビルドの有効化が必要です。"
        #endif
    }

    func signIn() {
        #if FITBOSS_FIREBASE_ENABLED
        guard !isSigningIn else { return }
        guard configured, let clientID = FirebaseApp.app()?.options.clientID,
              let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) else {
            errorMessage = "ログイン設定かウィンドウが見つかりません。"; return
        }
        isSigningIn = true
        refreshWorkingState()
        signInMessage = nil
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.signIn(withPresenting: window) { [weak self] result, error in
            guard let idToken = result?.user.idToken?.tokenString else {
                Task { @MainActor [weak self] in
                    self?.isSigningIn = false
                    self?.refreshWorkingState()
                    let code = (error as NSError?)?.code
                    if code == GIDSignInError.canceled.rawValue {
                        self?.signInMessage = "ログインを中止しました。もう一度試せます。"
                    } else if code == GIDSignInError.keychain.rawValue {
                        self?.signInMessage = "ログイン情報をKeychainに保存できません。アプリの署名設定を確認してください。"
                    } else if let code {
                        self?.signInMessage = "Google認証に失敗しました（コード \(code)）。もう一度お試しください。"
                    } else {
                        self?.signInMessage = "GoogleのIDトークンを取得できませんでした。OAuth設定を確認してください。"
                    }
                    self?.errorMessage = self?.signInMessage
                }
                return
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken, accessToken: result!.user.accessToken.tokenString
            )
            Auth.auth().signIn(with: credential) { [weak self] _, error in
                Task { @MainActor [weak self] in
                    self?.isSigningIn = false
                    self?.refreshWorkingState()
                    self?.signInMessage = error == nil ? nil : "Firebase認証に失敗しました。設定と通信状態を確認して、もう一度お試しください。"
                    self?.errorMessage = error?.localizedDescription
                }
            }
        }
        #endif
    }

    func signOut() {
        #if FITBOSS_FIREBASE_ENABLED
        stopPresence()
        do { try Auth.auth().signOut(); GIDSignIn.sharedInstance.signOut() }
        catch { errorMessage = error.localizedDescription }
        #endif
    }

    private func saveSelectedTeam() {
        if let uid, let teamId { UserDefaults.standard.set(teamId,forKey:"fitboss.lastTeamID." + uid + "") }
    }
    func createTeam(name: String) {
        call("createTeam", ["name": name]) { result in
            self.teamId = result["teamId"] as? String
            self.teamInviteCode = result["inviteCode"] as? String
            self.saveSelectedTeam()
            self.loadTeam()
        }
    }
    func joinTeam(code: String) {
        call("joinTeam", ["inviteCode": code]) { result in
            self.teamId = result["teamId"] as? String
            self.teamInviteCode = nil
            self.saveSelectedTeam()
            self.loadTeam()
        }
    }
    func leaveTeam() {
        guard let teamId else { return }
        call("leaveTeam", ["teamId":teamId]) { _ in
            if let uid = self.uid { UserDefaults.standard.removeObject(forKey:"fitboss.lastTeamID." + uid + "") }
            self.teamId = nil; self.members = []; self.ranking = []; self.pastRooms = []; self.roomId = nil
            self.roomProgress = []; self.roomPhase = nil; self.roomInviteCode = nil; self.teamInviteCode = nil
        }
    }
    private var rankingPeriod = "week"
    func loadTeam(period: String? = nil) {
        if let period { rankingPeriod = period }
        guard let teamId else { return }
        call("getTeamOverview", ["teamId":teamId]) { result in
            let items = result["members"] as? [[String: Any]] ?? []
            self.members = items.compactMap { row in
                guard let id = row["uid"] as? String, let online = row["online"] as? Bool else { return nil }
                let ms = (row["lastOfflineAt"] as? NSNumber)?.doubleValue
                return TeamPresence(uid: id, online: online, lastOfflineAt: ms.map { Date(timeIntervalSince1970:$0/1000) })
            }
        }
        call("getTeamRanking", ["teamId":teamId, "period":rankingPeriod]) { result in
            guard result["period"] as? String == self.rankingPeriod else { return }
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
        guard Date() >= nextProgressRead, let roomId else { return }
        call("getRoomProgress", ["roomId": roomId]) { result in
            self.progressBackoff = 3
            self.nextProgressRead = Date().addingTimeInterval(3)
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
    func submitWorkout(_ session: SavedWorkout, onSynced: (() -> Void)? = nil) {
        guard let teamId, !uploadsInFlight.contains(session.id) else { return }
        uploadsInFlight.insert(session.id)
        call("submitWorkout", [
            "teamId":teamId, "sessionId":session.id.uuidString.lowercased(),
            "exerciseId":session.exerciseID, "repetitions":session.repetitions,
            "completedAt":Int(session.completedAt.timeIntervalSince1970*1000)
        ], onComplete: { self.uploadsInFlight.remove(session.id) }) { _ in onSynced?() }
    }
    private func call(_ name: String, _ data: [String: Any], onComplete: (() -> Void)? = nil, onSuccess: @escaping ([String: Any])->Void) {
        guard signedIn else { onComplete?(); errorMessage = "Googleログインが必要です。"; return }
        #if FITBOSS_FIREBASE_ENABLED
        guard let functions else { onComplete?(); errorMessage = "Firebase Functionsが未設定です。"; return }
        let isRead = name.hasPrefix("get") || name.hasPrefix("list")
        let readKey = name == "getTeamRanking" ? name + ":" + (data["period"] as? String ?? "") : name
        if isRead && readsInFlight.contains(readKey) { onComplete?(); return }
        if isRead { readsInFlight.insert(readKey) }
        let requestUID = uid, requestTeam = teamId, requestRoom = roomId
        let mutationToken = isRead ? nil : mutatingRequests.begin()
        if mutationToken != nil { refreshWorkingState() }
        Task {
            defer {
                if isRead { readsInFlight.remove(readKey) }
                if let mutationToken { mutatingRequests.end(mutationToken); refreshWorkingState() }
                onComplete?()
            }
            do {
                let result = try await functions.httpsCallable(name).call(data)
                guard let object = result.data as? [String: Any] else { throw NSError(domain:"FitBOSS",code:0) }
                guard signedIn, uid == requestUID, teamId == requestTeam, roomId == requestRoom else { return }
                errorMessage = nil
                onSuccess(object)
            } catch {
                guard uid == requestUID, teamId == requestTeam else { return }
                errorMessage = error.localizedDescription
                if name == "getRoomProgress" {
                    progressBackoff = min(progressBackoff * 2, 60)
                    nextProgressRead = Date().addingTimeInterval(progressBackoff)
                }
                let permissionDenied = (error as NSError).code == FunctionsErrorCode.permissionDenied.rawValue
                if OnlineRequestPolicies.shouldClearTeamSelection(
                    operation: name, permissionDenied: permissionDenied,
                    requestUID: requestUID, currentUID: uid,
                    requestTeamID: requestTeam, currentTeamID: teamId
                ) {
                    clearStaleTeamSelection()
                } else if permissionDenied {
                    members = []; ranking = []; pastRooms = []; roomProgress = []
                }
            }
        }
        #else
        onComplete?()
        #endif
    }
    #if FITBOSS_FIREBASE_ENABLED
    private func startPresence(uid: String) {
        guard let url = FirebaseApp.app()?.options.databaseURL, !url.isEmpty else {
            errorMessage = "FirebaseのRealtime Database URLが設定されていません。"; return
        }
        databaseStatus = "接続を確認中"
        let database = Database.database(url: url)
        let connected = database.reference(withPath: ".info/connected")
        let own = database.reference(withPath: "presence/\(uid)/connections").childByAutoId()
        connectionRef = own
        connectedRef = connected
        let generation = presenceGeneration
        connectionHandle = connected.observe(.value) { [weak self] snap in
            guard snap.value as? Bool == true else {
                Task { @MainActor [weak self] in
                    guard self?.presenceGeneration == generation else { return }
                    self?.databaseStatus = "接続を待機中"
                }
                return
            }
            own.onDisconnectRemoveValue { error, _ in
                if error == nil {
                    Task { @MainActor [weak self] in
                        guard self?.presenceGeneration == generation, self?.uid == uid, self?.signedIn == true else { return }
                        own.setValue(true) { error, _ in
                            Task { @MainActor [weak self] in
                                guard self?.presenceGeneration == generation else { return }
                                self?.databaseStatus = error == nil ? "接続済み" : "接続できません。アクセス権限を確認してください。"
                                if error != nil { self?.errorMessage = "Realtime Databaseへの接続が拒否されました。" }
                            }
                        }
                    }
                }
                else {
                    Task { @MainActor [weak self] in
                        guard self?.presenceGeneration == generation else { return }
                        self?.databaseStatus = "接続できません。アクセス権限を確認してください。"
                        self?.errorMessage = "オンライン状態の登録に失敗しました。"
                    }
                }
            }
        }
    }
    #endif
    private func stopPresence() {
        #if FITBOSS_FIREBASE_ENABLED
        presenceGeneration = UUID()
        databaseStatus = "未接続"
        if let connectedRef, let connectionHandle { connectedRef.removeObserver(withHandle:connectionHandle) }
        connectionRef?.removeValue()
        connectionRef = nil; connectedRef = nil; connectionHandle = nil
        #endif
    }
}
