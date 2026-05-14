import SwiftUI

struct InboxView: View {
    @Environment(\.dismiss) var dismiss
    @State private var announcements: [Announcement] = []
    @State private var notifications: [AppNotification] = []
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        Text("← BACK")
                            .font(.pixelifyButton)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text("INBOX")
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
                } else if announcements.isEmpty && notifications.isEmpty {
                    Spacer()
                    Text("Nothing here yet.")
                        .font(.pixelifyBody)
                        .foregroundColor(.gray)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(notifications) { n in
                                NotificationCard(notification: n)
                            }
                            ForEach(announcements) { a in
                                AnnouncementCard(announcement: a)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .task {
            await load()
        }
    }

    private func load() async {
        async let announcementsTask = try? APIService.shared.getAnnouncements()
        async let notificationsTask = try? APIService.shared.getNotifications()

        let (a, n) = await (announcementsTask, notificationsTask)
        announcements = a ?? []
        notifications = n?.notifications ?? []

        if let newest = announcements.first {
            LocalStorageService.shared.saveLastSeenAnnouncementId(newest.id)
        }
        try? await APIService.shared.markNotificationsRead()
        isLoading = false
    }
}

private struct NotificationCard: View {
    let notification: AppNotification

    var icon: String {
        switch notification.type {
        case "campaign_invite": return "🥋"
        case "friend_accepted": return "🤝"
        default: return "📬"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.system(size: 24))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.title)
                        .font(.pixelifyBodyBold)
                        .foregroundColor(notification.isRead ? .white.opacity(0.7) : .white)
                    Spacer()
                    if !notification.isRead {
                        Circle()
                            .fill(Color.yellow)
                            .frame(width: 8, height: 8)
                    }
                }
                Text(notification.body)
                    .font(.pixelifySmall)
                    .foregroundColor(.gray)
                if let date = notification.createdAt {
                    Text(date.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.pixelify(size: 9))
                        .foregroundColor(.gray.opacity(0.7))
                }
            }
        }
        .padding(14)
        .background(notification.isRead ? Color.white.opacity(0.03) : Color.yellow.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(notification.isRead ? Color.white.opacity(0.1) : Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }
}

private struct AnnouncementCard: View {
    let announcement: Announcement

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let urlString = announcement.imageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                            .frame(maxWidth: .infinity).frame(height: 180).clipped()
                    case .failure:
                        EmptyView()
                    default:
                        Rectangle().fill(Color.white.opacity(0.05)).frame(height: 180)
                            .overlay(ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .gray)))
                    }
                }
            }

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
