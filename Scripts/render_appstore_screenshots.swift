#!/usr/bin/env swift
import AppKit
import Foundation

// ==============================================================================
// NetDoctor — Headless App Store Screenshot Renderer
// Renders 2880x1800 store screenshots (zh + en) entirely with CoreGraphics.
// All network data below is fictional and anonymized (Home-WiFi, 192.168.1.x).
// ==============================================================================

let W: CGFloat = 2880
let H: CGFloat = 1800

var g: CGContext!
var dict: [String: String] = [:]
func L(_ k: String) -> String { dict[k] ?? k }

// MARK: - Palette
let cGreen  = NSColor(calibratedRed: 0.24, green: 0.86, blue: 0.48, alpha: 1)
let cOrange = NSColor(calibratedRed: 1.00, green: 0.62, blue: 0.16, alpha: 1)
let cRed    = NSColor(calibratedRed: 1.00, green: 0.35, blue: 0.35, alpha: 1)
let cBlue   = NSColor(calibratedRed: 0.38, green: 0.66, blue: 1.00, alpha: 1)
let cGold   = NSColor(calibratedRed: 1.00, green: 0.82, blue: 0.18, alpha: 1)
let cSub    = NSColor.white.withAlphaComponent(0.64)
let cFaint  = NSColor.white.withAlphaComponent(0.40)
let windowBG = NSColor(calibratedRed: 0.105, green: 0.115, blue: 0.160, alpha: 1)
let cardBG   = NSColor.white.withAlphaComponent(0.055)
let accentBtn = NSColor(calibratedRed: 0.24, green: 0.52, blue: 0.98, alpha: 1)

// MARK: - Text helpers
func font(_ size: CGFloat, _ weight: NSFont.Weight, mono: Bool = false) -> NSFont {
    mono ? NSFont.monospacedSystemFont(ofSize: size, weight: weight)
         : NSFont.systemFont(ofSize: size, weight: weight)
}
func measure(_ s: String, size: CGFloat, weight: NSFont.Weight = .regular, mono: Bool = false) -> CGSize {
    (s as NSString).size(withAttributes: [.font: font(size, weight, mono: mono)])
}
@discardableResult
func text(_ s: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat,
          _ weight: NSFont.Weight = .regular, _ color: NSColor = .white, mono: Bool = false) -> CGSize {
    let a = NSAttributedString(string: s, attributes: [.font: font(size, weight, mono: mono), .foregroundColor: color])
    a.draw(at: CGPoint(x: x, y: y))
    return a.size()
}
func textCentered(_ s: String, _ cx: CGFloat, _ y: CGFloat, _ size: CGFloat,
                  _ weight: NSFont.Weight, _ color: NSColor) {
    let w = measure(s, size: size, weight: weight).width
    text(s, cx - w / 2, y, size, weight, color)
}
func textRight(_ s: String, _ xr: CGFloat, _ y: CGFloat, _ size: CGFloat,
               _ weight: NSFont.Weight = .regular, _ color: NSColor = .white, mono: Bool = false) {
    let w = measure(s, size: size, weight: weight, mono: mono).width
    text(s, xr - w, y, size, weight, color, mono: mono)
}
@discardableResult
func wrapText(_ s: String, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ size: CGFloat,
              _ weight: NSFont.Weight = .regular, _ color: NSColor = cSub) -> CGFloat {
    let a = NSAttributedString(string: s, attributes: [.font: font(size, weight), .foregroundColor: color])
    a.draw(in: CGRect(x: x, y: y, width: width, height: 3000))
    return a.boundingRect(with: CGSize(width: width, height: 3000),
                          options: [.usesLineFragmentOrigin, .usesFontLeading]).height
}

// MARK: - Shape helpers
func rrect(_ r: CGRect, _ rad: CGFloat, _ fill: NSColor, stroke: NSColor? = nil, lineW: CGFloat = 2) {
    let p = CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)
    g.saveGState()
    g.setFillColor(fill.cgColor)
    g.addPath(p); g.fillPath()
    if let st = stroke {
        g.setStrokeColor(st.cgColor); g.setLineWidth(lineW); g.addPath(p); g.strokePath()
    }
    g.restoreGState()
}
func gradientRRect(_ r: CGRect, _ rad: CGFloat, _ colors: [NSColor], vertical: Bool = false) {
    let p = CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)
    g.saveGState()
    g.addPath(p); g.clip()
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: colors.map { $0.cgColor } as CFArray, locations: nil)!
    g.drawLinearGradient(grad,
                         start: CGPoint(x: r.minX, y: r.minY),
                         end: vertical ? CGPoint(x: r.minX, y: r.maxY) : CGPoint(x: r.maxX, y: r.maxY),
                         options: [])
    g.restoreGState()
}
func divider(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat) {
    g.setFillColor(NSColor.white.withAlphaComponent(0.09).cgColor)
    g.fill(CGRect(x: x, y: y, width: w, height: 2))
}
func circle(_ cx: CGFloat, _ cy: CGFloat, _ d: CGFloat, _ color: NSColor) {
    g.setFillColor(color.cgColor)
    g.fillEllipse(in: CGRect(x: cx - d / 2, y: cy - d / 2, width: d, height: d))
}
func tintedImage(_ image: NSImage, _ color: NSColor) -> NSImage {
    let copy = image.copy() as! NSImage
    copy.isTemplate = false
    copy.lockFocus()
    color.set()
    CGRect(origin: .zero, size: copy.size).fill(using: .sourceAtop)
    copy.unlockFocus()
    return copy
}
func sym(_ name: String, _ cx: CGFloat, _ cy: CGFloat, _ size: CGFloat, _ color: NSColor) {
    guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return }
    let conf = NSImage.SymbolConfiguration(pointSize: size, weight: .semibold)
    let configured = base.withSymbolConfiguration(conf) ?? base
    let img = tintedImage(configured, color)
    let s = img.size
    img.draw(in: CGRect(x: cx - s.width / 2, y: cy - s.height / 2, width: s.width, height: s.height),
             from: .zero, operation: .sourceOver, fraction: 1)
}
func capsuleWidth(_ s: String, _ size: CGFloat, icon: String? = nil) -> CGFloat {
    let th = measure(s, size: size, weight: .semibold)
    let iw: CGFloat = icon != nil ? size * 1.35 : 0
    return th.width + iw + size * 1.7
}
@discardableResult
func capsule(_ s: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat,
             _ color: NSColor, icon: String? = nil, filled: Bool = false) -> CGFloat {
    let th = measure(s, size: size, weight: .semibold)
    let h = size * 1.9
    let iw: CGFloat = icon != nil ? size * 1.35 : 0
    let w = th.width + iw + size * 1.7
    rrect(CGRect(x: x, y: y, width: w, height: h), h / 2,
          filled ? color : color.withAlphaComponent(0.16))
    var tx = x + size * 0.85
    let fg: NSColor = filled ? .white : color
    if let ic = icon {
        let icx = x + size * 0.85 + iw / 2 - size * 0.12
        let icy = y + h / 2
        sym(ic, icx, icy, size * 1.05, fg)
        tx += iw
    }
    text(s, tx, y + (h - th.height) / 2, size, .semibold, fg)
    return w
}
@discardableResult
func button(_ s: String, _ x: CGFloat, _ y: CGFloat, primary: Bool) -> CGFloat {
    let h: CGFloat = 60
    let th = measure(s, size: 30, weight: .semibold)
    let w = th.width + 68
    if primary {
        rrect(CGRect(x: x, y: y, width: w, height: h), 15, accentBtn)
        text(s, x + 34, y + (h - th.height) / 2, 30, .semibold, .white)
    } else {
        rrect(CGRect(x: x, y: y, width: w, height: h), 15,
              NSColor.white.withAlphaComponent(0.08), stroke: NSColor.white.withAlphaComponent(0.16))
        text(s, x + 34, y + (h - th.height) / 2, 30, .semibold, NSColor.white.withAlphaComponent(0.9))
    }
    return w
}

// MARK: - Canvas scaffolding
func background(accent: NSColor) {
    let cs = CGColorSpaceCreateDeviceRGB()
    let grad = CGGradient(colorsSpace: cs, colors: [
        NSColor(calibratedRed: 0.055, green: 0.072, blue: 0.128, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.020, green: 0.030, blue: 0.056, alpha: 1).cgColor
    ] as CFArray, locations: [0, 1])!
    g.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: H), options: [])
    let glow = CGGradient(colorsSpace: cs, colors: [
        accent.withAlphaComponent(0.17).cgColor,
        accent.withAlphaComponent(0).cgColor
    ] as CFArray, locations: [0, 1])!
    g.drawRadialGradient(glow, startCenter: CGPoint(x: W / 2, y: 1080), startRadius: 80,
                         endCenter: CGPoint(x: W / 2, y: 1080), endRadius: 1550,
                         options: [.drawsBeforeStartLocation])
}
func header(_ title: String, _ sub: String) {
    textCentered(title, W / 2, 74, 102, .heavy, .white)
    textCentered(sub, W / 2, 208, 46, .medium, cSub)
}
func windowChrome(_ r: CGRect, _ title: String) {
    g.saveGState()
    g.setShadow(offset: CGSize(width: 0, height: -26), blur: 80,
                color: NSColor.black.withAlphaComponent(0.65).cgColor)
    rrect(r, 30, windowBG, stroke: NSColor.white.withAlphaComponent(0.12), lineW: 2)
    g.restoreGState()
    let cols = [NSColor(calibratedRed: 1, green: 0.38, blue: 0.35, alpha: 1),
                NSColor(calibratedRed: 1, green: 0.74, blue: 0.28, alpha: 1),
                NSColor(calibratedRed: 0.18, green: 0.79, blue: 0.25, alpha: 1)]
    for i in 0..<3 {
        circle(r.minX + 50 + CGFloat(i) * 42, r.minY + 44, 26, cols[i])
    }
    textCentered(title, r.midX, r.minY + 28, 32, .semibold, cSub)
}
func tabBar(_ r: CGRect, _ active: Int) -> CGFloat {
    let names = L("tabs").split(separator: "|").map(String.init)
    let icons = ["gauge.with.dots.needle.50percent", "network",
                 "point.3.filled.connected.trianglepath.dotted", "globe", "clock", "gearshape"]
    var x = r.minX + 48
    let y = r.minY + 100
    let h: CGFloat = 66
    for (i, name) in names.enumerated() {
        let tw = measure(name, size: 30, weight: .medium).width
        let w = tw + 44 + 40
        let on = i == active
        if on { rrect(CGRect(x: x, y: y, width: w, height: h), h / 2, cBlue.withAlphaComponent(0.22)) }
        let col = on ? cBlue : cFaint
        sym(icons[i], x + 30, y + h / 2, 27, col)
        text(name, x + 56, y + (h - 36) / 2 - 2, 30, on ? .semibold : .regular, col)
        x += w + 18
    }
    return y + h + 8
}
func appIconMark(_ r: CGRect) {
    gradientRRect(r, r.width * 0.26, [
        NSColor(calibratedRed: 0.20, green: 0.78, blue: 0.46, alpha: 1),
        NSColor(calibratedRed: 0.10, green: 0.55, blue: 0.62, alpha: 1)
    ])
    sym("waveform.path.ecg", r.midX, r.midY, r.width * 0.52, .white)
}

// MARK: - Localized strings
var zhDict: [String: String] = [
    "s1t": "菜单栏轻量常驻", "s1s": "网络好坏，抬头一眼便知",
    "s2t": "全球节点真实延迟", "s2s": "多端点并发采样，Ping 与丢包一清二楚",
    "s3t": "小白也能懂的排查建议", "s3s": "告别黑底白字终端，智能定位网络故障",
    "s4t": "接口与路由全景透视", "s4s": "Wi-Fi 信号、网关与 DNS 深度解析",
    "s5t": "100% 隐私 · 零系统入侵", "s5s": "免 Root 权限，无后台守护，数据绝不上传",
    "time": "上午 9:41",
    "healthy": "健康", "warning": "警告",
    "sum.ok": "网络状态正常，互联网连通性检测通过。",
    "sum.warn": "网络可用，但存在需要关注的信号。",
    "q.path": "路径", "q.if": "活动接口", "q.dns": "DNS", "q.net": "互联网",
    "v.ok": "可用", "dns1": "223.5.5.5", "dns2": "119.29.29.29", "v.net": "3/3 成功",
    "adv.ok.t": "网络状态正常",
    "adv.ok.m": "当前没有发现需要处理的问题。若仍有网页打不开，可检查具体网站是否单独不可用。",
    "b.check": "立即检查", "b.detail": "打开详情", "b.export": "导出支持包",
    "ver": "版本 1.1 (4) · Kevin Labs",
    "win.title": "NetDoctor 网络体检",
    "tabs": "概览|网络接口|DNS 与路由|互联网连通性|时间线|设置",
    "reach.note": "延迟和丢包为应用层近似 · 每端点并发采样 4 次",
    "loss": "丢包", "succ": "4/4 成功",
    "ov.title": "网络体检",
    "m.path": "网络路径", "m.path.d": "Network.framework 路径",
    "m.if": "活动接口", "m.if.d": "en0, en8",
    "m.dns": "DNS 服务器",
    "m.net": "互联网连通性", "m.net.v": "2/3", "m.net.d": "延迟和丢包为应用层近似",
    "adv.h": "排查建议",
    "adv1.t": "延迟偏高",
    "adv1.m": "P90 延迟超过 800 ms。建议暂停大流量下载或备份，优先使用 5 GHz Wi-Fi 或有线连接。",
    "adv2.t": "部分外网站点不可达",
    "adv2.m": "部分公开端点失败，可能只是该站点被网络策略拦截或服务端异常。请优先看 Apple、Cloudflare 等主端点是否成功。",
    "if.h": "网络接口", "dr.h": "DNS 与路由",
    "wifi": "Wi-Fi", "wired": "有线", "up": "已连接", "down": "未连接",
    "defroute": "默认路由接口", "noaddr": "无 IPv4/IPv6 地址",
    "dns.h": "DNS 解析器", "src": "来源", "src.v": "系统配置",
    "rt.h": "默认路由", "dst": "目标", "gw": "网关", "if.l": "接口",
    "set.t": "设置",
    "bdg1": "只读诊断", "bdg2": "沙盒运行", "bdg3": "免 Root", "bdg4": "零埋点",
    "priv.h": "隐私",
    "priv1": "诊断数据只保存在本机，不会自动上传。",
    "priv2": "支持包导出会脱敏 Wi-Fi SSID，不包含用户名、路径、Cookie 或密钥。",
    "kl.h": "更多来自 Kevin Labs",
    "volmix.d": "Mac 单应用音量独立控制 · 免驱动原生音频管理",
    "ksic.d": "轻量级 macOS 菜单栏工作台与快捷启动器",
    "view": "在 App Store 查看"
]
var enDict: [String: String] = [
    "s1t": "Lives in Your Menu Bar", "s1s": "Network health at a glance, anytime",
    "s2t": "Real Latency on Global Endpoints", "s2s": "Concurrent multi-endpoint sampling — ping and loss at a glance",
    "s3t": "Troubleshooting Anyone Understands", "s3s": "No terminal jargon — smart, plain-language root-cause hints",
    "s4t": "Interfaces & Routes in Full View", "s4s": "Wi-Fi signal, gateway and DNS, deeply inspected",
    "s5t": "100% Private. Zero Intrusion.", "s5s": "No root, no daemons — your data never leaves this Mac",
    "time": "9:41 AM",
    "healthy": "Healthy", "warning": "Warning",
    "sum.ok": "Your network is healthy and internet probes are working.",
    "sum.warn": "Your network is available, but some checks need attention.",
    "q.path": "Path", "q.if": "Active Interfaces", "q.dns": "DNS", "q.net": "Internet",
    "v.ok": "Available", "dns1": "1.1.1.1", "dns2": "8.8.8.8", "v.net": "3/3 succeeded",
    "adv.ok.t": "Your network looks healthy",
    "adv.ok.m": "No issue was found. If a specific website still fails, check whether that site is unavailable by itself.",
    "b.check": "Check Now", "b.detail": "Open Details", "b.export": "Export Support",
    "ver": "Version 1.1 (4) · Kevin Labs",
    "win.title": "NetDoctor Diagnostics",
    "tabs": "Overview|Interfaces|DNS & Route|Internet Connectivity|Timeline|Settings",
    "reach.note": "Latency and loss are app-level approximations · 4 concurrent samples per endpoint",
    "loss": "Loss", "succ": "4/4 succeeded",
    "ov.title": "Network Health",
    "m.path": "Network Path", "m.path.d": "Network.framework path",
    "m.if": "Active Interfaces", "m.if.d": "en0, en8",
    "m.dns": "DNS Servers",
    "m.net": "Internet Connectivity", "m.net.v": "2/3", "m.net.d": "Latency and loss are app-level approximations",
    "adv.h": "What to Check Next",
    "adv1.t": "Latency is high",
    "adv1.m": "P90 latency is above 800 ms. Pause large downloads or backups and prefer 5 GHz Wi-Fi or a wired connection.",
    "adv2.t": "Some endpoints are unreachable",
    "adv2.m": "Some public endpoints failed. This may be a blocked site or a remote service issue. Check whether Apple and Cloudflare succeeded.",
    "if.h": "Interfaces", "dr.h": "DNS & Route",
    "wifi": "Wi-Fi", "wired": "Wired", "up": "Connected", "down": "Disconnected",
    "defroute": "Default route interface", "noaddr": "No IPv4/IPv6 address",
    "dns.h": "DNS Resolver", "src": "Source", "src.v": "System Configuration",
    "rt.h": "Default Route", "dst": "Destination", "gw": "Gateway", "if.l": "Interface",
    "set.t": "Settings",
    "bdg1": "Read-Only", "bdg2": "Sandboxed", "bdg3": "No Root", "bdg4": "No Tracking",
    "priv.h": "Privacy",
    "priv1": "Diagnostic data stays on this Mac and is never uploaded automatically.",
    "priv2": "Support export redacts Wi-Fi SSID and excludes usernames, paths, cookies, and keys.",
    "kl.h": "More by Kevin Labs",
    "volmix.d": "Per-app volume control for Mac · driver-free native audio",
    "ksic.d": "Lightweight macOS menu bar workspace & quick launcher",
    "view": "View in App Store"
]

// MARK: - Scene 1 · Menu bar + QuickCheck popup
func scene1() {
    background(accent: cGreen)
    header(L("s1t"), L("s1s"))

    // macOS menu bar strip
    let bar = CGRect(x: 340, y: 400, width: 2200, height: 78)
    rrect(bar, 22, NSColor.white.withAlphaComponent(0.10), stroke: NSColor.white.withAlphaComponent(0.08))
    let barCY = bar.midY
    textRight(L("time"), bar.maxX - 44, barCY - 20, 32, .semibold, NSColor.white.withAlphaComponent(0.92))
    sym("battery.100", bar.maxX - 240, barCY, 40, NSColor.white.withAlphaComponent(0.92))
    sym("wifi", bar.maxX - 330, barCY, 34, NSColor.white.withAlphaComponent(0.92))

    // NetDoctor menu item (highlighted)
    let itemW = measure(L("appname"), size: 30, weight: .semibold).width + 100
    let itemR = CGRect(x: bar.maxX - 330 - 56 - itemW, y: barCY - 27, width: itemW, height: 54)
    rrect(itemR, 14, cGreen.withAlphaComponent(0.28))
    circle(itemR.minX + 30, itemR.midY, 18, cGreen)
    text(L("appname"), itemR.minX + 52, itemR.midY - 19, 30, .semibold, .white)

    // QuickCheck popup anchored under the item
    let pw: CGFloat = 1080
    let ph: CGFloat = 986
    let pr = CGRect(x: itemR.midX - pw / 2, y: bar.maxY + 22, width: pw, height: ph)
    g.saveGState()
    g.setShadow(offset: CGSize(width: 0, height: -22), blur: 70, color: NSColor.black.withAlphaComponent(0.6).cgColor)
    rrect(pr, 28, windowBG, stroke: NSColor.white.withAlphaComponent(0.12))
    g.restoreGState()

    let pad: CGFloat = 46
    let ix = pr.minX + pad
    var y = pr.minY + 40

    appIconMark(CGRect(x: ix, y: y, width: 88, height: 88))
    text("NetDoctor", ix + 112, y + 2, 44, .semibold, .white)
    capsule(L("healthy"), ix + 112, y + 58, 26, cGreen, icon: "checkmark.circle.fill")
    y += 126

    y += wrapText(L("sum.ok"), ix, y, pw - pad * 2, 32, .regular, cSub) + 26
    divider(ix, y, pw - pad * 2)
    y += 26

    // Info rows
    let rows: [(String, String, String)] = [
        ("point.3.connected.trianglepath.dotted", L("q.path"), L("v.ok")),
        ("network", L("q.if"), "2"),
        ("server.rack", L("q.dns"), L("dns1")),
        ("globe", L("q.net"), L("v.net"))
    ]
    for (ic, label, value) in rows {
        sym(ic, ix + 18, y + 27, 30, cBlue)
        text(label, ix + 52, y, 32, .regular, cSub)
        textRight(value, pr.maxX - pad, y, 32, .semibold, .white)
        y += 68
    }
    y += 4
    divider(ix, y, pw - pad * 2)
    y += 28

    // Advice row
    sym("checkmark.circle.fill", ix + 22, y + 24, 40, cGreen)
    text(L("adv.ok.t"), ix + 60, y, 34, .semibold, .white)
    y += 52
    y += wrapText(L("adv.ok.m"), ix + 60, y, pw - pad * 2 - 60, 28, .regular, cFaint) + 34

    // Buttons
    var bx = ix
    bx += button(L("b.check"), bx, y, primary: true) + 24
    bx += button(L("b.detail"), bx, y, primary: false) + 24
    _ = button(L("b.export"), bx, y, primary: false)
    y += 104
    text(L("ver"), ix, y, 26, .regular, cFaint)
}

// MARK: - Scene 2 · Reachability latency bars
func scene2() {
    background(accent: cBlue)
    header(L("s2t"), L("s2s"))
    let r = CGRect(x: 340, y: 330, width: 2200, height: 1390)
    windowChrome(r, L("win.title"))
    let top = tabBar(r, 3)

    struct EP { let name: String; let letter: String; let tint: NSColor; let p50: Int; let p90: Int; let p95: Int }
    let eps = [
        EP(name: "Apple", letter: "A", tint: NSColor(calibratedRed: 0.75, green: 0.78, blue: 0.85, alpha: 1), p50: 28, p90: 45, p95: 52),
        EP(name: "Google", letter: "G", tint: cBlue, p50: 96, p90: 132, p95: 148),
        EP(name: "Cloudflare", letter: "C", tint: cOrange, p50: 41, p90: 63, p95: 70)
    ]

    let cw = r.width - 112
    let ch: CGFloat = 296
    var y = top + 44
    for ep in eps {
        let cr = CGRect(x: r.minX + 56, y: y, width: cw, height: ch)
        rrect(cr, 24, cardBG, stroke: NSColor.white.withAlphaComponent(0.08))

        // monogram
        let mr = CGRect(x: cr.minX + 36, y: cr.minY + 34, width: 76, height: 76)
        rrect(mr, 20, ep.tint.withAlphaComponent(0.20), stroke: ep.tint.withAlphaComponent(0.45))
        textCentered(ep.letter, mr.midX, mr.midY - 26, 46, .bold, ep.tint)
        text(ep.name, cr.minX + 136, cr.minY + 44, 44, .bold, .white)
        textRight(L("succ"), cr.maxX - 44, cr.minY + 44, 34, .semibold, cGreen)

        // latency bar
        let trackR = CGRect(x: cr.minX + 44, y: cr.minY + 142, width: cr.width - 200, height: 28)
        rrect(trackR, 14, NSColor.white.withAlphaComponent(0.07))
        let fillW = trackR.width * CGFloat(ep.p95) / 160.0
        gradientRRect(CGRect(x: trackR.minX, y: trackR.minY, width: fillW, height: trackR.height), 14,
                      [cBlue, cGreen])
        text("\(ep.p95) ms", trackR.minX + fillW + 20, trackR.minY - 6, 30, .bold, .white, mono: true)

        // metrics
        let labels = [L("loss"), "P50", "P90", "P95"]
        let values = ["0%", "\(ep.p50) ms", "\(ep.p90) ms", "\(ep.p95) ms"]
        let colW = (cr.width - 88) / 4
        for i in 0..<4 {
            let mx = cr.minX + 44 + CGFloat(i) * colW
            text(labels[i], mx, cr.minY + 200, 26, .medium, cFaint)
            text(values[i], mx, cr.minY + 236, 36, .semibold, .white, mono: true)
        }
        y += ch + 40
    }
    text(L("reach.note"), r.minX + 56, y + 8, 28, .regular, cFaint)
}

// MARK: - Scene 3 · Overview + advice spotlight
func scene3() {
    background(accent: cOrange)
    header(L("s3t"), L("s3s"))
    let r = CGRect(x: 340, y: 330, width: 2200, height: 1390)
    windowChrome(r, L("win.title"))
    let top = tabBar(r, 0)

    let pad: CGFloat = 56
    var y = top + 36
    text(L("ov.title"), r.minX + pad, y, 64, .bold, .white)
    text(L("sum.warn"), r.minX + pad, y + 88, 34, .regular, cSub)
    let badgeW = capsuleWidth(L("warning"), 34, icon: "exclamationmark.triangle.fill")
    _ = capsule(L("warning"), r.maxX - pad - badgeW, y + 8, 34, cOrange, icon: "exclamationmark.triangle.fill")
    y += 162

    // Metric cards 2x2
    let gap: CGFloat = 30
    let cw = (r.width - pad * 2 - gap) / 2
    let ch: CGFloat = 168
    let cards: [(String, String, String, String)] = [
        ("point.3.connected.trianglepath.dotted", L("m.path"), L("v.ok"), L("m.path.d")),
        ("network", L("m.if"), "2", L("m.if.d")),
        ("server.rack", L("m.dns"), L("dns1"), "\(L("dns1")), \(L("dns2"))"),
        ("globe", L("m.net"), L("m.net.v"), L("m.net.d"))
    ]
    for (i, c) in cards.enumerated() {
        let cx = r.minX + pad + CGFloat(i % 2) * (cw + gap)
        let cy = y + CGFloat(i / 2) * (ch + gap)
        let cr = CGRect(x: cx, y: cy, width: cw, height: ch)
        rrect(cr, 22, cardBG, stroke: NSColor.white.withAlphaComponent(0.08))
        sym(c.0, cr.minX + 48, cr.minY + 44, 34, cBlue)
        text(c.1, cr.minX + 82, cr.minY + 26, 28, .medium, cFaint)
        text(c.2, cr.minX + 34, cr.minY + 74, 44, .bold, .white)
        text(c.3, cr.minX + 34, cr.minY + 128, 26, .regular, cSub)
    }
    y += ch * 2 + gap + 48

    // Advice section with golden spotlight ring
    let adviceR = CGRect(x: r.minX + pad - 18, y: y - 16, width: r.width - (pad - 18) * 2, height: 480)
    g.saveGState()
    g.setShadow(offset: .zero, blur: 34, color: cGold.withAlphaComponent(0.55).cgColor)
    let ringP = CGPath(roundedRect: adviceR, cornerWidth: 26, cornerHeight: 26, transform: nil)
    g.setStrokeColor(cGold.cgColor)
    g.setLineWidth(4)
    g.addPath(ringP); g.strokePath()
    g.restoreGState()

    sym("lightbulb.fill", r.minX + pad + 22, y + 26, 38, cGold)
    text(L("adv.h"), r.minX + pad + 54, y, 40, .semibold, .white)
    y += 72

    let adv: [(String, String)] = [(L("adv1.t"), L("adv1.m")), (L("adv2.t"), L("adv2.m"))]
    for (t, m) in adv {
        let cr = CGRect(x: r.minX + pad, y: y, width: r.width - pad * 2, height: 182)
        rrect(cr, 20, cOrange.withAlphaComponent(0.10), stroke: cOrange.withAlphaComponent(0.30))
        sym("exclamationmark.triangle.fill", cr.minX + 52, cr.minY + 52, 44, cOrange)
        text(t, cr.minX + 100, cr.minY + 28, 36, .semibold, .white)
        _ = wrapText(m, cr.minX + 100, cr.minY + 82, cr.width - 140, 30, .regular, cSub)
        y += 182 + 22
    }
}

// MARK: - Scene 4 · Interfaces + DNS/Route panorama
func scene4() {
    background(accent: cBlue)
    header(L("s4t"), L("s4s"))
    let r = CGRect(x: 340, y: 330, width: 2200, height: 1390)
    windowChrome(r, L("win.title"))
    let top = tabBar(r, 1)

    let pad: CGFloat = 56
    let gap: CGFloat = 36
    let panelW = (r.width - pad * 2 - gap) / 2
    let panelH: CGFloat = 1140
    let panelY = top + 44

    // ---- Left: Interfaces ----
    let lp = CGRect(x: r.minX + pad, y: panelY, width: panelW, height: panelH)
    rrect(lp, 24, cardBG, stroke: NSColor.white.withAlphaComponent(0.08))
    sym("network", lp.minX + 40, lp.minY + 48, 34, cBlue)
    text(L("if.h"), lp.minX + 70, lp.minY + 24, 38, .semibold, .white)

    // en0 card
    let e0 = CGRect(x: lp.minX + 32, y: lp.minY + 96, width: lp.width - 64, height: 640)
    rrect(e0, 20, NSColor.white.withAlphaComponent(0.045), stroke: cGreen.withAlphaComponent(0.35))
    sym("wifi", e0.minX + 46, e0.minY + 56, 40, cGreen)
    text("en0", e0.minX + 84, e0.minY + 32, 42, .bold, .white)
    _ = capsule(L("wifi"), e0.minX + 84, e0.minY + 96, 26, cSub)
    textRight(L("up"), e0.maxX - 32, e0.minY + 44, 32, .semibold, cGreen)

    var yy = e0.minY + 176
    sym("arrow.up.forward.circle", e0.minX + 46, yy + 18, 30, cBlue)
    text(L("defroute"), e0.minX + 82, yy, 30, .medium, cBlue)
    yy += 62
    sym("wifi", e0.minX + 46, yy + 18, 30, cSub)
    text("Home-WiFi", e0.minX + 82, yy, 34, .semibold, .white)
    yy += 72

    let addrs: [(String, String)] = [
        ("IPv4", "192.168.1.100"),
        ("IPv6", "fe80::a1b2:3c4d:5e6f:1024")
    ]
    for (fam, addr) in addrs {
        let ar = CGRect(x: e0.minX + 28, y: yy, width: e0.width - 56, height: 84)
        rrect(ar, 16, NSColor.black.withAlphaComponent(0.25), stroke: NSColor.white.withAlphaComponent(0.07))
        text(fam, ar.minX + 26, ar.minY + 22, 28, .medium, cFaint)
        textRight(addr, ar.maxX - 26, ar.minY + 20, 32, .semibold, .white, mono: true)
        yy += 100
    }

    // en8 card
    let e8 = CGRect(x: lp.minX + 32, y: e0.maxY + 28, width: lp.width - 64, height: 240)
    rrect(e8, 20, NSColor.white.withAlphaComponent(0.03), stroke: NSColor.white.withAlphaComponent(0.07))
    sym("cable.connector", e8.minX + 46, e8.minY + 52, 38, cFaint)
    text("en8", e8.minX + 84, e8.minY + 28, 40, .bold, .white)
    _ = capsule(L("wired"), e8.minX + 84, e8.minY + 92, 26, cFaint)
    textRight(L("down"), e8.maxX - 32, e8.minY + 40, 32, .medium, cFaint)
    text(L("noaddr"), e8.minX + 84, e8.minY + 164, 28, .regular, cFaint)

    // ---- Right: DNS & Route ----
    let rp = CGRect(x: lp.maxX + gap, y: panelY, width: panelW, height: panelH)
    rrect(rp, 24, cardBG, stroke: NSColor.white.withAlphaComponent(0.08))
    sym("point.3.filled.connected.trianglepath.dotted", rp.minX + 40, rp.minY + 48, 34, cBlue)
    text(L("dr.h"), rp.minX + 74, rp.minY + 24, 38, .semibold, .white)

    func section(_ title: String, _ sy: CGFloat) -> CGFloat {
        text(title, rp.minX + 36, sy, 28, .semibold, cFaint)
        return sy + 52
    }
    func row(_ label: String, _ value: String, _ ry: CGFloat, mono: Bool = true) -> CGFloat {
        let rr = CGRect(x: rp.minX + 36, y: ry, width: rp.width - 72, height: 76)
        rrect(rr, 16, NSColor.black.withAlphaComponent(0.22), stroke: NSColor.white.withAlphaComponent(0.06))
        text(label, rr.minX + 24, rr.minY + 18, 28, .regular, cSub)
        textRight(value, rr.maxX - 24, rr.minY + 16, 30, .semibold, .white, mono: mono)
        return ry + 92
    }

    var ry = section(L("dns.h"), rp.minY + 104)
    ry = row(L("src"), L("src.v"), ry, mono: false)
    ry = row("DNS 1", L("dns1"), ry)
    ry = row("DNS 2", L("dns2"), ry)
    ry += 40
    ry = section(L("rt.h"), ry)
    ry = row(L("dst"), "default", ry)
    ry = row(L("gw"), "192.168.1.1", ry)
    _ = row(L("if.l"), "en0", ry)
}

// MARK: - Scene 5 · Privacy + Kevin Labs
func scene5() {
    background(accent: cGreen)
    header(L("s5t"), L("s5s"))
    let r = CGRect(x: 440, y: 330, width: 2000, height: 1390)
    windowChrome(r, L("win.title"))
    _ = tabBar(r, 5)

    // Trust badges row
    let badges: [(String, String)] = [
        ("lock.shield.fill", L("bdg1")),
        ("checkmark.seal.fill", L("bdg2")),
        ("hand.raised.fill", L("bdg3")),
        ("eye.slash.fill", L("bdg4"))
    ]
    var widths: [CGFloat] = []
    var total: CGFloat = 0
    for (ic, t) in badges {
        let w = measure(t, size: 30, weight: .semibold).width + 30 * 1.35 + 30 * 1.7
        widths.append(w)
        total += w
    }
    total += CGFloat(badges.count - 1) * 28
    var bx = r.midX - total / 2
    let by = r.minY + 208
    for (i, (ic, t)) in badges.enumerated() {
        let w = capsule(t, bx, by, 30, cGreen, icon: ic)
        bx += widths[i] + 28
    }

    let pad: CGFloat = 56
    // Privacy card
    let pr = CGRect(x: r.minX + pad, y: by + 116, width: r.width - pad * 2, height: 420)
    rrect(pr, 24, cardBG, stroke: NSColor.white.withAlphaComponent(0.08))
    sym("lock.shield.fill", pr.minX + 42, pr.minY + 50, 36, cGreen)
    text(L("priv.h"), pr.minX + 76, pr.minY + 26, 38, .semibold, .white)
    let privRows = [("internaldrive", L("priv1")), ("doc.badge.gearshape", L("priv2"))]
    var py = pr.minY + 108
    for (ic, t) in privRows {
        let rr = CGRect(x: pr.minX + 36, y: py, width: pr.width - 72, height: 120)
        rrect(rr, 18, NSColor.black.withAlphaComponent(0.22), stroke: NSColor.white.withAlphaComponent(0.06))
        sym(ic, rr.minX + 50, rr.midY, 38, cSub)
        _ = wrapText(t, rr.minX + 96, rr.midY - 24, rr.width - 140, 30, .regular, cSub)
        py += 136
    }

    // Kevin Labs card
    let kr = CGRect(x: r.minX + pad, y: pr.maxY + 40, width: r.width - pad * 2, height: 560)
    rrect(kr, 24, cardBG, stroke: NSColor.white.withAlphaComponent(0.08))
    sym("sparkles", kr.minX + 42, kr.minY + 50, 34, cGold)
    text(L("kl.h"), kr.minX + 74, kr.minY + 26, 38, .semibold, .white)

    func devRow(_ ry: CGFloat, icon: String, iconColors: [NSColor], title: String,
                tag: String, desc: String) {
        let rr = CGRect(x: kr.minX + 36, y: ry, width: kr.width - 72, height: 200)
        rrect(rr, 20, NSColor.black.withAlphaComponent(0.22), stroke: NSColor.white.withAlphaComponent(0.07))
        let ir = CGRect(x: rr.minX + 40, y: rr.midY - 48, width: 96, height: 96)
        gradientRRect(ir, 24, iconColors)
        sym(icon, ir.midX, ir.midY, 46, .white)
        let tx = ir.maxX + 44
        text(title, tx, rr.minY + 42, 40, .bold, .white)
        _ = capsule(tag, tx + measure(title, size: 40, weight: .bold).width + 24, rr.minY + 44, 24, cSub)
        text(desc, tx, rr.minY + 116, 30, .regular, cSub)
        // View button
        let bw = measure(L("view"), size: 28, weight: .semibold).width + 96
        let br = CGRect(x: rr.maxX - bw - 36, y: rr.midY - 33, width: bw, height: 66)
        rrect(br, 16, accentBtn.withAlphaComponent(0.20), stroke: accentBtn.withAlphaComponent(0.55))
        text(L("view"), br.minX + 28, br.midY - 18, 28, .semibold, cBlue)
        sym("arrow.up.forward.app.fill", br.maxX - 40, br.midY, 30, cBlue)
    }
    devRow(kr.minY + 104, icon: "slider.vertical.3",
           iconColors: [NSColor(calibratedRed: 0.55, green: 0.40, blue: 0.95, alpha: 1),
                        NSColor(calibratedRed: 0.30, green: 0.55, blue: 1.00, alpha: 1)],
           title: "VolMix", tag: "App Store", desc: L("volmix.d"))
    devRow(kr.minY + 104 + 224, icon: "rectangle.grid.2x2",
           iconColors: [NSColor(calibratedRed: 0.25, green: 0.60, blue: 1.00, alpha: 1),
                        NSColor(calibratedRed: 0.15, green: 0.45, blue: 0.85, alpha: 1)],
           title: "KSIC Studio", tag: "Free", desc: L("ksic.d"))
}

// MARK: - App name entry (shared)
// injected into dicts at runtime
zhDict["appname"] = "NetDoctor"
enDict["appname"] = "NetDoctor"

// MARK: - Driver
func render(_ index: Int, _ draw: () -> Void) -> CGImage {
    let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: H)
    ctx.scaleBy(x: 1, y: -1)
    g = ctx
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return ctx.makeImage()!
}

func save(_ img: CGImage, _ path: String) {
    let rep = NSBitmapImageRep(cgImage: img)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("PNG encode failed: \(path)")
    }
    try! data.write(to: URL(fileURLWithPath: path))
}

let base = "\(FileManager.default.currentDirectoryPath)/docs/media/appstore/v1.1"
let scenes: [(NSColor, () -> Void)] = [
    (cGreen, scene1), (cBlue, scene2), (cOrange, scene3), (cBlue, scene4), (cGreen, scene5)
]
for (lang, d) in [("zh", zhDict), ("en", enDict)] {
    let dir = "\(base)/\(lang)"
    try! FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    dict = d
    for (i, scene) in scenes.enumerated() {
        let img = render(i + 1, scene.1)
        let path = String(format: "%@/%02d.png", dir, i + 1)
        save(img, path)
        print("rendered \(path)")
    }
}
print("Done.")
