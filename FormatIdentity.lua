require'strict'
require'ParseLua'
local util = require'Util'

local function debug_printf(...)
	--[[
	util.printf(...)
	--]]
end

--
-- FormatIdentity.lua
--
-- Returns the exact source code that was used to create an AST, preserving all
-- comments and whitespace.
-- This can be used to get back a Lua source after renaming some variables in
-- an AST.
--

local function Format_Identity(ast)
	local out = {
		rope = {},  -- List of strings
		line = 1,
		char = 1,

		appendStr = function(self, str)
			table.insert(self.rope, str)

			local lines = util.splitLines(str)
			if #lines == 1 then
				self.char = self.char + #str
			else
				self.line = self.line + #lines - 1
				local lastLine = lines[#lines]
				self.char = #lastLine
			end
		end,

		appendToken = function(self, token)
			self:appendWhite(token)
			--[*[
			--debug_printf("appendToken(%q)", token.Data)
			local data  = token.Data
			local lines = util.splitLines(data)
			while self.line + #lines < token.Line do
				log("Inserting extra line")
				self.str  = self.str .. '\n'
				self.line = self.line + 1
				self.char = 1
			end
			--]]
			self:appendStr(token.Data)
		end,

		appendTokens = function(self, tokens)
			for _,token in ipairs(tokens) do
				self:appendToken( token )
			end
		end,

		appendWhite = function(self, token)
			if token.LeadingWhite then
				self:appendTokens( token.LeadingWhite )
				--self.str = self.str .. ' '
			end
		end
	}

	local formatStatlist, formatExpr;

	formatExpr = function(expr,white)
		white = white == nil and true or false
		local tok_it = 1
		local function appendNextToken(str)
			local tok = expr.Tokens[tok_it];
			if str and tok.Data ~= str then
				error("Expected token '" .. str .. "'. Tokens: " .. util.PrintTable(expr.Tokens))
			end
			out:appendToken( tok )
			tok_it = tok_it + 1
		end
		local function appendToken(token)
			out:appendToken( token )
			tok_it = tok_it + 1
		end
		local function appendWhite()
			if not white then return end
			local tok = expr.Tokens[tok_it];
			if not tok then error(util.PrintTable(expr)) end
			out:appendWhite( tok )
			tok_it = tok_it + 1
		end
		local function appendStr(str)
			appendWhite()
			out:appendStr(str)
		end
		local function peek()
			if tok_it < #expr.Tokens then
				return expr.Tokens[tok_it].Data
			end
		end
		local function appendComma(mandatory, seperators)
			if true then
				seperators = seperators or { "," }
				seperators = util.lookupify( seperators )
				if not mandatory and not seperators[peek()] then
					return
				end
				assert(seperators[peek()], "Missing comma or semicolon")
				appendNextToken()
			else
				local p = peek()
				if p == "," or p == ";" then
					appendNextToken()
				end
			end
		end

		debug_printf("formatExpr(%s) at line %i", expr.AstType, expr.Tokens[1] and expr.Tokens[1].Line or -1)

		if expr.AstType == 'VarExpr' then
			if expr.Variable then
				appendStr( expr.Variable.Name )
			else
				appendStr( expr.Name )
			end

		elseif expr.AstType == 'NumberExpr' then
			appendToken( expr.Value )

		elseif expr.AstType == 'StringExpr' then
			appendToken( expr.Value )

		elseif expr.AstType == 'BooleanExpr' then
			appendNextToken( expr.Value and "true" or "false" )

		elseif expr.AstType == 'NilExpr' then
			appendNextToken( "nil" )

		elseif expr.AstType == 'BinopExpr' then
			formatExpr(expr.Lhs)
			appendStr( expr.Op )
			formatExpr(expr.Rhs)

		elseif expr.AstType == 'UnopExpr' then
			appendStr( expr.Op )
			formatExpr(expr.Rhs)

		elseif expr.AstType == 'DotsExpr' then
			appendNextToken( "..." )

		elseif expr.AstType == 'CallExpr' then
			formatExpr(expr.Base)
			appendNextToken( "(" )
			for i,arg in ipairs( expr.Arguments ) do
				formatExpr(arg)
				appendComma( i ~= #expr.Arguments )
			end
			appendNextToken( ")" )

		elseif expr.AstType == 'TableCallExpr' then
			formatExpr( expr.Base )
			formatExpr( expr.Arguments[1] )

		elseif expr.AstType == 'StringCallExpr' then
			formatExpr(expr.Base)
			appendToken( expr.Arguments[1] )

		elseif expr.AstType == 'IndexExpr' then
			formatExpr(expr.Base)
			appendNextToken( "[" )
			formatExpr(expr.Index)
			appendNextToken( "]" )

		elseif expr.AstType == 'MemberExpr' then
			formatExpr(expr.Base)
			appendNextToken()  -- . or :
			appendToken(expr.Ident)

		elseif expr.AstType == 'Function' then
			-- anonymous function
			appendNextToken( "function" )
			appendNextToken( "(" )
			if #expr.Arguments > 0 then
				for i = 1, #expr.Arguments do
					appendStr( expr.Arguments[i].Name )
					if i ~= #expr.Arguments then
						appendNextToken(",")
					elseif expr.VarArg then
						appendNextToken(",")
						appendNextToken("...")
					end
				end
			elseif expr.VarArg then
				appendNextToken("...")
			end
			appendNextToken(")")
			formatStatlist(expr.Body)
			appendNextToken("end")

		elseif expr.AstType == 'ConstructorExpr' then
			appendNextToken( "{" )
			for i = 1, #expr.EntryList do
				local entry = expr.EntryList[i]
				if entry.Type == 'Key' then
					appendNextToken( "[" )
					formatExpr(entry.Key)
					appendNextToken( "]" )
					appendNextToken( "=" )
					formatExpr(entry.Value)
				elseif entry.Type == 'Value' then
					formatExpr(entry.Value)
				elseif entry.Type == 'KeyString' then
					appendStr(entry.Key)
					appendNextToken( "=" )
					formatExpr(entry.Value)
				end
				appendComma( i ~= #expr.EntryList, { ",", ";" } )
			end
			appendNextToken( "}" )

		elseif expr.AstType == 'Parentheses' then
			appendNextToken( "(" )
			formatExpr(expr.Inner)
			appendNextToken( ")" )

		else
			log("Unknown AST Type: ", statement.AstType)
		end

		--assert(tok_it == #expr.Tokens + 1)
		debug_printf("/formatExpr")
	end


	local formatStatement = function(statement)
		local tok_it = 1
		local function appendNextToken(str)
			local tok = statement.Tokens[tok_it];
			assert(tok, string.format("Not enough tokens for %q. First token at %i:%i",
				str, statement.Tokens[1].Line, statement.Tokens[1].Char))
			assert(tok.Data == str,
				string.format('Expected token %q, got %q', str, tok.Data))
			out:appendToken( tok )
			tok_it = tok_it + 1
		end
		local function appendToken(token)
			out:appendToken( str )
			tok_it = tok_it + 1
		end
		local function appendWhite()
			local tok = statement.Tokens[tok_it];
			out:appendWhite( tok and tok or ' ')
			tok_it = tok_it + 1
		end
		local function appendStr(str)
			appendWhite()
			out:appendStr(str)
		end
		local function appendStrNoWhite(str)
			out:appendStr(str)
		end
		local function appendComma(mandatory)
			if mandatory
			   or (tok_it < #statement.Tokens and statement.Tokens[tok_it].Data == ",") then
			   appendNextToken( "," )
			end
		end

		debug_printf("")
		debug_printf(string.format("formatStatement(%s) at line %i", statement.AstType, statement.Tokens[1] and statement.Tokens[1].Line or -1))

		if statement.AstType == 'AssignmentStatement' then
			for i,v in ipairs(statement.Lhs) do
				formatExpr(v)
				appendComma( i ~= #statement.Lhs )
			end
			if #statement.Rhs > 0 then
				appendNextToken( "=" )
				for i,v in ipairs(statement.Rhs) do
					formatExpr(v)
					appendComma( i ~= #statement.Rhs )
				end
			end

		elseif statement.AstType == 'IncrementStatement' then
			formatExpr(statement.Lhs)

			appendStrNoWhite('= ( ')
			formatExpr(statement.Lhs,false)
			appendStrNoWhite(' ')
			appendStrNoWhite(statement.IncrementType)
			appendStrNoWhite(' ')
			formatExpr(statement.Rhs,false)
			appendStrNoWhite(' )')

		elseif statement.AstType == 'CallStatement' then
			formatExpr(statement.Expression)

		elseif statement.AstType == 'LocalStatement' then
			appendNextToken( "local" )
			for i = 1, #statement.LocalList do
				appendStr( statement.LocalList[i].Name )
				appendComma( i ~= #statement.LocalList )
			end
			if #statement.InitList > 0 then
				appendNextToken( "=" )
				for i = 1, #statement.InitList do
					formatExpr(statement.InitList[i])
					appendComma( i ~= #statement.InitList )
				end
			end

		elseif statement.AstType == 'IfStatement' then
			appendNextToken( "if" )
			formatExpr( statement.Clauses[1].Condition )
			appendNextToken( "then" )
			formatStatlist( statement.Clauses[1].Body )
			for i = 2, #statement.Clauses do
				local st = statement.Clauses[i]
				if st.Condition then
					appendNextToken( "elseif" )
					formatExpr(st.Condition)
					appendNextToken( "then" )
				else
					appendNextToken( "else" )
				end
				formatStatlist(st.Body)
			end
			appendNextToken( "end" )

		elseif statement.AstType == 'WhileStatement' then
			appendNextToken( "while" )
			formatExpr(statement.Condition)
			appendNextToken( "do" )
			formatStatlist(statement.Body)
			appendNextToken( "end" )

		elseif statement.AstType == 'DoStatement' then
			appendNextToken( "do" )
			formatStatlist(statement.Body)
			appendNextToken( "end" )

		elseif statement.AstType == 'ReturnStatement' then
			appendNextToken( "return" )
			for i = 1, #statement.Arguments do
				formatExpr(statement.Arguments[i])
				appendComma( i ~= #statement.Arguments )
			end

		elseif statement.AstType == 'BreakStatement' then
			appendNextToken( "break" )

		elseif statement.AstType == 'RepeatStatement' then
			appendNextToken( "repeat" )
			formatStatlist(statement.Body)
			appendNextToken( "until" )
			formatExpr(statement.Condition)

		elseif statement.AstType == 'Function' then
			if statement.IsLocal then
				appendNextToken( "local" )
			end
			appendNextToken( "function" )

			if statement.IsLocal then
				appendStr(statement.Name.Name)
			else
				formatExpr(statement.Name)
			end

			appendNextToken( "(" )
			if #statement.Arguments > 0 then
				for i = 1, #statement.Arguments do
					appendStr( statement.Arguments[i].Name )
					appendComma( i ~= #statement.Arguments or statement.VarArg )
					if i == #statement.Arguments and statement.VarArg then
						appendNextToken( "..." )
					end
				end
			elseif statement.VarArg then
				appendNextToken( "..." )
			end
			appendNextToken( ")" )

			formatStatlist(statement.Body)
			appendNextToken( "end" )

		elseif statement.AstType == 'GenericForStatement' then
			appendNextToken( "for" )
			for i = 1, #statement.VariableList do
				appendStr( statement.VariableList[i].Name )
				appendComma( i ~= #statement.VariableList )
			end
			appendNextToken( "in" )
			for i = 1, #statement.Generators do
				formatExpr(statement.Generators[i])
				appendComma( i ~= #statement.Generators )
			end
			appendNextToken( "do" )
			formatStatlist(statement.Body)
			appendNextToken( "end" )

		elseif statement.AstType == 'NumericForStatement' then
			appendNextToken( "for" )
			appendStr( statement.Variable.Name )
			appendNextToken( "=" )
			formatExpr(statement.Start)
			appendNextToken( "," )
			formatExpr(statement.End)
			if statement.Step then
				appendNextToken( "," )
				formatExpr(statement.Step)
			end
			appendNextToken( "do" )
			formatStatlist(statement.Body)
			appendNextToken( "end" )

		elseif statement.AstType == 'LabelStatement' then
			appendNextToken( "::" )
			appendStr( statement.Label )
			appendNextToken( "::" )

		elseif statement.AstType == 'GotoStatement' then
			appendNextToken( "goto" )
			appendStr( statement.Label )

		elseif statement.AstType == 'Eof' then
			appendWhite()

		else
			log("Unknown AST Type: ", statement.AstType)
		end

		if statement.Semicolon then
			appendNextToken(";")
		end

		--assert(tok_it == #statement.Tokens + 1, 'wrong number of tokens\n'..table.concat(out.rope))
		debug_printf("/formatStatment")
	end

	formatStatlist = function(statList)
		if statList.Body == nil then
			log(statList)
		end
		for _, stat in ipairs(statList.Body) do
			formatStatement(stat)
		end
	end

	formatStatlist(ast)
	
	return true, table.concat(out.rope)
end

return Format_Identity
