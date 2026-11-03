<div align="center">

<img src="assets/branding/hero.png" alt="Journal Banner" width="100%" style="border-radius: 12px; margin-bottom: 24px;">

# JOURNAL

### Minimalist Personal Archive & Visual Diary

<p align="center">
  <img src="https://img.shields.io/badge/FLUTTER-3.0%2B-02569B?style=for-the-badge&logo=flutter&logoColor=white&colorA=1D2021&colorB=458588" alt="Flutter">
  <img src="https://img.shields.io/badge/MATERIAL_DESIGN-3_EXPRESSIVE-757575?style=for-the-badge&logo=materialdesign&logoColor=white&colorA=1D2021&colorB=D65D0E" alt="Material 3">
  <img src="https://img.shields.io/badge/PALETTE-GRUVBOX-282828?style=for-the-badge&colorA=1D2021&colorB=FABD2F" alt="Gruvbox">
  <img src="https://img.shields.io/badge/LICENSE-MIT-282828?style=for-the-badge&colorA=1D2021&colorB=8EC07C" alt="License">
</p>

<br>

<p align="center">
  <strong>Journal</strong> — кроссплатформенное приложение для ведения цифровых дневников и каталогизации фотоархивов.<br>Проект объединяет эстетику аналоговой фотографии, палитру Gruvbox и принципы адаптивного интерфейса Material You.
</p>

<br>

<p align="center">
  <a href="https://github.com/euggene/journal/releases/latest">
    <img src="assets/branding/btn-android.png" alt="Download for Android" height="54">
  </a>
  &nbsp;&nbsp;&nbsp;
  <a href="https://github.com/euggene/journal/releases/latest">
    <img src="assets/branding/btn-iphone.png" alt="Download for iOS" height="54">
  </a>
</p>

</div>

---

## Архитектура и Дизайн

### Визуальная концепция
Дизайн-система основана на рекомендациях Material Design 3 Expressive с интеграцией палитры Gruvbox. Выбор контрастов и оттенков снижает нагрузку на зрение при длительном чтении и просмотре снимков.

* **Контрастность и типографика:** Использование контрастных акцентов для навигации и выразительных гарнитур для заголовков.
* **Темы интерфейса:** Автоматическое переключение между тёмным и светлым режимами с сохранением единой тональности.
* **Адаптивная верстка:** Корректное отображение элементов на экранах с различной плотностью пикселей и диагональю.

### Ключевые модули
1. **Модуль хроники:** Структурированное хранение текстовых записей и метаданных.
2. **Галерея и архивация:** Каталогизация изображений с поддержкой фильтрации по датам и тегам.
3. **Локальное хранилище:** Приоритет локального сохранения данных без обязательной синхронизации с внешними серверами.

---

## Технические Характеристики

| Компонент | Стек / Технология | Назначение |
| :--- | :--- | :--- |
| **Ядро** | Flutter SDK | Кроссплатформенный фреймворк |
| **Язык** | Dart | Основной язык разработки |
| **UI Framework** | Material 3 (Expressive) | Компоненты интерфейса |
| **Цветовая схема** | Gruvbox Palette | Графическая палитра |
| **Сборка** | GitHub Actions | Автоматизация CI/CD |

---

## Развертывание и Сборка

### Предварительные требования
* Flutter SDK версии `3.0.0` или выше
* Настроенная среда разработки (Android Studio / VS Code)
* Подключенное устройство или эмулятор (Android / iOS)

### Пошаговая установка

1. Клонируйте репозиторий:
   ```bash
   git clone https://github.com/euggene/journal.git
   ```

2. Перейдите в каталог проекта:
   ```bash
   cd journal
   ```

3. Загрузите зависимости:
   ```bash
   flutter pub get
   ```

4. Запустите сборку:
   ```bash
   flutter run
   ```

---

## Вклад в Проект

Если вы хотите предложить изменения или сообщить об ошибке:

1. Создайте ответвление (Fork) репозитория.
2. Создайте рабочую ветку:
   ```bash
   git checkout -b feature/proposal-name
   ```
3. Зафиксируйте изменения:
   ```bash
   git commit -m 'feat: Add new proposal'
   ```
4. Отправьте изменения в свой репозиторий:
   ```bash
   git push origin feature/proposal-name
   ```
5. Откройте Pull Request с подробным описанием изменений.

---

<div align="center">

`Journal Project` &nbsp;&bull;&nbsp; Open Source Software &nbsp;&bull;&nbsp; MIT License

</div>