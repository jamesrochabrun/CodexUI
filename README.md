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

This allows CodexUI to read your Xcode workspace." or "This enables access to your Xcode workspace.

<img width="1152" height="956" alt="Image" src="https://github.com/user-attachments/assets/41a0d2f3-1b85-4937-bc4d-f6894bb6b7d9" />

## Profiles

CodexUI comes with pre-built profiles that control sandbox and approval behavior:

<img width="702" height="678" alt="Image" src="https://github.com/user-attachments/assets/1fa15f1a-6c40-4f20-93a1-7d5781103199" />

| Intent | Flags | Effect |
|--------|-------|--------|
| Safe read-only browsing | `--sandbox read-only --ask-for-approval on-request` | Codex can read files and answer questions. Requires approval to make edits, run commands, or access network. |
| Read-only non-interactive (CI) | `--sandbox read-only --ask-for-approval never` | Reads only; never escalates |
| Let it edit the repo, ask if risky | `--sandbox workspace-write --ask-for-approval on-request` | Codex can read files, make edits, and run commands in the workspace. Requires approval for actions outside the workspace or for network access. |
| Auto (preset; trusted repos) | `--full-auto` | Codex runs sandboxed commands that can write inside the workspace without prompting. It escalates only when it must leave the sandbox. |
| YOLO (not recommended) | `--dangerously-bypass-approvals-and-sandbox` | No sandbox; no prompts |

See [Codex sandbox documentation](https://github.com/openai/codex/blob/main/docs/sandbox.md) for more details.

Users can also create their own profiles

<img width="539" height="630" alt="Image" src="https://github.com/user-attachments/assets/73a433da-c767-45eb-90a4-ee7cdf4332b2" />

## Sessions

Easy access to your Codex sessions, initiated in CodexUI

<img width="550" height="444" alt="Image" src="https://github.com/user-attachments/assets/e3f48228-a650-4072-907c-066e8e346d15" />

## Context Management

<img width="580" height="676" alt="Screenshot 2025-12-01 at 3 17 12 PM" src="https://github.com/user-attachments/assets/41733d75-2028-4b55-8824-f70ff05c2036" />


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
