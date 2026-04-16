import Testing
import Foundation
@testable import Cam360

struct DownloadsStoreTests {
    @Test
    func initialStateShowsEmptyDownloadMessage() {
        let store = DownloadsStore()

        #expect(store.title == "没有下载任务")
        #expect(store.message == "当前没有进行中或已完成的下载。")
    }
}
