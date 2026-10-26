import SwiftUI

@main
struct RepCounterApp: App {
    @StateObject private var themeStore = ThemeStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(themeStore)
                .environment(\.theme, themeStore.current)
                .preferredColorScheme(themeStore.current.colorScheme)
        }
    }
}
