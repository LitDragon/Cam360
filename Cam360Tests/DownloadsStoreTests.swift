import Testing
import Foundation
@testable import Cam360

struct DownloadsStoreTests {
    @Test
    func initialStateShowsPlaceholderMessage() {
        let store = DownloadsStore()

        #expect(store.title == "下载任务中心搭建中")
        #expect(store.message.contains("M4"))
    }
}
