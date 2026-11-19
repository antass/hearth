import SwiftUI
import SwiftData

struct RootView: View {
    @State private var tab: AppTab = .today

    enum AppTab: Hashable { case today, rooms, upkeep, family }

    var body: some View {
        TabView(selection: $tab) {
            Tab("Today", systemImage: "sun.max", value: AppTab.today) {
                NavigationStack { TodayView() }
            }
            Tab("Rooms", systemImage: "square.grid.2x2", value: AppTab.rooms) {
                NavigationStack { RoomsView() }
            }
            Tab("Upkeep", systemImage: "wrench.and.screwdriver", value: AppTab.upkeep) {
                NavigationStack { UpkeepView() }
            }
            Tab("Family", systemImage: "person.2", value: AppTab.family) {
                NavigationStack { FamilyView() }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

/// Wraps sheet content so it gets a sensible size on macOS.
struct SheetFrame: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
        content.frame(minWidth: 460, idealWidth: 520, minHeight: 560, idealHeight: 640)
        #else
        content
        #endif
    }
}

extension View {
    func sheetFrame() -> some View { modifier(SheetFrame()) }
}
