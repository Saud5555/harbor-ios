import Foundation

#if canImport(FirebasePerformance)
import FirebasePerformance
#endif

/// A single-stop wrapper around Firebase custom traces. It accepts only fixed
/// trace, attribute, and metric enums, and never accepts a URL.
final class HarborPerformanceTrace {
    private let lock = NSLock()
    private var stopped = false

    #if canImport(FirebasePerformance)
    private var firebaseTrace: Trace?
    #endif

    init(
        name: HarborPerformanceTraceName,
        enabled: Bool,
        attributes: [HarborTraceAttribute: String]
    ) {
        #if canImport(FirebasePerformance)
        if enabled {
            firebaseTrace = Performance.startTrace(name: name.rawValue)
            for (key, value) in attributes {
                guard let safe = Self.safeAttribute(value) else { continue }
                firebaseTrace?.setValue(safe, forAttribute: key.rawValue)
            }
        }
        #endif
    }

    func stop(
        outcome: String,
        attributes: [HarborTraceAttribute: String] = [:],
        metrics: [HarborTraceMetric: Int64] = [:]
    ) {
        lock.lock()
        guard !stopped else {
            lock.unlock()
            return
        }
        stopped = true
        lock.unlock()

        #if canImport(FirebasePerformance)
        if let safeOutcome = Self.safeAttribute(outcome) {
            firebaseTrace?.setValue(safeOutcome, forAttribute: HarborTraceAttribute.outcome.rawValue)
        }
        for (key, value) in attributes {
            guard let safe = Self.safeAttribute(value) else { continue }
            firebaseTrace?.setValue(safe, forAttribute: key.rawValue)
        }
        for (key, value) in metrics {
            firebaseTrace?.incrementMetric(key.rawValue, by: max(0, value))
        }
        firebaseTrace?.stop()
        firebaseTrace = nil
        #endif
    }

    private static func safeAttribute(_ value: String) -> String? {
        guard !value.isEmpty, value.count <= 32 else { return nil }
        let allowed = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-"
        )
        guard value.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
        return value
    }
}
