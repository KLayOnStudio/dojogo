import SwiftUI

private let brandPurple = Color(red: 0x7F/255, green: 0x64/255, blue: 0xAC/255)
private let brandGreen  = Color(red: 0x52/255, green: 0xB6/255, blue: 0x74/255)

struct InboxView: View {
    @Environment(\.dismiss) var dismiss
    var onOpenCampaign: (() -> Void)? = nil

    @State private var announcements: [Announcement] = []
    @State private var notifications: [AppNotification] = []
    @State private var checkedIds: Set<Int> = []
    @State private var isLoading = true
    @State private var selectedTab: InboxTab = .all

    enum InboxTab { case all, messages, notices }

    private func effectivelyRead(_ n: AppNotification) -> Bool { n.isRead || checkedIds.contains(n.id) }
    private var unread: [AppNotification] { notifications.filter { !effectivelyRead($0) } }
    private var read: [AppNotification]   { notifications.filter {  effectivelyRead($0) } }

    private var showNotifications: Bool { selectedTab == .all || selectedTab == .messages }
    private var showAnnouncements: Bool { selectedTab == .all || selectedTab == .notices }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ZStack {
                    Text("INBOX")
                        .font(.pixelifyHeadline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                    HStack {
                        Button(action: {
                            markCheckedAndDismiss()
                        }) {
                            Text("← BACK")
                                .font(.pixelifyButton)
                                .foregroundColor(.white)
                        }
                        .buttonStyle(PixelButtonStyle())
                        Spacer()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                Divider().background(Color.white.opacity(0.1))

                // Tab bar
                HStack(spacing: 0) {
                    ForEach([("ALL", InboxTab.all), ("MESSAGES", .messages), ("NOTICES", .notices)], id: \.0) { label, tab in
                        Button(action: { selectedTab = tab }) {
                            VStack(spacing: 4) {
                                Text(label)
                                    .font(.pixelify(size: 10, weight: .bold))
                                    .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.35))
                                Rectangle()
                                    .fill(selectedTab == tab ? (tab == .notices ? brandGreen : brandPurple) : Color.clear)
                                    .frame(height: 2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(PixelButtonStyle())
                    }
                }
                .background(Color.white.opacity(0.04))

                Divider().background(Color.white.opacity(0.1))

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
                        VStack(spacing: 0) {

                            if showNotifications {
                                // Unread notifications — purple accent
                                if !unread.isEmpty {
                                    SectionHeader(title: "NEW", color: brandPurple)
                                    VStack(spacing: 10) {
                                        ForEach(unread) { n in
                                            NotificationCard(notification: n, checkedIds: $checkedIds, onOpenCampaign: n.type == "campaign_invite" ? onOpenCampaign : nil)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 20)
                                }

                                // Read notifications — muted
                                if !read.isEmpty {
                                    SectionHeader(title: unread.isEmpty ? "MESSAGES" : "EARLIER", color: .white.opacity(0.35))
                                    VStack(spacing: 8) {
                                        ForEach(read) { n in
                                            NotificationCard(notification: n, checkedIds: $checkedIds, onOpenCampaign: n.type == "campaign_invite" ? onOpenCampaign : nil)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 20)
                                }

                                if notifications.isEmpty {
                                    Spacer().frame(height: 20)
                                    Text("No messages yet.")
                                        .font(.pixelifyBody)
                                        .foregroundColor(.gray)
                                        .frame(maxWidth: .infinity)
                                        .padding(.bottom, 20)
                                }
                            }

                            if showAnnouncements {
                                // Announcements — green accent
                                if !announcements.isEmpty {
                                    SectionHeader(title: "NOTICES", color: brandGreen)
                                    VStack(spacing: 10) {
                                        ForEach(announcements) { a in
                                            AnnouncementCard(announcement: a)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 32)
                                } else {
                                    Spacer().frame(height: 20)
                                    Text("No notices yet.")
                                        .font(.pixelifyBody)
                                        .foregroundColor(.gray)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
        .task { await load() }
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
        let ids = announcements.map { $0.id }
        Task { try? await APIService.shared.logAnnouncementViews(ids: ids) }
        isLoading = false
    }

    private func markCheckedAndDismiss() {
        let ids = Array(checkedIds)
        if !ids.isEmpty {
            Task { try? await APIService.shared.markNotificationsRead(ids: ids) }
        }
        dismiss()
    }
}

// MARK: - Section Header

private struct SectionHeader: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(color.opacity(0.5))
                .frame(height: 1)
            Text(title)
                .font(.pixelify(size: 10, weight: .bold))
                .foregroundColor(color)
                .fixedSize()
            Rectangle()
                .fill(color.opacity(0.5))
                .frame(height: 1)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }
}

// MARK: - Notification Card (RPG speech bubble)

private struct NotificationCard: View {
    let notification: AppNotification
    @Binding var checkedIds: Set<Int>
    var onOpenCampaign: (() -> Void)? = nil

    private let avatarSize: CGFloat = 64
    private var isChecked: Bool { checkedIds.contains(notification.id) }
    private var isUnread: Bool { !notification.isRead && !isChecked }

    private var borderColor: Color {
        isUnread ? brandPurple : Color.white.opacity(0.15)
    }
    private var bgColor: Color {
        isUnread ? brandPurple.opacity(0.08) : Color.clear
    }
    private var titleColor: Color {
        isUnread ? .white : .white.opacity(0.55)
    }
    private var bodyColor: Color {
        isUnread ? .white.opacity(0.85) : .white.opacity(0.4)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            avatarView
            bubbleBox
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if notification.type == "campaign_invite" { onOpenCampaign?() }
        }
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
            .opacity(isUnread ? 1.0 : 0.4)
    }

    private var bubbleBox: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.pixelifyBodyBold)
                    .foregroundColor(titleColor)
                    .fixedSize(horizontal: false, vertical: true)

                Text(notification.body)
                    .font(.pixelifySmall)
                    .foregroundColor(bodyColor)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .bottom) {
                    if let date = notification.createdAt {
                        Text(date.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.pixelify(size: 9))
                            .foregroundColor(.gray.opacity(isUnread ? 0.9 : 0.45))
                            .padding(.top, 6)
                    }
                    Spacer()
                    if notification.type == "campaign_invite" && onOpenCampaign != nil {
                        Text("▶")
                            .font(.pixelify(size: 10))
                            .foregroundColor(isUnread ? .white.opacity(0.6) : .white.opacity(0.2))
                    }
                    Button(action: {
                        if notification.isRead { return }
                        if isChecked { checkedIds.remove(notification.id) }
                        else { checkedIds.insert(notification.id) }
                    }) {
                        ZStack {
                            Rectangle()
                                .fill(Color.black.opacity(0.3))
                                .frame(width: 20, height: 20)
                            Rectangle()
                                .stroke(isUnread ? brandPurple : Color.white.opacity(0.3), lineWidth: 2)
                                .frame(width: 20, height: 20)
                            if isChecked || notification.isRead {
                                Rectangle()
                                    .fill(notification.isRead ? Color.white.opacity(0.3) : brandPurple)
                                    .frame(width: 12, height: 12)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(notification.isRead)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(bgColor)
            .overlay(
                Image("SpeechBubbleBorder")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(borderColor)
            )

            if isUnread {
                Circle()
                    .fill(brandPurple)
                    .frame(width: 7, height: 7)
                    .offset(x: -8, y: 8)
            }
        }
    }
}

// MARK: - Announcement Card

private struct AnnouncementCard: View {
    let announcement: Announcement
    private let logoSize: CGFloat = 64

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            // Left: full LogoPixel image
            Image("LogoPixel")
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: logoSize, height: logoSize)

            // Right: speech bubble box
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(announcement.title)
                        .font(.pixelifyBodyBold)
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(announcement.body)
                        .font(.pixelifySmall)
                        .foregroundColor(.white.opacity(0.85))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    if let date = announcement.createdAt {
                        Text(date.formatted(.dateTime.month(.abbreviated).day().year()))
                            .font(.pixelify(size: 9))
                            .foregroundColor(.gray.opacity(0.9))
                            .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(brandGreen.opacity(0.05))
                .overlay(
                    Image("SpeechBubbleBorder")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(brandGreen.opacity(0.6))
                )
            }
        }
    }
}
