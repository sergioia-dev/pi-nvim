--- Spec for pi-nvim.ui.build_message: the text handed to pi must start with a
--- slash command, otherwise pi treats the whole thing as prose and never
--- dispatches the command.
---
--- Regression guard for the report "I ran /plan start and it was executed as a
--- prompt": the file branch used to put `File: <path>` first, so the command
--- never reached byte 0 and `expandPromptTemplates` was never set.
local ui = require("pi-nvim.ui")

local failures = 0
local checks = 0

local function check(label, cond, extra)
	checks = checks + 1
	if cond then
		io.write("ok   - " .. label .. "\n")
	else
		failures = failures + 1
		io.write("FAIL - " .. label .. (extra and (" :: " .. tostring(extra)) or "") .. "\n")
	end
end

local function eq(label, actual, expected)
	check(label, actual == expected, "expected " .. vim.inspect(expected) .. ", got " .. vim.inspect(actual))
end

-- Matches the offset of the first difference, 0 when identical.
local function first_mismatch(actual, expected)
	if actual == expected then return 0 end
	for i = 1, math.min(#actual, #expected) do
		if actual:sub(i, i) ~= expected:sub(i, i) then return i end
	end
	return math.min(#actual, #expected) + 1
end

local file = "/home/sia/Work/src/app.ts"

-- 1. The reported regression: a slash command with file context attached.
local msg = ui.build_message({ prompt_text = "/plan start", file = file })
check("a command with a file keeps the command first", msg:sub(1, 11) == "/plan start", msg)
check("the file context survives", msg:find("File: " .. file, 1, true) ~= nil, msg)
eq("nothing is prepended", first_mismatch(msg, "/plan start\n\nFile: " .. file), 0)

-- 2. Plain prose keeps the context-first layout that reads naturally.
eq(
	"plain prose keeps the file first",
	ui.build_message({ prompt_text = "explain this", file = file }),
	"File: " .. file .. "\n\nexplain this"
)

-- 3. A path-like prompt is still prose: only the leading token decides.
eq(
	"a path is not mistaken for a command",
	ui.build_message({ prompt_text = "/etc/hosts is wrong", file = file }),
	"File: " .. file .. "\n\n/etc/hosts is wrong"
)

-- 4. TUI-only built-ins are commands too; pi-nvim.prompt does the warning.
local builtin = ui.build_message({ prompt_text = "/settings", file = file })
check("a builtin also stays first", builtin:sub(1, 9) == "/settings", builtin)

-- 5. A terminal buffer is just another file.
local term = ui.build_message({ prompt_text = "/plan start", file = "term://~/Work//123:/bin/bash" })
check("a terminal buffer keeps the command first", term:sub(1, 11) == "/plan start", term)

-- 6. A selection carries its own context, command first as well.
local sel = ui.build_message({
	prompt_text = "/plan start",
	selection = { file = "src/app.ts", start_line = 3, end_line = 9, text = "x = 1", ft = "typescript" },
})
check("a selection keeps the command first", sel:sub(1, 11) == "/plan start", sel)
check("the selection is included", sel:find("src/app.ts lines 3-9", 1, true) ~= nil, sel)

-- 7. A whole buffer works the same way.
local buf = ui.build_message({
	prompt_text = "/plan start",
	send_buffer = true,
	rel_file = "src/app.ts",
	buf_lines = { "line one" },
	ft = "typescript",
})
check("a whole buffer keeps the command first", buf:sub(1, 11) == "/plan start", buf)

-- 8. No prompt at all still means "look at this".
eq("an empty prompt names the file", ui.build_message({ file = file }), "Look at this file: " .. file)

-- 9. Nothing to send at all is reported as nil, not as an empty message.
eq("an empty prompt without a file yields nil", ui.build_message({}), nil)
eq("nil prompt with no file yields nil", ui.build_message({ prompt_text = nil }), nil)

-- 10. A bare prompt is forwarded unchanged (the caller trims, not this).
eq("a bare prompt is unchanged", ui.build_message({ prompt_text = "hello  world" }), "hello  world")

-- 11. A buffer with no prompt but with content still goes out.
local whole = ui.build_message({ send_buffer = true, rel_file = "src/app.ts", buf_lines = {}, ft = "typescript" })
check("a buffer with no prompt still sends the buffer", whole:find("Look at this file src/app.ts", 1, true) ~= nil, whole)

if failures > 0 then
	io.write(string.format("%d checks, %d failures\n", checks, failures))
	vim.cmd("cquit 1")
end
io.write(string.format("%d checks, %d failures\n", checks, failures))
vim.cmd("qa!")
