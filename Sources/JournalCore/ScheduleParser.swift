import Foundation

public struct ScheduleRow: Equatable, Sendable {
    public var group: String
    public var number: Int
    public var entry: LessonEntry
}

public struct ParsedPage: Sendable {
    public var rows: [ScheduleRow]
    public var dates: Set<Day>
    public var hasText: Bool
    public var groups: [String] { Array(Set(rows.map(\.group))).sorted { (Int($0) ?? 0) < (Int($1) ?? 0) } }
    public func matches(_ day: Day) -> Bool { dates.isEmpty || dates.contains(day) }
    public func lessons(for group: String) -> [Lesson] {
        let grouped = Dictionary(grouping: rows.filter { $0.group == group }, by: \.number)
        return grouped.keys.sorted().map { number in
            var seen: Set<LessonEntry> = []
            return Lesson(number: number, entries: grouped[number]!.map(\.entry).filter { seen.insert($0).inserted })
        }
    }
}

public enum ScheduleParser {
    public static func decode(_ bytes: Data) throws -> String {
        let prefix = String(decoding: bytes.prefix(4096), as: UTF8.self).lowercased()
        let explicitUTF8 = prefix.range(of: #"charset\s*=\s*["']?utf-?8"#, options: .regularExpression) != nil
        let hasCharset = prefix.range(of: #"charset\s*="#, options: .regularExpression) != nil
        if explicitUTF8, let string = String(data: bytes, encoding: .utf8) { return string }
        if !hasCharset, let string = String(data: bytes, encoding: .utf8) { return string }
        if let string = String(data: bytes, encoding: .windowsCP1251) { return string }
        throw JournalError("Не удалось прочитать кодировку страницы.")
    }

    public static func parse(_ html: String) -> ParsedPage {
        var text = replace(html, #"<!--[\s\S]*?-->"#, "")
        text = replace(text, #"<(style|script)\b[^>]*>[\s\S]*?</\1\s*>"#, "")
        if let body = text.range(of: #"<body\b[^>]*>"#, options: [.regularExpression, .caseInsensitive]) {
            text = String(text[body.upperBound...])
        }
        // Word inserts physical CR/LF inside spans and cells. Only markup defines
        // a record boundary; splitting by source lines loses the group column.
        let boundary = "\u{001e}"
        let hasParagraphs = text.range(of: #"<p\b|<tr\b"#, options: [.regularExpression, .caseInsensitive]) != nil
        text = replace(text, #"</p\s*>|</tr\s*>"#, boundary)
        text = replace(text, #"<br\s*/?>"#, " ")
        text = replace(text, #"<[^>]+>"#, "")
        text = entities(text)
        let chunks = hasParagraphs ? text.components(separatedBy: boundary) : text.components(separatedBy: .newlines)
        let lines = chunks.map {
            replace($0.replacingOccurrences(of: "\u{00a0}", with: " "), #"\s+"#, " ").trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
        var group: String?
        var number: Int?
        var rows: [ScheduleRow] = []
        var header: [String] = []
        for line in lines {
            guard line.contains("│") else { header.append(line); continue }
            var cells = line.components(separatedBy: "│").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            if cells.first == "" { cells.removeFirst() }
            if cells.last == "" { cells.removeLast() }
            guard cells.count == 5 else { continue }
            guard cells[0].isEmpty || validGroup(cells[0]),
                  cells[1].isEmpty || (cells[1].count <= 2 && cells[1].utf8.allSatisfy { (48...57).contains($0) }) else { continue }
            if !cells[0].isEmpty {
                number = nil
                group = cells[0]
            }
            if !cells[1].isEmpty { number = Int(cells[1]) }
            guard let group, let number, (1...7).contains(number), !cells[2].isEmpty, cells[2] != "√" else { continue }
            rows.append(ScheduleRow(group: group, number: number, entry: LessonEntry(subject: cells[2], room: cells[3], teacher: cells[4])))
        }
        let headerText = header.joined(separator: " ")
        let regex = try! NSRegularExpression(pattern: #"(?<!\d)(\d{2})\.(\d{2})\.(\d{4}|\d{2})(?!\d)"#)
        var dates: Set<Day> = []
        for match in regex.matches(in: headerText, range: NSRange(headerText.startIndex..., in: headerText)) {
            func part(_ n: Int) -> String { String(headerText[Range(match.range(at: n), in: headerText)!]) }
            let year = part(3).count == 2 ? "20" + part(3) : part(3)
            if let day = Day("\(year)-\(part(2))-\(part(1))") { dates.insert(day) }
        }
        return ParsedPage(rows: rows, dates: dates, hasText: !lines.isEmpty)
    }

    private static func replace(_ text: String, _ pattern: String, _ replacement: String) -> String {
        text.replacingOccurrences(of: pattern, with: replacement, options: [.regularExpression, .caseInsensitive])
    }
    private static func entities(_ text: String) -> String {
        let named: [String: String] = ["nbsp": " ", "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "ndash": "–", "mdash": "—", "ensp": " ", "emsp": " ", "thinsp": " ", "shy": "", "hellip": "…"]
        let regex = try! NSRegularExpression(pattern: #"&(#x[0-9a-fA-F]+|#\d+|[a-zA-Z]+);"#)
        var result = text
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let tokenRange = Range(match.range(at: 1), in: text), let fullRange = Range(match.range, in: result) else { continue }
            let token = String(text[tokenRange])
            var value = named[token.lowercased()]
            if token.lowercased().hasPrefix("#x"), let code = UInt32(token.dropFirst(2), radix: 16), let scalar = UnicodeScalar(code) { value = String(scalar) }
            else if token.hasPrefix("#"), let code = UInt32(token.dropFirst()), let scalar = UnicodeScalar(code) { value = String(scalar) }
            if let value { result.replaceSubrange(fullRange, with: value) }
        }
        return result
    }
}
