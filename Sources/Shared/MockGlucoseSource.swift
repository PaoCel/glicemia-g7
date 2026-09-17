import Foundation

/// Milestone 1 stand-in for Dexcom Share. Produces a plausible random walk so the
/// whole pipeline (source -> iPhone -> WatchConnectivity -> Watch UI) can be exercised
/// end to end before any network code exists.
final class MockGlucoseSource: GlucoseSource {

    /// Real G7 cadence is 300s. Shortened here so a device test does not require
    /// standing still for five minutes.
    var interval: TimeInterval = 30

    private(set) var isRunning = false
    var onReading: ((GlucoseReading) -> Void)?
    var onError: ((GlucoseSourceError) -> Void)?

    let displayName = "Simulatore (Milestone 1)"

    private var timer: Timer?
    private var currentValue: Double = 112
    private var drift: Double = 0

    func start() {
        guard !isRunning else { return }
        isRunning = true
        emit()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.emit()
        }
        // .common so the timer keeps firing while a list is being scrolled.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    /// Forces a value out of band, used by the manual "aggiorna" action.
    func refreshNow() {
        emit()
    }

    func fetchOnce() async -> Bool {
        await MainActor.run { self.emit() }
        return true
    }

    private func emit() {
        advance()
        let reading = GlucoseReading(
            mgdl: Int(currentValue.rounded()),
            trend: trend(for: drift),
            date: Date(),
            source: .mock
        )
        onReading?(reading)
    }

    private func advance() {
        // Small random acceleration, damped, and pulled back toward 110 mg/dL so the
        // walk stays inside a believable range instead of escaping to the boundaries.
        let kick = Double.random(in: -3.5...3.5)
        let pullToCentre = (110 - currentValue) * 0.02
        drift = drift * 0.7 + kick + pullToCentre
        drift = min(max(drift, -9), 9)
        currentValue = min(max(currentValue + drift, 45), 320)
    }

    private func trend(for drift: Double) -> TrendDirection {
        // drift is mg/dL per tick; scaled to the classic Dexcom per-minute bands.
        let perMinute = drift / (interval / 60)
        switch perMinute {
        case ..<(-3): return .doubleDown
        case ..<(-2): return .singleDown
        case ..<(-1): return .fortyFiveDown
        case ..<1: return .flat
        case ..<2: return .fortyFiveUp
        case ..<3: return .singleUp
        default: return .doubleUp
        }
    }
}
