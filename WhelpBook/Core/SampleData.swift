import Foundation
import SwiftData

#if DEBUG
/// A realistic litter for screenshots and manual testing: a dam three seasons deep, whelped three
/// weeks ago, seven puppies, one of whom did not gain overnight.
enum SampleData {
    static func insert(into context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: today) ?? today }

        let dam = Dam(name: "Juno", breed: "Labrador Retriever",
                      dateOfBirth: day(-1460), registration: "KC AX01234567",
                      notes: "Free whelper, settles best in the utility room.")
        context.insert(dam)

        for (offset, note) in [(-560, "First season, quiet."), (-386, "Ten days, heavy."), (-212, "Bred on this one.")] {
            let heat = HeatCycle(startDate: day(offset), endDate: day(offset + 18),
                                 observations: note)
            heat.dam = dam
            context.insert(heat)
        }

        let litter = Litter(name: "Juno x Ridge", sireName: "Ridge", seasonStart: day(-212))
        litter.dam = dam
        litter.sireOwner = "M. Ellery"
        litter.sireRegistration = "KC BZ07761122"
        litter.firstMating = day(-202)
        litter.lastMating = day(-200)
        litter.ovulationDate = day(-203)
        litter.whelpedAt = day(-21)
        litter.notes = "Whelped overnight, no intervention."
        context.insert(litter)

        let collars: [(String, PuppySex, Double, String)] = [
            ("Red", .male, 452, "Black, small white chest flash"),
            ("Blue", .male, 431, "Black"),
            ("Green", .female, 398, "Yellow, dark ears"),
            ("Yellow", .female, 412, "Yellow"),
            ("Orange", .male, 470, "Black, white toe"),
            ("Purple", .female, 366, "Yellow, pale"),
            ("White", .female, 389, "Black, white blaze"),
        ]

        var puppies: [Puppy] = []
        for (index, entry) in collars.enumerated() {
            let born = calendar.date(byAdding: .minute, value: index * 37,
                                     to: calendar.date(bySettingHour: 23, minute: 10, second: 0, of: day(-22)) ?? day(-22)) ?? day(-21)
            let puppy = Puppy(birthOrder: index + 1, bornAt: born, sex: entry.1,
                              collar: entry.0, birthWeightGrams: entry.2)
            puppy.markings = entry.3
            puppy.placentaPassed = index != 5
            puppy.litter = litter
            context.insert(puppy)
            puppies.append(puppy)

            // Three weeks of daily weights. Everyone climbs; the purple collar girl flattens out
            // on the last day, which is exactly the case the weight screen exists to surface.
            var grams = entry.2
            for age in 1...21 {
                let slowing = (index == 5 && age >= 20)
                grams += slowing ? 0 : Double(Int.random(in: 46...74))
                let when = calendar.date(bySettingHour: 8, minute: 15, second: 0, of: day(-21 + age)) ?? day(-21 + age)
                guard when <= .now else { break }
                let weighIn = WeighIn(date: when, grams: grams.rounded())
                weighIn.puppy = puppy
                context.insert(weighIn)
            }
        }

        for item in HealthSchedule.tasks(whelpedAt: day(-21)) {
            let task = HealthTask(name: item.name, dueDate: item.dueDate, sortIndex: item.sortIndex)
            task.litter = litter
            if item.sortIndex == 0 { task.product = "Panacur oral suspension, as directed by the practice" }
            context.insert(task)
            if item.dueDate <= .now {
                for puppy in puppies {
                    let given = HealthGiven(givenOn: item.dueDate)
                    given.task = task
                    given.puppy = puppy
                    context.insert(given)
                }
            }
        }

        litter.goHomeDate = day(35)
        puppies[0].buyerName = "The Ashworths"
        puppies[0].buyerContact = "07700 900412"
        puppies[0].depositPaid = true
        puppies[0].depositAmount = 300
        puppies[1].buyerName = "R. Okafor"
        puppies[1].depositPaid = true

        try? context.save()
    }
}
#endif
