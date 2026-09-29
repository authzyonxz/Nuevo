import SwiftUI

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @State private var tabNavigation = AppTabNavigationState()

    var body: some View {
        TabView(selection: tabSelection) {
            HomeView()
                .tabItem {
                    Label(language.text("tab.home"), systemImage: "house.fill")
                }
                .tag(AppSection.home.rawValue)

            FeaturesView()
                .tabItem {
                    Label(language.text("tab.features"), systemImage: "switch.2")
                }
                .tag(AppSection.features.rawValue)
        }
        .tint(AppTheme.accent)
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { tabNavigation.selectedTab },
            set: { tabNavigation.select($0) }
        )
    }
}
