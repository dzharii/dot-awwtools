--[[
============================================================
Experimental Lua Script
This script demonstrates an example implementation of a command-line interface using the (aww) LUA embedded engine.
It includes commands for displaying help and processing clipboard text.
2024-12-07
============================================================
]]

local aww = require("aww")

local function execute_command(command)
    local COMMAND_HELP = "help"
    local COMMAND_UPPERCASE_CLIPBOARD = "uppercase-clipboard"

    local HELP_MESSAGE = [[
Usage:
   luatext.lua <command>
   aww run luatext <command>

Commands:
    ]] .. COMMAND_HELP .. [[:
      Shows this help message
    ]] .. COMMAND_UPPERCASE_CLIPBOARD .. [[:
      Reads text from the clipboard, converts it to uppercase, and outputs the result

]]

    command = string.lower(command)

    if command == COMMAND_HELP then
        print(HELP_MESSAGE)
    elseif command == COMMAND_UPPERCASE_CLIPBOARD then
        local clipboard_text = aww.clipboard.getClipboardText()
        if clipboard_text and clipboard_text ~= "" then
            print(string.upper(clipboard_text))
        else
            print("Clipboard is empty or contains no text.")
        end
    else
        print("Unknown command: " .. command)
        print(HELP_MESSAGE)
        os.exit(1)
    end

    print("Done: " .. os.date("!%Y-%m-%dT%H:%M:%SZ"))
end

-- Main execution
local args = aww.cmd.getArgs()
if #args < 1 then
    print("Error: Command is required.")
    os.exit(1)
end

execute_command(args[1])
