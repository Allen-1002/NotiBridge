import XCTest
@testable import NotiBridgeCore

final class DesktopAppsTests: XCTestCase {
    func testMatchByAndroidHarmonyAndIphoneIds() {
        XCTAssertEqual(DesktopApps.match(bundleName: "com.tencent.mm", appName: "")?.key, "wechat")
        XCTAssertEqual(DesktopApps.match(bundleName: "com.tencent.wechat", appName: "")?.key, "wechat")
        XCTAssertEqual(DesktopApps.match(bundleName: "com.tencent.xin", appName: "")?.key, "wechat")
        XCTAssertEqual(DesktopApps.match(bundleName: "com.tencent.mobileqq", appName: "")?.key, "qq")
        XCTAssertEqual(DesktopApps.match(bundleName: "com.alibaba.android.rimet", appName: "")?.key, "dingtalk")
        XCTAssertEqual(DesktopApps.match(bundleName: "org.telegram.messenger", appName: "")?.key, "telegram")
        // 大小写不敏感
        XCTAssertEqual(DesktopApps.match(bundleName: "COM.SLACK", appName: "")?.key, "slack")
    }

    func testFallbackToAppName() {
        // 未收录的包名（比如鸿蒙版换了包名）按应用名匹配
        XCTAssertEqual(DesktopApps.match(bundleName: "com.example.unknown", appName: "微信")?.key, "wechat")
        XCTAssertEqual(DesktopApps.match(bundleName: "", appName: " 钉钉 ")?.key, "dingtalk")
        XCTAssertEqual(DesktopApps.match(bundleName: "x", appName: "lark")?.key, "feishu")
        // 名字只做完全匹配：QQ 音乐不是 QQ
        XCTAssertNil(DesktopApps.match(bundleName: "com.tencent.qqmusic", appName: "QQ音乐"))
        XCTAssertNil(DesktopApps.match(bundleName: "com.ohos.mms", appName: "信息"))
        XCTAssertNil(DesktopApps.match(bundleName: "", appName: ""))
    }

    func testIdWinsOverName() {
        // 包名明确是 QQ，即使应用名写成“微信”也按包名
        XCTAssertEqual(DesktopApps.match(bundleName: "com.tencent.mobileqq", appName: "微信")?.key, "qq")
    }

    func testTableIsConsistent() {
        let keys = DesktopApps.builtIn.map(\.key)
        XCTAssertEqual(Set(keys).count, keys.count, "key 不能重复")
        var seen: [String: String] = [:]
        for a in DesktopApps.builtIn {
            XCTAssertFalse(a.phoneIds.isEmpty, a.key)
            XCTAssertFalse(a.macBundleIds.isEmpty, a.key)
            XCTAssertFalse(a.windowsProcesses.isEmpty, a.key)
            for id in a.phoneIds {
                XCTAssertNil(seen[id.lowercased()], "\(id) 同时出现在 \(seen[id.lowercased()] ?? "") 和 \(a.key)")
                seen[id.lowercased()] = a.key
            }
            for p in a.windowsProcesses { XCTAssertFalse(p.lowercased().hasSuffix(".exe"), p) }
        }
    }

    func testSettingsDecision() {
        var s = DesktopDuplicateSettings()
        let running: Set<String> = ["com.tencent.xinwechat"]
        let isRunning = { (a: DesktopAppSpec) in DesktopDuplicateSettings.isRunningOnMac(a, runningBundleIds: running) }

        // 默认开：微信电脑版开着 → 不弹
        XCTAssertEqual(s.suppressingApp(bundleName: "com.tencent.mm", appName: "微信", isRunning: isRunning)?.key, "wechat")
        // QQ 电脑版没开 → 照常弹
        XCTAssertNil(s.suppressingApp(bundleName: "com.tencent.mobileqq", appName: "QQ", isRunning: isRunning))
        // 不在对照表 → 照常弹
        XCTAssertNil(s.suppressingApp(bundleName: "com.ohos.mms", appName: "信息", isRunning: { _ in true }))

        // 单独关掉微信
        s.set("wechat", on: false)
        XCTAssertFalse(s.isOn("wechat"))
        XCTAssertNil(s.suppressingApp(bundleName: "com.tencent.mm", appName: "微信", isRunning: isRunning))
        s.set("wechat", on: true)
        XCTAssertNotNil(s.suppressingApp(bundleName: "com.tencent.mm", appName: "微信", isRunning: isRunning))

        // 总开关关掉
        s.enabled = false
        XCTAssertNil(s.suppressingApp(bundleName: "com.tencent.mm", appName: "微信", isRunning: isRunning))
    }

    func testSettingsCodableAndDefaults() throws {
        let fresh = try JSONDecoder().decode(DesktopDuplicateSettings.self,
                                             from: JSONEncoder().encode(DesktopDuplicateSettings()))
        XCTAssertTrue(fresh.enabled)
        XCTAssertTrue(DesktopApps.builtIn.allSatisfy { fresh.isOn($0.key) })
        var s = DesktopDuplicateSettings()
        s.set("qq", on: false)
        let back = try JSONDecoder().decode(DesktopDuplicateSettings.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back, s)
    }

    func testMacRunningCheck() {
        let dingtalk = DesktopApps.builtIn.first { $0.key == "dingtalk" }!
        XCTAssertTrue(DesktopDuplicateSettings.isRunningOnMac(dingtalk, runningBundleIds: ["5zsl2cju2t.com.dingtalk.mac"]))
        XCTAssertFalse(DesktopDuplicateSettings.isRunningOnMac(dingtalk, runningBundleIds: ["com.tencent.qq"]))
    }

    /// Mac 和 Windows 两份对照表要一致：逐项核对 Windows 端 DesktopApps.cs 里有同样的 key 和标识
    func testMatchesWindowsTable() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("windows/src/NotiBridge.Core/DesktopApps.cs")
        guard let cs = try? String(contentsOf: url, encoding: .utf8) else {
            throw XCTSkip("没找到 \(url.path)")
        }
        for a in DesktopApps.builtIn {
            XCTAssertTrue(cs.contains("\"\(a.key)\""), "Windows 缺少 \(a.key)")
            for s in a.phoneIds + a.phoneNames + a.windowsProcesses {
                XCTAssertTrue(cs.contains("\"\(s)\""), "Windows 表里缺少 \(a.key) 的 \(s)")
            }
        }
    }
}
