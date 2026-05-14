import SwiftUI

struct InboxView: View {
    @Environment(\.dismiss) var dismiss
    var onOpenCampaign: (() -> Void)? = nil

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
                        VStack(spacing: 16) {
                            ForEach(notifications) { n in
                                NotificationCard(notification: n, onOpenCampaign: n.type == "campaign_invite" ? onOpenCampaign : nil)
                            }
                            ForEach(announcements) { a in
                                AnnouncementCard(announcement: a)
                            }
                        }
                        .padding(.horizontal, 16)
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

// MARK: - RPG Speech Bubble Notification Card

private struct NotificationCard: View {
    let notification: AppNotification
    var onOpenCampaign: (() -> Void)? = nil

    private let avatarSize: CGFloat = 64
    private var borderColor: Color {
        notification.isRead ? Color.white.opacity(0.25) : Color.yellow.opacity(0.7)
    }

    var body: some View {
        Button(action: {
            if notification.type == "campaign_invite" {
                onOpenCampaign?()
            }
        }) {
            HStack(alignment: .bottom, spacing: 0) {
                // Left: top half of sender avatar sprite
                avatarView

                // Right: speech bubble dialog box
                bubbleBox
            }
        }
        .buttonStyle(.plain)
        .disabled(notification.type != "campaign_invite" || onOpenCampaign == nil)
    }

    private var avatarView: some View {
        let name = notification.senderAvatar ?? "kendoka"
        return Image(name)
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: avatarSize, height: avatarSize)
            .frame(width: avatarSize, height: avatarSize / 2, alignment: .top)
            .clipped()
            .padding(.bottom, 0)
    }

    private var bubbleBox: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.pixelifyBodyBold)
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(notification.body)
                    .font(.pixelifySmall)
                    .foregroundColor(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)

                if let date = notification.createdAt {
                    Text(date.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.pixelify(size: 9))
                        .foregroundColor(.gray.opacity(0.8))
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black)
            .overlay(
                Image("SpeechBubbleBorder")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(borderColor)
            )

            if !notification.isRead {
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 7, height: 7)
                    .offset(x: -8, y: 8)
            }

            if notification.type == "campaign_invite" && onOpenCampaign != nil {
                Text("▶")
                    .font(.pixelify(size: 10))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.trailing, 8)
                    .padding(.top, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
    }
}

// MARK: - Announcement Card

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
            Rectangle()
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
}
