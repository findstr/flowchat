local format = string.format
local M = {}

local mt = {__index = M}

local LOADED = {}

function M:create(name)
	local obj = {
		idx = 0,
		dirty = true,
		name = name,
		depend = {},
		action = {}
	}
	setmetatable(obj, mt)
	assert(not LOADED[name], name)
	LOADED[name] = obj
	return obj
end

function M:start(alias)
	local act = self.action
	name = "start"
	if not alias then
		alias = name
	end
	act[#act + 1] = { act = "barrier", name = name, alias = alias}
end

function M:stop(name, alias)
	local act = self.action
	if not alias then
		alias = name
		name = "stop"
	end
	act[#act + 1] = { act = "barrier", name = name, alias = alias}
end

function M:call(name, alias)
	local id = self.idx + 1
	self.idx = id
	local ok, err = pcall(require, name)
	if not ok and err:find("error") then
		assert(false, err)
	end
	local act = self.action
	local id = #act + 1
	local depend = self.depend
	depend[#depend + 1] = name
	if not alias then
		alias = name
	else
		alias = format("%s(%s)", alias, name)
	end
	act[#act + 1] = { act = "call", name = name .. id, alias = alias, call = name}
end

function M:state(name, alias)
	local act = self.action
	local id = #act + 1
	if not alias then
		alias = name
		name = format("state%s", id)
	else
		alias = format("%s(%s)", alias, name)
	end
	act[id] = { act = "state", name = name, alias = alias }
end

function branch(self, name, alias, fall, jmp, target)
	local act = self.action
	if not alias then
		alias = name
	else
		alias = format("%s(%s)", alias, name)
	end
	act[#act + 1] = { act = "branch", name = name, alias = alias, target = target, fall = fall, jmp = jmp}
end

function M:branchN(name, fail, alias)
	return branch(self, name, alias, "Y", "N", fail)
end

function M:branchY(name, success, alias)
	return branch(self, name, alias, "N", "Y", success)
end

function M:switch(name, mux, alias)
	local act = self.action
	if not alias then
		alias = name
	else
		alias = format("%s(%s)", alias, name)
	end
	act[#act + 1] = { act = "switch", name = name, alias = alias, mux = mux}
end

local function drawcluster(name, item)
	return format("\t%s_%s->%s_start;", name, item.name, item.call)
end

local drawtype = {
	["barrier"] = function(name, item, i, act)
		local follow = act[i+1]
		local part = format('\t\t%s_%s [shape=ellipse, label="%s"];',name, item.name, item.alias)
		if follow then
			part = part .. format('\n\t\t%s_%s->%s_%s;',  name, item.name, name, follow.name)
		end
		return part
	end,
	["call"] = function(name, item, i, act)
		local follow = act[i+1]
		return format('\t\t%s_%s [shape=box, fillcolor=yellow, label="%s"];\n\t\t%s_%s->%s_%s;', name, item.name, item.alias, name, item.name, name, follow.name)
	end,
	["state"] = function(name, item, i, act)
		local follow = act[i+1]
		return format('\t\t%s_%s [shape=box , label="%s"];\n\t\t%s_%s->%s_%s;', name, item.name, item.alias, name, item.name, name, follow.name)
	end,
	["branch"] = function(name, item, i, act)
		local follow = act[i+1]
		local count = #act
		local target
		local k = i
		for n = 1, count do
			local j = k % count
			local n = act[j + 1]
			if n.name:find(item.target) then
				target = n
				break
			end
			k = k+1
		end
		assert(target, item.target)
		return format('\t\t%s_%s [shape=diamond, label="%s"];\n\t\t%s_%s->%s_%s[label="%s"];\n\t\t%s_%s -> %s_%s[label="%s"];',
			name, item.name, item.alias, name, item.name, name, follow.name, item.fall, name, item.name, name, target.name, item.jmp)
	end,
	["switch"] = function(name, item)
		local tbl = {}
		tbl[1] = format('\t\t%s_%s [shape=diamond, label="%s"];', name, item.name, item.alias)
		local id = 2
		for _, v in ipairs(item.mux) do
			local n, color
			if v.call then
				n = v.call
				color = "yellow"
			else
				n = v.target
				color = ""
			end
			local alias = v.alias
			if not alias then
				alias = n
			else
				alias = format("%s(%s)", alias, n)
			end
			tbl[id] = format('\t\t%s_%s [shape=box, fillcolor="%s", label="%s"];', name, n, color, alias)
			id = id + 1
			tbl[id] = format('\t\t%s_%s->%s_%s[label="%s"];', name, item.name, name, n, v.case);
			id = id + 1
		end
		return table.concat(tbl, "\n")
	end

}

function M:draw(output, tail)
	local name = self.name
	local act = self.action
	output[#output + 1] = format("\tsubgraph cluster_%s {", self.name)
	output[#output + 1] = format('\t\tlabel = "%s";', self.name)
	for i, v in ipairs(act) do
		output[#output + 1] = assert(drawtype[v.act])(name, v, i, act)
		if v.act == "call" then
			tail[#tail + 1] = drawcluster(name, v)
		elseif v.act == "switch" then
			for _, m in ipairs(v.mux) do
				if m.call then
					tail[#tail + 1] = format("\t%s_%s->%s_start;", name, m.call, m.call)
					output[#output + 1] = format("\t%s_%s->%s_%s;", name, m.call, name, act[i+1].name)
				end
			end
		end
	end
	output[#output + 1] = "\t}"
end

function M:drawall(output, tail)
	local depend = self.depend
	for _, d in ipairs(depend) do
		local f = LOADED[d]
		if f and f.dirty then
			f.dirty = nil
			f:drawall(output, tail)
		end
	end
	self:draw(output, tail)
end

function M:flow(name)
	local output = {}
	local tail = {}
	output[#output + 1] = string.format("digraph %s {", "name")
	output[#output + 1] = '\tnode [shape=box, style=filled, fontname="NSimSun", fillcolor=lightblue, fontsize=14];'
	output[#output + 1] = '\tedge [fontname="NSimSun", fontsize=12];'
	require(name)
	local f = assert(LOADED[name], name)
	f:drawall(output, tail)
	table.move(tail, 1, #tail, #output + 1, output)
	output[#output + 1] = "}\n"
	return output
end


return M

