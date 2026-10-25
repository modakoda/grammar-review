import os

public enum Log {
    public static let subsystem = "com.grammarreview.app"
    public static let app = Logger(subsystem: subsystem, category: "app")
    public static let engine = Logger(subsystem: subsystem, category: "engine")
    public static let accessibility = Logger(subsystem: subsystem, category: "accessibility")
    public static let overlay = Logger(subsystem: subsystem, category: "overlay")
}
