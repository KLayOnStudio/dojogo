import SwiftUI

struct FriendInsightsView: View {
    let friend: FriendInfo
    @Environment(\.dismiss) var dismiss
    @State private var insights: FriendInsights?
    @State private var isLoading = true
    @State private var errorMessage: String?

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

                        Text("KENSHI")
                            .font(.pixelifyHeadline)
                            .foregroundColor(.white)

                        Spacer()
                            .frame(width: 80)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, max(geometry.safeAreaInsets.top + 8, 20))
                    .padding(.bottom, 16)

                    if isLoading {
                        Spacer()
                        Text("LOADING...")
                            .font(.pixelifyButton)
                            .foregroundColor(.white)
                        Spacer()
                    } else if let insights = insights {
                        ScrollView {
                            VStack(spacing: 24) {
                                // Name & Number
                                VStack(spacing: 8) {
                                    Text(insights.displayName)
                                        .font(.pixelifyTitle)
                                        .foregroundColor(.white)

                                    if let num = insights.userNumber {
                                        Text("Player #\(num)")
                                            .font(.pixelifySmall)
                                            .foregroundColor(.gray)
                                    }
                                }

                                // Stats Grid
                                VStack(spacing: 16) {
                                    HStack(spacing: 12) {
                                        StatBox(title: "STREAK", value: "\(insights.streak)", color: .orange)
                                        StatBox(title: "TOTAL SWINGS", value: "\(insights.totalCount)", color: .green)
                                    }

                                    HStack(spacing: 12) {
                                        StatBox(title: "SWING RANK", value: "#\(insights.swingRank)", color: .yellow)
                                        StatBox(title: "STREAK RANK", value: "#\(insights.streakRank)", color: .cyan)
                                    }
                                }
                                .padding(.horizontal, 20)

                                // Details
                                VStack(spacing: 16) {
                                    if let rank = insights.kendoRank {
                                        detailRow(label: "KENDO RANK", value: rank)
                                    }

                                    detailRow(label: "EXPERIENCE", value: insights.experienceString)

                                    if let dojo = insights.homeDojo {
                                        detailRow(label: "HOME DOJO", value: dojo)
                                    }

                                    if let date = insights.lastActiveDate {
                                        detailRow(label: "LAST ACTIVE", value: formatDate(date))
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                            .padding(.bottom, max(geometry.safeAreaInsets.bottom, 20))
                        }
                    } else if let error = errorMessage {
                        Spacer()
                        Text(error)
                            .font(.pixelifyBody)
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
            }
        }
        .task {
            await fetchInsights()
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.pixelify(size: 10))
                .foregroundColor(.gray)

            Spacer()

            Text(value)
                .font(.pixelifyBody)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func fetchInsights() async {
        do {
            insights = try await APIService.shared.getUserInsights(userId: friend.userId)
            isLoading = false
        } catch {
            errorMessage = "Could not load insights"
            isLoading = false
        }
    }
}
