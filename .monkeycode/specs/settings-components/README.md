# 开关设置组件记录

来源：
- `/Users/naxclow/Cam360/UI/开关设置/总和.png`
- `/Users/naxclow/Desktop/UI/设置.png`

## 组件表

| component_id | name | base_component | variant | props / slots | reused_pages | status | notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| DS-001 | AppTopBar | `AppTopBar` | `default`, `leadingIcon`, `eyebrow`, `trailingIcon` | `title`, `eyebrow`, `subtitle`, `leadingSystemImage`, `leadingAction`, `trailing*` | More, Notification Settings, Help Center, System Permissions, Device Settings | built | 已扩展支持返回图标、眉题和右上动作 |
| DS-002 | SettingsSectionHeader | `SettingsSectionHeader` | `default` | `title` | More, Notification Settings, Help Center | built | Section 外层标题 |
| DS-003 | SettingsGroupCard | `SettingsGroupCard` | `default` | `content` | More, Notification Settings, Help Center, System Permissions | built | 分组卡片容器 |
| DS-004 | SettingsNavigationRow | `SettingsNavigationRow` | `chevron`, `externalLink`, `disabled` | `iconName`, `title`, `subtitle`, `trailingSystemImage`, `isEnabled`, `action`, `showsDivider` | More, Help Center, Device Settings, Storage Policy | built | 导航型列表项 |
| DS-005 | SettingsToggleRow | `SettingsToggleRow` | `switch`, `disabled` | `iconName`, `title`, `subtitle`, `isOn`, `isEnabled`, `showsDivider` | More, Notification Settings, Storage Policy, Safety, Video Quality | built | 开关型列表项 |
| DS-006 | SettingsStatusRow | `SettingsStatusRow` | `text`, `text+icon`, `disabled` | `iconName`, `title`, `subtitle`, `statusText`, `trailingSystemImage`, `statusColor`, `isEnabled`, `showsDivider` | More, System Permissions | built | 状态展示型列表项 |
| DS-007 | SettingsActionRow | `SettingsActionRow` | `pillButton` | `iconName`, `title`, `subtitle`, `actionTitle`, `action`, `showsDivider` | System Permissions | built | 行内操作按钮 |
| DS-008 | SettingsSearchBar | `SettingsSearchBar` | `default` | `text`, `placeholder` | Help Center | built | 搜索框 |
| DS-009 | SettingsTimeField | `SettingsTimeField` | `default` | `title`, `value` | Notification Settings | built | 时间输入框 |
| DS-010 | SettingsFootnote | `SettingsFootnote` | `info` | `text`, `iconName` | Notification Settings, Help Center, System Permissions | built | 页脚说明 / 提示文案 |
| DS-011 | SettingsValueRow | `SettingsValueRow` | `value`, `value+chevron`, `disabled` | `iconName`, `title`, `subtitle`, `valueText`, `valueColor`, `trailingSystemImage`, `isEnabled`, `action`, `showsDivider` | Device Settings, Storage Policy, Localization | built | 值展示型列表项 |
| DS-012 | SettingsInputRow | `SettingsInputRow` | `plain`, `secure`, `disabled` | `title`, `text`, `subtitle`, `placeholder`, `fieldKind`, `trailingSystemImage`, `isEnabled`, `showsDivider` | Network Identity, Watermark Configuration | built | 输入型列表项 |
| DS-013 | SettingsSegmentedRow | `SettingsSegmentedRow` | `segmented` | `title`, `subtitle`, `options`, `selection`, `titleForOption`, `showsDivider` | Video Quality, Safety, Audio Controls | built | 分段选择列表项 |
| DS-014 | SettingsMetricCard | `SettingsMetricCard` | `ring+details` | `title`, `progress`, `progressLabel`, `progressCaption`, `details`, `footnote` | Storage Policy | built | 指标摘要卡片 |
| DS-015 | SettingsNoticeCard | `SettingsNoticeCard` | `info`, `warning`, `danger` | `title`, `message`, `tone`, `iconName` | Storage Policy, Video Quality, Safety | built | 提示/警告卡片 |
| DS-016 | StatusTag | `StatusTag` | `accent`, `success`, `warning`, `danger`, `neutral` | `title`, `tone` | Device Settings, Network Identity | existing | 复用现有状态徽标 |
| DS-017 | PrimaryButton | `PrimaryButton` | `primary` | `title`, `action` | Watermark Configuration, Network Identity | existing | 复用现有主按钮 |
| DS-018 | DestructiveButton | `DestructiveButton` | `danger` | `title`, `action` | Storage Policy, Safety | built | 危险操作按钮 |

## 页面关系表

注：`/Users/naxclow/Desktop/UI/设置.png` 最后 3 张弹窗页未计入本表。

| page_id | page_name | section | component_id | variant | count | implemented_in_repo | notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| PAGE-001 | More | App Preferences | DS-002 | `default` | 1 | yes | 分组标题 |
| PAGE-001 | More | App Preferences | DS-003 | `default` | 1 | yes | 卡片容器 |
| PAGE-001 | More | App Preferences | DS-004 | `chevron` | 2 | yes | Notifications / System Permissions |
| PAGE-001 | More | Support | DS-002 | `default` | 1 | yes | 分组标题 |
| PAGE-001 | More | Support | DS-003 | `default` | 1 | yes | 卡片容器 |
| PAGE-001 | More | Support | DS-004 | `chevron` | 1 | yes | Help Center |
| PAGE-001 | More | Diagnostics & Maintenance | DS-002 | `default` | 1 | yes | 分组标题 |
| PAGE-001 | More | Diagnostics & Maintenance | DS-003 | `default` | 1 | yes | 卡片容器 |
| PAGE-001 | More | Diagnostics & Maintenance | DS-005 | `switch` | 1 | yes | Share Anonymous Logs |
| PAGE-001 | More | About | DS-002 | `default` | 1 | yes | 分组标题 |
| PAGE-001 | More | About | DS-003 | `default` | 1 | yes | 卡片容器 |
| PAGE-001 | More | About | DS-006 | `text` | 1 | yes | App Version |
| PAGE-001 | More | About | DS-004 | `externalLink` | 2 | yes | Privacy Policy / Terms of Service |
| PAGE-002 | Notification Settings | Nav | DS-001 | `leadingIcon+eyebrow` | 1 | partial | 顶部返回导航 |
| PAGE-002 | Notification Settings | Safety Alerts | DS-002 | `default` | 1 | yes | 分组标题 |
| PAGE-002 | Notification Settings | Safety Alerts | DS-003 | `default` | 1 | yes | 卡片容器 |
| PAGE-002 | Notification Settings | Safety Alerts | DS-005 | `switch` | 3 | yes | 三个告警开关 |
| PAGE-002 | Notification Settings | Notification Delivery | DS-002 | `default` | 1 | yes | 分组标题 |
| PAGE-002 | Notification Settings | Notification Delivery | DS-003 | `default` | 1 | yes | 卡片容器 |
| PAGE-002 | Notification Settings | Notification Delivery | DS-005 | `switch` | 2 | yes | 两个通知开关 |
| PAGE-002 | Notification Settings | Quiet Hours | DS-002 | `default` | 1 | yes | 分组标题 |
| PAGE-002 | Notification Settings | Quiet Hours | DS-003 | `default` | 1 | yes | 卡片容器 |
| PAGE-002 | Notification Settings | Quiet Hours | DS-005 | `switch` | 1 | yes | Enable Quiet Hours |
| PAGE-002 | Notification Settings | Quiet Hours | DS-009 | `default` | 2 | yes | Start / End time |
| PAGE-002 | Notification Settings | Quiet Hours | DS-010 | `info` | 1 | yes | 说明文案 |
| PAGE-003 | Help Center | Nav | DS-001 | `leadingIcon` | 1 | partial | 顶部返回导航 |
| PAGE-003 | Help Center | Search | DS-008 | `default` | 1 | yes | 搜索框 |
| PAGE-003 | Help Center | Help Topics | DS-002 | `default` | 1 | yes | 分组标题 |
| PAGE-003 | Help Center | Help Topics | DS-003 | `default` | 1 | yes | 卡片容器 |
| PAGE-003 | Help Center | Help Topics | DS-004 | `chevron` | 6 | yes | 六个帮助项 |
| PAGE-003 | Help Center | Quick Actions | DS-002 | `default` | 1 | yes | 分组标题 |
| PAGE-003 | Help Center | Quick Actions | DS-003 | `default` | 1 | yes | 卡片容器 |
| PAGE-003 | Help Center | Quick Actions | DS-004 | `chevron` | 2 | yes | FAQ / Contact Support |
| PAGE-003 | Help Center | Footer | DS-010 | `info` | 1 | yes | 底部支持文案可复用该组件，文案样式需补链接态 |
| PAGE-004 | System Permissions | Nav | DS-001 | `leadingIcon` | 1 | partial | 顶部返回导航 |
| PAGE-004 | System Permissions | Permissions | DS-003 | `default` | 1 | yes | 卡片容器 |
| PAGE-004 | System Permissions | Permissions | DS-006 | `text+icon` | 4 | yes | Enabled 状态 |
| PAGE-004 | System Permissions | Permissions | DS-007 | `pillButton` | 2 | yes | Allow Access / Open Settings |
| PAGE-004 | System Permissions | Footer | DS-010 | `info` | 1 | yes | 页脚说明 |
| PAGE-005 | Device Settings Overview | Header | DS-001 | `leadingIcon` | 1 | partial | 顶部返回导航 |
| PAGE-005 | Device Settings Overview | Header | DS-016 | `accent` | 1 | yes | CONNECTED 状态徽标 |
| PAGE-005 | Device Settings Overview | Camera Settings | DS-002 | `default` | 1 | yes | 分组标题 |
| PAGE-005 | Device Settings Overview | Camera Settings | DS-003 | `default` | 1 | yes | 卡片容器 |
| PAGE-005 | Device Settings Overview | Camera Settings | DS-004 | `chevron` | 4 | yes | Recording / Safety / Storage / Watermark |
| PAGE-005 | Device Settings Overview | System & Maintenance | DS-002 | `default` | 1 | yes | 分组标题 |
| PAGE-005 | Device Settings Overview | System & Maintenance | DS-003 | `default` | 1 | yes | 卡片容器 |
| PAGE-005 | Device Settings Overview | System & Maintenance | DS-011 | `value` | 1 | yes | Firmware Version |
| PAGE-005 | Device Settings Overview | System & Maintenance | DS-004 | `chevron` | 2 | yes | System Preferences / Rename Device |
| PAGE-006 | Storage Policy Healthy | Nav | DS-001 | `leadingIcon` | 1 | partial | 顶部返回导航 |
| PAGE-006 | Storage Policy Healthy | Maintenance | DS-014 | `ring+details` | 1 | yes | 存储使用摘要 |
| PAGE-006 | Storage Policy Healthy | General Policy | DS-002 | `default` | 1 | yes | 分组标题 |
| PAGE-006 | Storage Policy Healthy | General Policy | DS-003 | `default` | 1 | yes | 卡片容器 |
| PAGE-006 | Storage Policy Healthy | General Policy | DS-005 | `switch` | 2 | yes | Auto Cleanup / Auto Overwrite |
| PAGE-006 | Storage Policy Healthy | General Policy | DS-011 | `value+chevron` | 1 | yes | Locked Event Retention |
| PAGE-006 | Storage Policy Healthy | Storage Allocation | DS-002 | `default` | 1 | yes | 分组标题 |
| PAGE-006 | Storage Policy Healthy | Storage Allocation | DS-003 | `default` | 1 | yes | 卡片容器 |
| PAGE-006 | Storage Policy Healthy | Storage Allocation | DS-011 | `value+chevron` | 1 | yes | Reserved Space for Events |
| PAGE-007 | Storage Policy Error | Nav | DS-001 | `leadingIcon` | 1 | partial | 顶部返回导航 |
| PAGE-007 | Storage Policy Error | Maintenance | DS-015 | `danger` | 1 | yes | SD card error / No SD Card |
| PAGE-007 | Storage Policy Error | Maintenance | DS-018 | `danger` | 1 | yes | Format Card |
| PAGE-007 | Storage Policy Error | General Policy | DS-005 | `disabled` | 2 | yes | Auto Cleanup / Auto Overwrite disabled |
| PAGE-007 | Storage Policy Error | General Policy | DS-011 | `disabled` | 1 | yes | Locked Event Retention disabled |
| PAGE-007 | Storage Policy Error | Storage Allocation | DS-011 | `disabled` | 1 | yes | Reserved Space for Events disabled |
| PAGE-008 | Video Quality | Nav | DS-001 | `leadingIcon+eyebrow` | 1 | partial | 顶部返回导航 |
| PAGE-008 | Video Quality | Video Quality | DS-002 | `default` | 1 | yes | 分组标题 |
| PAGE-008 | Video Quality | Video Quality | DS-003 | `default` | 1 | yes | 卡片容器 |
| PAGE-008 | Video Quality | Video Quality | DS-013 | `segmented` | 2 | yes | Resolution / Recording Quality Priority |
| PAGE-008 | Video Quality | Recording Behavior | DS-002 | `default` | 1 | yes | 分组标题 |
| PAGE-008 | Video Quality | Recording Behavior | DS-003 | `default` | 1 | yes | 卡片容器 |
| PAGE-008 | Video Quality | Recording Behavior | DS-013 | `segmented` | 3 | yes | Loop / Start Behavior / Clip Duration |
| PAGE-008 | Video Quality | Audio & Visibility | DS-002 | `default` | 1 | yes | 分组标题 |
| PAGE-008 | Video Quality | Audio & Visibility | DS-003 | `default` | 1 | yes | 卡片容器 |
| PAGE-008 | Video Quality | Audio & Visibility | DS-005 | `switch` | 5 | yes | Audio / HDR / Indicator / Reminder 等 |
| PAGE-008 | Video Quality | Footer | DS-015 | `info` | 1 | yes | Estimated storage per hour |
| PAGE-009 | Watermark Configuration | Nav | DS-001 | `leadingIcon` | 1 | partial | 顶部返回导航 |
| PAGE-009 | Watermark Configuration | Overlay Settings | DS-005 | `switch` | 2 | yes | Timestamp / License Plate |
| PAGE-009 | Watermark Configuration | Overlay Settings | DS-012 | `plain` | 1 | yes | Plate Number |
| PAGE-009 | Watermark Configuration | Footer Action | DS-017 | `primary` | 1 | yes | Save Configuration |
| PAGE-010 | Network Identity | Current Connection | DS-003 | `default` | 1 | yes | 卡片容器 |
| PAGE-010 | Network Identity | Current Connection | DS-016 | `accent` | 1 | yes | CONNECTED 状态徽标 |
| PAGE-010 | Network Identity | Current Connection | DS-011 | `value` | 1 | yes | 当前连接 SSID |
| PAGE-010 | Network Identity | Network Identity | DS-012 | `plain` | 1 | yes | New WiFi Name |
| PAGE-010 | Network Identity | Security Credentials | DS-012 | `secure` | 2 | yes | Password / Security Credentials |
| PAGE-010 | Network Identity | Footer Action | DS-017 | `primary` | 1 | yes | Save Changes |
| PAGE-011 | Device Settings Detail | Nav | DS-001 | `leadingIcon+trailingIcon` | 1 | partial | 顶部返回导航，右上帮助按钮 |
| PAGE-011 | Device Settings Detail | Device Identity | DS-011 | `value+chevron` | 3 | yes | Device Name / Connectivity / Date & Time |
| PAGE-011 | Device Settings Detail | Software | DS-011 | `value` | 1 | yes | Firmware Version |
| PAGE-011 | Device Settings Detail | Localization | DS-011 | `value+chevron` | 1 | yes | Time Zone |
| PAGE-011 | Device Settings Detail | Audio Controls | DS-013 | `segmented` | 1 | yes | Speaker Volume |
| PAGE-011 | Device Settings Detail | Notifications | DS-005 | `switch` | 2 | yes | Event / Status sounds |
| PAGE-012 | Safety | Collision Detection | DS-013 | `segmented` | 1 | yes | G-Sensor Sensitivity |
| PAGE-012 | Safety | Parking Surveillance | DS-005 | `switch` | 3 | yes | Parking / Motion / Impact |
| PAGE-012 | Safety | Event Recording | DS-005 | `switch` | 1 | yes | Emergency Video Lock |
| PAGE-012 | Safety | Footer Notice | DS-015 | `danger` | 1 | yes | Important Notice |
| PAGE-012 | Safety | Footer Actions | DS-018 | `danger` | 2 | yes | Reset Safety Defaults / Factory Reset |
