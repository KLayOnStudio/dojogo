import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button(action: { dismiss() }) {
                            Text("← BACK")
                                .font(.pixelifyButton)
                                .foregroundColor(.white)
                        }

                        Spacer()

                        Text("ABOUT")
                            .font(.pixelifyHeadline)
                            .foregroundColor(.white)
                            .shadow(color: .white.opacity(0.3), radius: 2, x: 0, y: 2)

                        Spacer()
                            .frame(width: 80)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, max(geometry.safeAreaInsets.top + 8, 20))
                    .padding(.bottom, 16)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 24) {

                            // App Logo & Title
                            VStack(spacing: 12) {
                                Text("DOJOGO")
                                    .font(.pixelify(size: 36, weight: .bold))
                                    .foregroundColor(.yellow)
                                    .shadow(color: .yellow.opacity(0.5), radius: 8, x: 0, y: 0)

                                Text("Your Personal Kendo Training Companion")
                                    .font(.pixelifyBody)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)

                                Text("v1.0")
                                    .font(.pixelify(size: 10, weight: .regular))
                                    .foregroundColor(.gray.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)

                            // What is DojoGo
                            sectionCard(
                                title: "WHAT IS DOJOGO?",
                                icon: "⚔️",
                                content: """
DojoGo is a training app designed for kendoka who want to improve their suburi practice at home.

Using your iPhone or Apple Watch, DojoGo tracks your swings, measures your speed and power, and helps you build consistent training habits.

Whether you're a beginner working on basics or an experienced practitioner maintaining your edge, DojoGo provides the feedback and motivation you need.
"""
                            )

                            // Features
                            sectionCard(
                                title: "FEATURES",
                                icon: "✨",
                                content: nil,
                                bulletPoints: [
                                    "Guided Sessions: Follow audio cues for structured practice",
                                    "Free Practice: Train at your own pace",
                                    "Swing Detection: Accurate tracking via IMU sensors",
                                    "Performance Metrics: Speed, power, and reaction time",
                                    "Progress Tracking: Daily streaks and lifetime stats",
                                    "Insights: Visualize your training trends over time",
                                    "Leaderboard: Compare with other kendoka worldwide"
                                ]
                            )

                            // Roadmap
                            sectionCard(
                                title: "COMING SOON",
                                icon: "🗺️",
                                content: nil,
                                bulletPoints: [
                                    "Apple Watch standalone app",
                                    "Swing trajectory visualization",
                                    "Custom training programs",
                                    "Dojo leaderboards & challenges",
                                    "AI-powered form analysis"
                                ]
                            )

                            // Contact
                            sectionCard(
                                title: "FEEDBACK",
                                icon: "💬",
                                content: """
DojoGo is built by kendoka, for kendoka. We'd love to hear your thoughts, suggestions, and feature requests.

Contact us at: hello@klayonstudio.com
"""
                            )

                            // Credits
                            VStack(spacing: 8) {
                                Text("Made with ❤️ for the kendo community")
                                    .font(.pixelify(size: 10, weight: .regular))
                                    .foregroundColor(.gray)

                                Text("© 2025 DojoGo")
                                    .font(.pixelify(size: 9, weight: .regular))
                                    .foregroundColor(.gray.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 20)
                            .padding(.bottom, 40)
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
    }

    // MARK: - Section Card

    private func sectionCard(title: String, icon: String, content: String?, bulletPoints: [String]? = nil) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.pixelifyBodyBold)
                    .foregroundColor(.white)
            }

            if let content = content {
                Text(content)
                    .font(.pixelify(size: 12, weight: .regular))
                    .foregroundColor(.gray)
                    .lineSpacing(4)
            }

            if let points = bulletPoints {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(points, id: \.self) { point in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .font(.pixelify(size: 12, weight: .bold))
                                .foregroundColor(.yellow)
                            Text(point)
                                .font(.pixelify(size: 12, weight: .regular))
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.15))
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    AboutView()
}
