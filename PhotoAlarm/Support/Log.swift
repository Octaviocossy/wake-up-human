import OSLog

enum Log {
    private static let subsystem = "com.ovct.photoalarm"

    static let alarm = Logger(subsystem: subsystem, category: "alarm")
    static let intents = Logger(subsystem: subsystem, category: "intents")
    static let vision = Logger(subsystem: subsystem, category: "vision")
    static let mission = Logger(subsystem: subsystem, category: "mission")
}
