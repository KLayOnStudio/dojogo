import SwiftUI

struct NakamaView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = NakamaViewModel()
    @State private var selectedFriend: FriendInfo?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button(action: { dismiss() }) {
                            Text("← BACK")
                                .font(.pixelifyButton)
                                .foregroundColor(.white)
                        }
                        .buttonStyle(PixelButtonStyle())

                        Spacer()

                        Text("NAKAMA")
                            .font(.pixelifyHeadline)
                            .foregroundColor(.white)
                            .shadow(color: .white.opacity(0.3), radius: 2, x: 0, y: 2)

                        Spacer()
                            .frame(width: 80)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, max(geometry.safeAreaInsets.top + 8, 20))
                    .padding(.bottom, 16)

                    ScrollView {
                        VStack(spacing: 20) {
                            // Search mode toggle
                            searchModeToggle

                            // Search input
                            if viewModel.searchMode == .kenshi {
                                kenshiSearchSection
                                if !viewModel.searchResults.isEmpty {
                                    searchResultsSection(results: viewModel.searchResults)
                                }
                            } else {
                                dojoSearchSection
                                if !viewModel.dojoResults.isEmpty {
                                    searchResultsSection(results: viewModel.dojoResults)
                                }
                            }

                            // Requests
                            if !viewModel.incomingRequests.isEmpty || !viewModel.outgoingRequests.isEmpty {
                                requestsSection
                            }

                            // Friends List
                            friendsSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, max(geometry.safeAreaInsets.bottom, 20))
                    }
                }
            }
        }
        .task {
            await viewModel.loadAll()
        }
        .sheet(item: $selectedFriend) { friend in
            FriendInsightsView(friend: friend)
        }
    }

    // MARK: - Search Mode Toggle

    private var searchModeToggle: some View {
        HStack(spacing: 0) {
            ForEach([NakamaViewModel.SearchMode.kenshi, .dojo], id: \.self) { mode in
                Button(action: { viewModel.searchMode = mode }) {
                    Text(mode == .kenshi ? "FIND KENSHI" : "FIND DOJO")
                        .font(.pixelify(size: 11, weight: .bold))
                        .foregroundColor(viewModel.searchMode == mode ? .black : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(viewModel.searchMode == mode ? Color.yellow : Color.clear)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Kenshi Search

    private var kenshiSearchSection: some View {
        HStack {
            TextField("", text: $viewModel.searchQuery)
                .placeholder(when: viewModel.searchQuery.isEmpty) {
                    Text("Search by nickname or #number...")
                        .font(.pixelifyBody)
                        .foregroundColor(.gray)
                }
                .font(.pixelifyBody)
                .foregroundColor(.white)
                .autocapitalization(.none)
                .disableAutocorrection(true)

            if viewModel.isSearching {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.2))
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(viewModel.searchQuery.isEmpty ? Color.white.opacity(0.3) : Color.yellow, lineWidth: viewModel.searchQuery.isEmpty ? 1 : 2)
        )
    }

    // MARK: - Dojo Search

    private var dojoSearchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("", text: $viewModel.dojoQuery)
                    .placeholder(when: viewModel.dojoQuery.isEmpty) {
                        Text("Enter dojo name...")
                            .font(.pixelifyBody)
                            .foregroundColor(.gray)
                    }
                    .font(.pixelifyBody)
                    .foregroundColor(.white)
                    .autocapitalization(.words)
                    .disableAutocorrection(true)

                if viewModel.isSearchingDojo {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.2))
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(viewModel.dojoQuery.isEmpty ? Color.white.opacity(0.3) : Color.cyan, lineWidth: viewModel.dojoQuery.isEmpty ? 1 : 2)
            )

            if !viewModel.dojoQuery.isEmpty && !viewModel.isSearchingDojo && viewModel.dojoResults.isEmpty {
                Text("No public members found for this dojo.")
                    .font(.pixelifySmall)
                    .foregroundColor(.gray)
            }
        }
    }

    // MARK: - Search Results (shared)

    private func searchResultsSection(results: [UserSummary]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            let alreadyFriendIds = Set(viewModel.friends.map { $0.userId })
            let pendingIds = Set((viewModel.outgoingRequests + viewModel.incomingRequests).map { $0.userId })

            ForEach(results) { user in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.displayName)
                            .font(.pixelifyBody)
                            .foregroundColor(.white)

                        if let rank = user.kendoRank {
                            Text(rank)
                                .font(.pixelify(size: 10))
                                .foregroundColor(.gray)
                        }
                    }

                    Spacer()

                    if alreadyFriendIds.contains(user.userId) {
                        Text("NAKAMA")
                            .font(.pixelify(size: 10, weight: .bold))
                            .foregroundColor(.green)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    } else if pendingIds.contains(user.userId) {
                        Text("PENDING")
                            .font(.pixelify(size: 10, weight: .bold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    } else {
                        Button(action: {
                            Task { await viewModel.sendFriendRequest(to: user) }
                        }) {
                            Text("ADD")
                                .font(.pixelify(size: 12, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.yellow)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 0)
                                        .stroke(Color.white, lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Requests

    private var requestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("REQUESTS")
                .font(.pixelifyBodyBold)
                .foregroundColor(.white)

            ForEach(viewModel.incomingRequests) { request in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(request.displayName)
                            .font(.pixelifyBody)
                            .foregroundColor(.white)

                        if let rank = request.kendoRank {
                            Text(rank)
                                .font(.pixelify(size: 10))
                                .foregroundColor(.gray)
                        }
                    }

                    Spacer()

                    Button(action: {
                        Task { await viewModel.acceptRequest(request) }
                    }) {
                        Text("ACCEPT")
                            .font(.pixelify(size: 10, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green)
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.white, lineWidth: 1)
                            )
                    }

                    Button(action: {
                        Task { await viewModel.declineRequest(request) }
                    }) {
                        Text("DECLINE")
                            .font(.pixelify(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.white, lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
            }

            ForEach(viewModel.outgoingRequests) { request in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(request.displayName)
                            .font(.pixelifyBody)
                            .foregroundColor(.white)

                        Text("PENDING")
                            .font(.pixelify(size: 10))
                            .foregroundColor(.orange)
                    }

                    Spacer()

                    Button(action: {
                        Task { await viewModel.cancelRequest(request) }
                    }) {
                        Text("CANCEL")
                            .font(.pixelify(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.white, lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Friends List

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MY NAKAMA")
                .font(.pixelifyBodyBold)
                .foregroundColor(.white)

            if viewModel.friends.isEmpty && !viewModel.isLoading {
                Text("No nakama yet. Search for kenshi above!")
                    .font(.pixelifySmall)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }

            ForEach(viewModel.friends) { friend in
                Button(action: { selectedFriend = friend }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(friend.displayName)
                                .font(.pixelifyBody)
                                .foregroundColor(.white)

                            if let rank = friend.kendoRank {
                                Text(rank)
                                    .font(.pixelify(size: 10))
                                    .foregroundColor(.gray)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            HStack(spacing: 8) {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(friend.streak)")
                                        .font(.pixelify(size: 14, weight: .bold))
                                        .foregroundColor(.orange)
                                    Text("STREAK")
                                        .font(.pixelify(size: 8))
                                        .foregroundColor(.gray)
                                }

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(friend.totalCount)")
                                        .font(.pixelify(size: 14, weight: .bold))
                                        .foregroundColor(.green)
                                    Text("SWINGS")
                                        .font(.pixelify(size: 8))
                                        .foregroundColor(.gray)
                                }
                            }
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.gray.opacity(0.5))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
