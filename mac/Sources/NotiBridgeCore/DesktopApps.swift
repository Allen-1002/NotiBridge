import Foundation

/// 手机应用 ↔ 电脑客户端的对照表：电脑上已经开着同一个应用时，不再重复弹手机转发来的通知。
/// Windows 端 DesktopApps.cs 有同样的一份，改这里时两边一起改。
public struct DesktopAppSpec: Equatable, Sendable {
    /// 设置里保存用的稳定标识
    public let key: String
    /// 显示名
    public let name: String
    /// 手机端应用标识：安卓包名、鸿蒙 bundleName、iPhone（经 ESP32）bundle id
    public let phoneIds: [String]
    /// 手机发来的应用名（标识对不上时按名字匹配，例如鸿蒙版包名与安卓不同）
    public let phoneNames: [String]
    /// Mac 客户端的 bundle id
    public let macBundleIds: [String]
    /// Windows 客户端的进程名（不带 .exe）
    public let windowsProcesses: [String]
}

public enum DesktopApps {
    public static let builtIn: [DesktopAppSpec] = [
        DesktopAppSpec(key: "wechat", name: "微信",
                       phoneIds: ["com.tencent.mm", "com.tencent.wechat", "com.tencent.xin"],
                       phoneNames: ["微信", "WeChat"],
                       macBundleIds: ["com.tencent.xinWeChat"],
                       windowsProcesses: ["WeChat", "Weixin"]),
        DesktopAppSpec(key: "qq", name: "QQ",
                       phoneIds: ["com.tencent.mobileqq", "com.tencent.mqq", "com.tencent.qq"],
                       phoneNames: ["QQ"],
                       macBundleIds: ["com.tencent.qq"],
                       windowsProcesses: ["QQ"]),
        DesktopAppSpec(key: "tim", name: "TIM",
                       phoneIds: ["com.tencent.tim"],
                       phoneNames: ["TIM"],
                       macBundleIds: ["com.tencent.tim"],
                       windowsProcesses: ["TIM"]),
        DesktopAppSpec(key: "wework", name: "企业微信",
                       phoneIds: ["com.tencent.wework", "com.tencent.ww"],
                       phoneNames: ["企业微信", "WeCom"],
                       macBundleIds: ["com.tencent.WeWorkMac"],
                       windowsProcesses: ["WXWork"]),
        DesktopAppSpec(key: "dingtalk", name: "钉钉",
                       phoneIds: ["com.alibaba.android.rimet", "com.dingtalk.hmos", "com.laiwang.DingTalk"],
                       phoneNames: ["钉钉", "DingTalk"],
                       macBundleIds: ["com.alibaba.DingTalkMac", "5ZSL2CJU2T.com.dingtalk.mac", "com.dingtalk.mac"],
                       windowsProcesses: ["DingTalk"]),
        DesktopAppSpec(key: "feishu", name: "飞书 / Lark",
                       phoneIds: ["com.ss.android.lark", "com.larksuite.suite", "com.ss.feishu", "com.bytedance.ee.lark"],
                       phoneNames: ["飞书", "Lark"],
                       macBundleIds: ["com.bytedance.macos.feishu", "com.bytedance.macos.lark", "com.electron.lark"],
                       windowsProcesses: ["Feishu", "Lark"]),
        DesktopAppSpec(key: "telegram", name: "Telegram",
                       phoneIds: ["org.telegram.messenger", "org.telegram.messenger.web", "ph.telegra.Telegraph"],
                       phoneNames: ["Telegram"],
                       macBundleIds: ["ru.keepcoder.Telegram", "org.telegram.desktop", "com.tdesktop.Telegram"],
                       windowsProcesses: ["Telegram"]),
        DesktopAppSpec(key: "whatsapp", name: "WhatsApp",
                       phoneIds: ["com.whatsapp", "com.whatsapp.w4b", "net.whatsapp.WhatsApp"],
                       phoneNames: ["WhatsApp"],
                       macBundleIds: ["net.whatsapp.WhatsApp", "desktop.WhatsApp"],
                       windowsProcesses: ["WhatsApp", "WhatsApp.Root"]),
        DesktopAppSpec(key: "slack", name: "Slack",
                       phoneIds: ["com.Slack", "com.tinyspeck.chatlyio"],
                       phoneNames: ["Slack"],
                       macBundleIds: ["com.tinyspeck.slackmacgap"],
                       windowsProcesses: ["slack"]),
        DesktopAppSpec(key: "discord", name: "Discord",
                       phoneIds: ["com.discord", "com.hammerandchisel.discord"],
                       phoneNames: ["Discord"],
                       macBundleIds: ["com.hnc.Discord"],
                       windowsProcesses: ["Discord"]),
        DesktopAppSpec(key: "teams", name: "Microsoft Teams",
                       phoneIds: ["com.microsoft.teams", "com.microsoft.skype.teams"],
                       phoneNames: ["Microsoft Teams", "Teams"],
                       macBundleIds: ["com.microsoft.teams2", "com.microsoft.teams"],
                       windowsProcesses: ["ms-teams", "Teams"]),
    ]

    /// 按手机端标识（优先）或应用名找到对应的电脑客户端；大小写不敏感
    public static func match(bundleName: String, appName: String,
                             in apps: [DesktopAppSpec] = builtIn) -> DesktopAppSpec? {
        let id = bundleName.trimmingCharacters(in: .whitespaces).lowercased()
        if !id.isEmpty, let a = apps.first(where: { $0.phoneIds.contains { $0.lowercased() == id } }) {
            return a
        }
        let name = appName.trimmingCharacters(in: .whitespaces).lowercased()
        guard !name.isEmpty else { return nil }
        return apps.first { $0.phoneNames.contains { $0.lowercased() == name } }
    }
}

/// “电脑上已打开同一应用时不重复提醒”的设置（只存在电脑上，不同步给手机）
public struct DesktopDuplicateSettings: Codable, Equatable, Sendable {
    /// 总开关
    public var enabled: Bool = true
    /// 单独关掉的应用（DesktopAppSpec.key）。记关掉的，新加入对照表的应用默认就是开着的
    public var disabledApps: Set<String> = []

    public init(enabled: Bool = true, disabledApps: Set<String> = []) {
        self.enabled = enabled
        self.disabledApps = disabledApps
    }

    public func isOn(_ key: String) -> Bool { !disabledApps.contains(key) }

    public mutating func set(_ key: String, on: Bool) {
        if on { disabledApps.remove(key) } else { disabledApps.insert(key) }
    }

    /// 这条通知是否因为电脑上已开着同一应用而不弹出；返回对应的应用
    public func suppressingApp(bundleName: String, appName: String,
                               isRunning: (DesktopAppSpec) -> Bool) -> DesktopAppSpec? {
        guard enabled, let app = DesktopApps.match(bundleName: bundleName, appName: appName),
              isOn(app.key), isRunning(app) else { return nil }
        return app
    }

    /// Mac：给定正在运行的 bundle id，判断该应用的 Mac 客户端是否开着
    public static func isRunningOnMac(_ app: DesktopAppSpec, runningBundleIds: Set<String>) -> Bool {
        app.macBundleIds.contains { runningBundleIds.contains($0.lowercased()) }
    }
}
