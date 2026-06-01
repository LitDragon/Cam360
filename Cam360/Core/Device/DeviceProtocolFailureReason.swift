import Foundation

enum DeviceProtocolFailureReason {
    static func message(for error: DeviceProtocolError) -> String {
        switch error {
        case .transportDisconnected:
            return "控制通道已断开"
        case .requestTimedOut(let topic):
            if isSnapshotTopic(topic) {
                return "截图请求超时: \(topic)"
            }
            return "请求超时: \(topic)"
        case .deviceError(let errno, let topic, _):
            if errno == -6, topic == "FILE_DELETE" {
                return "文件已加锁，无法删除: \(topic) (errno \(errno))"
            }
            if errno == -3, topic == "SNAPSHOT_CTRL" {
                return "截图失败: \(topic) (errno \(errno))"
            }
            if errno == -7, topic == "SNAPSHOT_DATA" {
                return "截图数据超限: \(topic) (errno \(errno))"
            }
            if let reason = deviceErrorReason(for: errno) {
                return "\(reason): \(topic) (errno \(errno))"
            }
            return "设备错误 errno \(errno): \(topic)"
        case .transportFailed(let message):
            return "传输失败: \(message)"
        case .invalidFrame:
            return "协议帧无效"
        case .encodeFailed:
            return "协议编码失败"
        case .decodeFailed:
            return "协议解码失败"
        case .responseWithoutRequest(let replyTo):
            return "未匹配的设备响应: \(replyTo)"
        case .unsupportedAppVersion(let appVersion, let minSupportedVersion):
            return "APP 版本 \(appVersion) 低于设备最低支持 \(minSupportedVersion)"
        }
    }

    private static func isSnapshotTopic(_ topic: String) -> Bool {
        topic == "SNAPSHOT_CTRL" || topic == "SNAPSHOT_DATA"
    }

    private static func deviceErrorReason(for errno: Int) -> String? {
        switch errno {
        case -1:
            return "未知错误"
        case -2:
            return "参数错误"
        case -3:
            return "操作失败"
        case -4:
            return "设备忙"
        case -5:
            return "不支持此功能"
        case -6:
            return "资源受保护"
        case -7:
            return "资源不足"
        default:
            return nil
        }
    }
}
