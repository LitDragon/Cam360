---
depends_on: [device-session]
hardware_required: true
---

# 设备接入规格

本文件只记录 onboarding 真实接入时必须保持的契约。

## 当前离线契约

- `DeviceOnboardingStore.connectionStage` 区分 `connectingHotspot`、`validatingControlChannel`、`ready` 和 `retryRequired`。
- `retryRequired` 必须携带恢复动作：热点信息重试、本地网络权限检查或控制通道重试。
- `connecting` 路由只表示接入流程进行中；只有 `DeviceSession.ready` 后才进入 `success` 并写入已知设备。
- 握手失败回到 `wifiDetails`，保留失败原因作为可重试提示。
- `wifiDetails` 明确引导用户到 iOS 设置 > Wi-Fi 手动加入设备热点；继续按钮只表示用户确认手动步骤，不代表 App 已完成系统级自动切网。
- 当前仍以本地 AP 成功事件进入控制通道校验，不代表真机 Wi-Fi 自动连接已完成。

## 当前范围外

- 真实热点发现
- Wi-Fi 连接
- endpoint 自动发现
- 失败重试与恢复

## 配置清单

- 已有 `NSLocalNetworkUsageDescription`。
- 控制通道握手失败先提示检查本地网络权限，但不把所有握手失败都声明为权限拒绝。
- 引入 `NEHotspotConfiguration` 前，不启用 Hotspot Configuration capability。
- 只有确认 Bonjour 发现规则后，才补 `NSBonjourServices`。

## 后续接入约束

- onboarding 完成态仍由统一状态决定，不能把入口分流散落到多个 Feature 中。
- 真实连接、握手和超时控制不直接写在 View 内。
- 新增步骤时，优先扩展 Store、Route、Session 契约，不回退到临时布尔值堆砌。
