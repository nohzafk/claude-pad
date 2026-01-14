#!/usr/bin/env lua
-- Minimal JSON encoder/decoder for ClaudeQ
-- Based on public domain code, simplified for our use case

local json = {}

-- Encode
local function encode_value(val, indent, level)
  local t = type(val)
  if t == "nil" then
    return "null"
  elseif t == "boolean" then
    return val and "true" or "false"
  elseif t == "number" then
    return tostring(val)
  elseif t == "string" then
    return '"' .. val:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t') .. '"'
  elseif t == "table" then
    local is_array = #val > 0 or next(val) == nil
    local parts = {}
    local prefix = indent and ("\n" .. string.rep("  ", level + 1)) or ""
    local suffix = indent and ("\n" .. string.rep("  ", level)) or ""
    
    if is_array then
      for i, v in ipairs(val) do
        parts[i] = prefix .. encode_value(v, indent, level + 1)
      end
      return "[" .. table.concat(parts, ",") .. suffix .. "]"
    else
      local i = 1
      for k, v in pairs(val) do
        parts[i] = prefix .. '"' .. tostring(k) .. '": ' .. encode_value(v, indent, level + 1)
        i = i + 1
      end
      return "{" .. table.concat(parts, ",") .. suffix .. "}"
    end
  end
  return "null"
end

function json.encode(val, options)
  local indent = options and options.indent
  return encode_value(val, indent, 0)
end

-- Decode
local function skip_whitespace(s, pos)
  return s:match("^%s*()", pos)
end

local function decode_value(s, pos)
  pos = skip_whitespace(s, pos)
  local c = s:sub(pos, pos)
  
  if c == '"' then
    -- String
    local end_pos = pos + 1
    while true do
      local char = s:sub(end_pos, end_pos)
      if char == '"' then break end
      if char == '\\' then end_pos = end_pos + 1 end
      end_pos = end_pos + 1
    end
    local str = s:sub(pos + 1, end_pos - 1)
    str = str:gsub('\\n', '\n'):gsub('\\r', '\r'):gsub('\\t', '\t'):gsub('\\"', '"'):gsub('\\\\', '\\')
    return str, end_pos + 1
    
  elseif c == '[' then
    -- Array
    local arr = {}
    pos = pos + 1
    pos = skip_whitespace(s, pos)
    if s:sub(pos, pos) == ']' then
      return arr, pos + 1
    end
    while true do
      local val
      val, pos = decode_value(s, pos)
      table.insert(arr, val)
      pos = skip_whitespace(s, pos)
      local next_char = s:sub(pos, pos)
      if next_char == ']' then
        return arr, pos + 1
      elseif next_char == ',' then
        pos = pos + 1
      end
    end
    
  elseif c == '{' then
    -- Object
    local obj = {}
    pos = pos + 1
    pos = skip_whitespace(s, pos)
    if s:sub(pos, pos) == '}' then
      return obj, pos + 1
    end
    while true do
      local key, val
      key, pos = decode_value(s, pos)
      pos = skip_whitespace(s, pos)
      pos = pos + 1 -- skip ':'
      val, pos = decode_value(s, pos)
      obj[key] = val
      pos = skip_whitespace(s, pos)
      local next_char = s:sub(pos, pos)
      if next_char == '}' then
        return obj, pos + 1
      elseif next_char == ',' then
        pos = pos + 1
      end
    end
    
  elseif s:sub(pos, pos + 3) == "true" then
    return true, pos + 4
  elseif s:sub(pos, pos + 4) == "false" then
    return false, pos + 5
  elseif s:sub(pos, pos + 3) == "null" then
    return nil, pos + 4
  else
    -- Number
    local num_str = s:match("^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
    return tonumber(num_str), pos + #num_str
  end
end

function json.decode(s)
  if not s or s == "" then return nil end
  local ok, result = pcall(function()
    local val, _ = decode_value(s, 1)
    return val
  end)
  if ok then
    return result, nil, nil
  else
    return nil, nil, result
  end
end

return json
