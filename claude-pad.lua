#!/usr/bin/env lua
-- ClaudePad: A controller pad for Claude Code sessions in WezTerm
-- Usage: lua claude-pad.lua <pane_id>

-- Add script directory to package.path so require works from any directory
local script_dir = debug.getinfo(1).source:match("@?(.*/)")
if script_dir then
  package.path = script_dir .. "?.lua;" .. package.path
end

local json = require("dkjson")

-- ============================================================================
-- Config
-- ============================================================================
local INSTRUCTIONS_FILE = "/tmp/claudepad.json"
local TMP_EDIT_FILE = "/tmp/claudepad_edit.txt"

-- ============================================================================
-- Helpers
-- ============================================================================

local function file_exists(path)
  local f = io.open(path, "r")
  if f then
    f:close()
    return true
  end
  return false
end

local function load_instructions()
  if not file_exists(INSTRUCTIONS_FILE) then
    return {}
  end
  local f = io.open(INSTRUCTIONS_FILE, "r")
  local content = f:read("*a")
  f:close()
  if content == "" then
    return {}
  end
  local obj, _, err = json.decode(content)
  if err then
    print("Error loading instructions: " .. err)
    return {}
  end
  return obj or {}
end

local function save_instructions(instructions)
  local f = io.open(INSTRUCTIONS_FILE, "w")
  f:write(json.encode(instructions, { indent = true }))
  f:close()
end

local function shell_escape(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function send_to_pane(pane_id, text)
  local cmd = string.format("wezterm cli send-text --pane-id %s --no-paste -- %s", pane_id, shell_escape(text))
  os.execute(cmd)
end

local function send_enter(pane_id)
  local cmd = string.format("wezterm cli send-text --pane-id %s --no-paste $'\\r'", pane_id)
  os.execute(cmd)
end

local function send_tab(pane_id)
  local cmd = string.format("wezterm cli send-text --pane-id %s --no-paste $'\\t'", pane_id)
  os.execute(cmd)
end

local function send_shift_tab(pane_id)
  -- Shift+Tab (backtab) sends escape sequence \e[Z
  local cmd = string.format("wezterm cli send-text --pane-id %s --no-paste $'\\e[Z'", pane_id)
  os.execute(cmd)
end

local function send_escape(pane_id)
  local cmd = string.format("wezterm cli send-text --pane-id %s --no-paste $'\\e'", pane_id)
  os.execute(cmd)
end

local function clear_screen()
  os.execute("clear")
end

local function edit_in_editor(initial_content)
  -- Write initial content to temp file
  local f = io.open(TMP_EDIT_FILE, "w")
  if initial_content then
    f:write(initial_content)
  end
  f:close()

  -- Open vim
  os.execute("vim " .. TMP_EDIT_FILE)

  -- Read back the content
  f = io.open(TMP_EDIT_FILE, "r")
  local content = f:read("*a")
  f:close()

  -- Clean up
  os.remove(TMP_EDIT_FILE)

  -- Trim whitespace
  content = content:match("^%s*(.-)%s*$")
  return content
end

local function print_instructions(instructions)
  print("Saved Instructions:")
  if #instructions == 0 then
    print("  (none)")
  else
    for i, v in ipairs(instructions) do
      -- Replace newlines with spaces and show only first 50 chars on one line
      local display = v:gsub("\n", " ")
      if #display > 50 then
        display = display:sub(1, 50) .. "..."
      end
      print(string.format("  [%d] %s", i, display))
    end
  end
  print("")
end

local function print_menu()
  print(
    "Cmd: s<n> send | e<n> edit | d<n> del | a vim | r repeat | esc interrupt | [empty]=Enter | t=Tab | st=Shift+Tab | q quit"
  )
  io.write("> ")
end

-- ============================================================================
-- Main
-- ============================================================================

local function main()
  -- Get pane_id from command line arg, or fallback to WEZTERM_PANE env var
  local pane_id = arg[1] or os.getenv("WEZTERM_PANE")

  if not pane_id then
    print("Usage: lua claude-pad.lua <pane_id>")
    print("   Or: Set WEZTERM_PANE environment variable")
    print("")
    print("To find pane IDs, run: wezterm cli list")
    os.exit(1)
  end

  local instructions = load_instructions()
  local last_sent = nil -- Track last sent text for repeat command

  while true do
    clear_screen()
    print_instructions(instructions)
    print_menu()

    local input = io.read()
    if not input then
      break
    end


    -- Check for leading space FIRST (before trim) - instant send, no save
    if input:match("^%s.+$") then
      local text = input:match("^%s(.+)$")
      text = text:match("^%s*(.-)%s*$") -- trim the content only
      send_to_pane(pane_id, text)
      send_enter(pane_id)
      last_sent = text
      goto continue
    end

    -- Trim for normal processing
    input = input:match("^%s*(.-)%s*$")

    if input == "q" or input == "quit" then
      break

    -- Empty line: Send Enter to Claude
    elseif input == "" then
      send_enter(pane_id)

    -- t: Send Tab to Claude
    elseif input == "t" then
      send_tab(pane_id)

    -- st: Send Shift+Tab to Claude (accept edit / plan mode)
    elseif input == "st" then
      send_shift_tab(pane_id)

    -- esc: Send Escape to Claude (interrupt)
    elseif input == "esc" then
      send_escape(pane_id)

    -- r: Repeat last sent text
    elseif input == "r" then
      if last_sent then
        send_to_pane(pane_id, last_sent)
        send_enter(pane_id)
      else
      end

    -- Send single digit (0-9) - sends immediately to Claude (for menu selection)
    elseif input:match("^[0-9]$") then
      send_to_pane(pane_id, input)

    -- s<num>: Send instruction (and delete it)
    elseif input:match("^s(%d+)$") then
      local idx = tonumber(input:match("^s(%d+)$"))
      if idx and instructions[idx] then
        send_to_pane(pane_id, instructions[idx])
        send_enter(pane_id)
        last_sent = instructions[idx]
        -- Delete the instruction after sending
        table.remove(instructions, idx)
        save_instructions(instructions)
      else
      end

    -- e<num>: Edit instruction in vim
    elseif input:match("^e(%d+)$") then
      local idx = tonumber(input:match("^e(%d+)$"))
      if idx and instructions[idx] then
        local new_val = edit_in_editor(instructions[idx])
        if new_val and new_val ~= "" then
          instructions[idx] = new_val
          save_instructions(instructions)
        end
      end

    -- d<num>: Delete instruction
    elseif input:match("^d(%d+)$") then
      local idx = tonumber(input:match("^d(%d+)$"))
      if idx and instructions[idx] then
        table.remove(instructions, idx)
        save_instructions(instructions)
      end

    -- a: Add instruction in vim
    elseif input == "a" then
      local new_inst = edit_in_editor(nil)
      if new_inst and new_inst ~= "" then
        table.insert(instructions, new_inst)
        save_instructions(instructions)
      end

    -- Default: Save as new instruction (with multi-line support)
    else
      -- Enter multi-line mode to handle pasted content with multiple lines
      local lines = {input}
      io.write("... ")
      while true do
        local next_line = io.read()
        if not next_line or next_line:match("^%s*$") then
          -- Empty line or EOF ends multi-line input
          break
        end
        table.insert(lines, next_line)
        io.write("... ")
      end
      local full_input = table.concat(lines, "\n")
      table.insert(instructions, full_input)
      save_instructions(instructions)
    end

    ::continue::
  end

  print("Goodbye!")
end

main()
