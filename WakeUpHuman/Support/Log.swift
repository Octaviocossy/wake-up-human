import os

/// Unified-logging categories. Filter with `log stream --predicate 'subsystem == "com.ovct.wakeuphuman"'`.
enum Log {
    static let app = Logger(subsystem: "com.ovct.wakeuphuman", category: "app")
    static let alarms = Logger(subsystem: "com.ovct.wakeuphuman", category: "alarms")
    static let ring = Logger(subsystem: "com.ovct.wakeuphuman", category: "ring")
    static let audio = Logger(subsystem: "com.ovct.wakeuphuman", category: "audio")
    static let power = Logger(subsystem: "com.ovct.wakeuphuman", category: "power")
    static let bedtime = Logger(subsystem: "com.ovct.wakeuphuman", category: "bedtime")
}
