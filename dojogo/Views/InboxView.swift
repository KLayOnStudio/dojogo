import SwiftUI

private let brandPurple = Color(red: 0x7F/255, green: 0x64/255, blue: 0xAC/255)
private let brandGreen  = Color(red: 0x52/255, green: 0xB6/255, blue: 0x74/255)

struct InboxView: View {
    @Environment(\.dismiss) var dismiss
    var onOpenCampaign: (() -> Void)? = nil

    @State private var announcements: [Announcement] = []
    @State private var notifications: [AppNotification] = []
    @State private var checkedIds: Set<Int> = []
    @State private var dismissedAnnouncementIds: Set<Int> = []
    @State private var isLoading = true
    @State private var selectedTab: InboxTab = .all

    enum InboxTab { case all, messages, notices }

    private func effectivelyRead(_ n: AppNotification) -> Bool { n.isRead || checkedIds.contains(n.id) }
    private var unread: [AppNotification] { notifications.filter { !effectivelyRead($0) } }
    private var read: [AppNotification]   { notifications.filter {  effectivelyRead($0) } }

    private var activeAnnouncements: [Announcement]    { announcements.filter { !dismissedAnnouncementIds.contains($0.id) } }
    private var dismissedAnnouncements: [Announcement] { announcements.filter {  dismissedAnnouncementIds.contains($0.id) } }


    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ZStack {
                    Text("TEGAMI")
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

                            if selectedTab == .all {
                                // ALL tab: unchecked items first, checked items below
                                let hasUnchecked = !unread.isEmpty || !activeAnnouncements.isEmpty
                                let hasChecked = !read.isEmpty || !dismissedAnnouncements.isEmpty

                                if hasUnchecked {
                                    SectionHeader(title: "NEW", color: .white.opacity(0.7))
                                    VStack(spacing: 10) {
                                        ForEach(unread) { n in
                                            NotificationCard(notification: n, checkedIds: $checkedIds, onOpenCampaign: n.type == "campaign_invite" ? onOpenCampaign : nil)
                                        }
                                        ForEach(activeAnnouncements) { a in
                                            AnnouncementCard(announcement: a, dismissedIds: $dismissedAnnouncementIds)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 20)
                                }

                                if hasChecked {
                                    SectionHeader(title: hasUnchecked ? "EARLIER" : "ALL", color: .white.opacity(0.35))
                                    VStack(spacing: 8) {
                                        ForEach(read) { n in
                                            NotificationCard(notification: n, checkedIds: $checkedIds, onOpenCampaign: n.type == "campaign_invite" ? onOpenCampaign : nil)
                                        }
                                        ForEach(dismissedAnnouncements) { a in
                                            AnnouncementCard(announcement: a, dismissedIds: $dismissedAnnouncementIds)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 32)
                                }

                                if !hasUnchecked && !hasChecked {
                                    Spacer().frame(height: 20)
                                    Text("Nothing here yet.")
                                        .font(.pixelifyBody)
                                        .foregroundColor(.gray)
                                        .frame(maxWidth: .infinity)
                                }
                            }

                            if selectedTab == .messages {
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

                            if selectedTab == .notices {
                                if !activeAnnouncements.isEmpty {
                                    SectionHeader(title: "NOTICES", color: brandGreen)
                                    VStack(spacing: 10) {
                                        ForEach(activeAnnouncements) { a in
                                            AnnouncementCard(announcement: a, dismissedIds: $dismissedAnnouncementIds)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 20)
                                }
                                if !dismissedAnnouncements.isEmpty {
                                    SectionHeader(title: activeAnnouncements.isEmpty ? "NOTICES" : "EARLIER", color: .white.opacity(0.35))
                                    VStack(spacing: 8) {
                                        ForEach(dismissedAnnouncements) { a in
                                            AnnouncementCard(announcement: a, dismissedIds: $dismissedAnnouncementIds)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 32)
                                }
                                if announcements.isEmpty {
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
        .onDisappear { markCheckedAndDismiss() }
    }

    private func load() async {
        dismissedAnnouncementIds = LocalStorageService.shared.getDismissedAnnouncementIds()

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
            checkedIds = []  // prevent double-send on onDisappear
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
                    if notification.type == "campaign_invite", let openCampaign = onOpenCampaign {
                        Button(action: openCampaign) {
                            Text("▶")
                                .font(.pixelify(size: 10))
                                .foregroundColor(isUnread ? .white.opacity(0.6) : .white.opacity(0.2))
                        }
                        .buttonStyle(.plain)
                    }
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
                    .onTapGesture {
                        guard !notification.isRead else { return }
                        if isChecked { checkedIds.remove(notification.id) }
                        else { checkedIds.insert(notification.id) }
                    }
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
                    .allowsHitTesting(false)
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
    @Binding var dismissedIds: Set<Int>
    private let logoSize: CGFloat = 64

    private var isDismissed: Bool { dismissedIds.contains(announcement.id) }
    private var accentColor: Color { isDismissed ? .white.opacity(0.25) : brandGreen.opacity(0.6) }
    private var textOpacity: Double { isDismissed ? 0.4 : 1.0 }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Image("LogoPixel")
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: logoSize, height: logoSize)
                .opacity(isDismissed ? 0.4 : 1.0)

            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(announcement.title)
                        .font(.pixelifyBodyBold)
                        .foregroundColor(.white.opacity(textOpacity))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(announcement.body)
                        .font(.pixelifySmall)
                        .foregroundColor(.white.opacity(isDismissed ? 0.3 : 0.85))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(alignment: .bottom) {
                        if let date = announcement.createdAt {
                            Text(date.formatted(.dateTime.month(.abbreviated).day().year()))
                                .font(.pixelify(size: 9))
                                .foregroundColor(.gray.opacity(isDismissed ? 0.45 : 0.9))
                                .padding(.top, 6)
                        }
                        Spacer()
                        ZStack {
                            Rectangle()
                                .fill(Color.black.opacity(0.3))
                                .frame(width: 20, height: 20)
                            Rectangle()
                                .stroke(isDismissed ? Color.white.opacity(0.3) : brandGreen.opacity(0.8), lineWidth: 2)
                                .frame(width: 20, height: 20)
                            if isDismissed {
                                Rectangle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(width: 12, height: 12)
                            }
                        }
                        .onTapGesture {
                            if isDismissed {
                                dismissedIds.remove(announcement.id)
                                LocalStorageService.shared.undismissAnnouncement(announcement.id)
                            } else {
                                dismissedIds.insert(announcement.id)
                                LocalStorageService.shared.dismissAnnouncement(announcement.id)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isDismissed ? Color.clear : brandGreen.opacity(0.05))
                .overlay(
                    Image("SpeechBubbleBorder")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(accentColor)
                        .allowsHitTesting(false)
                )
            }
        }
    }
}
