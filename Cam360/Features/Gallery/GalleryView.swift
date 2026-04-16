import SwiftUI

struct GalleryView: View {
    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(title: "相册")
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-gallery")
    }
}
