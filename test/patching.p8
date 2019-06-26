pico-8 cartridge // http://www.pico-8.com
version 18
__lua__
function doutput(s,tof,bp)
 local prnt = tof or print
 local j = 1
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

c=[==[

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
"if x then i += h $e end"
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
"if x then i += h(e) e end"
if x then i += h(e) end
"if x then i += h -- e end"
if x then i += h -- e end
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
