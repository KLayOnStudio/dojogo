// IMUCaptureManager.swift
// DojoGo IMU Capture - Session-Coupled Recording
//
// USAGE:
// 1. Start IMU recording when tap-game begins
// 2. Buffer samples and write Parquet parts during gameplay
// 3. Upload all parts when game ends
// 4. Finalize manifest with checksums

import Foundation
import CoreMotion
import CryptoKit

// MARK: - Models

struct IMUSample: Codable {
    let ts_ns: Int64        // Nanoseconds since Unix epoch
    let ax: Float           // Acceleration X (m/s²)
    let ay: Float           // Acceleration Y (m/s²)
    let az: Float           // Acceleration Z (m/s²)
    let gx: Float           // Gyroscope X (rad/s)
    let gy: Float           // Gyroscope Y (rad/s)
    let gz: Float           // Gyroscope Z (rad/s)
}

struct PartInfo {
    let filename: String
    let localURL: URL
    let numSamples: Int
    var fileSize: Int64 = 0
    var checksum: String = ""
}

struct CreateImuSessionRequest: Codable {
    let clientUploadId: String
    let deviceInfo: DeviceInfo
    let startTimeUtc: String
    let nominalHz: Double
    let coordFrame: String
    let gameSessionId: String?
    let notes: String?
}

struct CreateImuSessionResponse: Codable {
    let imuSessionId: Int
    let userId: String
    let deviceId: Int
    let startTimeUtc: String
    let nominalHz: Double?
    let coordFrame: String
    let gameSessionId: String?
    let sasToken: SasToken

    enum CodingKeys: String, CodingKey {
        case imuSessionId = "imu_session_id"
        case userId = "user_id"
        case deviceId = "device_id"
        case startTimeUtc = "start_time_utc"
        case nominalHz = "nominal_hz"
        case coordFrame = "coord_frame"
        case gameSessionId = "game_session_id"
        case sasToken = "sas_token"
    }
}

struct SasToken: Codable {
    let container: String
    let path: String
    let sasUrl: String
    let expiresAt: String

    enum CodingKeys: String, CodingKey {
        case container
        case path
        case sasUrl = "sas_url"
        case expiresAt = "expires_at"
    }
}

struct DeviceInfo: Codable {
    let platform: String
    let model: String
    let osVersion: String
    let appVersion: String
    let hwId: String

    enum CodingKeys: String, CodingKey {
        case platform
        case model
        case osVersion = "os_version"
        case appVersion = "app_version"
        case hwId = "hw_id"
    }

    static func current() -> DeviceInfo {
        DeviceInfo(
            platform: "ios",
            model: UIDevice.current.model,
            osVersion: UIDevice.current.systemVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            hwId: UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        )
    }
}

struct FileManifestEntry: Codable {
    let filename: String
    let purpose: String
    let contentType: String
    let bytesSize: Int64
    let sha256Hex: String
    let numSamples: Int?

    enum CodingKeys: String, CodingKey {
        case filename
        case purpose
        case contentType = "content_type"
        case bytesSize = "bytes_size"
        case sha256Hex = "sha256_hex"
        case numSamples = "num_samples"
    }
}

struct RateStats: Codable {
    let samplesTotal: Int
    let durationMs: Double
    let meanHz: Double
    let dtMsP50: Double?
    let dtMsP95: Double?
    let dtMsMax: Double?
    let droppedSeqPct: Double?

    enum CodingKeys: String, CodingKey {
        case samplesTotal = "samples_total"
        case durationMs = "duration_ms"
        case meanHz = "mean_hz"
        case dtMsP50 = "dt_ms_p50"
        case dtMsP95 = "dt_ms_p95"
        case dtMsMax = "dt_ms_max"
        case droppedSeqPct = "dropped_seq_pct"
    }
}

struct FinalizeManifestRequest: Codable {
    let endTimeUtc: String
    let files: [FileManifestEntry]
    let rateStats: RateStats?

    enum CodingKeys: String, CodingKey {
        case endTimeUtc = "end_time_utc"
        case files
        case rateStats = "rate_stats"
    }
}

struct FinalizeManifestResponse: Codable {
    let message: String
    let imuSessionId: Int
    let totalFiles: Int
    let totalBytes: Int64
    let totalSamples: Int
    let endTimeUtc: String

    enum CodingKeys: String, CodingKey {
        case message
        case imuSessionId = "imu_session_id"
        case totalFiles = "total_files"
        case totalBytes = "total_bytes"
        case totalSamples = "total_samples"
        case endTimeUtc = "end_time_utc"
    }
}

// MARK: - IMU Capture Manager

class IMUCaptureManager {
    static let shared = IMUCaptureManager()

    // CoreMotion
    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()

    // Session state
    private(set) var isRecording = false
    private var imuSessionId: Int?
    private var gameSessionId: String?
    private var clientUploadId: String?
    private var sasURL: URL?
    private var sasExpiry: Date?
    private var startTime: Date?

    // Buffering
    private var buffer: [IMUSample] = []
    private var currentPart = 0
    private var pendingParts: [PartInfo] = []

    // Configuration
    private let partSizeThreshold = 10_000 // Samples per part (~100 seconds at 100Hz)
    private let sampleRate = 100.0 // Hz

    private init() {
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
    }

    // MARK: - Public API

    /// Start IMU recording synchronized with tap-game session
    func startRecording(gameSessionId: String) async throws {
        guard !isRecording else {
            print("⚠️ IMU already recording")
            return
        }

        print("🎬 Starting IMU recording for game session: \(gameSessionId)")

        // Step 1: Create IMU session via API
        self.gameSessionId = gameSessionId
        self.clientUploadId = UUID().uuidString
        self.startTime = Date()

        let request = CreateImuSessionRequest(
            clientUploadId: clientUploadId!,
            deviceInfo: DeviceInfo.current(),
            startTimeUtc: ISO8601DateFormatter().string(from: startTime!),
            nominalHz: sampleRate,
            coordFrame: "device",
            gameSessionId: gameSessionId,
            notes: "Alpha tap-game session"
        )

        let response = try await createImuSession(request: request)

        self.imuSessionId = response.imuSessionId
        self.sasURL = URL(string: response.sasToken.sasUrl)
        self.sasExpiry = ISO8601DateFormatter().date(from: response.sasToken.expiresAt)

        print("✅ IMU session created: \(response.imuSessionId)")

        // Step 2: Start CoreMotion sensors
        guard motionManager.isDeviceMotionAvailable else {
            throw IMUError.sensorsUnavailable
        }

        motionManager.deviceMotionUpdateInterval = 1.0 / sampleRate

        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }

            let sample = IMUSample(
                ts_ns: Int64(Date().timeIntervalSince1970 * 1_000_000_000),
                ax: Float(motion.userAcceleration.x * 9.80665), // Convert g to m/s²
                ay: Float(motion.userAcceleration.y * 9.80665),
                az: Float(motion.userAcceleration.z * 9.80665),
                gx: Float(motion.rotationRate.x), // Already in rad/s
                gy: Float(motion.rotationRate.y),
                gz: Float(motion.rotationRate.z)
            )

            self.bufferSample(sample)
        }

        isRecording = true
        print("📊 IMU sensors started at \(sampleRate) Hz")
    }

    /// Stop IMU recording and upload data
    func stopRecording() async throws {
        guard isRecording else {
            print("⚠️ IMU not recording")
            return
        }

        print("🛑 Stopping IMU recording")

        // Step 1: Stop sensors
        motionManager.stopDeviceMotionUpdates()
        isRecording = false

        // Step 2: Flush final part
        if !buffer.isEmpty {
            writeParquetPart()
        }

        // Step 3: Write sidecar files
        try writeSidecarFiles()

        // Step 4: Compute checksums for all parts
        try computeChecksums()

        // Step 5: Upload all parts
        try await uploadAllParts()

        // Step 6: Finalize manifest
        try await finalizeManifest()

        // Step 7: Clean up local files
        deleteLocalParts()

        print("✅ IMU recording stopped and uploaded")

        // Reset state
        imuSessionId = nil
        gameSessionId = nil
        clientUploadId = nil
        sasURL = nil
        sasExpiry = nil
        startTime = nil
        currentPart = 0
        pendingParts.removeAll()
    }

    // MARK: - Buffering

    private func bufferSample(_ sample: IMUSample) {
        buffer.append(sample)

        // Check if part threshold reached
        if buffer.count >= partSizeThreshold {
            writeParquetPart()
        }
    }

    private func writeParquetPart() {
        guard let imuSessionId = imuSessionId else { return }

        let filename = String(format: "raw_%d_%04d.jsonl", imuSessionId, currentPart)
        let localURL = getDocumentsDirectory().appendingPathComponent(filename)

        // Alpha: Write JSONL (convert to Parquet server-side later)
        do {
            let encoder = JSONEncoder()
            var lines: [String] = []

            for sample in buffer {
                let data = try encoder.encode(sample)
                if let json = String(data: data, encoding: .utf8) {
                    lines.append(json)
                }
            }

            let content = lines.joined(separator: "\n")
            try content.write(to: localURL, atomically: true, encoding: .utf8)

            // Track part for later upload
            let partInfo = PartInfo(
                filename: filename,
                localURL: localURL,
                numSamples: buffer.count
            )
            pendingParts.append(partInfo)

            print("📦 Wrote part \(currentPart): \(filename) (\(buffer.count) samples)")

            // Clear buffer and increment part counter
            buffer.removeAll(keepingCapacity: true)
            currentPart += 1

        } catch {
            print("❌ Failed to write part: \(error)")
        }
    }

    // MARK: - Sidecar Files

    private func writeSidecarFiles() throws {
        guard let imuSessionId = imuSessionId else { return }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        // device_{session_id}.json
        let deviceInfo: [String: Any] = [
            "imu_session_id": imuSessionId,
            "user_id": "auth0|placeholder", // TODO: Get from AuthViewModel
            "device_id": 0, // TODO: Get from API response
            "captured_at": ISO8601DateFormatter().string(from: Date()),
            "device_info": [
                "platform": "ios",
                "model": UIDevice.current.model,
                "os_version": UIDevice.current.systemVersion,
                "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
                "hw_id": UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
            ]
        ]

        let deviceData = try JSONSerialization.data(withJSONObject: deviceInfo, options: [.prettyPrinted, .sortedKeys])
        let deviceURL = getDocumentsDirectory().appendingPathComponent("device_\(imuSessionId).json")
        try deviceData.write(to: deviceURL)

        // calib_{session_id}.json
        let calibInfo: [String: Any] = [
            "imu_session_id": imuSessionId,
            "captured_at": ISO8601DateFormatter().string(from: Date()),
            "accelerometer": [
                "bias_x": 0.0,
                "bias_y": 0.0,
                "bias_z": 0.0,
                "scale_x": 1.0,
                "scale_y": 1.0,
                "scale_z": 1.0,
                "calibration_source": "uncalibrated"
            ],
            "gyroscope": [
                "bias_x": 0.0,
                "bias_y": 0.0,
                "bias_z": 0.0,
                "scale_x": 1.0,
                "scale_y": 1.0,
                "scale_z": 1.0,
                "calibration_source": "uncalibrated"
            ]
        ]

        let calibData = try JSONSerialization.data(withJSONObject: calibInfo, options: [.prettyPrinted, .sortedKeys])
        let calibURL = getDocumentsDirectory().appendingPathComponent("calib_\(imuSessionId).json")
        try calibData.write(to: calibURL)

        print("✅ Wrote sidecar files")
    }

    // MARK: - Checksums

    private func computeChecksums() throws {
        for i in 0..<pendingParts.count {
            let url = pendingParts[i].localURL
            let data = try Data(contentsOf: url)

            let hash = SHA256.hash(data: data)
            let checksum = hash.compactMap { String(format: "%02x", $0) }.joined()

            pendingParts[i].fileSize = Int64(data.count)
            pendingParts[i].checksum = checksum
        }

        print("✅ Computed checksums for \(pendingParts.count) parts")
    }

    // MARK: - Upload

    private func uploadAllParts() async throws {
        guard let sasURL = sasURL, let imuSessionId = imuSessionId else {
            throw IMUError.invalidState
        }

        // Upload raw parts
        for part in pendingParts {
            let blobURL = sasURL.appendingPathComponent(part.filename)
            try await uploadFile(localURL: part.localURL, to: blobURL, contentType: "application/x-ndjson")
        }

        // Upload sidecar files
        let deviceURL = getDocumentsDirectory().appendingPathComponent("device_\(imuSessionId).json")
        try await uploadFile(localURL: deviceURL, to: sasURL.appendingPathComponent("device_\(imuSessionId).json"), contentType: "application/json")

        let calibURL = getDocumentsDirectory().appendingPathComponent("calib_\(imuSessionId).json")
        try await uploadFile(localURL: calibURL, to: sasURL.appendingPathComponent("calib_\(imuSessionId).json"), contentType: "application/json")

        print("✅ Uploaded all files")
    }

    private func uploadFile(localURL: URL, to blobURL: URL, contentType: String) async throws {
        var request = URLRequest(url: blobURL)
        request.httpMethod = "PUT"
        request.setValue("BlockBlob", forHTTPHeaderField: "x-ms-blob-type")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        let (_, response) = try await URLSession.shared.upload(for: request, fromFile: localURL)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
            throw IMUError.uploadFailed
        }

        print("✅ Uploaded \(localURL.lastPathComponent)")
    }

    // MARK: - Finalization

    private func finalizeManifest() async throws {
        guard let imuSessionId = imuSessionId else {
            throw IMUError.invalidState
        }

        var files: [FileManifestEntry] = []

        // Add raw parts
        for part in pendingParts {
            files.append(FileManifestEntry(
                filename: part.filename,
                purpose: "raw",
                contentType: "application/x-ndjson",
                bytesSize: part.fileSize,
                sha256Hex: part.checksum,
                numSamples: part.numSamples
            ))
        }

        // Compute rate_stats from all samples
        let rateStats = computeRateStats()

        // Add sidecar files
        let deviceURL = getDocumentsDirectory().appendingPathComponent("device_\(imuSessionId).json")
        let deviceData = try Data(contentsOf: deviceURL)
        let deviceHash = SHA256.hash(data: deviceData).compactMap { String(format: "%02x", $0) }.joined()

        files.append(FileManifestEntry(
            filename: "device_\(imuSessionId).json",
            purpose: "device",
            contentType: "application/json",
            bytesSize: Int64(deviceData.count),
            sha256Hex: deviceHash,
            numSamples: nil
        ))

        let calibURL = getDocumentsDirectory().appendingPathComponent("calib_\(imuSessionId).json")
        let calibData = try Data(contentsOf: calibURL)
        let calibHash = SHA256.hash(data: calibData).compactMap { String(format: "%02x", $0) }.joined()

        files.append(FileManifestEntry(
            filename: "calib_\(imuSessionId).json",
            purpose: "calib",
            contentType: "application/json",
            bytesSize: Int64(calibData.count),
            sha256Hex: calibHash,
            numSamples: nil
        ))

        let request = FinalizeManifestRequest(
            endTimeUtc: ISO8601DateFormatter().string(from: Date()),
            files: files,
            rateStats: rateStats
        )

        let response = try await finalizeManifestAPI(imuSessionId: imuSessionId, request: request)

        print("✅ Manifest finalized: \(response.totalFiles) files, \(response.totalBytes) bytes, \(response.totalSamples) samples")
    }

    // MARK: - Rate Stats Computation

    private func computeRateStats() -> RateStats? {
        // Collect all timestamps from all parts
        var allTimestamps: [Int64] = []

        for part in pendingParts {
            do {
                let data = try Data(contentsOf: part.localURL)
                let content = String(data: data, encoding: .utf8) ?? ""
                let lines = content.components(separatedBy: "\n")

                let decoder = JSONDecoder()
                for line in lines where !line.isEmpty {
                    if let lineData = line.data(using: .utf8),
                       let sample = try? decoder.decode(IMUSample.self, from: lineData) {
                        allTimestamps.append(sample.ts_ns)
                    }
                }
            } catch {
                print("⚠️ Failed to read part for rate stats: \(part.filename)")
            }
        }

        guard !allTimestamps.isEmpty else {
            print("⚠️ No timestamps found, skipping rate_stats")
            return nil
        }

        // Sort timestamps
        allTimestamps.sort()

        let samplesTotal = allTimestamps.count
        let firstTs = allTimestamps.first!
        let lastTs = allTimestamps.last!

        // Duration in milliseconds
        let durationMs = Double(lastTs - firstTs) / 1_000_000.0

        guard durationMs > 0 else {
            print("⚠️ Zero duration, skipping rate_stats")
            return nil
        }

        // Mean Hz
        let meanHz = Double(samplesTotal) / (durationMs / 1000.0)

        // Compute inter-sample intervals (dt)
        var deltas: [Double] = []
        for i in 1..<allTimestamps.count {
            let dt_ns = allTimestamps[i] - allTimestamps[i - 1]
            let dt_ms = Double(dt_ns) / 1_000_000.0
            deltas.append(dt_ms)
        }

        guard !deltas.isEmpty else {
            return RateStats(
                samplesTotal: samplesTotal,
                durationMs: durationMs,
                meanHz: meanHz,
                dtMsP50: nil,
                dtMsP95: nil,
                dtMsMax: nil,
                droppedSeqPct: nil
            )
        }

        // Sort deltas for percentile calculation
        deltas.sort()

        // Percentiles
        let p50Index = Int(Double(deltas.count) * 0.50)
        let p95Index = Int(Double(deltas.count) * 0.95)

        let dtMsP50 = deltas[min(p50Index, deltas.count - 1)]
        let dtMsP95 = deltas[min(p95Index, deltas.count - 1)]
        let dtMsMax = deltas.last!

        print("📊 Rate stats: \(String(format: "%.1f", meanHz)) Hz actual (target: \(sampleRate) Hz)")
        print("   Duration: \(String(format: "%.1f", durationMs))ms, Samples: \(samplesTotal)")
        print("   dt P50: \(String(format: "%.1f", dtMsP50))ms, P95: \(String(format: "%.1f", dtMsP95))ms, Max: \(String(format: "%.1f", dtMsMax))ms")

        return RateStats(
            samplesTotal: samplesTotal,
            durationMs: durationMs,
            meanHz: meanHz,
            dtMsP50: dtMsP50,
            dtMsP95: dtMsP95,
            dtMsMax: dtMsMax,
            droppedSeqPct: nil  // Not tracking seq in alpha
        )
    }

    // MARK: - Cleanup

    private func deleteLocalParts() {
        guard let imuSessionId = imuSessionId else { return }

        for part in pendingParts {
            try? FileManager.default.removeItem(at: part.localURL)
        }

        let deviceURL = getDocumentsDirectory().appendingPathComponent("device_\(imuSessionId).json")
        try? FileManager.default.removeItem(at: deviceURL)

        let calibURL = getDocumentsDirectory().appendingPathComponent("calib_\(imuSessionId).json")
        try? FileManager.default.removeItem(at: calibURL)

        print("🗑️ Deleted local files")
    }

    // MARK: - API Calls

    private func createImuSession(request: CreateImuSessionRequest) async throws -> CreateImuSessionResponse {
        let url = URL(string: "\(APIService.baseURL)/v1/imu/sessions")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(APIService.shared.getAuthToken())", forHTTPHeaderField: "Authorization")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...201).contains(httpResponse.statusCode) else {
            throw IMUError.apiError
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(CreateImuSessionResponse.self, from: data)
    }

    private func finalizeManifestAPI(imuSessionId: Int, request: FinalizeManifestRequest) async throws -> FinalizeManifestResponse {
        let url = URL(string: "\(APIService.baseURL)/v1/imu/sessions/\(imuSessionId)/manifest")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(APIService.shared.getAuthToken())", forHTTPHeaderField: "Authorization")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw IMUError.apiError
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(FinalizeManifestResponse.self, from: data)
    }

    // MARK: - Helpers

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

// MARK: - Errors

enum IMUError: Error, LocalizedError {
    case sensorsUnavailable
    case invalidState
    case uploadFailed
    case apiError

    var errorDescription: String? {
        switch self {
        case .sensorsUnavailable: return "IMU sensors not available on this device"
        case .invalidState: return "IMU manager in invalid state"
        case .uploadFailed: return "Failed to upload IMU data"
        case .apiError: return "IMU API request failed"
        }
    }
}

// MARK: - Usage Example

/*
// In your GameViewController or GameViewModel:

class GameViewModel: ObservableObject {
    @Published var gameSessionId: String?
    private let imuManager = IMUCaptureManager.shared

    func startGame() async {
        // Start tap-game session (existing system)
        gameSessionId = UUID().uuidString

        // Start IMU recording
        do {
            try await imuManager.startRecording(gameSessionId: gameSessionId!)
        } catch {
            print("❌ Failed to start IMU recording: \(error)")
        }

        // Start game loop...
    }

    func endGame() async {
        // Stop IMU recording and upload
        do {
            try await imuManager.stopRecording()
        } catch {
            print("❌ Failed to stop IMU recording: \(error)")
        }

        // End tap-game session (existing system)
        // ...
    }
}
*/
