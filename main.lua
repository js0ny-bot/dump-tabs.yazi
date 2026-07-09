local function default_output()
	local home = os.getenv("HOME")
	if home and home ~= "" then
		return home .. "/.local/state/yazi/tabs.dump"
	end

	return "/tmp/yazi-tabs.dump"
end

local function shell_escape(value)
	if value == nil then
		return "-"
	end

	local s = tostring(value)
	if s == "" then
		return "-"
	end

	-- Backslash-escape fields so the default space separator remains parseable.
	-- This is intentionally close to shell escaping, while keeping the output
	-- compact and easy to read: `/path/with space` -> `/path/with\ space`.
	s = s:gsub("\\", "\\\\")
	s = s:gsub("\n", "\\n")
	s = s:gsub("\r", "\\r")
	s = s:gsub("\t", "\\t")
	s = s:gsub(" ", "\\ ")

	return s
end

local collect_tabs = ya.sync(function(sep)
	local lines = {}

	for i = 1, #cx.tabs do
		local tab = cx.tabs[i]
		local current = tab.current
		local hovered = current.hovered

		local fields = {
			shell_escape(i),
			shell_escape(i == cx.tabs.idx and "active" or "-"),
			shell_escape(tab.name),
			shell_escape(current.cwd),
			shell_escape(hovered and hovered.url or nil),
		}

		lines[#lines + 1] = table.concat(fields, sep)
	end

	return table.concat(lines, "\n") .. "\n"
end)

return {
	entry = function(_, job)
		local output = job.args.output or job.args[1] or default_output()
		local sep = job.args.sep or " "
		local data = collect_tabs(sep)

		local ok, err = fs.write(Url(output), data)
		if not ok then
			ya.notify {
				title = "dump-tabs",
				content = "failed: " .. tostring(err),
				level = "error",
				timeout = 5,
			}
			return
		end

		ya.notify {
			title = "dump-tabs",
			content = "written: " .. output,
			level = "info",
			timeout = 3,
		}
	end,
}
