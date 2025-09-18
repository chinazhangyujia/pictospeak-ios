import SwiftUI

struct TestView: View {
    @State private var selectedTab: NavTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "tray.and.arrow.down.fill", value: NavTab.home) {
                HomeView()
            }

            Tab("Capture", systemImage: "tray.and.arrow.up.fill", value: NavTab.capture) {
                HomeView()
            }

            Tab("Review", systemImage: "person.crop.circle.fill", value: NavTab.review) {
                HomeView()
            }
        }
    }
}
