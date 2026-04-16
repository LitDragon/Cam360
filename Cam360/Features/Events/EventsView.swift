import SwiftUI

struct EventsView: View {
    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(title: "事件")
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-events")
    }
}
