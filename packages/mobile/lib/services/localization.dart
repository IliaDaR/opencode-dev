/// Simple localization — Russian + English
class AppLocalization {
  static String _lang = "en";

  static String get current => _lang;
  static set current(String v) => _lang = v;

  static const Map<String, Map<String, String>> _strings = {
    "welcome": {"en": "Welcome to OpenCode", "ru": "Добро пожаловать в OpenCode"},
    "welcome_desc": {
      "en": "Your AI coding agent on Android. 64 skill domains, 55+ tools, 6 sub-agents. Powered by DeepSeek.",
      "ru": "Твой AI-агент для кодинга на Android. 64 домена знаний, 55+ инструментов, 6 саб-агентов. Работает на DeepSeek."
    },
    "select_language": {"en": "Select Language", "ru": "Выберите язык"},
    "english": {"en": "English", "ru": "Английский"},
    "russian": {"en": "Russian", "ru": "Русский"},
    "continue": {"en": "Continue", "ru": "Продолжить"},
    "next": {"en": "Next", "ru": "Далее"},
    "back": {"en": "Back", "ru": "Назад"},
    "start": {"en": "Start", "ru": "Начать"},
    "settings": {"en": "Settings", "ru": "Настройки"},
    "save": {"en": "Save", "ru": "Сохранить"},
    "saved": {"en": "Saved", "ru": "Сохранено"},
    "cancel": {"en": "Cancel", "ru": "Отмена"},
    "close": {"en": "Close", "ru": "Закрыть"},
    "clone": {"en": "Clone", "ru": "Клонировать"},
    "send": {"en": "Send", "ru": "Отправить"},
    "projects": {"en": "Projects", "ru": "Проекты"},
    "no_projects": {"en": "No projects yet", "ru": "Пока нет проектов"},
    "clone_desc": {"en": "Clone a project from GitHub to get started", "ru": "Клонируйте проект с GitHub чтобы начать"},
    "tap_to_open": {"en": "Tap to open", "ru": "Нажмите чтобы открыть"},
    "repo_name": {"en": "repository-name", "ru": "имя-репозитория"},
    "scanning": {"en": "Scanning project...", "ru": "Сканирую проект..."},
    "syncing": {"en": "Syncing with GitHub...", "ru": "Синхронизация с GitHub..."},
    "session_restored": {"en": "Session restored", "ru": "Сессия восстановлена"},
    "ready": {"en": "Ready. What are we working on?", "ru": "Готов. Над чем работаем?"},
    "mode": {"en": "Mode", "ru": "Режим"},
    "auto_detect": {"en": "Auto detect", "ru": "Авто"},
    "brainstorm": {"en": "Brainstorm ideas", "ru": "Генерация идей"},
    "research": {"en": "Research", "ru": "Исследование"},
    "architect": {"en": "Plan architecture", "ru": "Архитектура"},
    "write_code": {"en": "Write code", "ru": "Написать код"},
    "debug": {"en": "Debug", "ru": "Отладка"},
    "refactor": {"en": "Refactor", "ru": "Рефакторинг"},
    "sync_pc": {"en": "Sync with PC", "ru": "Синхронизация с ПК"},
    "files": {"en": "Files", "ru": "Файлы"},
    "ask_hint": {"en": "Ask OpenCode...", "ru": "Спроси OpenCode..."},
    "thinking": {"en": "Thinking...", "ru": "Думаю..."},
    "you": {"en": "You", "ru": "Вы"},
    "cloning": {"en": "Cloning...", "ru": "Клонирую..."},
    "memory_cleared": {"en": "Memory cleared. Fresh session.", "ru": "Память очищена. Новая сессия."},
    "uncommitted": {"en": "Uncommitted changes detected", "ru": "Обнаружены незакоммиченные изменения"},
    "offline_pending": {"en": "offline actions pending", "ru": "оффлайн-действий ожидают"},
    "synced": {"en": "Synced", "ru": "Синхронизировано"},
    "sync_failed": {"en": "Sync failed", "ru": "Ошибка синхронизации"},
    "api_key": {"en": "DeepSeek API Key", "ru": "Ключ DeepSeek API"},
    "api_key_hint": {"en": "sk-...", "ru": "sk-..."},
    "api_key_help": {"en": "Get at platform.deepseek.com → API Keys", "ru": "Получить на platform.deepseek.com → API Keys"},
    "github_token": {"en": "GitHub Token", "ru": "Токен GitHub"},
    "github_token_hint": {"en": "ghp_...", "ru": "ghp_..."},
    "github_token_help": {"en": "GitHub → Settings → Developer settings → Tokens (repo scope)", "ru": "GitHub → Settings → Developer settings → Tokens (repo scope)"},
    "github_user": {"en": "GitHub Username", "ru": "Имя пользователя GitHub"},
    "own_key_note": {"en": "You bring your own API key. We don't store or see it. Pay only for what you use.", "ru": "Вы используете свой ключ. Мы не храним и не видим его. Платите только за использование."},
    "sync_github_title": {"en": "Sync with GitHub", "ru": "Синхронизация с GitHub"},
    "sync_github_desc": {"en": "Your projects sync via GitHub. Work on your phone, continue on PC. Same repo, seamless sync.", "ru": "Проекты синхронизируются через GitHub. Работайте на телефоне, продолжайте на ПК. Один репозиторий."},
    "all_set": {"en": "You're all set!", "ru": "Всё готово!"},
    "feature_list": {"en": "You're joining the future of mobile coding. No server needed. Just your phone, your ideas, and AI.", "ru": "Вы присоединяетесь к будущему мобильной разработки. Никаких серверов. Только телефон, идеи и ИИ."},
    "empty_dir": {"en": "Empty directory", "ru": "Пустая папка"},
    "loading": {"en": "Loading...", "ru": "Загрузка..."},
    "project_loaded": {"en": "loaded", "ru": "загружен"},
    "files_count": {"en": "files", "ru": "файлов"},
  };

  static String get(String key) {
    return _strings[key]?[_lang] ?? _strings[key]?["en"] ?? key;
  }
}
