// IMUDebugView.swift
// DojoGo - Debug view to visualize mock IMU data on simulator
//
// Shows real-time IMU data capture and basic statistics

import SwiftUI

#if targetEnvironment(simulator)

struct IMUDebugView: View {
    @ObservedObject var mockIMU: MockIMUManager

    var body: some View {
        VStack(spacing: 20) {
            Text("IMU Debug (Simulator)")
                .font(.custom("PixelifySans-Bold", size: 20))
                .padding(.top)

            // Recording status
            HStack {
                Circle()
                    .fill(mockIMU.isRecording ? Color.red : Color.gray)
                    .frame(width: 12, height: 12)
                Text(mockIMU.isRecording ? "RECORDING" : "IDLE")
                    .font(.custom("PixelifySans-Regular", size: 14))
            }

            // Sample count
            VStack(alignment: .leading, spacing: 8) {
                Text("Total Samples: \(mockIMU.samples.count)")
                    .font(.custom("PixelifySans-Regular", size: 14))

                if mockIMU.samples.count > 0 {
                    let duration = Double(mockIMU.samples.count) / 100.0
                    Text("Duration: \(duration, specifier: "%.2f")s")
                        .font(.custom("PixelifySans-Regular", size: 14))
                }
            }

            // Latest sample data
            if let latest = mockIMU.samples.last {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Latest Sample:")
                        .font(.custom("PixelifySans-SemiBold", size: 16))

                    Group {
                        Text("Accel: (\(latest.ax, specifier: "%.2f"), \(latest.ay, specifier: "%.2f"), \(latest.az, specifier: "%.2f")) m/s²")
                        Text("Gyro: (\(latest.gx, specifier: "%.2f"), \(latest.gy, specifier: "%.2f"), \(latest.gz, specifier: "%.2f")) rad/s")
                    }
                    .font(.custom("PixelifySans-Regular", size: 12))
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }

            Spacer()
        }
        .padding()
    }
}

#endif
