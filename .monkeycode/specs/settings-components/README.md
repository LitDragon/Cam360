# 开关设置组件记录

来源：`/Users/naxclow/Cam360/UI/开关设置/总和.png`

## 组件表

| component_id | name | base_component | variant | props / slots | reused_pages | status | notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| DS-001 | AppTopBar | `AppTopBar` | `default`, `leadingIcon`, `eyebrow` | `title`, `eyebrow`, `subtitle`, `leadingSystemImage`, `leadingAction`, `trailing*` | More, Notification Settings, Help Center, System Permissions | built | 已扩展支持返回图标和眉题 |
| DS-002 | SettingsSectionHeader | `SettingsSectionHeader` | `default` | `title` | More, Notification Settings, Help Center | built | Section 外层标题 |
| DS-003 | SettingsGroupCard | `SettingsGroupCard` | `default` | `content` | More, Notification Settings, Help Center, System Permissions | built | 分组卡片容器 |
| DS-004 | SettingsNavigationRow | `SettingsNavigationRow` | `chevron`, `externalLink` | `iconName`, `title`, `subtitle`, `trailingSystemImage`, `action`, `showsDivider` | More, Help Center | built | 导航型列表项 |
| DS-005 | SettingsToggleRow | `SettingsToggleRow` | `switch` | `iconName`, `title`, `subtitle`, `isOn`, `showsDivider` | More, Notification Settings | built | 开关型列表项 |
| DS-006 | SettingsStatusRow | `SettingsStatusRow` | `text`, `text+icon` | `iconName`, `title`, `subtitle`, `statusText`, `trailingSystemImage`, `statusColor`, `showsDivider` | More, System Permissions | built | 状态展示型列表项 |
| DS-007 | SettingsActionRow | `SettingsActionRow` | `pillButton` | `iconName`, `title`, `subtitle`, `actionTitle`, `action`, `showsDivider` | System Permissions | built | 行内操作按钮 |
| DS-008 | SettingsSearchBar | `SettingsSearchBar` | `default` | `text`, `placeholder` | Help Center | built | 搜索框 |
| DS-009 | SettingsTimeField | `SettingsTimeField` | `default` | `title`, `value` | Notification Settings | built | 时间输入框 |
| DS-010 | SettingsFootnote | `SettingsFootnote` | `info` | `text`, `iconName` | Notification Settings, Help Center, System Permissions | built | 页脚说明 / 提示文案 |

## 页面关系表

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
