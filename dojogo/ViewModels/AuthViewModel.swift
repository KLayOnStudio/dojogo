import Foundation
import SwiftUI
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let auth0Manager = Auth0Manager.shared

    init() {
        // Observe Auth0Manager state changes
        observeAuth0State()

        // Only load stored user if Auth0 is already authenticated
        if auth0Manager.isAuthenticated {
            loadStoredUser()
        }
    }

    func clearAllData() {
        Task {
            // Clear local storage
            LocalStorageService.shared.clearUserData()

            // Sign out from Auth0 and clear credentials
            do {
                try await auth0Manager.signOut()
                print("Cleared all Auth0 credentials and local data")
            } catch {
                print("Error clearing Auth0 data: \(error)")
            }

            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
                self.errorMessage = nil
            }
        }
    }

    private func observeAuth0State() {
        auth0Manager.$isAuthenticated
            .assign(to: &$isAuthenticated)

        // Also check for stored user when authentication state changes
        auth0Manager.$isAuthenticated
            .sink { [weak self] isAuth in
                if isAuth && self?.currentUser == nil {
                    self?.loadStoredUser()
                }
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    private func loadStoredUser() {
        if let storedUser = LocalStorageService.shared.getCurrentUser() {
            self.currentUser = storedUser
            print("Loaded stored user: \(storedUser.name) (ID: \(storedUser.id))")
        } else {
            print("No stored user found")
        }
    }

    func signIn() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let user = try await auth0Manager.signIn()

                await MainActor.run {
                    self.currentUser = user
                    self.isLoading = false

                    // Clear any old user data and save new user
                    LocalStorageService.shared.clearStoredUser()
                    LocalStorageService.shared.saveUser(user)
                    print("Saved new Auth0 user: \(user.name) (ID: \(user.id))")
                }

                // Create user in API
                do {
                    let createdUser = try await APIService.shared.createUser(user)
                    print("✅ User created/retrieved from API: \(createdUser.name) (ID: \(createdUser.id))")

                    // Update with full user data from API
                    await MainActor.run {
                        self.currentUser = createdUser
                        LocalStorageService.shared.saveUser(createdUser)
                        print("✅ Updated local storage with full user data")
                    }
                } catch {
                    print("❌ Failed to create user in API: \(error)")
                    print("❌ Error details: \(error.localizedDescription)")
                    // Continue with local user for now
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func signUp() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let user = try await auth0Manager.signUp()

                await MainActor.run {
                    self.currentUser = user
                    self.isLoading = false

                    // Clear any old user data and save new user
                    LocalStorageService.shared.clearStoredUser()
                    LocalStorageService.shared.saveUser(user)
                    print("Saved new Auth0 user: \(user.name) (ID: \(user.id))")
                }

                // Create user in API
                do {
                    let createdUser = try await APIService.shared.createUser(user)
                    print("✅ User created/retrieved from API: \(createdUser.name) (ID: \(createdUser.id))")

                    // Update with full user data from API
                    await MainActor.run {
                        self.currentUser = createdUser
                        LocalStorageService.shared.saveUser(createdUser)
                        print("✅ Updated local storage with full user data")
                    }
                } catch {
                    print("❌ Failed to create user in API: \(error)")
                    print("❌ Error details: \(error.localizedDescription)")
                    // Continue with local user for now
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func signOut() async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }

        do {
            try await auth0Manager.signOut()

            await MainActor.run {
                self.currentUser = nil
                self.isLoading = false

                // Clear local storage
                LocalStorageService.shared.clearUserData()
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func refreshTokenIfNeeded() async {
        do {
            try await auth0Manager.refreshCredentialsIfNeeded()
        } catch {
            await MainActor.run {
                self.errorMessage = "Session expired. Please sign in again."
            }
            await self.signOut()
        }
    }

    // TEMPORARY: Get token for smoke tests
    func printTokenForTesting() {
        Task {
            do {
                let accessToken = try await auth0Manager.getAccessToken()
                let idToken = try await auth0Manager.getIdToken()
                print("╔════════════════════════════════════════════════════════════")
                print("║ 🔑 AUTH0 TOKENS FOR SMOKE TESTS")
                print("╠════════════════════════════════════════════════════════════")
                print("║ ACCESS TOKEN (may be encrypted JWE):")
                print(accessToken)
                print("╠════════════════════════════════════════════════════════════")
                print("║ ID TOKEN (standard JWT):")
                print(idToken)
                print("╠════════════════════════════════════════════════════════════")
                print("║ Use ID TOKEN - copy the second token and run:")
                print("║ export TOKEN='<paste_id_token_here>'")
                print("║ cd /Users/laeunkim/Dropbox/Dev/dojogo/dojogo/dojogo-api")
                print("║ ./smoke_test.sh")
                print("╚════════════════════════════════════════════════════════════")
            } catch {
                print("❌ Failed to get tokens: \(error)")
            }
        }
    }
}