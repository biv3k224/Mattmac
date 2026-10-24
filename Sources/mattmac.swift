import AppKit
import SwiftUI

enum Paper: String, CaseIterable, Identifiable {
    case classic = "Classic Matte"
    case whisper = "Whisper Weave"
    case sunbaked = "Sunbaked Parchment"
    case linen = "Saddle Linen"
    case painter = "Painter’s Press"
    case mulberry = "Mulberry Veil"
    case vellum = "Vellum Mist"
    case felt = "Monastic Felt"
    case legacy = "Classic Matte Legacy"

    var id: String { rawValue }
    var subtitle: String {
        switch self {
        case .classic: return "A clean, even matte finish"
        case .whisper: return "An ultra-fine weave for reading"
        case .sunbaked: return "Soft grain with a paper-like warmth"
        case .linen: return "A natural, woven surface"
        case .painter: return "Subtle tooth and pressed-paper depth"
        case .mulberry: return "A delicate, fine-grain veil"
        case .vellum: return "A soft, frosted-paper diffusion"
        case .felt: return "Dense, close-cropped fibers"
        case .legacy: return "The original, slightly grainier matte"
        }
    }
}

@MainActor final class MatteModel: ObservableObject {
    @Published var enabled = false {
        didSet { UserDefaults.standard.set(enabled, forKey: "mattmac.enabled.v2"); OverlayManager.shared.refresh(model: self) }
    }
    @Published var paper: Paper = .classic {
        didSet { UserDefaults.standard.set(paper.rawValue, forKey: "mattmac.paper"); OverlayManager.shared.refresh(model: self) }
    }
    @Published var intensity = 0.42 {
        didSet { UserDefaults.standard.set(intensity, forKey: "mattmac.intensity"); OverlayManager.shared.refresh(model: self) }
    }

    init() {
        let defaults = UserDefaults.standard
        enabled = defaults.object(forKey: "mattmac.enabled.v2") as? Bool ?? true
        paper = Paper(rawValue: defaults.string(forKey: "mattmac.paper") ?? "") ?? .classic
        intensity = defaults.object(forKey: "mattmac.intensity") as? Double ?? 0.42
    }
}

@MainActor final class OverlayManager {
    static let shared = OverlayManager()
    private var windows: [NSScreen: NSWindow] = [:]
    private weak var controlPanel: NSWindow?

    func setControlPanel(_ window: NSWindow) {
        controlPanel = window
        if window.isVisible { window.orderFrontRegardless() }
    }

    func refresh(model: MatteModel) {
        let screens = NSScreen.screens
        for (screen, window) in windows where !screens.contains(screen) {
            window.orderOut(nil)
            windows.removeValue(forKey: screen)
        }
        guard model.enabled else {
            windows.values.forEach { $0.orderOut(nil) }
            return
        }
        for screen in screens {
            let window: NSWindow
            if let existing = windows[screen] {
                window = existing
                window.setFrame(screen.frame, display: true)
            } else {
                window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false, screen: screen)
                window.isOpaque = false
                window.backgroundColor = .clear
                window.hasShadow = false
                window.ignoresMouseEvents = true
                window.level = .floating
                window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
                window.isReleasedWhenClosed = false
                windows[screen] = window
            }
            let host = NSHostingView(rootView: GrainLayer(paper: model.paper, intensity: model.intensity))
            host.wantsLayer = true
            host.layer?.isOpaque = false
            host.layer?.backgroundColor = NSColor.clear.cgColor
            window.contentView = host
            window.orderFrontRegardless()
        }
        if let controlPanel, controlPanel.isVisible { controlPanel.orderFrontRegardless() }
    }
}

struct GrainLayer: View {
    let paper: Paper
    let intensity: Double

    var body: some View {
        GeometryReader { geometry in
            Image(nsImage: TextureTileCache.image(for: paper))
                .resizable(resizingMode: .tile)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .opacity(intensity * 0.28)
        }
        .background(Color.clear)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private enum TextureTileCache {
    private static let cache = NSCache<NSString, NSImage>()
    private static let side = 256

    static func image(for paper: Paper) -> NSImage {
        let key = paper.rawValue as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let image = makeImage(paper)
        cache.setObject(image, forKey: key)
        return image
    }

    private static func makeImage(_ paper: Paper) -> NSImage {
        var bytes = [UInt8](repeating: 0, count: side * side * 4)
        for y in 0..<side {
            for x in 0..<side {
                let grain = random(x &+ y &* side &+ (Paper.allCases.firstIndex(of: paper) ?? 0) &* 0x12345) * 2 - 1
                let coarse = random((x / 4) &+ (y / 4) &* 64 &+ 0x54321) * 2 - 1
                let diagonal = sin(Double(x + y) * 0.13)
                let cross = ((x % 7 == 0 || y % 7 == 0) ? -0.35 : 0.0)
                let variation: Double
                switch paper {
                case .classic: variation = grain * 0.55
                case .whisper: variation = grain * 0.22 + diagonal * 0.12
                case .sunbaked: variation = grain * 0.42 + coarse * 0.22
                case .linen: variation = grain * 0.24 + cross
                case .painter: variation = grain * 0.68 + coarse * 0.18
                case .mulberry: variation = grain * 0.30 + sin(Double(x - y) * 0.16) * 0.28
                case .vellum: variation = grain * 0.16 + sin(Double(x) * 0.035) * cos(Double(y) * 0.04) * 0.20
                case .felt: variation = grain * 0.42 + coarse * 0.38
                case .legacy: variation = grain * 0.85
                }
                let gray = UInt8(max(35, min(220, Int(128 + variation * 72))))
                let alpha: UInt8 = 190
                let i = (y * side + x) * 4
                bytes[i] = UInt8(Int(gray) * Int(alpha) / 255)
                bytes[i + 1] = UInt8(Int(gray) * Int(alpha) / 255)
                bytes[i + 2] = UInt8(Int(gray) * Int(alpha) / 255)
                bytes[i + 3] = alpha
            }
        }
        let data = Data(bytes) as CFData
        let provider = CGDataProvider(data: data)!
        let cgImage = CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 32,
                              bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                              provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        return NSImage(cgImage: cgImage, size: NSSize(width: side / 2, height: side / 2))
    }

    private static func random(_ value: Int) -> Double {
        var x = UInt64(bitPattern: Int64(value)) &+ 0x9E3779B97F4A7C15
        x = (x ^ (x >> 30)) &* 0xBF58476D1CE4E5B9
        x = (x ^ (x >> 27)) &* 0x94D049BB133111EB
        x ^= x >> 31
        return Double(x & 0xFFFFFF) / Double(0xFFFFFF)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}

struct ControlPanel: View {
    @ObservedObject var model: MatteModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("mattmac").font(.system(size: 25, weight: .semibold, design: .rounded))
                    Text("A softer surface for your screen").font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Matte effect", isOn: $model.enabled).toggleStyle(.switch).labelsHidden()
                    .accessibilityLabel("Matte effect")
            }

            ZStack {
                RoundedRectangle(cornerRadius: 13).fill(Color(red: 0.94, green: 0.93, blue: 0.90))
                VStack(spacing: 8) {
                    Text("The quick brown fox").font(.system(size: 20, weight: .medium, design: .serif)).foregroundStyle(Color.black.opacity(0.86))
                    Text("Soft grain. Lower glare. Clear colors.").font(.system(size: 12)).foregroundStyle(Color.black.opacity(0.62))
                }
                GrainLayer(paper: model.paper, intensity: model.intensity).clipShape(RoundedRectangle(cornerRadius: 13))
            }
            .frame(height: 100)
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(.black.opacity(0.07)))

            VStack(alignment: .leading, spacing: 7) {
                Text("PAPER TEXTURE").font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
                Picker("Paper texture", selection: $model.paper) {
                    ForEach(Paper.allCases) { paper in Text(paper.rawValue).tag(paper) }
                }.labelsHidden().pickerStyle(.menu)
                Text(model.paper.subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("INTENSITY").font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(model.intensity * 100))%").font(.system(size: 12).monospacedDigit()).foregroundStyle(.secondary)
                }
                Slider(value: $model.intensity, in: 0...1)
            }

            HStack {
                Text(model.enabled ? "Matte overlay active · \(NSScreen.screens.count) display(s)" : "Matte overlay paused")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
            }
        }
        .padding(22)
        .frame(width: 360)
        .background(.regularMaterial)
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = MatteModel()
    private var statusItem: NSStatusItem!
    private var panel: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "circle.lefthalf.filled", accessibilityDescription: "mattmac")
            button.toolTip = "mattmac — paper texture"
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "Open mattmac…", action: #selector(showPanel), keyEquivalent: "")
        menu.addItem(withTitle: "Turn matte effect on", action: #selector(toggleEffect), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit mattmac", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
        OverlayManager.shared.refresh(model: model)
        showPanel()
    }

    @objc private func showPanel() {
        if panel == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 450), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "mattmac"
            window.level = .floating
            window.center()
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: ControlPanel(model: model))
            panel = window
        }
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
        if let panel { OverlayManager.shared.setControlPanel(panel) }
    }

    @objc private func toggleEffect() { model.enabled.toggle() }
    @objc private func quit() { NSApplication.shared.terminate(nil) }
}

@main struct MattmacApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
