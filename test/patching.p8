pico-8 cartridge // http://www.pico-8.com
version 18
__lua__
-- todo: modify run with "make test" or similar

function doutput(s,tof,bp)
 local prnt = tof or print
 local j = 1
 local s = s or ""
 for i=1,#s do
  local c = sub(s,i,i)
  if c == "\n" then
   local st=sub(s,j,i-1)
   j = i+1
   if (bp and i % 14 == 0) then
    while(not btnp(0)) do
    end
   end
   prnt(st)
  end
 end

 if j!=#s then
  print(sub(s,j,#s))
 end
 print("done")
end

-- for debugging
-- print("^"..testpatch.."$")

-- todo: remove comment lines when patching
local commentpatch = [==[
//
]==]
assert("\n" == commentpatch)

-- todo: fix issue with misplaced end statement
-- todo: modify make patched code look like in pico8
local ifpatch = [==[
if (not i) a=1 a=2
]==]
assert("if (not i) then  a=1 a=2 end \n" == ifpatch)

local negpatch = [==[
i != a
]==]
assert("i ~= a\n" == negpatch)

-- todo: fix issue with missing/misplaced parens
-- todo: modify make patched code look like in pico8
local addpatch = [==[
i += a
]==]
assert("i = i + ( a) \n" == addpatch)

-- todo: fix issue with missing/misplaced parens
-- todo: modify make patched code look like in pico8
local subpatch = [==[
i -= a
]==]
assert("i = i - ( a) \n" == subpatch)

-- todo: fix issue with missing/misplaced parens
-- todo: modify make patched code look like in pico8
local mulpatch = [==[
i *= a
]==]
assert("i = i * ( a) \n" == mulpatch)

-- todo: fix issue with missing/misplaced parens
-- todo: modify make patched code look like in pico8
local divpatch = [==[
i /= a
]==]
assert("i = i / ( a) \n" == divpatch)

-- todo: fix issue with missing/misplaced parens
-- todo: modify make patched code look like in pico8
local modpatch = [==[
i %= a
]==]
assert("i = i % ( a) \n" == modpatch)


local advspacepatch1 = [==[
i+=a
]==]
assert("i = i + (a) \n" == advspacepatch1)

local advspacepatch2 = [==[
i+=  b
]==]
assert("i = i + (  b) \n" == advspacepatch2)

local advspacepatch3 = [==[
i  +=c
]==]
assert("i = i + (c) \n" == advspacepatch3)

local advspacepatch3 = [==[
i  +=   d
]==]
assert("i = i + (   d) \n" == advspacepatch3)

local advspacepatch4 = [==[
i+=e   ]==]
assert("i = i + (e)    " == advspacepatch4)

local advspacepatch5 = [==[
i  +=   f    ]==]
assert("i = i + (   f)     " == advspacepatch5)

local advspacepatch6 = [==[
  i+=g   ]==]
assert("  i = i + (g)    " == advspacepatch6)

local advspacepatch7 = [==[
  i  +=   h    ]==]
assert("  i = i + (   h)     " == advspacepatch7)

local advspacepatch8 = [==[
if x then i += h end
]==]
assert("if x then i = i + ( h)  end\n" == advspacepatch8)

local advspacepatch9 = [==[
if x then i += h + 1 end
]==]
assert( "if x then i = i + ( h + 1)  end\n" == advspacepatch9)

local advspacepatch10 = [==[
if x then i += h + e end]==]
assert( "if x then i = i + ( h + e)  end" == advspacepatch10)

local advspacepatch11 = [==[
if x then i += h - e end]==]
assert( "if x then i = i + ( h - e)  end" == advspacepatch11)

local advspacepatch12 = [==[
if x then i += h * e end]==]
assert( "if x then i = i + ( h * e)  end" == advspacepatch12)

local advspacepatch13 = [==[
if x then i += h / e end]==]
assert( "if x then i = i + ( h / e)  end" == advspacepatch13)

local advspacepatch14 = [==[
if x then i += h % e end]==]
assert( "if x then i = i + ( h % e)  end" == advspacepatch14)

local advspacepatch15 = [==[
if x then i += h ! e end]==]
assert("if x then i = i + ( h)  ! e end" == advspacepatch15)

local advspacepatch16 = [==[
if x then i += h " e end]==]
assert('if x then i = i + ( h)  " e end' == advspacepatch16)

local advspacepatch17 = [==[
if x then i += h $ e end]==]
assert("if x then i = i + ( h)  $ e end" == advspacepatch17)

local advspacepatch18 = [==[
if x then i += h & e end]==]
assert("if x then i = i + ( h)  & e end" == advspacepatch18)

local advspacepatch19 = [==[
if x then i += h ( e end
]==]
assert("if x then i = i + ( h ( e end) \n" == advspacepatch19)

local advspacepatch20 = [==[
if x then i += h ) e end]==]
assert("if x then i = i + ( h ) ) e end" == advspacepatch20)

local advspacepatch21 = [==[
if x then i += h = e end]==]
assert("if x then i = i + ( h)  = e end" == advspacepatch21)

local advspacepatch22 = [==[
if x then i += h ? e end]==]
assert("if x then i = i + ( h)  ? e end" == advspacepatch22)

local advspacepatch23 = [==[
if x then i += h ` e end]==]
assert("if x then i = i + ( h)  ` e end" == advspacepatch23)

local advspacepatch24 = [==[
if x then i += h \ e end]==]
assert("if x then i = i + ( h)  \\ e end" == advspacepatch24)

local advspacepatch25 = [==[
if x then i += h ^ e end]==]
assert("if x then i = i + ( h ^ e)  end" == advspacepatch25)

local advspacepatch26 = [==[
if x then i += h | e end]==]
assert("if x then i = i + ( h)  | e end" == advspacepatch26)

local advspacepatch27 = [==[
if x then i += h < e end]==]
assert("if x then i = i + ( h)  < e end" == advspacepatch27)

local advspacepatch28 = [==[
if x then i += h > e end]==]
assert("if x then i = i + ( h)  > e end" == advspacepatch28)

local advspacepatch29 = [==[
if x then i += h , e end]==]
assert("if x then i = i + ( h)  , e end" == advspacepatch29)

local advspacepatch30 = [==[
if x then i += h . e end]==]
assert("if x then i = i + ( h . e)  end" == advspacepatch30)

local advspacepatch31 = [==[
if x then i += h ; e end]==]
assert("if x then i = i + ( h)  ; e end" == advspacepatch31)

local advspacepatch32 = [==[
if x then i += h : e end]==]
assert("if x then i = i + ( h : e)  end" == advspacepatch32)

local advspacepatch33 = [==[
if x then i += h _ e end]==]
assert("if x then i = i + ( h)  _ e end" == advspacepatch33)

local advspacepatch34 = [==[
if x then i += h # e end]==]
assert("if x then i = i + ( h # e)  end" == advspacepatch34)

local advspacepatch35 = [==[
if x then i += h ' e end]==]
assert("if x then i = i + ( h)  ' e end" == advspacepatch35)

local advspacepatch36 = [==[
if x then i += h ~ e end]==]
assert("if x then i = i + ( h)  ~ e end" == advspacepatch36)

local advspacepatch37 = [==[
if x then i += h == e end]==]
assert("if x then i = i + ( h)  == e end" == advspacepatch37)

local advspacepatch38 = [==[
if x then i += h or e end]==]
assert("if x then i = i + ( h)  or e end" == advspacepatch38)

local advspacepatch39 = [==[
if x then i += h and e end]==]
assert("if x then i = i + ( h)  and e end" == advspacepatch39)

local advspacepatch40 = [==[
if x then i += h not e end]==]
assert("if x then i = i + ( h)  not e end" == advspacepatch40)

local advspacepatch41 = [==[
if x then i += h else e end]==]
assert("if x then i = i + ( h)  else e end" == advspacepatch41)

local advspacepatch42 = [==[
if x then i += h(e) end]==]
assert("if x then i = i + ( h(e))  end" == advspacepatch42)

local advspacepatch43 = [==[
if x then i += h -- e end
]==]
assert("if x then i = i + ( h) \n" == advspacepatch43)

local advspacepatch44 = [==[
if x then i += h // e end
]==]
assert("if x then i = i + ( h) \n" == advspacepatch44)

local advspacepatch45 = [==[
if x then i += h(e,f) end]==]
assert("if x then i = i + ( h(e,f))  end" == advspacepatch45)

local advspacepatch46 = [==[
if x then i += h [ e end]==]
assert("if x then i = i + ( h [ e)  end" == advspacepatch46)

-- todo: add more patching tests
c=[==[

comments:
"//"
//


shorthands:
"if (not i) a=1 a=2"
if (not i) a=1 a=2


unary math operators:
"i != a"
i != a
"i += a"
i += a
"i -= a"
i -= a
"i *= a"
i *= a
"i /= a"
i /= a
"i %= a"
i %= a


unary math operators - adcanced tests:
"i+=a"
i+=a
"i+=  b"
i+=  b
"i  +=c"
i  +=c
"i  +=   d"
i  +=   d
"i+=e   "
i+=e
"i  +=   f    "
i  +=   f
"  i+=g   "
  i+=g
"  i  +=   h    "
  i  +=   h
"if x then i += h end"
if x then i += h end
"if x then i += h + 1 end"
if x then i += h + 1 end

"if x then i += h + e end"
if x then i += h + e end
"if x then i += h - e end"
if x then i += h - e end
"if x then i += h * e end"
if x then i += h * e end
"if x then i += h / e end"
if x then i += h / e end
"if x then i += h % e end"
if x then i += h % e end

"if x then i += h ! e end"
if x then i += h ! e end
"if x then i += h " e end"
if x then i += h " e end
"if x then i += h $ e end"
if x then i += h $ e end
"if x then i += h & e end"
if x then i += h & e end
"if x then i += h ( e end"
if x then i += h ( e end
"if x then i += h ) e end"
if x then i += h ) e end
"if x then i += h = e end"
if x then i += h = e end
"if x then i += h ? e end"
if x then i += h ? e end
"if x then i += h ` e end"
if x then i += h ` e end
"if x then i += h \ e end"
if x then i += h \ e end
"if x then i += h ^ e end"
if x then i += h ^ e end
"if x then i += h | e end"
if x then i += h | e end
"if x then i += h < e end"
if x then i += h < e end
"if x then i += h > e end"
if x then i += h > e end

"if x then i += h , e end"
if x then i += h , e end
"if x then i += h . e end"
if x then i += h . e end
"if x then i += h ; e end"
if x then i += h ; e end
"if x then i += h : e end"
if x then i += h : e end
"if x then i += h _ e end"
if x then i += h _ e end
"if x then i += h # e end"
if x then i += h # e end
"if x then i += h ' e end"
if x then i += h ' e end
"if x then i += h ~ e end"
if x then i += h ~ e end
"if x then i += h == e end"
if x then i += h == e end

"if x then i += h or e end"
if x then i += h or e end
"if x then i += h and e end"
if x then i += h and e end
"if x then i += h not e end"
if x then i += h not e end
"if x then i += h else e end"
if x then i += h else e end
"if x then i += h(e) end"
if x then i += h(e) end
"if x then i += h -- e end"
if x then i += h -- e end
"if x then i += h // e end"
if x then i += h // e end
"if x then i += h(e,f) end"
if x then i += h(e,f) end
"if x then i += h [ e end"
if x then i += h [ e end
"if x then i += h ] e end"
if x then i += h ] e end
"if x then i += h[e] end"
if x then i += h[e] end

]==]

cls()

doutput(c,printh)
__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
