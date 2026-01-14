# ClaudePad

A controller pad for Claude Code sessions in WezTerm. Queue instructions, send commands, and control your Claude Code session from a side pane.

## Why ClaudePad?

**It feels like playing a game.**

When you're watching Claude Code work, you're observing - thinking ahead - planning your next move. ClaudePad turns this into a game-like flow:

1. **Watch** Claude Code work on the current task
2. **Think** about what you want to do next
3. **Write** your instruction while Claude is still working
4. **Send** at the perfect moment

No more waiting idle. No more losing your train of thought. You're always one step ahead, queueing up moves while the action unfolds.

**The game-like workflow:**

```text
Claude is fixing a bug...
  → You type: "run the tests" (saved for later)
  → You type: " check coverage" (instant send, no save)

Claude finishes and asks what to do next...
  → You press: `s` + `1` (send saved instruction #1)
  → Claude runs the tests

While tests are running...
  → You open vim with `a` to write a multi-step refactoring prompt
  → You save it as instruction #2

Tests fail with 3 errors...
  → You type: "fix error 1" → saves as #3
  → You type: "fix error 2" → saves as #4
  → You type: "fix error 3" → saves as #5

Now you work through them one by one:
  → `s3` (fix error 1)
  → Watch Claude work...
  → `s4` (fix error 2)
  → Watch Claude work...
  → `s5` (fix error 3)
```

**This is why I built it:**

I found myself constantly interrupting my flow - switching focus to Claude, waiting, then remembering what I wanted to do next. With ClaudePad, I stay in the zone. I'm playing the game, always thinking one move ahead, executing at the right moment.

It's a small tool but it changes how you work with Claude Code - from passive waiting to active planning.

## Quick Start

### Installation

Clone or download ClaudePad:

```bash
git clone <repo-url> ~/claude-pad
# or download and extract to ~/claude-pad
```

Add to your `~/.wezterm.lua` (or merge into existing config):

```lua
local wezterm = require('wezterm')
local act = wezterm.action

local config = {}

config.keys = {
  -- ClaudePad: Press Cmd+K to spawn in bottom split pane
  {
    key = 'k',
    mods = 'CMD',
    action = act.SplitPane({
      direction = 'Down',
      size = { Percent = 30 },
      command = {
        args = {
          'fish',
          '-l',
          '-C',
          'cd ~/claude-pad && rlwrap lua claude-pad.lua $(wezterm cli list --format json | jq -r '.[0].pane_id')',
        },
      },
    }),
  },
}

return config
```

**Shell compatibility:**

- **Fish** (recommended): Use `'fish', '-l', '-C', '...'` (as shown above)
- **Zsh/Bash**: Change to `'zsh', '-c', '...'` or `'bash', '-c', '...'`

**Adjust the path** `~/claude-pad` if you installed ClaudePad elsewhere.

Press `Cmd+K` when Claude is running to spawn ClaudePad in a split pane

## Usage

### Inteface

```text
Saved Instructions:
  [1] fix the type error on line 42
  [2] run the tests
  [3] commit with message 'wip'

Cmd: s<n> send | e<n> edit | d<n> del | a vim | r repeat | esc interrupt | [empty]=Enter | t=Tab | st=Shift+Tab | q quit
> _
```

## How It Works

**Default behavior:** Type any text and press Enter to save it as a new instruction.

### Commands

**Send to Claude:**

- `s<n>` - Send instruction #n + Enter
- `< text>` - Instant send without saving (leading space)
- `r` - Repeat last sent text
- `0`-`9` - Send single digit to Claude (for option selection)
- _(empty line)_ - Send Enter key to Claude
- `t` - Send Tab key to Claude
- `st` - Send Shift+Tab to Claude (accept edit / plan mode)
- `esc` - Send Escape key to Claude (interrupt)

**Manage Instructions:**

- `a` - Add new instruction in vim (multi-line editing)
- `e<n>` - Edit instruction #n in vim (e.g., `e2`)
- `d<n>` - Delete instruction #n (e.g., `d1`)

**Other:**

- `q` or `quit` - Exit ClaudePad
- `Ctrl+D` - Exit ClaudePad (EOF)
- `Ctrl+C` - Terminate ClaudePad

## Requirements

- WezTerm
- Lua 5.1+ (included with macOS)
- rlwrap (for readline support): `brew install rlwrap`
- vim (for multi-line editing)

**Note:** rlwrap provides Emacs-style keybindings for single-line input (Ctrl+A, Ctrl+E, Ctrl+N/P, etc.)

## Storage

Instructions are saved to `/tmp/claudepad.json` (temporary, cleared on reboot).

## License

MIT
