import SwiftUI
import UIKit

/// Public UIKit implementation of the compact Apple welcome-sheet pattern.
/// No OnBoardingKit loading or private selectors are used.
struct NativeWelcome: UIViewControllerRepresentable {
    let firstRun: Bool
    var continueAction: () -> Void
    func makeUIViewController(context: Context) -> JournalWelcomeController {
        JournalWelcomeController(firstRun: firstRun, continueAction: continueAction)
    }
    func updateUIViewController(_ controller: JournalWelcomeController, context: Context) {
        controller.continueAction = continueAction
    }
}

@MainActor
final class JournalWelcomeController: UIViewController {
    private let firstRun: Bool
    var continueAction: () -> Void
    init(firstRun: Bool, continueAction: @escaping () -> Void) {
        self.firstRun = firstRun
        self.continueAction = continueAction
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let accent = UIColor(named: "AccentColor") ?? .systemOrange
        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = false
        scroll.showsVerticalScrollIndicator = false
        scroll.accessibilityIdentifier = "welcome-content"
        let content = stack(spacing: 24)
        let heading = label(firstRun ? "Добро пожаловать в Journal" : "Что нового в Journal", size: 20, bold: true)
        heading.accessibilityTraits.insert(.header)
        content.addArrangedSubview(heading)
        content.addArrangedSubview(feature("calendar", "Расписание под рукой", firstRun
            ? "Выберите группу: занятия, аудитории и преподаватели появятся в расписании. Загруженные дни доступны без интернета."
            : "Исправлена загрузка групп и занятий с сайта колледжа. Расписание снова можно выбрать из списка или найти вручную.", accent: accent))
        content.addArrangedSubview(feature("clock", firstRun ? "Время на вашей стороне" : "Подробная карточка занятия",
            "Смотрите, сколько осталось до перерыва и конца пары. Кабинет, преподаватель и время звонков — в той же карточке.", accent: accent))
        content.addArrangedSubview(feature("chart.bar", "Оценки и пропуски",
            "Средний балл и показатели по предметам, уважительные и неуважительные часы, лимиты месяца и семестра — всё по порядку.", accent: accent))

        let footer = stack(spacing: 14)
        let privacy = stack(spacing: 7)
        let privacyIcon = UIImageView(image: UIImage(systemName: "hand.raised.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)))
        privacyIcon.tintColor = accent
        privacyIcon.contentMode = .left
        privacyIcon.isAccessibilityElement = false
        privacyIcon.heightAnchor.constraint(equalToConstant: 22).isActive = true
        privacy.addArrangedSubview(privacyIcon)
        let privacyText = label("Личные записи хранятся на iPhone. Интернет нужен только для расписания с сайта колледжа. Journal — неофициальное приложение.", size: 11)
        privacyText.textColor = .secondaryLabel
        privacy.addArrangedSubview(privacyText)
        footer.addArrangedSubview(privacy)

        var configuration = UIButton.Configuration.filled()
        configuration.title = "Продолжить"
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = accent
        configuration.baseForegroundColor = UIColor { $0.userInterfaceStyle == .dark ? .black : .white }
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var result = incoming
            result.font = UIFont.boldSystemFont(ofSize: 17)
            return result
        }
        let button = UIButton(configuration: configuration)
        button.accessibilityIdentifier = "welcome-continue"
        button.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
        footer.addArrangedSubview(button)

        [scroll, footer].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; view.addSubview($0) }
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(content)
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: safe.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -24),
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 40),
            content.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 28),
            content.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -28),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -8),
            content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -56),
            footer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            footer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            footer.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -20)
        ])
    }

    @objc private func continueTapped() { continueAction() }
    private func stack(spacing: CGFloat) -> UIStackView {
        let result = UIStackView()
        result.axis = .vertical
        result.spacing = spacing
        return result
    }
    private func label(_ text: String, size: CGFloat, bold: Bool = false) -> UILabel {
        let result = UILabel()
        result.text = text
        result.numberOfLines = 0
        result.font = bold ? .boldSystemFont(ofSize: size) : .systemFont(ofSize: size)
        result.adjustsFontForContentSizeCategory = false
        result.textColor = .label
        result.setContentCompressionResistancePriority(.required, for: .vertical)
        return result
    }
    private func feature(_ symbol: String, _ title: String, _ detail: String, accent: UIColor) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .top
        row.spacing = 12
        let icon = UIImageView(image: UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .regular)))
        icon.tintColor = accent
        icon.contentMode = .scaleAspectFit
        icon.widthAnchor.constraint(equalToConstant: 28).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 28).isActive = true
        let text = stack(spacing: 4)
        text.addArrangedSubview(label(title, size: 16, bold: true))
        let description = label(detail, size: 13)
        description.textColor = .secondaryLabel
        text.addArrangedSubview(description)
        row.addArrangedSubview(icon)
        row.addArrangedSubview(text)
        row.isAccessibilityElement = true
        row.accessibilityLabel = "\(title). \(detail)"
        return row
    }
}
