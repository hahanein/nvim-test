local base = require("test.base")

local M = {}

-- Check if the global variable 'g:test#zig#zigtest#file_pattern' exists and set it if not
if not vim.g["test#zig#zigtest#file_pattern"] then
	vim.g["test#zig#zigtest#file_pattern"] = ".zig$"
end

-- Function to check if a file matches the zig test file pattern
function M.test_file(file)
	return string.match(file, vim.g["test#zig#zigtest#file_pattern"]) ~= nil
end

-- Helper function to find the nearest test
local function nearest_test(position)
	local name = base.nearest_test(position, vim.g["test#zig#patterns"])
	return base.escape_regex(table.concat(name.test, ""))
end

-- Function to build the test command position based on the type of test
function M.build_position(test_type, position)
	if test_type == "nearest" then
		local name = nearest_test(position)
		if name == "" then
			return { "--", position.file }
		else
			return { "--", position.file, "--test-filter " .. vim.fn.shellescape(name, 1) }
		end
	elseif test_type == "file" then
		return { "--", position.file }
	else
		return {}
	end
end

-- Function to build the test command arguments
function M.build_args(args)
	return args
end

-- Function to get the test executable
function M.executable()
	return "zig build test"
end

return M
