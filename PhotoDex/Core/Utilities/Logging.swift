import Foundation
import OSLog

enum AppLogger {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.PhotoDex"

    static let analysis = Logger(subsystem: subsystem, category: "analysis")
    static let camera = Logger(subsystem: subsystem, category: "camera")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let permissions = Logger(subsystem: subsystem, category: "permissions")
    static let error = Logger(subsystem: subsystem, category: "error")
    static let navigation = Logger(subsystem: subsystem, category: "navigation")
}

