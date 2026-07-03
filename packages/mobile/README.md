# OpenCode Mobile

AI coding agent for Android. Write code, manage projects, sync with GitHub — all from your phone. No server needed.

[![Build APK](https://github.com/anomalyco/opencode/actions/workflows/mobile-apk.yml/badge.svg)](https://github.com/anomalyco/opencode/actions/workflows/mobile-apk.yml)

## Download

Latest APK from [GitHub Actions](https://github.com/anomalyco/opencode/actions/workflows/mobile-apk.yml) → click latest run → Artifacts → `opencode-mobile-apks`.

## How It Works

```
Phone (Flutter)                GitHub                     PC
┌──────────────┐            ┌──────────┐            ┌──────────┐
│ AgentService │  git pull  │   Repo   │  git pull  │ OpenCode │
│ DeepSeek API ◄────────────│          │────────────►   CLI    │
│ 7 tools      │──git push─►│          │◄──git push─│          │
│ git clone    │            │          │            │          │
└──────────────┘            └──────────┘            └──────────┘
```

1. Clone a GitHub project on your phone
2. Chat with the AI agent — it reads/writes files, searches code, commits
3. Pull on PC, continue working
4. Push from PC, pull on phone — full sync

## Setup

### Prerequisites
- Flutter SDK 3.24+
- Android Studio with SDK 24+
- DeepSeek API key ([platform.deepseek.com](https://platform.deepseek.com))
- GitHub personal access token (repo scope)

### Build from Source
```bash
cd packages/mobile
flutter pub get
flutter run                    # Debug on device
flutter build apk --release    # Release APK
```

Install `build/app/outputs/flutter-apk/app-release.apk` on your phone.

### On First Launch
1. Tap Settings (gear icon)
2. Enter DeepSeek API key
3. Enter GitHub token + username
4. Clone a project from your GitHub
5. Start coding

## Features

- **AI Agent**: DeepSeek V4 Pro via streaming API
- **7 Tools**: read_file, write_file, list_files, delete_file, search_code, git_sync, git_status
- **GitHub Sync**: clone, pull, commit, push — your repo is the hub
- **Code Blocks**: Markdown rendering with syntax highlighting
- **Dark Theme**: GitHub-inspired design
- **Offline Files**: All project files stored locally on device

## Architecture

```
packages/mobile/
├── lib/
│   ├── main.dart                  # App entry, theme config
│   ├── models/
│   │   └── message.dart           # Chat message model
│   ├── services/
│   │   ├── agent_service.dart     # AI agent + DeepSeek API
│   │   ├── git_service.dart       # Git operations (system git)
│   │   ├── storage_service.dart   # File I/O + search
│   │   └── settings_service.dart  # SharedPreferences
│   └── screens/
│       ├── chat_screen.dart       # Main chat UI
│       ├── projects_screen.dart   # Project list + clone
│       └── settings_screen.dart   # API keys config
├── android/                       # Android platform
├── pubspec.yaml                   # Dependencies
└── .github/workflows/mobile-apk.yml  # CI: auto-build APK
```

## Requirements

- Android 7.0+ (API 24)
- ~50 MB storage
- Internet for AI API + GitHub sync
