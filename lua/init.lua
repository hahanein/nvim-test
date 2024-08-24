local M = {}

-- Helper functions
local function alternate_file()
	if vim.g.test_no_alternate then
		return ""
	end
	local result = ""

	if result == "" and vim.g.loaded_projectionist then
		result =
			vim.fn.get(vim.fn.filter(vim.fn["projectionist#query_file"]("alternate"), "filereadable(v:val)"), 1, "")
	end

	if result == "" and vim.g.test_custom_alternate_file then
		result = vim.g.test_custom_alternate_file()
	end

	if result == "" and vim.g.loaded_rails and vim.fn["rails#app"]() ~= "" then
		result = vim.fn["rails#buffer"]().alternate()
	end

	return result
end

local function before_run()
	local modified_buffers = #vim.fn.getbufinfo({ bufmodified = 1 })
	if vim.o.autowrite or vim.o.autowriteall then
		vim.cmd("silent! wall")
	elseif vim.g.test_prompt_for_unsaved_changes and modified_buffers > 0 then
		local answer = vim.fn.confirm("Warning: you have unsaved changes", "&write\nwrite &all\n&continue", 3)

		if answer == 1 then
			vim.cmd("write")
		elseif answer == 2 then
			vim.cmd("wall")
		end
	end

	if vim.g.test_project_root then
		if type(vim.g.test_project_root) == "function" then
			vim.cmd("cd " .. vim.g.test_project_root())
		else
			vim.cmd("cd " .. vim.g.test_project_root)
		end
	end
end

local function after_run()
	if vim.g.test_project_root then
		vim.cmd("cd -")
	end
end

local function get_position(path)
	local filename_modifier = vim.g.test_filename_modifier or ":."

	local position = {}
	position.file = vim.fn.fnamemodify(path, filename_modifier)
	position.line = path == vim.fn.expand("%") and vim.fn.line(".") or 1
	position.col = path == vim.fn.expand("%") and vim.fn.col(".") or 1

	return position
end

local function extract_strategy_from_command(arguments)
	for idx = 1, #arguments do
		if arguments[idx]:match("^-strategy=") then
			return arguments[idx]:gsub("^-strategy=", "")
		end
	end
end

local function extract_env_from_command(arguments)
	local env = vim.tbl_filter(function(val)
		return val:match("^[A-Z_]+=.+")
	end, vim.deepcopy(arguments))
	vim.tbl_filter(function(val)
		return not val:match("^[A-Z_]+=.+")
	end, arguments)
	return table.concat(env, " ")
end

local function echo_failure(message)
	vim.cmd("echohl WarningMsg")
	vim.cmd('echo "' .. message .. '"')
	vim.cmd("echohl None")
end

local function extend(source, dict)
	local result = vim.tbl_extend("force", {}, source)
	for key, value in pairs(dict) do
		result[key] = vim.tbl_extend("force", result[key] or {}, value)
	end
	return result
end

-- Main functions
function M.run(type, arguments)
	before_run()

	local file = alternate_file()

	local position
	if M.test_file(vim.fn.expand("%")) then
		position = get_position(vim.fn.expand("%"))
		vim.g["test#last_position"] = position
	elseif
		file ~= ""
		and M.test_file(file)
		and (not vim.g["test#last_position"] or file ~= vim.g["test#last_position"].file)
	then
		position = get_position(file)
	elseif vim.g["test#last_position"] then
		position = vim.g["test#last_position"]
	else
		after_run()
		echo_failure("Not a test file")
		return
	end

	local runner = M.determine_runner(position.file)

	local args = vim.fn["test#base#build_position"](runner, type, position)
	args = vim.list_extend(arguments, args)
	args = vim.fn["test#base#options"](runner, args, type)

	if type(vim.g["test#strategy"]) == "table" then
		local strategy = vim.g["test#strategy"][type]
		M.execute(runner, args, strategy)
	else
		M.execute(runner, args)
	end

	after_run()
end

function M.run_last(arguments)
	if vim.g["test#last_command"] then
		before_run()

		local env = extract_env_from_command(arguments)
		local strategy = extract_strategy_from_command(arguments)

		if strategy == "" then
			strategy = vim.g["test#last_strategy"]
		end

		local cmd = { env, vim.g["test#last_command"] }
		vim.list_extend(cmd, arguments)
		vim.tbl_filter(function(v)
			return v ~= ""
		end, cmd)

		M.shell(table.concat(cmd, " "), strategy)

		after_run()
	else
		echo_failure("No tests were run so far")
	end
end

function M.exists()
	return M.test_file(vim.fn.expand("%")) or M.test_file(alternate_file())
end

function M.visit()
	if vim.g["test#last_position"] then
		vim.cmd("edit +" .. vim.g["test#last_position"].line .. " " .. vim.g["test#last_position"].file)
	else
		echo_failure("No tests were run so far")
	end
end

function M.execute(runner, args, ...)
	local env = extract_env_from_command(args)
	local strategy = extract_strategy_from_command(args)
	if strategy == "" then
		if #{ ... } > 0 then
			strategy = select(1, ...)
		else
			strategy = vim.g["test#strategy"]
		end
	end
	if strategy == "" then
		strategy = "basic"
	end

	args = vim.fn["test#base#options"](runner, args)
	vim.tbl_filter(function(v)
		return v ~= ""
	end, args)

	local executable = vim.fn["test#base#executable"](runner)
	args = vim.fn["test#base#build_args"](runner, args, strategy)
	local cmd = { env, executable }
	vim.list_extend(cmd, args)
	vim.tbl_filter(function(v)
		return v ~= ""
	end, cmd)

	M.shell(table.concat(cmd, " "), strategy)
end

function M.shell(cmd, strategy)
	vim.g["test#last_command"] = cmd
	vim.g["test#last_strategy"] = strategy

	if vim.g["test#transformation"] then
		cmd = vim.g["test#custom_transformations"][vim.g["test#transformation"]](cmd)
	end

	if cmd:match("^:") then
		strategy = "vimscript"
	end

	if vim.g["test#custom_strategies"] and vim.g["test#custom_strategies"][strategy] then
		vim.g["test#custom_strategies"][strategy](cmd)
	else
		vim.fn["test#strategy#" .. strategy](cmd)
	end
end

function M.determine_runner(file)
	for language, runners in pairs(M.get_runners()) do
		for _, runner in ipairs(runners) do
			runner = string.lower(language) .. "#" .. string.lower(runner)
			if vim.g["test#enabled_runners"] and not vim.tbl_contains(vim.g["test#enabled_runners"], runner) then
				goto continue
			end
			if vim.fn["test#base#test_file"](runner, vim.fn.fnamemodify(file, ":p:.")) then
				return runner
			end
			::continue::
		end
	end
end

function M.get_runners()
	local custom_runners = vim.g["test#runners"] or vim.g["test#custom_runners"] or {}
	return extend(custom_runners, vim.g["test#default_runners"])
end

function M.test_file(file)
	return M.determine_runner(file) ~= nil
end

return M
