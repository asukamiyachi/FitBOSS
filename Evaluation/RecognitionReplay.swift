import Foundation

/// Only synthetic signals are replayed. Nothing reads a camera, history or network.
@main
struct RecognitionReplay {
    static func percentile(_ values: [Double], _ fraction: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        return sorted[min(sorted.count - 1, Int(ceil(Double(sorted.count) * fraction)) - 1)]
    }

    static func main() throws {
        // Predeclared one-to-one matching: count must follow first full extension
        // by 0...450ms. Too-early and unmatched counts are FP, unmatched truths FN.
        let tolerance = 0.450
        var rows: [[String: Any]] = []
        var errors: [Double] = [], biases: [Double] = [], delays: [Double] = []
        var totalTP = 0, totalFP = 0, totalFN = 0
        for trial in RecognitionFixtures.trials {
            var evaluator = PushUpEvaluator(), count = 0
            var events: [Double] = []
            for sample in trial.samples {
                let result = evaluator.process(sample.frame)
                if result.value > count { events.append(sample.time) }
                count = result.value
            }
            var unmatched = trial.truth
            var tp = 0, fp = 0
            for event in events {
                if let index = unmatched.firstIndex(where: { event >= $0 - 1e-9 && event - $0 <= tolerance + 1e-9 }) {
                    tp += 1
                    delays.append(max(0, event - unmatched.remove(at: index)))
                } else { fp += 1 }
            }
            let fn = unmatched.count
            totalTP += tp; totalFP += fp; totalFN += fn
            let bias = Double(count - trial.truth.count)
            errors.append(abs(bias)); biases.append(bias)
            rows.append(["trial": trial.name, "truth": trial.truth.count, "detected": count,
                         "tp": tp, "fp": fp, "fn": fn])
        }
        // Pure evaluator wall time, NOT Vision inference or end-to-end latency.
        var micros: [Double] = []
        var checksum = 0
        for _ in 0..<200 {
            for trial in RecognitionFixtures.trials {
                var evaluator = PushUpEvaluator()
                for sample in trial.samples {
                    let frame = sample.frame
                    let start = DispatchTime.now().uptimeNanoseconds
                    let result = evaluator.process(frame)
                    let elapsed = DispatchTime.now().uptimeNanoseconds - start
                    micros.append(Double(elapsed) / 1000)
                    checksum &+= result.value
                }
            }
        }
        let report: [String: Any] = [
            "dataset": "hand-authored synthetic v3 (26 trials); no camera observations",
            "trials": rows, "matching_window_seconds": tolerance,
            "mae": errors.reduce(0,+) / Double(errors.count),
            "bias": biases.reduce(0,+) / Double(biases.count),
            "tp": totalTP, "fp": totalFP, "fn": totalFN,
            "precision": Double(totalTP) / Double(max(1,totalTP+totalFP)),
            "recall": Double(totalTP) / Double(max(1,totalTP+totalFN)),
            "event_delay_median_ms": (percentile(delays,0.5) ?? 0) * 1000,
            "event_delay_p95_ms": (percentile(delays,0.95) ?? 0) * 1000,
            "evaluator_wall_median_us": percentile(micros,0.5) ?? 0,
            "evaluator_wall_p95_us": percentile(micros,0.95) ?? 0,
            "benchmark_frames": micros.count, "checksum": checksum
        ]
        let json = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: json, as: UTF8.self))
    }
}
