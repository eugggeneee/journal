import Foundation

public enum BellKind: String, CaseIterable, Codable, Sendable {
    case weekdays, saturday, shortened
    public var title: String {
        switch self { case .weekdays: "Будни"; case .saturday: "Суббота"; case .shortened: "Сокращённые" }
    }
}

public struct Bell: Codable, Equatable, Sendable, Identifiable {
    public var number: Int
    public var start: Int
    public var end: Int
    public var breakStart: Int?
    public var breakEnd: Int?
    public var id: Int { number }
    public init(_ number: Int, _ start: Int, _ end: Int, _ breakStart: Int? = nil, _ breakEnd: Int? = nil) {
        self.number = number; self.start = start; self.end = end
        self.breakStart = breakStart; self.breakEnd = breakEnd
    }
}

public struct BellProfile: Codable, Equatable, Sendable {
    public var slots: [Bell]
    public var lunchAfter: Int
    public init(slots: [Bell] = [], lunchAfter: Int = 0) { self.slots = slots; self.lunchAfter = lunchAfter }
    public func bell(_ number: Int) -> Bell? { slots.first { $0.number == number } }
    public var validationError: String? {
        guard slots.count <= 7, Set(slots.map(\.number)).count == slots.count else { return "Номера пар не должны повторяться." }
        let sorted = slots.sorted { $0.number < $1.number }
        for (i, bell) in sorted.enumerated() {
            guard (1...7).contains(bell.number), (0...1439).contains(bell.start), (1...1439).contains(bell.end), bell.end > bell.start else {
                return "\(bell.number)-я пара: конец должен быть позже начала, в пределах одного дня."
            }
            if bell.breakStart != nil || bell.breakEnd != nil {
                guard let a = bell.breakStart, let b = bell.breakEnd, a > bell.start, b < bell.end, b > a else {
                    return "\(bell.number)-я пара: перерыв должен находиться внутри пары."
                }
            }
            if i > 0 && bell.start < sorted[i - 1].end { return "\(bell.number)-я пара начинается раньше окончания предыдущей." }
        }
        if lunchAfter != 0 && !slots.contains(where: { $0.number == lunchAfter }) { return "Выберите существующую пару перед обедом." }
        return nil
    }

    public static let weekdayOne = BellProfile(slots: [
        Bell(1, 500, 600, 545, 555), Bell(2, 610, 710, 655, 665), Bell(3, 740, 840, 785, 795),
        Bell(4, 850, 945, 895, 900), Bell(5, 955, 1050, 1000, 1005),
        Bell(6, 1060, 1155, 1105, 1110), Bell(7, 1165, 1260, 1210, 1215)
    ], lunchAfter: 2)
    public static let weekdayTwo = BellProfile(slots: [
        Bell(1, 500, 600, 545, 555), Bell(2, 610, 710, 655, 665), Bell(3, 720, 840, 765, 795),
        Bell(4, 850, 945, 895, 900), Bell(5, 955, 1050, 1000, 1005),
        Bell(6, 1060, 1155, 1105, 1110), Bell(7, 1165, 1260, 1210, 1215)
    ])
    public static let saturday = BellProfile(slots: [
        Bell(1, 500, 595, 545, 550), Bell(2, 605, 700, 650, 655), Bell(3, 710, 805, 755, 760),
        Bell(4, 815, 910, 860, 865), Bell(5, 920, 1015, 965, 970), Bell(6, 1025, 1120, 1070, 1075)
    ])
    /// User-provided college notice, 6 November 2026; no internal breaks shown.
    public static let shortened = BellProfile(slots: (1...6).map { Bell($0, 500 + ($0 - 1) * 70, 560 + ($0 - 1) * 70) })

    public static func generated(count: Int, start: Int, studyMinutes: Int, gap: Int, internalBreak: Int,
                                 lunchAfter: Int, lunchMinutes: Int) -> BellProfile {
        var slots: [Bell] = []
        var next = start
        for number in 1...max(1, min(7, count)) {
            let end = next + studyMinutes + internalBreak
            guard next >= 0, end < 1440, studyMinutes > 0 else { break }
            let a = internalBreak > 0 ? next + studyMinutes / 2 : nil
            slots.append(Bell(number, next, end, a, a.map { $0 + internalBreak }))
            next = end + (number == lunchAfter ? lunchMinutes : gap)
        }
        return BellProfile(slots: slots, lunchAfter: slots.contains(where: { $0.number == lunchAfter }) ? lunchAfter : 0)
    }
}

public struct DayPhase: Equatable, Sendable {
    public var title: String
    public var detail: String
    public var minutes: Int
    public var progress: Double
    public var lesson: Int?
    public var isFinished: Bool

    public static func current(schedule: Schedule, profile: BellProfile, minute: Int) -> DayPhase? {
        let slots = schedule.lessons.compactMap { profile.bell($0.number) }.sorted { $0.start < $1.start }
        guard let first = slots.first, let last = slots.last else { return nil }
        if minute < first.start {
            return DayPhase(title: "Скоро начало", detail: "\(first.number)-я пара в \(timeText(first.start))", minutes: first.start - minute, progress: 0, lesson: first.number, isFinished: false)
        }
        for (index, slot) in slots.enumerated() {
            if minute >= slot.start && minute < slot.end {
                if let a = slot.breakStart, let b = slot.breakEnd, minute >= a && minute < b {
                    return DayPhase(title: b - a >= 20 ? "Время обеда" : "Небольшой перерыв", detail: "Продолжение \(slot.number)-й пары в \(timeText(b))", minutes: b - minute, progress: Double(minute - a) / Double(b - a), lesson: slot.number, isFinished: false)
                }
                return DayPhase(title: "Идёт \(slot.number)-я пара", detail: "До \(timeText(slot.end))", minutes: slot.end - minute, progress: Double(minute - slot.start) / Double(slot.end - slot.start), lesson: slot.number, isFinished: false)
            }
            if index + 1 < slots.count {
                let next = slots[index + 1]
                if minute >= slot.end && minute < next.start {
                    let title = next.number - slot.number > 1 ? "Свободное окно" : profile.lunchAfter == slot.number ? "Время обеда" : "Перерыв"
                    return DayPhase(title: title, detail: "\(next.number)-я пара в \(timeText(next.start))", minutes: next.start - minute, progress: Double(minute - slot.end) / Double(next.start - slot.end), lesson: next.number, isFinished: false)
                }
            }
        }
        return DayPhase(title: "На сегодня всё", detail: "Последняя пара закончилась в \(timeText(last.end))", minutes: 0, progress: 1, lesson: nil, isFinished: true)
    }
}
