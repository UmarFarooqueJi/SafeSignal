# Contributing to SafeSignal

Thank you for your interest in contributing to **SafeSignal**! We welcome contributions from developers, security researchers, and designers worldwide to help build the best open-source anti-fraud and mobile security platform.

---

## 🚀 How to Get Started

### 1. Prerequisites
- **Flutter SDK**: 3.10.7 or higher
- **Dart SDK**: ^3.10.7
- **Android Studio / VS Code** with Flutter extensions installed
- **Git**

### 2. Fork & Clone
```bash
git clone https://github.com/umarfarooqueji-byte/SafeSignal.git
cd SafeSignal/safesignal
```

### 3. Environment Setup
Copy `.env.example` to `.env` and provide your test keys:
```bash
cp .env.example .env
```
*(Note: Never commit your `.env` file!)*

### 4. Install Dependencies
```bash
flutter pub get
```

### 5. Run the Application
```bash
flutter run
```

---

## 🛠️ Code Conventions & Guidelines

- **Architecture**: We follow a clean feature-driven architecture located in `lib/features/` with shared logic in `lib/core/`.
- **State Management**: We use `Riverpod` (`flutter_riverpod`) for reactive state management.
- **Routing**: Navigation is strictly managed via `GoRouter` in `lib/core/router/app_router.dart`.
- **Null Safety**: All Dart code must be sound null-safe with zero analyzer warnings.
- **Testing**: Ensure all unit and widget tests pass before submitting a PR:
  ```bash
  flutter test
  flutter analyze
  ```

---

## 📦 Pull Request Process

1. **Create a branch**: `git checkout -b feature/amazing-feature` or `git checkout -b fix/issue-description`.
2. **Commit your changes**: Write clear, descriptive commit messages following Conventional Commits (e.g. `feat: add biometric vault lock`, `fix: handle null phone state on Android 14`).
3. **Push to branch**: `git push origin feature/amazing-feature`.
4. **Open a Pull Request**: Submit your PR with a clear summary of changes, linked issues, and screenshots if UI changes were made.

---

## 🔒 Reporting Vulnerabilities
If you discover a security vulnerability within SafeSignal, please review our [SECURITY.md](SECURITY.md) for reporting guidelines.
