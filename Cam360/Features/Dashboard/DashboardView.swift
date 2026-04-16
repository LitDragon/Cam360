import SwiftUI

struct DashboardView: View {
    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(title: "概览")
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-dashboard")
    }
}
