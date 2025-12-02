import SwiftUI

struct IRDrainageView: View {
    @StateObject private var store = DrainageStore()
    
    var body: some View {
        DrainageListView()
            .environmentObject(store)
            .withNavigation()
    }
}

#Preview {
    IRDrainageView()
}
