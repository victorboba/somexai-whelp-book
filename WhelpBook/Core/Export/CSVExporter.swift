import Foundation

/// The spreadsheet a breeder already keeps, generated instead of typed.
///
/// One row per weigh-in, with the puppy's identity repeated on every row so the file sorts and
/// pivots without any cleaning up. The birth weight is included as a row of its own, because it is
/// the first point on the curve and leaving it out loses day zero.
enum CSVExporter {
    static let header = "litter,dam,sire,puppy,birth_order,sex,collar,markings,date,age_days,weight_g,weight_oz,change_g,is_birth_weight,notes"

    static func csv(for litter: Litter) -> String {
        let stamp = ISO8601DateFormatter()
        var lines = [header]
        let damName = litter.dam?.displayName ?? ""
        for puppy in litter.pups {
            let samples = puppy.weightSamples
            let notesByDate = Dictionary(uniqueKeysWithValues: puppy.weights.map { ($0.date, $0.notes) })
            for (index, sample) in samples.enumerated() {
                let change = index > 0 ? sample.grams - samples[index - 1].grams : 0
                let fields = [
                    litter.displayName,
                    damName,
                    litter.sireName,
                    puppy.displayName,
                    String(puppy.birthOrder),
                    puppy.sex.label,
                    puppy.collar,
                    puppy.markings,
                    stamp.string(from: sample.date),
                    String(puppy.ageInDays(now: sample.date)),
                    formatted(sample.grams.rounded()),
                    String(format: "%.2f", WeightMath.ounces(fromGrams: sample.grams)),
                    index > 0 ? formatted(change.rounded()) : "",
                    sample.isBirthWeight ? "yes" : "no",
                    notesByDate[sample.date] ?? "",
                ]
                lines.append(fields.map(quote).joined(separator: ","))
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Writes the CSV to a temporary file and returns its URL for the share sheet.
    static func exportWeighIns(_ litter: Litter) throws -> URL {
        let url = ExportFile.temporaryURL(extension: "csv")
        try csv(for: litter).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func quote(_ field: String) -> String {
        "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func formatted(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}

/// A file URL wrapped so it can drive `.sheet(item:)`.
struct ExportFile: Identifiable {
    let url: URL
    var id: String { url.path }

    static func temporaryURL(extension ext: String, stem: String = AppConfig.exportFileStem) -> URL {
        let stamp = DateFormatter.fileStamp.string(from: .now)
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("\(stem)-\(stamp)")
            .appendingPathExtension(ext)
    }
}

extension DateFormatter {
    static let fileStamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmm"
        return f
    }()

    static let report: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    static let reportDay: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}
