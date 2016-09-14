NeP.DSL = {
	Conditions = {}
}

local DSL = NeP.DSL

local function pString(mString, spell)
	local _, args = mString:match('(.+)%((.+)%)')
	if args then mString = mString:gsub('%((.+)%)', '') end
	mString = mString:gsub('%s', '')
	if DSL.Conditions[mString] then
		local result = DSL.Get(mString)(nil, (args or spell))
		return result
	else
		local unitId, rest = strsplit('.', mString, 2)
		local unitId = NeP.Engine.FilterUnit(unitId)
		if UnitExists(unitId) then
			local result = DSL.Get(rest)(unitId, (args or spell))
			return result
		end
	end
end

local mOps = {'+','-','*','/'}
local function SplitMath(mString)
	for i=1, #mOps do
		local OP = mOps[i]
		if string.find(mString, OP) then 
			local mString, math = unpack(string.split(mString, OP))
			if math then math = OP..math end
			return mString, (math or '')
		end
	end
	return mString, ''
end

local fOps = {['!='] = '~=', ['='] = '=='}
local tableComparator = {'>=','<=','!=','~=','==','>','<','='}
local function Comperatores(mString, spell)
	for i=1, #tableComparator do
		local OP = tableComparator[i]
		if string.find(mString, OP) then
			local tT = string.split(mString, OP)
			for k=1, #tT do
				local mString, math = SplitMath(tT[k])
				if string.find(mString, '%a') then
					tT[k] = pString(mString, spell)
				end
				if not tT[k] then return false end
				tT[k] = tT[k]..math
			end
			if fOps[OP] then OP = fOps[OP] end
			return loadstring(" return "..tT[1]..OP..tT[2])()
		end
	end
end

local function Parse(mString, spell)
	local modify_not = false
	local result = false
	if string.sub(mString, 1, 1) == '!' then
		mString = string.sub(mString, 2)
		modify_not = true
	end
	if string.find(mString, '[><=!]') then
		result =  Comperatores(mString, spell)
	else
		result = pString(mString, spell)
	end
	result = result or false
	if modify_not then
		return not result
	end
	return result
end

-- Routes
local typesTable = {
	['function'] = function(dsl, spell) return dsl() end,
	['table'] = function(dsl, spell)
		local r_Tbl = {[1] = true}
		for _,String in ipairs(dsl) do
			if String == 'or' then
				r_Tbl[#r_Tbl+1] = true
			elseif r_Tbl[#r_Tbl] then
				local eval = DSL.Parse(String, spell)
				r_Tbl[#r_Tbl] = eval or false
			end
		end
		for i = 1, #r_Tbl do
			if r_Tbl[i] then
				return true
			end
		end
		return false
	end,
	['string'] = function(dsl, spell) 
		if string.sub(dsl, 1, 1) == '@' then
			return NeP.library.parse(false, dsl, 'target')
		else
			return Parse(dsl, spell)
		end
	end,
	['nil'] = function(dsl, spell) return true end,
	['boolean']	 = function(dsl, spell) return dsl end,
}

function DSL.Get(condition)
	if condition then
		local condition = string.lower(condition)
		if DSL.Conditions[condition] then
			return DSL.Conditions[condition]
		end
	end
	return (function() end)
end

function DSL.RegisterConditon(name, condition, overwrite)
	local name = string.lower(name)
	if not DSL.Conditions[name] or overwrite then
		DSL.Conditions[name] = condition
	end
end

function DSL.Parse(dsl, spell)
	if typesTable[type(dsl)] then
		return typesTable[type(dsl)](dsl, spell)
	end
end