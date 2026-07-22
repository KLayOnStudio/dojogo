import SwiftUI

struct GuestInfoView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedRank: KendoRank = .unranked
    @State private var experienceYears: Int = 0
    @State private var experienceMonths: Int = 0
    @State private var guestName: String = ""
    @State private var showBetaInvite = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image("MapVer0")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .ignoresSafeArea()

                Color.black.opacity(0.55)
                    .ignoresSafeArea()

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
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, max(geometry.safeAreaInsets.top + 8, 20))
                    .padding(.bottom, 16)

                    ScrollView {
                        VStack(spacing: 24) {
                            Text("TRY DOJOGO")
                                .font(.pixelifyTitle)
                                .foregroundColor(.white)
                                .shadow(color: .white.opacity(0.3), radius: 4, x: 0, y: 2)

                            Text("Quick setup before your session")
                                .font(.pixelifySmall)
                                .foregroundColor(.gray)

                            // Kendo Rank
                            VStack(alignment: .leading, spacing: 8) {
                                Text("KENDO RANK")
                                    .font(.pixelifyBodyBold)
                                    .foregroundColor(.white)

                                Picker("Rank", selection: $selectedRank) {
                                    ForEach(KendoRank.allCases, id: \.self) { rank in
                                        Text(rank.displayName).tag(rank)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(.cyan)
                                .font(.pixelifyBody)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 0)
                                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                )
                            }
                            .padding(.horizontal, 20)

                            // Experience
                            VStack(alignment: .leading, spacing: 8) {
                                Text("EXPERIENCE")
                                    .font(.pixelifyBodyBold)
                                    .foregroundColor(.white)

                                HStack(spacing: 12) {
                                    // Years
                                    VStack(spacing: 4) {
                                        Picker("Years", selection: $experienceYears) {
                                            ForEach(0..<51) { year in
                                                Text("\(year)").tag(year)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .tint(.cyan)
                                        .font(.pixelifyBody)
                                        .padding(8)
                                        .background(Color.gray.opacity(0.2))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 0)
                                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                        )

                                        Text("YEARS")
                                            .font(.pixelify(size: 9, weight: .bold))
                                            .foregroundColor(.gray)
                                    }

                                    // Months
                                    VStack(spacing: 4) {
                                        Picker("Months", selection: $experienceMonths) {
                                            ForEach(0..<12) { month in
                                                Text("\(month)").tag(month)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .tint(.cyan)
                                        .font(.pixelifyBody)
                                        .padding(8)
                                        .background(Color.gray.opacity(0.2))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 0)
                                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                        )

                                        Text("MONTHS")
                                            .font(.pixelify(size: 9, weight: .bold))
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)

                            // Name (optional)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 4) {
                                    Text("NAME")
                                        .font(.pixelifyBodyBold)
                                        .foregroundColor(.white)
                                    Text("(optional)")
                                        .font(.pixelifySmall)
                                        .foregroundColor(.gray)
                                }

                                TextField("", text: $guestName)
                                    .font(.pixelifyBody)
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Color.gray.opacity(0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 0)
                                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                    )
                                    .placeholder(when: guestName.isEmpty) {
                                        Text("Your name")
                                            .font(.pixelifyBody)
                                            .foregroundColor(.gray.opacity(0.5))
                                            .padding(.leading, 12)
                                    }
                            }
                            .padding(.horizontal, 20)

                            Spacer()
                                .frame(height: 20)

                            // START button
                            Button(action: {
                                authViewModel.guestKendoRank = selectedRank
                                authViewModel.guestExperienceYears = experienceYears
                                authViewModel.guestExperienceMonths = experienceMonths
                                authViewModel.guestName = guestName.isEmpty ? nil : guestName
                                authViewModel.enterGuestMode()
                                dismiss()
                            }) {
                                Text("START")
                                    .font(.pixelifyButtonLarge)
                                    .foregroundColor(.black)
                                    .frame(maxWidth: min(geometry.size.width * 0.7, 280))
                                    .frame(height: 56)
                                    .background(Color.green)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 0)
                                            .stroke(Color.white, lineWidth: 3)
                                    )
                                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                            }

                            // JOIN BETA button
                            Button(action: { showBetaInvite = true }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "qrcode")
                                        .font(.system(size: 20))
                                    Text("JOIN BETA")
                                        .font(.pixelifyButtonLarge)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: min(geometry.size.width * 0.7, 280))
                                .frame(height: 56)
                                .background(Color(red: 0x7F/255, green: 0x64/255, blue: 0xAC/255))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 0)
                                        .stroke(Color.white, lineWidth: 3)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                            }

                            Spacer()
                                .frame(height: max(geometry.safeAreaInsets.bottom, 20))
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
        .sheet(isPresented: $showBetaInvite) { BetaInviteView() }
    }
}
