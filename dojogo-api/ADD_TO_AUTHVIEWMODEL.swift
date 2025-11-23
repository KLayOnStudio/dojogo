// ============================================================================
// TEMPORARY: Add this to AuthViewModel.swift for getting test token
// ============================================================================

// Add this function to your AuthViewModel class:
func printTokenForTesting() {
    Task {
        do {
            let credentials = try await auth0Manager.credentialsManager.credentials()
            print("╔════════════════════════════════════════════════════════════")
            print("║ 🔑 AUTH0 TOKEN FOR SMOKE TESTS")
            print("╠════════════════════════════════════════════════════════════")
            print(credentials.accessToken)
            print("╠════════════════════════════════════════════════════════════")
            print("║ Copy the token above and run:")
            print("║ export TOKEN='<paste_token_here>'")
            print("║ ./smoke_test.sh")
            print("╚════════════════════════════════════════════════════════════")
        } catch {
            print("❌ Failed to get credentials: \(error)")
        }
    }
}

// Then call this function after successful sign-in, or add a button:
// In your MainMapView or ProfileView, add:
/*
Button("Get Test Token") {
    authViewModel.printTokenForTesting()
}
.buttonStyle(.borderedProminent)
*/
