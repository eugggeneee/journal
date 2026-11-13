import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum PageOutcome: Sendable {
    case page(ParsedPage)
    case rest
    case unpublished
    case offline(String)
    case failure(String)
}

/// Only follows redirects within the same public HTTPS schedule host.
private final class ScheduleRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(request.url?.scheme == "https" && request.url?.host == "bseumtc.by" ? request : nil)
    }
}

public actor ScheduleClient {
    public typealias Transport = @Sendable (URLRequest) async throws -> (Data, Int)
    private let transport: Transport
    private var pending: [Day: Task<PageOutcome, Never>] = [:]
    public init(transport: Transport? = nil) {
        if let transport { self.transport = transport }
        else {
            let config = URLSessionConfiguration.ephemeral
            config.httpCookieStorage = nil
            config.httpShouldSetCookies = false
            config.urlCache = nil
            config.timeoutIntervalForRequest = 15
            config.timeoutIntervalForResource = 20
            let session = URLSession(configuration: config, delegate: ScheduleRedirects(), delegateQueue: nil)
            self.transport = { request in
                let (data, response) = try await session.data(for: request)
                return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
            }
        }
    }
    public static func url(for day: Day) -> URL {
        URL(string: String(format: "https://bseumtc.by/schedule/public/rasp/PODNAM%%20%02d_%02d.htm", day.number, day.month))!
    }
    public func page(_ day: Day) async -> PageOutcome {
        if day.isSunday { return .rest }
        if let task = pending[day] { return await task.value }
        let transport = self.transport
        let task = Task<PageOutcome, Never> {
            var request = URLRequest(url: Self.url(for: day), cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
            request.setValue("text/html", forHTTPHeaderField: "Accept")
            request.httpShouldHandleCookies = false
            do {
                let (bytes, code) = try await transport(request)
                if code == 403 || code == 404 { return .unpublished }
                guard code == 200 else { return .failure("Ошибка сайта (\(code)).") }
                guard !bytes.isEmpty else { return .unpublished }
                guard bytes.count <= 8 * 1024 * 1024 else { return .failure("Страница сайта слишком большая.") }
                let html = try ScheduleParser.decode(bytes)
                let page = ScheduleParser.parse(html)
                guard page.hasText, !page.rows.isEmpty, page.matches(day) else { return .unpublished }
                return .page(page)
            } catch let error as URLError {
                if error.code == .cancelled { return .failure("Загрузка отменена.") }
                return .offline(error.code == .timedOut ? "Сайт не отвечает. Попробуйте позже." : "Нет подключения к интернету.")
            } catch { return .failure(error.localizedDescription) }
        }
        pending[day] = task
        let result = await task.value
        pending[day] = nil
        return result
    }
    public func discoverGroups(today: Day = Day()) async -> (groups: [String], message: String?) {
        for offset in Array(0...5) + Array((-6 ... -1).reversed()) {
            if Task.isCancelled { return ([], nil) }
            switch await page(today.adding(offset)) {
            case .page(let page): return (page.groups, nil)
            case .offline(let message): return ([], message + " Можно ввести группу вручную.")
            case .failure(let message): return ([], message + " Можно ввести группу вручную.")
            default: continue
            }
        }
        return ([], "Список групп пока недоступен. Введите номер вручную.")
    }
}
