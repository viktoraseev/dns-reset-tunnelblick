import AppKit
import Foundation

final class DNSResetDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var repairItem: NSMenuItem!
    private var resultItem: NSMenuItem!
    private var statusVersion = 0

    private func showTBIcon(progress: Double? = nil) {
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

            let letters = NSAttributedString(string: "TB", attributes: [
                .font: NSFont.systemFont(ofSize: 7.4, weight: .heavy),
                .foregroundColor: NSColor.black,
                .kern: -0.3
            ])
            let size = letters.size()
            letters.draw(at: NSPoint(x: (18 - size.width) / 2, y: (18 - size.height) / 2 + 0.3))
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
        statusItem.autosaveName = "ru.viktoraseev.dns-reset"
        showTBIcon()
        statusItem.button?.toolTip = "Восстановление сети"
        statusItem.isVisible = true

        let menu = NSMenu()
        repairItem = NSMenuItem(title: "Починить сеть после Tunnelblick", action: #selector(repairNetwork), keyEquivalent: "")
        repairItem.target = self
        menu.addItem(repairItem)

        resultItem = NSMenuItem(title: "Готово к запуску", action: nil, keyEquivalent: "")
        resultItem.isEnabled = false
        menu.addItem(resultItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Выход", action: #selector(quit), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    @objc private func repairNetwork() {
        statusVersion += 1
        let thisRun = statusVersion
        guard let scriptPath = Bundle.main.path(forResource: "reset", ofType: "sh") else {
            resultItem.title = "Ошибка: reset.sh не найден в приложении"
            showIcon("exclamationmark.triangle.fill", description: "Ошибка восстановления сети")
            return
        }

        repairItem.isEnabled = false
        resultItem.title = "Ожидание Touch ID…"
        showTBIcon(progress: 0)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
            process.arguments = ["-A", "--", "/bin/bash", scriptPath]
            var environment = ProcessInfo.processInfo.environment
            environment["SUDO_ASKPASS"] = "/usr/bin/false"
            process.environment = environment

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe
            var currentStep = "Авторизация"
            var recentOutput: [String] = []

            func consume(_ line: String) {
                let parts = line.split(separator: "\t", maxSplits: 3, omittingEmptySubsequences: false)
                if parts.count == 4 && parts[0] == "PROGRESS" {
                    let scriptStepCount = Int(parts[2]) ?? 6
                    let fraction = "\(parts[1])/\(scriptStepCount + 1)"
                    let stepLabel = String(parts[3])
                    currentStep = stepLabel
                    DispatchQueue.main.async { [weak self] in
                        self?.showTBIcon(progress: Double(parts[1]).map { $0 / Double(scriptStepCount + 1) } ?? 0)
                        self?.resultItem.title = "\(fraction) · \(stepLabel)"
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
                        self.showTBIcon(progress: 1)
                        self.resultItem.title = "7/7 · Запускаю Tunnelblick"
                        self.statusItem.button?.toolTip = "7/7 · Запускаю Tunnelblick"

                        let appURL = URL(fileURLWithPath: "/Applications/Tunnelblick.app")
                        NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                            DispatchQueue.main.async { [weak self] in
                                guard let self else { return }
                                let message = error.map { "Сеть восстановлена, но Tunnelblick не запустился: \($0.localizedDescription)" }
                                    ?? "Сеть восстановлена, Tunnelblick запущен"
                                self.repairItem.isEnabled = true
                                self.resultItem.title = message
                                self.showIcon(error == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                                              description: error == nil ? "Сеть восстановлена" : "Ошибка запуска Tunnelblick")
                                self.statusItem.button?.toolTip = message
                                if error == nil {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                                        guard let self, self.statusVersion == thisRun else { return }
                                        self.showTBIcon()
                                        self.statusItem.button?.toolTip = "Восстановление сети"
                                    }
                                }
                            }
                        }
                    }
                } else {
                    let detail = recentOutput.last ?? "код \(process.terminationStatus)"
                    let message = "Ошибка на этапе «\(currentStep)»: \(detail)"
                    DispatchQueue.main.async { [weak self] in
                        self?.repairItem.isEnabled = true
                        self?.resultItem.title = message
                        self?.showIcon("exclamationmark.triangle.fill", description: "Ошибка восстановления сети")
                        self?.statusItem.button?.toolTip = message
                    }
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.repairItem.isEnabled = true
                    self?.resultItem.title = "Ошибка: \(error.localizedDescription)"
                    self?.showIcon("exclamationmark.triangle.fill", description: "Ошибка восстановления сети")
                }
            }
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

let application = NSApplication.shared
let delegate = DNSResetDelegate()
application.delegate = delegate
application.run()
