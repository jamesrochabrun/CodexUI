# CodexUI

A native macOS application that provides a graphical interface for the [OpenAI Codex CLI](https://github.com/openai/codex). CodexUI enables AI-assisted coding with seamless Xcode integration.

## How It Works

CodexUI spawns the Codex CLI as a subprocess:

- **Subprocess Communication**: Executes Codex via `/bin/zsh` and communicates through stdin/stdout pipes
- **Real-time Streaming**: Responses stream as they're generated
- **Session Persistence**: Uses `--resume-last-session` to maintain conversation context across turns
- **Xcode Integration**: Reads your active Xcode file and selection via the Accessibility API, providing context to Codex automatically

## Prerequisites

### 1. Install Codex CLI

```bash
npm install -g @openai/codex
```

### 2. Authenticate

```bash
codex auth
```

This creates the required configuration files in `~/.codex/`.

## Permissions

### Accessibility Permission

Required for Xcode integration. Grant access at:

**System Settings > Privacy & Security > Accessibility > CodexUI**

Without this permission, CodexUI works but cannot read your Xcode context.

## Profiles

CodexUI comes with pre-built profiles that control sandbox and approval behavior:

| Intent | Flags | Effect |
|--------|-------|--------|
| Safe read-only browsing | `--sandbox read-only --ask-for-approval on-request` | Codex can read files and answer questions. Requires approval to make edits, run commands, or access network. |
| Read-only non-interactive (CI) | `--sandbox read-only --ask-for-approval never` | Reads only; never escalates |
| Let it edit the repo, ask if risky | `--sandbox workspace-write --ask-for-approval on-request` | Codex can read files, make edits, and run commands in the workspace. Requires approval for actions outside the workspace or for network access. |
| Auto (preset; trusted repos) | `--full-auto` | Codex runs sandboxed commands that can write inside the workspace without prompting. Escalates only when it must leave the sandbox. |
| YOLO (not recommended) | `--dangerously-bypass-approvals-and-sandbox` | No sandbox; no prompts |

See [Codex sandbox documentation](https://github.com/openai/codex/blob/main/docs/sandbox.md) for more details.

## Development

### Building

1. Clone the repository
2. Open `CodexUI.xcodeproj` in Xcode
3. Build and run the `CodexUI` target

### Dependencies

- **CodexSDK** - Codex CLI execution client
- **Down** - Markdown rendering
- **highlightswift** - Syntax highlighting
- **SQLite.swift** - Session persistence
- **KeyboardShortcuts** - Global keyboard shortcuts

### Project Structure

```
CodexUI/
├── Chat/
│   ├── ViewModels/      # ChatViewModel, SessionManager, ContextManager
│   ├── Views/           # ChatScreen, ChatInputView, SettingsView
│   ├── Models/          # ChatMessage, CodexProfile, FileAttachment
│   └── Services/        # CodexConfigService, ProfileManager
├── Services/
│   ├── AccessibilityService/   # Xcode UI reading
│   ├── XcodeObserverService/   # Live Xcode monitoring
│   └── TerminalService/        # Process execution
└── CodexUIApp.swift     # App entry point
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Submit a pull request
