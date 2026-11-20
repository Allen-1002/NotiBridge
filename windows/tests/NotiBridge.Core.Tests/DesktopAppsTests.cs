using System.Text.Json;
using NotiBridge.Core;
using Xunit;

namespace NotiBridge.Core.Tests;

public class DesktopAppsTests
{
    [Theory]
    [InlineData("com.tencent.mm", "wechat")]
    [InlineData("com.tencent.wechat", "wechat")]
    [InlineData("com.tencent.xin", "wechat")]
    [InlineData("com.tencent.mobileqq", "qq")]
    [InlineData("com.alibaba.android.rimet", "dingtalk")]
    [InlineData("com.ss.android.lark", "feishu")]
    [InlineData("org.telegram.messenger", "telegram")]
    [InlineData("COM.SLACK", "slack")]
    public void MatchById(string id, string key) => Assert.Equal(key, DesktopApps.Match(id, "")?.Key);

    [Fact]
    public void FallbackToAppName()
    {
        Assert.Equal("wechat", DesktopApps.Match("com.example.unknown", "微信")?.Key);
        Assert.Equal("dingtalk", DesktopApps.Match(null, " 钉钉 ")?.Key);
        Assert.Null(DesktopApps.Match("com.tencent.qqmusic", "QQ音乐"));
        Assert.Null(DesktopApps.Match("com.ohos.mms", "信息"));
        Assert.Null(DesktopApps.Match("", ""));
        // 包名优先于名字
        Assert.Equal("qq", DesktopApps.Match("com.tencent.mobileqq", "微信")?.Key);
    }

    [Fact]
    public void TableIsConsistent()
    {
        Assert.Equal(DesktopApps.BuiltIn.Length, DesktopApps.BuiltIn.Select(a => a.Key).Distinct().Count());
        var ids = DesktopApps.BuiltIn.SelectMany(a => a.PhoneIds).Select(s => s.ToLowerInvariant()).ToList();
        Assert.Equal(ids.Count, ids.Distinct().Count());
        Assert.All(DesktopApps.BuiltIn, a =>
        {
            Assert.NotEmpty(a.WindowsProcesses);
            Assert.All(a.WindowsProcesses, p => Assert.False(p.EndsWith(".exe", StringComparison.OrdinalIgnoreCase)));
        });
    }

    [Fact]
    public void SettingsDecision()
    {
        var s = new DesktopDuplicateSettings();
        var running = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "Weixin" };
        bool IsRunning(DesktopAppSpec a) => DesktopDuplicateSettings.IsRunningOnWindows(a, running);

        Assert.Equal("wechat", s.SuppressingApp("com.tencent.mm", "微信", IsRunning)?.Key);
        Assert.Null(s.SuppressingApp("com.tencent.mobileqq", "QQ", IsRunning));
        Assert.Null(s.SuppressingApp("com.ohos.mms", "信息", _ => true));

        s.Set("wechat", false);
        Assert.False(s.IsOn("wechat"));
        Assert.Null(s.SuppressingApp("com.tencent.mm", "微信", IsRunning));
        s.Set("wechat", true);
        Assert.NotNull(s.SuppressingApp("com.tencent.mm", "微信", IsRunning));

        s.Enabled = false;
        Assert.Null(s.SuppressingApp("com.tencent.mm", "微信", IsRunning));
    }

    [Fact]
    public void ProcessNameCaseInsensitive()
    {
        var slack = DesktopApps.BuiltIn.First(a => a.Key == "slack");
        Assert.True(DesktopDuplicateSettings.IsRunningOnWindows(slack, new HashSet<string> { "slack" }));
        var wechat = DesktopApps.BuiltIn.First(a => a.Key == "wechat");
        Assert.True(DesktopDuplicateSettings.IsRunningOnWindows(wechat, new HashSet<string> { "wechat" }));
        Assert.False(DesktopDuplicateSettings.IsRunningOnWindows(wechat, new HashSet<string> { "QQ" }));
    }

    [Fact]
    public void SettingsJsonRoundTrip()
    {
        var s = new DesktopDuplicateSettings();
        s.Set("qq", false);
        var back = JsonSerializer.Deserialize<DesktopDuplicateSettings>(JsonSerializer.Serialize(s))!;
        Assert.True(back.Enabled);
        Assert.False(back.IsOn("qq"));
        Assert.True(back.IsOn("wechat"));
        // 旧设置文件里没有这一项：默认开
        var empty = JsonSerializer.Deserialize<DesktopDuplicateSettings>("{}")!;
        Assert.True(empty.Enabled);
        Assert.All(DesktopApps.BuiltIn, a => Assert.True(empty.IsOn(a.Key)));
    }
}
