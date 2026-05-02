import SwiftUI

struct AnnouncementBoardView: View {
    @Environment(\.dismiss) var dismiss
    @State private var announcements: [Announcement] = []
    @State private var isLoading = true

    var body: some View {
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
                    Spacer()
                    Text("ANNOUNCEMENTS")
                        .font(.pixelifyHeadline)
                        .foregroundColor(.white)
                    Spacer()
                        .frame(width: 80)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 20)

                if isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Spacer()
                } else if announcements.isEmpty {
                    Spacer()
                    Text("No announcements yet.")
                        .font(.pixelifyBody)
                        .foregroundColor(.gray)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(announcements) { announcement in
                                AnnouncementCard(announcement: announcement)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .task {
            await loadAnnouncements()
        }
    }

    private func loadAnnouncements() async {
        do {
            let items = try await APIService.shared.getAnnouncements()
            announcements = items
            // Mark all as seen
            if let newest = items.first {
                LocalStorageService.shared.saveLastSeenAnnouncementId(newest.id)
            }
        } catch {
            print("Failed to load announcements: \(error)")
        }
        isLoading = false
    }
}

private struct AnnouncementCard: View {
    let announcement: Announcement

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image
            if let urlString = announcement.imageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .clipped()
                    case .failure:
                        EmptyView()
                    case .empty:
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .frame(height: 180)
                            .overlay(ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .gray)))
                    @unknown default:
                        EmptyView()
                    }
                }
            }

            // Text content
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text(announcement.title)
                        .font(.pixelifyBodyBold)
                        .foregroundColor(.white)
                    Spacer()
                    if let date = announcement.createdAt {
                        Text(date.formatted(.dateTime.month(.abbreviated).day().year()))
                            .font(.pixelify(size: 10))
                            .foregroundColor(.gray)
                    }
                }

                Text(announcement.body)
                    .font(.pixelifyBody)
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
}
