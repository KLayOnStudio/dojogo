import Foundation
import Auth0
import JWTDecode

class Auth0Manager: ObservableObject {
    static let shared = Auth0Manager()

    private let auth0 = Auth0.authentication()
    private let credentialsManager = CredentialsManager(authentication: Auth0.authentication())

    @Published var isAuthenticated = false
    @Published var userProfile: ManagementObject?
    @Published var idToken: String?

    private init() {
        checkForStoredCredentials()
    }

    // MARK: - Configuration

    private var domain: String {
        guard let path = Bundle.main.path(forResource: "Auth0", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let domain = plist["Domain"] as? String else {
            fatalError("Auth0.plist file missing or Domain not found")
        }
        return domain
    }

    private var clientId: String {
        guard let path = Bundle.main.path(forResource: "Auth0", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["ClientId"] as? String else {
            fatalError("Auth0.plist file missing or ClientId not found")
        }
        return clientId
    }

    // MARK: - Authentication

    func signUp() async throws -> User {
        return try await withCheckedThrowingContinuation { continuation in
            Auth0
                .webAuth()
                .scope("openid profile email")
                .parameters(["screen_hint": "signup", "prompt": "select_account"])
                .start { result in
                    switch result {
                    case .success(let credentials):
                        Task { @MainActor in
                            self.isAuthenticated = true
                            self.idToken = credentials.idToken

                            // Store credentials securely
                            _ = self.credentialsManager.store(credentials: credentials)

                            // Get user profile from ID token
                            do {
                                let idToken = credentials.idToken
                                let jwt = try decode(jwt: idToken)

                                let user = User(
                                    id: jwt.subject ?? "unknown",
                                    name: jwt.claim(name: "name").string ?? jwt.claim(name: "nickname").string ?? "User",
                                    email: jwt.claim(name: "email").string ?? ""
                                )

                                self.userProfile = [
                                    "sub": user.id,
                                    "name": user.name,
                                    "email": user.email
                                ]

                                continuation.resume(returning: user)
                            } catch {
                                print("Failed to decode ID token: \(error)")
                                continuation.resume(throwing: error)
                            }
                        }
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
        }
    }

    func signIn() async throws -> User {
        return try await withCheckedThrowingContinuation { continuation in
            Auth0
                .webAuth()
                .scope("openid profile email")
                .parameters(["prompt": "select_account"])
                .start { result in
                    switch result {
                    case .success(let credentials):
                        Task { @MainActor in
                            self.isAuthenticated = true
                            self.idToken = credentials.idToken

                            // Store credentials securely
                            _ = self.credentialsManager.store(credentials: credentials)

                            // Get user profile from ID token
                            do {
                                let idToken = credentials.idToken
                                let jwt = try decode(jwt: idToken)

                                let user = User(
                                    id: jwt.subject ?? "unknown",
                                    name: jwt.claim(name: "name").string ?? jwt.claim(name: "nickname").string ?? "User",
                                    email: jwt.claim(name: "email").string ?? ""
                                )

                                self.userProfile = [
                                    "sub": user.id,
                                    "name": user.name,
                                    "email": user.email
                                ]

                                continuation.resume(returning: user)
                            } catch {
                                print("Failed to decode ID token: \(error)")
                                continuation.resume(throwing: error)
                            }
                        }
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
        }
    }

    func signOut() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            Auth0
                .webAuth()
                .clearSession(federated: true) { result in
                    switch result {
                    case .success:
                        Task { @MainActor in
                            self.isAuthenticated = false
                            self.userProfile = nil
                            self.idToken = nil
                            _ = self.credentialsManager.clear()
                            continuation.resume()
                        }
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
        }
    }

    // MARK: - User Profile
    // Note: User profile is now extracted from ID token instead of API calls

    // MARK: - Credentials Management

    private func checkForStoredCredentials() {
        guard credentialsManager.hasValid() else { return }

        credentialsManager.credentials { result in
            switch result {
            case .success(let credentials):
                Task { @MainActor in
                    self.isAuthenticated = true
                    self.idToken = credentials.idToken

                    // Get user profile from stored ID token
                    do {
                        let idToken = credentials.idToken
                        let jwt = try decode(jwt: idToken)

                        self.userProfile = [
                            "sub": jwt.subject ?? "unknown",
                            "name": jwt.claim(name: "name").string ?? jwt.claim(name: "nickname").string ?? "User",
                            "email": jwt.claim(name: "email").string ?? ""
                        ]
                    } catch {
                        print("Failed to decode stored ID token: \(error)")
                    }
                }
            case .failure(let error):
                print("Failed to retrieve stored credentials: \(error)")
            }
        }
    }

    func refreshCredentialsIfNeeded() async throws {
        guard !credentialsManager.hasValid() else { return }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            credentialsManager.credentials { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Token Access

    func getAccessToken() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            credentialsManager.credentials { result in
                switch result {
                case .success(let credentials):
                    continuation.resume(returning: credentials.accessToken)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getIdToken() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            credentialsManager.credentials { result in
                switch result {
                case .success(let credentials):
                    continuation.resume(returning: credentials.idToken)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - Auth0 Error Extension

extension Auth0Manager {
    enum Auth0Error: Error, LocalizedError {
        case missingAccessToken
        case invalidCredentials

        var errorDescription: String? {
            switch self {
            case .missingAccessToken:
                return "Access token is missing"
            case .invalidCredentials:
                return "Invalid credentials"
            }
        }
    }
}