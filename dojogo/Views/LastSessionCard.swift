import SwiftUI

struct LastSessionCard: View {
    let session: Session
    let stats: StoredSessionStats?

    var body: some View {
        VStack(spacing: 8) {
            // Header row: title + date
            HStack {
                Text("LAST SESSION")
                    .font(.pixelify(size: 11, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text(formattedDate)
                    .font(.pixelify(size: 10, weight: .regular))
                    .foregroundColor(.gray)
            }

            // Stats row 1: swings, duration, streak
            HStack(spacing: 0) {
                Text("\(session.swingCount) swings")
                    .font(.pixelify(size: 10, weight: .bold))
                    .foregroundColor(.yellow)
                Text("  ·  ")
                    .foregroundColor(.gray.opacity(0.6))
                    .font(.pixelify(size: 10, weight: .regular))
                Text(formattedDuration)
                    .font(.pixelify(size: 10, weight: .bold))
                    .foregroundColor(.cyan)
                Spacer()
            }

            // Stats row 2: reaction + max speed
            HStack(spacing: 0) {
                if let reaction = stats?.avgReactionMs {
                    Text("Reaction: \(Int(reaction))ms")
                        .font(.pixelify(size: 10, weight: .regular))
                        .foregroundColor(.green)
                    Text("  ")
                }
                if let maxSpeed = stats?.maxSpeed {
                    Text("Max Speed: \(String(format: "%.1f", maxSpeed))")
                        .font(.pixelify(size: 10, weight: .regular))
                        .foregroundColor(.orange)
                }
                Spacer()
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.7))
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: session.date)
    }

    private var formattedDuration: String {
        let minutes = Int(session.duration) / 60
        let seconds = Int(session.duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
