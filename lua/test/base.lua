local M = {}

function M.test_file(runner, file)
	return runner.test_file(file)
end

function M.build_position(runner, run_type, position)
	return runner.build_position(run_type, position)
end

function M.options(runner, args, ...)
	local options = runner.options or {}

	if vim.tbl_isempty({ ... }) and type(options) == "string" then
		options = vim.split(options, "%s+")
	elseif not vim.tbl_isempty({ ... }) and type(options) == "table" then
		local key = ({ ... })[1]
		options = vim.list_extend(vim.split(options.all or "", "%s+"), vim.split(options[key] or "", "%s+"))
	else
		options = {}
	end

	if runner.build_options == nil then
		return vim.list_extend(options, args)
	else
		return runner.build_options(args, options)
	end
end

function M.build_args(runner, args)
	local no_color = vim.fn.has("gui_running") == 1

	local ok, result = pcall(function()
		return runner.build_args(args, not no_color)
	end)

	if ok then
		return result
	else
		if result:match("E118") then
			return vim.fn["test_" .. runner .. "_build_args"](args)
		else
			error(result)
		end
	end
end

function M.file_exists(file)
	return vim.fn.glob(file) ~= "" or vim.fn.bufexists(file) == 1
end

function M.escape_regex(str)
	return vim.fn.escape(str, "?+*\\^$.|{}[]()")
end

function M.nearest_test(position, patterns, ...)
	local configuration = select("#", ...) > 0 and select(1, ...) or {}
	return M.nearest_test_in_lines(position.file, position.line, 1, patterns, configuration)
end

function M.nearest_test_in_lines(filename, from_line, to_line, patterns, ...)
	local configuration = select("#", ...) > 0 and select(1, ...) or {}
	local test = {}
	local namespace = {}
	local last_indent = -1
	local current_line = from_line + 1
	local test_line = -1
	local last_namespace_line = -1
	local is_namespace_with_same_indent_allowed = configuration.namespaces_with_same_indent or false
	local match_index = patterns.whole_match and 0 or 1

	local is_reverse = from_line == "$" or from_line > to_line
	local lines = is_reverse and vim.fn.reverse(vim.fn.getbufline(filename, to_line, from_line))
		or vim.fn.getbufline(filename, from_line, to_line)

	for _, line in ipairs(lines) do
		current_line = current_line + (is_reverse and -1 or 1)
		local test_match = M.find_match(line, patterns.test)
		local namespace_match = M.find_match(line, patterns.namespace)

		local indent = #line:match("^%s*")
		if
			not vim.tbl_isempty(test_match)
			and (
				last_indent == -1
				or (
					test_line == -1
					and last_indent > indent
					and last_namespace_line > current_line
					and last_namespace_line ~= -1
				)
			)
		then
			if last_namespace_line > current_line then
				namespace = {}
				last_namespace_line = -1
			end
			table.insert(
				test,
				vim.tbl_filter(function(v)
					return v ~= ""
				end, test_match[match_index])[1]
			)
			last_indent = indent
			test_line = current_line
		elseif
			not vim.tbl_isempty(namespace_match)
			and (is_namespace_with_same_indent_allowed or (indent < last_indent or last_indent == -1))
		then
			table.insert(
				namespace,
				vim.tbl_filter(function(v)
					return v ~= ""
				end, namespace_match[match_index])[1]
			)
			last_indent = indent
			last_namespace_line = current_line
		end
	end

	return { test = test, test_line = test_line, namespace = vim.fn.reverse(namespace) }
end

function M.find_match(line, patterns)
	local matches = vim.tbl_map(function(pattern)
		return vim.fn.matchlist(line, pattern)
	end, patterns)
	return vim.tbl_filter(function(match)
		return not vim.tbl_isempty(match)
	end, matches)[1] or {}
end

return M
