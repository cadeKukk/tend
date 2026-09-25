import SwiftUI

@main
struct TendApp: App {
    @State private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { store.refreshDay() }
                }
        }
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ZStack {
            if store.data.hatched {
                MainTabs()
                    .transition(.opacity)
            } else {
                HatchView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: store.data.hatched)
        .fontDesign(.rounded)
        .tint(Tint.leaf.color)
    }
}

struct MainTabs: View {
    @Environment(AppStore.self) private var store
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "checklist") }
                .tag(0)
            LookBackView()
                .tabItem { Label("Look back", systemImage: "calendar") }
                .tag(1)
            WardrobeView()
                .tabItem { Label(store.look.name, systemImage: "tshirt.fill") }
                .tag(2)
            JourneyView()
                .tabItem { Label("Journey", systemImage: "map.fill") }
                .tag(3)
        }
        #if DEBUG
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-tab"), i + 1 < args.count { tab = Int(args[i + 1]) ?? 0 }
            if let i = args.firstIndex(of: "-levelup"), i + 1 < args.count { store.levelUpToShow = Int(args[i + 1]) }
        }
        #endif
        .fullScreenCover(isPresented: Binding(
            get: { store.levelUpToShow != nil },
            set: { if !$0 { store.levelUpToShow = nil } }
        )) {
            if let level = store.levelUpToShow {
                LevelUpView(level: level) {
                    var quiet = Transaction()
                    quiet.disablesAnimations = true
                    withTransaction(quiet) { store.levelUpToShow = nil }
                }
                .presentationBackground(.clear)
                .environment(store)
            }
        }
        .transaction { t in
            // The cover fades itself in; skip the default slide-up.
            if store.levelUpToShow != nil { t.disablesAnimations = true }
        }
    }
}
