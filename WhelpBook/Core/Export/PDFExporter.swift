import UIKit

/// Two documents, both printable on US Letter.
///
/// **The puppy record** is the one that sells the app. It is what the new owner is handed at the
/// door: who this puppy is, who its parents are, what it weighed every day of its life so far, and
/// what the vet gave it and when. Breeders currently write this by hand or not at all.
///
/// **The litter report** is the breeder's own copy of the whole thing — the timeline, the whelping
/// log with times and birth weights, and the health grid.
///
/// Neither document interprets anything. Every line is a value the breeder or their vet entered.
enum PDFExporter {
    private static let page = CGRect(x: 0, y: 0, width: 612, height: 792)
    private static let margin: CGFloat = 48
    private static let rowHeight: CGFloat = 17

    private static let titleFont = UIFont.boldSystemFont(ofSize: 22)
    private static let sectionFont = UIFont.boldSystemFont(ofSize: 13)
    private static let headerFont = UIFont.boldSystemFont(ofSize: 9.5)
    private static let bodyFont = UIFont.systemFont(ofSize: 10)
    private static let smallFont = UIFont.systemFont(ofSize: 8.5)

    // MARK: Puppy record

    static func exportPuppy(_ puppy: Puppy) throws -> URL {
        let stem = "\(AppConfig.exportFileStem)-\(slug(puppy.displayName))"
        let url = ExportFile.temporaryURL(extension: "pdf", stem: stem)
        try puppyData(puppy).write(to: url)
        return url
    }

    static func puppyData(_ puppy: Puppy) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let litter = puppy.litter
        return renderer.pdfData { context in
            var layout = Layout(context: context, page: page, margin: margin)
            layout.startPage(title: "Puppy Record", subtitle: puppy.displayName)

            layout.section("Identification")
            layout.field("Name", puppy.name.isEmpty ? "Not named" : puppy.name)
            layout.field("Collar", puppy.collar.isEmpty ? "Not recorded" : puppy.collar)
            layout.field("Sex", puppy.sex.label)
            layout.field("Colour and markings", puppy.markings.isEmpty ? "Not recorded" : puppy.markings)
            layout.field("Microchip", puppy.microchip.isEmpty ? "Not recorded" : puppy.microchip)

            layout.section("Birth")
            layout.field("Born", DateFormatter.report.string(from: puppy.bornAt))
            layout.field("Birth order", "\(puppy.birthOrder) of \(litter?.pups.count ?? 1)")
            layout.field("Birth weight", puppy.birthWeightGrams > 0 ? WeightMath.bothUnits(puppy.birthWeightGrams) : "Not recorded")
            layout.field("Placenta passed", puppy.placentaPassed ? "Yes" : "Not recorded")

            layout.section("Breeding")
            layout.field("Dam", litter?.dam?.displayName ?? "Not recorded")
            layout.field("Dam breed", litter?.dam?.breed.isEmpty == false ? (litter?.dam?.breed ?? "") : "Not recorded")
            layout.field("Dam registration", litter?.dam?.registration.isEmpty == false ? (litter?.dam?.registration ?? "") : "Not recorded")
            layout.field("Sire", litter?.sireName.isEmpty == false ? (litter?.sireName ?? "") : "Not recorded")
            layout.field("Sire registration", litter?.sireRegistration.isEmpty == false ? (litter?.sireRegistration ?? "") : "Not recorded")
            layout.field("Litter", litter?.displayName ?? "Not recorded")

            layout.section("Weight history")
            let samples = puppy.weightSamples
            if samples.isEmpty {
                layout.note("No weights recorded.")
            } else {
                let columns: [Layout.Column] = [
                    .init(name: "Date", width: 150),
                    .init(name: "Age", width: 80),
                    .init(name: "Grams", width: 80),
                    .init(name: "Ounces", width: 80),
                    .init(name: "Change", width: 80),
                ]
                layout.tableHeader(columns)
                for (index, sample) in samples.enumerated() {
                    let change = index > 0 ? WeightMath.changeString(sample.grams - samples[index - 1].grams) : "-"
                    layout.tableRow(columns, [
                        DateFormatter.report.string(from: sample.date),
                        "\(puppy.ageInDays(now: sample.date)) days",
                        WeightMath.gramsString(sample.grams),
                        WeightMath.ouncesString(sample.grams),
                        change,
                    ])
                }
            }

            layout.section("Worming, vaccination and microchip")
            let tasks = litter?.healthTasks ?? []
            if tasks.isEmpty {
                layout.note("Nothing recorded for this litter.")
            } else {
                let columns: [Layout.Column] = [
                    .init(name: "Event", width: 150),
                    .init(name: "Date given", width: 130),
                    .init(name: "Product", width: 190),
                ]
                layout.tableHeader(columns)
                for task in tasks {
                    let record = puppy.wasGiven(task)
                    layout.tableRow(columns, [
                        task.shortName,
                        record.map { DateFormatter.reportDay.string(from: $0.givenOn) } ?? "Not given",
                        task.product.isEmpty ? "Not recorded" : task.product,
                    ])
                }
            }

            if !puppy.notes.isEmpty {
                layout.section("Breeder notes")
                layout.paragraph(puppy.notes)
            }

            layout.section("New owner")
            layout.field("Name", puppy.buyerName.isEmpty ? "Not recorded" : puppy.buyerName)
            layout.field("Contact", puppy.buyerContact.isEmpty ? "Not recorded" : puppy.buyerContact)
            layout.field("Deposit", puppy.depositPaid ? "Paid" : "Not recorded")
            layout.field("Goes home", (puppy.goHomeDate ?? litter?.goHomeDate).map { DateFormatter.reportDay.string(from: $0) } ?? "Not set")

            layout.footerNote(AppConfig.disclaimer)
        }
    }

    // MARK: Litter report

    static func exportLitter(_ litter: Litter) throws -> URL {
        let stem = "\(AppConfig.exportFileStem)-\(slug(litter.displayName))"
        let url = ExportFile.temporaryURL(extension: "pdf", stem: stem)
        try litterData(litter).write(to: url)
        return url
    }

    static func litterData(_ litter: Litter) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        return renderer.pdfData { context in
            var layout = Layout(context: context, page: page, margin: margin)
            layout.startPage(title: "Litter Report", subtitle: litter.displayName)

            layout.section("Timeline")
            let status = litter.status()
            layout.field("Stage", status.stage.title)
            layout.field("Season started", dateOrDash(litter.seasonStart))
            layout.field("First mating", dateOrDash(litter.firstMating))
            layout.field("Last mating", dateOrDash(litter.lastMating))
            layout.field("Ovulation", dateOrDash(litter.ovulationDate))
            if let window = litter.dueWindow {
                layout.field("Due window", "\(DateFormatter.reportDay.string(from: window.earliest)) to \(DateFormatter.reportDay.string(from: window.latest))")
                layout.field("Counted from", window.countedFrom)
            }
            layout.field("Whelped", dateOrDash(litter.whelpedAt))
            layout.field("Go home", dateOrDash(litter.goHomeDate))

            layout.section("Breeding")
            layout.field("Dam", litter.dam?.displayName ?? "Not recorded")
            layout.field("Dam breed", litter.dam?.breed.isEmpty == false ? (litter.dam?.breed ?? "") : "Not recorded")
            layout.field("Sire", litter.sireName.isEmpty ? "Not recorded" : litter.sireName)
            layout.field("Sire owner", litter.sireOwner.isEmpty ? "Not recorded" : litter.sireOwner)

            layout.section("Whelping log")
            let pups = litter.pups
            if pups.isEmpty {
                layout.note("No puppies recorded.")
            } else {
                let columns: [Layout.Column] = [
                    .init(name: "No", width: 34),
                    .init(name: "Time born", width: 120),
                    .init(name: "Sex", width: 60),
                    .init(name: "Collar", width: 84),
                    .init(name: "Birth weight", width: 120),
                    .init(name: "Placenta", width: 76),
                ]
                layout.tableHeader(columns)
                for puppy in pups {
                    layout.tableRow(columns, [
                        "\(puppy.birthOrder)",
                        DateFormatter.report.string(from: puppy.bornAt),
                        puppy.sex.label,
                        puppy.collar.isEmpty ? "-" : puppy.collar,
                        puppy.birthWeightGrams > 0 ? WeightMath.bothUnits(puppy.birthWeightGrams) : "-",
                        puppy.placentaPassed ? "Yes" : "-",
                    ])
                }
            }

            layout.section("Latest weights")
            if pups.isEmpty {
                layout.note("No puppies recorded.")
            } else {
                let columns: [Layout.Column] = [
                    .init(name: "Puppy", width: 110),
                    .init(name: "Weigh-ins", width: 65),
                    .init(name: "Latest", width: 95),
                    .init(name: "Last change", width: 75),
                    .init(name: "Flag", width: 171),
                ]
                layout.tableHeader(columns)
                for puppy in pups {
                    layout.tableRow(columns, [
                        puppy.displayName,
                        "\(puppy.weightSamples.count)",
                        puppy.latestWeightGrams.map { WeightMath.bothUnits($0) } ?? "-",
                        puppy.changeSinceLastWeighIn.map { WeightMath.changeString($0) } ?? "-",
                        puppy.weightConcern?.label ?? "-",
                    ])
                }
                layout.note("A flag means the last weigh-in did not go up. It is a statement about the numbers entered, not a diagnosis.")
            }

            let tasks = litter.healthTasks
            if !tasks.isEmpty {
                layout.section("Worming and vaccination")
                let columns: [Layout.Column] = [
                    .init(name: "Event", width: 130),
                    .init(name: "Due", width: 110),
                    .init(name: "Product", width: 180),
                    .init(name: "Given to", width: 90),
                ]
                layout.tableHeader(columns)
                for task in tasks {
                    layout.tableRow(columns, [
                        task.shortName,
                        DateFormatter.reportDay.string(from: task.dueDate),
                        task.product.isEmpty ? "Not recorded" : task.product,
                        "\(task.doneCount) of \(pups.count)",
                    ])
                }
            }

            if !pups.isEmpty {
                layout.section("Buyers")
                let columns: [Layout.Column] = [
                    .init(name: "Puppy", width: 116),
                    .init(name: "Buyer", width: 130),
                    .init(name: "Deposit", width: 70),
                    .init(name: "Goes home", width: 100),
                    .init(name: "Placed", width: 60),
                ]
                layout.tableHeader(columns)
                for puppy in pups {
                    layout.tableRow(columns, [
                        puppy.displayName,
                        puppy.buyerName.isEmpty ? "-" : puppy.buyerName,
                        puppy.depositPaid ? "Paid" : "-",
                        (puppy.goHomeDate ?? litter.goHomeDate).map { DateFormatter.reportDay.string(from: $0) } ?? "-",
                        puppy.placed ? "Yes" : "-",
                    ])
                }
            }

            if !litter.notes.isEmpty {
                layout.section("Notes")
                layout.paragraph(litter.notes)
            }

            layout.footerNote(AppConfig.disclaimer)
        }
    }

    private static func dateOrDash(_ date: Date?) -> String {
        date.map { DateFormatter.reportDay.string(from: $0) } ?? "Not recorded"
    }

    private static func slug(_ text: String) -> String {
        let allowed = text.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "-" }
        return String(allowed).split(separator: "-").joined(separator: "-")
    }

    // MARK: Layout

    /// A tiny flowing layout: text goes down the page, and anything that would fall off the bottom
    /// starts a new page with the same running head.
    private struct Layout {
        struct Column { let name: String; let width: CGFloat }

        let context: UIGraphicsPDFRendererContext
        let page: CGRect
        let margin: CGFloat
        var y: CGFloat = 0
        var pageNumber = 0
        var title = ""
        var subtitle = ""

        init(context: UIGraphicsPDFRendererContext, page: CGRect, margin: CGFloat) {
            self.context = context
            self.page = page
            self.margin = margin
        }

        mutating func startPage(title: String? = nil, subtitle: String? = nil) {
            if let title { self.title = title }
            if let subtitle { self.subtitle = subtitle }
            context.beginPage()
            pageNumber += 1
            y = margin
            self.title.draw(at: CGPoint(x: margin, y: y), withAttributes: [.font: PDFExporter.titleFont])
            y += 27
            self.subtitle.draw(at: CGPoint(x: margin, y: y),
                               withAttributes: [.font: UIFont.systemFont(ofSize: 12),
                                                .foregroundColor: UIColor.darkGray])
            y += 17
            let stamp = "Prepared \(DateFormatter.report.string(from: .now)) · \(AppConfig.appName) · Page \(pageNumber)"
            stamp.draw(at: CGPoint(x: margin, y: y),
                       withAttributes: [.font: PDFExporter.smallFont, .foregroundColor: UIColor.gray])
            y += 20
            rule()
            y += 8
        }

        mutating func ensure(_ needed: CGFloat) {
            if y + needed > page.height - margin - 24 { startPage() }
        }

        mutating func rule() {
            context.cgContext.setStrokeColor(UIColor.lightGray.cgColor)
            context.cgContext.setLineWidth(0.5)
            context.cgContext.move(to: CGPoint(x: margin, y: y))
            context.cgContext.addLine(to: CGPoint(x: page.width - margin, y: y))
            context.cgContext.strokePath()
        }

        mutating func section(_ name: String) {
            ensure(40)
            y += 8
            name.uppercased().draw(at: CGPoint(x: margin, y: y),
                                   withAttributes: [.font: PDFExporter.sectionFont,
                                                    .foregroundColor: UIColor.black])
            y += 16
            rule()
            y += 6
        }

        /// Label on the left, value in its own column. Never padded into one string: `PDFDocument`
        /// hands padded columns back out of order and a test written against the pair would be a
        /// coin flip (CLAUDE.md rule 7).
        mutating func field(_ label: String, _ value: String) {
            ensure(PDFExporter.rowHeight + 4)
            label.draw(in: CGRect(x: margin, y: y, width: 150, height: PDFExporter.rowHeight),
                       withAttributes: [.font: PDFExporter.bodyFont, .foregroundColor: UIColor.darkGray])
            let width = page.width - margin - (margin + 156)
            let box = CGRect(x: margin + 156, y: y, width: width, height: 200)
            let attributes: [NSAttributedString.Key: Any] = [.font: PDFExporter.bodyFont]
            let height = (value as NSString).boundingRect(
                with: CGSize(width: width, height: 200),
                options: [.usesLineFragmentOrigin], attributes: attributes, context: nil).height
            (value as NSString).draw(with: box, options: [.usesLineFragmentOrigin],
                                     attributes: attributes, context: nil)
            y += max(PDFExporter.rowHeight, ceil(height) + 2)
        }

        mutating func tableHeader(_ columns: [Column]) {
            ensure(PDFExporter.rowHeight * 2)
            var x = margin
            for column in columns {
                column.name.draw(in: CGRect(x: x, y: y, width: column.width, height: PDFExporter.rowHeight),
                                 withAttributes: [.font: PDFExporter.headerFont])
                x += column.width
            }
            y += PDFExporter.rowHeight
            rule()
            y += 3
        }

        /// Rows wrap and grow rather than clip: a cell whose text does not fit the column width gets
        /// a second line instead of silently losing whatever did not fit (the same principle as
        /// CLAUDE.md rule 18, applied to an exported document instead of a live control).
        mutating func tableRow(_ columns: [Column], _ cells: [String]) {
            let attributes: [NSAttributedString.Key: Any] = [.font: PDFExporter.bodyFont]
            var height = PDFExporter.rowHeight
            for (column, text) in zip(columns, cells) {
                let needed = (text as NSString).boundingRect(
                    with: CGSize(width: column.width - 6, height: 200),
                    options: [.usesLineFragmentOrigin], attributes: attributes, context: nil).height
                height = max(height, ceil(needed))
            }
            ensure(height + 4)
            var x = margin
            for (column, text) in zip(columns, cells) {
                (text as NSString).draw(with: CGRect(x: x, y: y, width: column.width - 6, height: height),
                                        options: [.usesLineFragmentOrigin], attributes: attributes, context: nil)
                x += column.width
            }
            y += height + 2
        }

        mutating func note(_ text: String) {
            paragraph(text, font: PDFExporter.smallFont, color: .darkGray)
        }

        mutating func paragraph(_ text: String, font: UIFont = PDFExporter.bodyFont, color: UIColor = .black) {
            let width = page.width - margin * 2
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            let height = ceil((text as NSString).boundingRect(
                with: CGSize(width: width, height: 400),
                options: [.usesLineFragmentOrigin], attributes: attributes, context: nil).height)
            ensure(height + 6)
            (text as NSString).draw(with: CGRect(x: margin, y: y, width: width, height: height + 4),
                                    options: [.usesLineFragmentOrigin], attributes: attributes, context: nil)
            y += height + 6
        }

        mutating func footerNote(_ text: String) {
            y += 10
            ensure(40)
            rule()
            y += 6
            paragraph(text, font: PDFExporter.smallFont, color: .darkGray)
        }
    }
}
