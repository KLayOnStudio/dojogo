import Foundation
import Combine

@MainActor
class NakamaViewModel: ObservableObject {
    @Published var searchQuery = ""
    @Published var searchResults: [UserSummary] = []
    @Published var incomingRequests: [FriendRequest] = []
    @Published var outgoingRequests: [FriendRequest] = []
    @Published var friends: [FriendInfo] = []
    @Published var isSearching = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var searchCancellable: AnyCancellable?

    init() {
        searchCancellable = $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self = self else { return }
                Task { await self.performSearch(query: query) }
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

    func sendFriendRequest(to user: UserSummary) async {
        do {
            _ = try await APIService.shared.createFriendRequest(toUserId: user.userId)
            // Remove from search results, refresh outgoing
            searchResults.removeAll { $0.userId == user.userId }
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

    func loadFriends() async {
        do {
            friends = try await APIService.shared.getFriends()
        } catch {
            print("Failed to load friends: \(error)")
        }
    }
}
