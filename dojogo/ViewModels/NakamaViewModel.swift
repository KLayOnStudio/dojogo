import Foundation
import Combine

@MainActor
class NakamaViewModel: ObservableObject {
    enum SearchMode {
        case kenshi, dojo
    }

    @Published var searchMode: SearchMode = .kenshi
    @Published var searchQuery = ""
    @Published var searchResults: [UserSummary] = []
    @Published var dojoQuery = ""
    @Published var dojoResults: [UserSummary] = []
    @Published var isSearchingDojo = false
    @Published var incomingRequests: [FriendRequest] = []
    @Published var outgoingRequests: [FriendRequest] = []
    @Published var friends: [FriendInfo] = []
    @Published var isSearching = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private var nudgeSentAt: [String: Date] = [:]

    /// Must match NUDGE_COOLDOWN_MINUTES in dojogo-api/CreateNudge/__init__.py.
    private let nudgeCooldownSeconds: TimeInterval = 2 * 60

    private var searchCancellable: AnyCancellable?
    private var dojoSearchCancellable: AnyCancellable?

    init() {
        searchCancellable = $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self = self else { return }
                Task { await self.performSearch(query: query) }
            }

        dojoSearchCancellable = $dojoQuery
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self = self else { return }
                Task { await self.performDojoSearch(query: query) }
            }
    }

    func loadAll() async {
        isLoading = true
        async let requestsTask: () = loadFriendRequests()
        async let friendsTask: () = loadFriends()
        _ = await (requestsTask, friendsTask)
        isLoading = false
    }

    private func performSearch(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            searchResults = []
            return
        }

        isSearching = true
        do {
            let results = try await APIService.shared.searchUsers(query: trimmed)
            searchResults = results
        } catch {
            print("Search failed: \(error)")
            searchResults = []
        }
        isSearching = false
    }

    private func performDojoSearch(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            dojoResults = []
            return
        }

        isSearchingDojo = true
        do {
            let results = try await APIService.shared.searchByDojo(dojo: trimmed)
            dojoResults = results
        } catch {
            print("Dojo search failed: \(error)")
            dojoResults = []
        }
        isSearchingDojo = false
    }

    func sendFriendRequest(to user: UserSummary) async {
        do {
            _ = try await APIService.shared.createFriendRequest(toUserId: user.userId)
            searchResults.removeAll { $0.userId == user.userId }
            dojoResults.removeAll { $0.userId == user.userId }
            await loadFriendRequests()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func acceptRequest(_ request: FriendRequest) async {
        do {
            try await APIService.shared.respondFriendRequest(requestId: request.requestId, action: "accept")
            await loadFriendRequests()
            await loadFriends()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func declineRequest(_ request: FriendRequest) async {
        do {
            try await APIService.shared.respondFriendRequest(requestId: request.requestId, action: "decline")
            await loadFriendRequests()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelRequest(_ request: FriendRequest) async {
        do {
            try await APIService.shared.respondFriendRequest(requestId: request.requestId, action: "cancel")
            await loadFriendRequests()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadFriendRequests() async {
        do {
            async let incoming = APIService.shared.getFriendRequests(type: "incoming")
            async let outgoing = APIService.shared.getFriendRequests(type: "outgoing")
            let (inc, out) = try await (incoming, outgoing)
            incomingRequests = inc
            outgoingRequests = out
        } catch {
            print("Failed to load friend requests: \(error)")
        }
    }

    /// False if the given user can be nudged right now.
    func isOnNudgeCooldown(userId: String) -> Bool {
        guard let sentAt = nudgeSentAt[userId] else { return false }
        return Date().timeIntervalSince(sentAt) < nudgeCooldownSeconds
    }

    func sendNudge(toUserId userId: String, message: String) async {
        guard !isOnNudgeCooldown(userId: userId) else { return }
        nudgeSentAt[userId] = Date()
        do {
            try await APIService.shared.createNudge(toUserId: userId, message: message)
        } catch {
            let nsError = error as NSError
            if nsError.code == 429 {
                // Server says still on cooldown (e.g. stale client-side timer) — keep nudgeSentAt
                // set so the compose sheet shows the cooldown card, not a raw system alert.
            } else {
                nudgeSentAt.removeValue(forKey: userId)
                errorMessage = error.localizedDescription
            }
        }
    }

    /// For sending a nakama request to someone who isn't a friend yet (e.g. from the leaderboard).
    func sendFriendRequest(toUserId userId: String) async {
        do {
            _ = try await APIService.shared.createFriendRequest(toUserId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadFriends() async {
        do {
            friends = try await APIService.shared.getFriends()
        } catch {
            print("Failed to load friends: \(error)")
        }
    }
}
