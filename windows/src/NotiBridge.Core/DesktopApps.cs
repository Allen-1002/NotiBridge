namespace NotiBridge.Core;

/// <summary>
/// 手机应用 ↔ 电脑客户端的对照表：电脑上已经开着同一个应用时，不再重复弹手机转发来的通知。
/// 与 Mac 端 DesktopApps.swift 是同一份（Mac 的单元测试会核对两边一致），改这里时两边一起改。
/// </summary>
/// <param name="Key">设置里保存用的稳定标识</param>
/// <param name="Name">显示名</param>
/// <param name="PhoneIds">手机端应用标识：安卓包名、鸿蒙 bundleName、iPhone（经 ESP32）bundle id</param>
/// <param name="PhoneNames">手机发来的应用名（标识对不上时按名字匹配）</param>
/// <param name="MacBundleIds">Mac 客户端的 bundle id</param>
/// <param name="WindowsProcesses">Windows 客户端的进程名（不带 .exe）</param>
public sealed record DesktopAppSpec(
    string Key, string Name, string[] PhoneIds, string[] PhoneNames, string[] MacBundleIds, string[] WindowsProcesses);

public static class DesktopApps
{
    public static readonly DesktopAppSpec[] BuiltIn =
    [
        new("wechat", "微信",
            ["com.tencent.mm", "com.tencent.wechat", "com.tencent.xin"],
            ["微信", "WeChat"],
            ["com.tencent.xinWeChat"],
            ["WeChat", "Weixin"]),
        new("qq", "QQ",
            ["com.tencent.mobileqq", "com.tencent.mqq", "com.tencent.qq"],
            ["QQ"],
            ["com.tencent.qq"],
            ["QQ"]),
        new("tim", "TIM",
            ["com.tencent.tim"],
            ["TIM"],
            ["com.tencent.tim"],
            ["TIM"]),
        new("wework", "企业微信",
            ["com.tencent.wework", "com.tencent.ww"],
            ["企业微信", "WeCom"],
            ["com.tencent.WeWorkMac"],
            ["WXWork"]),
        new("dingtalk", "钉钉",
            ["com.alibaba.android.rimet", "com.dingtalk.hmos", "com.laiwang.DingTalk"],
            ["钉钉", "DingTalk"],
            ["com.alibaba.DingTalkMac", "5ZSL2CJU2T.com.dingtalk.mac", "com.dingtalk.mac"],
            ["DingTalk"]),
        new("feishu", "飞书 / Lark",
            ["com.ss.android.lark", "com.larksuite.suite", "com.ss.feishu", "com.bytedance.ee.lark"],
            ["飞书", "Lark"],
            ["com.bytedance.macos.feishu", "com.bytedance.macos.lark", "com.electron.lark"],
            ["Feishu", "Lark"]),
        new("telegram", "Telegram",
            ["org.telegram.messenger", "org.telegram.messenger.web", "ph.telegra.Telegraph"],
            ["Telegram"],
            ["ru.keepcoder.Telegram", "org.telegram.desktop", "com.tdesktop.Telegram"],
            ["Telegram"]),
        new("whatsapp", "WhatsApp",
            ["com.whatsapp", "com.whatsapp.w4b", "net.whatsapp.WhatsApp"],
            ["WhatsApp"],
            ["net.whatsapp.WhatsApp", "desktop.WhatsApp"],
            ["WhatsApp", "WhatsApp.Root"]),
        new("slack", "Slack",
            ["com.Slack", "com.tinyspeck.chatlyio"],
            ["Slack"],
            ["com.tinyspeck.slackmacgap"],
            ["slack"]),
        new("discord", "Discord",
            ["com.discord", "com.hammerandchisel.discord"],
            ["Discord"],
            ["com.hnc.Discord"],
            ["Discord"]),
        new("teams", "Microsoft Teams",
            ["com.microsoft.teams", "com.microsoft.skype.teams"],
            ["Microsoft Teams", "Teams"],
            ["com.microsoft.teams2", "com.microsoft.teams"],
            ["ms-teams", "Teams"]),
    ];

    /// <summary>按手机端标识（优先）或应用名找到对应的电脑客户端；大小写不敏感。</summary>
    public static DesktopAppSpec? Match(string? bundleName, string? appName, IReadOnlyList<DesktopAppSpec>? apps = null)
    {
        apps ??= BuiltIn;
        var id = (bundleName ?? "").Trim();
        if (id.Length > 0)
        {
            var byId = apps.FirstOrDefault(a => a.PhoneIds.Any(p => string.Equals(p, id, StringComparison.OrdinalIgnoreCase)));
            if (byId != null) return byId;
        }
        var name = (appName ?? "").Trim();
        if (name.Length == 0) return null;
        return apps.FirstOrDefault(a => a.PhoneNames.Any(p => string.Equals(p, name, StringComparison.OrdinalIgnoreCase)));
    }
}

/// <summary>“电脑上已打开同一应用时不重复提醒”的设置（只存在电脑上，不同步给手机）。</summary>
public sealed class DesktopDuplicateSettings
{
    /// <summary>总开关</summary>
    public bool Enabled { get; set; } = true;

    /// <summary>单独关掉的应用（DesktopAppSpec.Key）。记关掉的，新加入对照表的应用默认就是开着的。</summary>
    public HashSet<string> DisabledApps { get; set; } = [];

    public bool IsOn(string key) => !DisabledApps.Contains(key);

    public void Set(string key, bool on)
    {
        if (on) DisabledApps.Remove(key);
        else DisabledApps.Add(key);
    }

    /// <summary>这条通知是否因为电脑上已开着同一应用而不弹出；返回对应的应用，null 表示照常弹。</summary>
    public DesktopAppSpec? SuppressingApp(string? bundleName, string? appName, Func<DesktopAppSpec, bool> isRunning)
    {
        if (!Enabled) return null;
        var app = DesktopApps.Match(bundleName, appName);
        if (app == null || !IsOn(app.Key) || !isRunning(app)) return null;
        return app;
    }

    /// <summary>Windows：给定正在运行的进程名（不带 .exe），判断该应用的客户端是否开着。</summary>
    public static bool IsRunningOnWindows(DesktopAppSpec app, ISet<string> runningProcessNames) =>
        app.WindowsProcesses.Any(p => runningProcessNames.Contains(p) || runningProcessNames.Contains(p.ToLowerInvariant()));
}
