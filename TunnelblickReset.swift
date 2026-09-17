import AppKit
import Foundation

final class TunnelblickResetDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var repairItem: NSMenuItem!
    private var resultItem: NSMenuItem!
    private var statusVersion = 0

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    private func setStatus(_ message: String) {
        resultItem.title = String(format: localized("status.prefix"), message)
    }

    private func showMonogramIcon(progress: Double? = nil) {
        let icon = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            let center = NSPoint(x: 9, y: 9)
            let radius: CGFloat = 7.3
            let ring = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius,
                                                   width: radius * 2, height: radius * 2))
            ring.lineWidth = 1.4
            let fullRing = progress.map { $0 >= 1 } ?? true
            NSColor.black.withAlphaComponent(fullRing ? 1 : 0.25).setStroke()
            ring.stroke()

            if let progress, progress > 0 && progress < 1 {
                let arc = NSBezierPath()
                arc.appendArc(withCenter: center, radius: radius, startAngle: 90,
                              endAngle: 90 - 360 * progress, clockwise: true)
                arc.lineWidth = 1.8
                arc.lineCapStyle = .round
                NSColor.black.setStroke()
                arc.stroke()
            }

            NSColor.black.setFill()
            let capitalT = NSBezierPath()
            capitalT.appendRect(NSRect(x: 3.4, y: 11.5, width: 7.6, height: 1.5))
            capitalT.appendRect(NSRect(x: 6.3, y: 4.2, width: 1.8, height: 8.3))
            capitalT.fill()

            let smallB = NSBezierPath()
            smallB.lineWidth = 0.9
            smallB.lineCapStyle = .round
            smallB.move(to: NSPoint(x: 10.5, y: 10.0))
            smallB.line(to: NSPoint(x: 9.7, y: 4.4))
            smallB.move(to: NSPoint(x: 10.0, y: 7.0))
            smallB.curve(to: NSPoint(x: 12.7, y: 6.9), controlPoint1: NSPoint(x: 11.4, y: 8.0),
                         controlPoint2: NSPoint(x: 12.6, y: 8.0))
            smallB.curve(to: NSPoint(x: 9.7, y: 4.6), controlPoint1: NSPoint(x: 13.2, y: 5.2),
                         controlPoint2: NSPoint(x: 10.8, y: 3.9))
            NSColor.black.setStroke()
            smallB.stroke()
            return true
        }
        icon.isTemplate = true
        statusItem.button?.image = icon
        statusItem.button?.title = ""
        statusItem.length = NSStatusItem.squareLength
    }

    private func showIcon(_ symbol: String, description: String) {
        if let icon = NSImage(systemSymbolName: symbol, accessibilityDescription: description) {
            icon.isTemplate = true
            statusItem.button?.image = icon
        }
        statusItem.button?.title = ""
        statusItem.length = NSStatusItem.squareLength
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.autosaveName = "ru.viktoraseev.tunnelblick-reset"
        showMonogramIcon()
        statusItem.button?.toolTip = localized("tooltip.idle")
        statusItem.isVisible = true

        let menu = NSMenu()
        repairItem = NSMenuItem(title: localized("menu.repair"), action: #selector(repairNetwork), keyEquivalent: "")
        repairItem.target = self
        menu.addItem(repairItem)

        resultItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        setStatus(localized("status.ready"))
        resultItem.isEnabled = false
        menu.addItem(resultItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: localized("menu.quit"), action: #selector(quit), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    @objc private func repairNetwork() {
        statusVersion += 1
        let thisRun = statusVersion
        guard let scriptPath = Bundle.main.path(forResource: "reset", ofType: "sh") else {
            let message = localized("error.scriptMissing")
            setStatus(message)
            showIcon("exclamationmark.triangle.fill", description: localized("accessibility.repairFailed"))
            statusItem.button?.toolTip = message
            return
        }

        repairItem.isEnabled = false
        setStatus(localized("status.waitingTouchID"))
        showMonogramIcon(progress: 0)
        statusItem.button?.toolTip = localized("status.waitingTouchID")

        let language = Bundle.main.preferredLocalizations.first?.hasPrefix("ru") == true ? "ru" : "en"
        let authorizationStep = localized("status.authorization")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
            process.arguments = ["-A", "--", "/bin/bash", scriptPath, "--lang", language]
            var environment = ProcessInfo.processInfo.environment
            environment["SUDO_ASKPASS"] = "/usr/bin/false"
            process.environment = environment

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe
            var currentStep = authorizationStep
            var recentOutput: [String] = []

            func consume(_ line: String) {
                let parts = line.split(separator: "\t", maxSplits: 3, omittingEmptySubsequences: false)
                if parts.count == 4 && parts[0] == "PROGRESS" {
                    let scriptStepCount = Int(parts[2]) ?? 6
                    let fraction = "\(parts[1])/\(scriptStepCount + 1)"
                    let stepLabel = String(parts[3])
                    currentStep = stepLabel
                    DispatchQueue.main.async { [weak self] in
                        self?.showMonogramIcon(progress: Double(parts[1]).map { $0 / Double(scriptStepCount + 1) } ?? 0)
                        self?.setStatus("\(fraction) · \(stepLabel)")
                        self?.statusItem.button?.toolTip = "\(fraction) · \(stepLabel)"
                    }
                } else if !line.isEmpty {
                    recentOutput.append(line)
                    if recentOutput.count > 8 { recentOutput.removeFirst() }
                }
            }

            do {
                try process.run()
                var pending = Data()
                while true {
                    let chunk = outputPipe.fileHandleForReading.availableData
                    if chunk.isEmpty { break }
                    pending.append(chunk)
                    while let newline = pending.firstIndex(of: 0x0A) {
                        let line = String(decoding: pending[..<newline], as: UTF8.self)
                        pending.removeSubrange(...newline)
                        consume(line.trimmingCharacters(in: .newlines))
                    }
                }
                if !pending.isEmpty {
                    consume(String(decoding: pending, as: UTF8.self))
                }
                process.waitUntilExit()

                if process.terminationStatus == 0 {
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        self.showMonogramIcon(progress: 1)
                        let launchStatus = "7/7 · \(self.localized("step.launchTunnelblick"))"
                        self.setStatus(launchStatus)
                        self.statusItem.button?.toolTip = launchStatus

                        let appURL = URL(fileURLWithPath: "/Applications/Tunnelblick.app")
                        NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                            DispatchQueue.main.async { [weak self] in
                                guard let self else { return }
                                let message = error.map {
                                    String(format: self.localized("status.launchFailed"), $0.localizedDescription)
                                } ?? self.localized("status.success")
                                self.repairItem.isEnabled = true
                                self.setStatus(message)
                                self.showIcon(error == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                                              description: error == nil ? self.localized("accessibility.repaired") : self.localized("accessibility.launchFailed"))
                                self.statusItem.button?.toolTip = message
                                if error == nil {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                                        guard let self, self.statusVersion == thisRun else { return }
                                        self.showMonogramIcon()
                                        self.statusItem.button?.toolTip = self.localized("tooltip.idle")
                                    }
                                }
                            }
                        }
                    }
                } else {
                    let detail = recentOutput.last ?? String(format: self?.localized("error.exitCode") ?? "Exit code %d", process.terminationStatus)
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        let message = String(format: self.localized("error.step"), currentStep, detail)
                        self.repairItem.isEnabled = true
                        self.setStatus(message)
                        self.showIcon("exclamationmark.triangle.fill", description: self.localized("accessibility.repairFailed"))
                        self.statusItem.button?.toolTip = message
                    }
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.repairItem.isEnabled = true
                    let message = String(format: self.localized("error.generic"), error.localizedDescription)
                    self.setStatus(message)
                    self.showIcon("exclamationmark.triangle.fill", description: self.localized("accessibility.repairFailed"))
                    self.statusItem.button?.toolTip = message
                }
            }
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

let application = NSApplication.shared
let delegate = TunnelblickResetDelegate()
application.delegate = delegate
application.run()
