-- Fly v3: coba semua cara menemukan phys table
local RSvc = game:GetService("ReplicatedStorage")
local RS = game:GetService("RunService")
local Unr = RSvc:FindFirstChild("ByteNetUnreliable")
local VIM = game:GetService("VirtualInputManager")
local GS = game:GetService("GuiService")
local LP = game:GetService("Players").LocalPlayer

local function pressBtn(name, secs)
   local gui = LP.PlayerGui:FindFirstChild("MobileGui")
   local btn = gui and gui:FindFirstChild(name)
   if not btn then return end
   local p, s = btn.AbsolutePosition, btn.AbsoluteSize
   local x, y = p.X+s.X/2, p.Y+s.Y/2+GS:GetGuiInset().Y
   VIM:SendMouseButtonEvent(x,y,0,true,game,0)
   task.wait(secs or 0.2)
   VIM:SendMouseButtonEvent(x,y,0,false,game,0)
end

local function isPhys(t)
   return type(t)=="table"
      and rawget(t,"vy")~=nil
      and rawget(t,"y")~=nil
      and rawget(t,"x")~=nil
      and rawget(t,"grounded")~=nil
      and rawget(t,"vx")~=nil
end

local phys = nil

-- Metode 1: hook __namecall + debug.getlocal di callstack
warn("[FLY3] Metode 1: callstack via debug.getlocal...")
local hookRef
pcall(function()
   hookRef = hookmetamethod(game,"__namecall",newcclosure(function(self,...)
      if self==Unr and getnamecallmethod()=="FireServer" and not phys and not checkcaller() then
         -- cari lewat locals di tiap level
         for level=1,20 do
            local i=1
            while true do
               local ok,name,val=pcall(debug.getlocal,level,i)
               if not ok or name==nil then break end
               if isPhys(val) then
                  phys=val
                  warn("[FLY3] M1 found via getlocal level="..level.." name="..tostring(name))
                  break
               end
               i+=1
            end
            if phys then break end
            -- juga cek upvalues
            local ok2,fn=pcall(debug.getinfo,level,"f")
            if ok2 and fn and fn.func and islclosure(fn.func) then
               local ok3,ups=pcall(getupvalues,fn.func)
               if ok3 and type(ups)=="table" then
                  for _,v in pairs(ups) do
                     if isPhys(v) then
                        phys=v
                        warn("[FLY3] M1 found via upvalue level="..level)
                        break
                     end
                  end
               end
            end
            if phys then break end
         end
      end
      return hookRef(self,...)
   end))
end)

-- Trigger hook beberapa kali
for i=1,5 do
   pressBtn("Right",0.2)
   task.wait(0.3)
   if phys then break end
end

-- Metode 2: getreg
if not phys then
   warn("[FLY3] Metode 2: getreg...")
   local ok,reg=pcall(getreg)
   if ok and reg then
      for _,v in ipairs(reg) do
         if isPhys(v) then phys=v warn("[FLY3] M2 getreg found!") break end
      end
   end
end

-- Metode 3: getgc dengan banyak retries
if not phys then
   warn("[FLY3] Metode 3: getgc 10x retries...")
   for attempt=1,10 do
      pressBtn("Right",0.1)
      pressBtn("Left",0.1)
      for _,s in ipairs(getgc(true)) do
         if isPhys(s) then phys=s warn("[FLY3] M3 getgc found attempt="..attempt) break end
      end
      if phys then break end
      task.wait(0.2)
   end
end

-- Metode 4: cari di semua thread (coroutines di getgc)
if not phys then
   warn("[FLY3] Metode 4: cari di coroutines...")
   for _,obj in ipairs(getgc(true)) do
      if type(obj)=="thread" then
         -- coba getupvalues pada coroutine (beberapa executor support ini)
         pcall(function()
            local ups=getupvalues(obj)
            if type(ups)=="table" then
               for _,v in pairs(ups) do
                  if isPhys(v) then phys=v warn("[FLY3] M4 coroutine found!") end
               end
            end
         end)
         if phys then break end
      end
   end
end

if not phys then
   warn("[FLY3] SEMUA METODE GAGAL")
   warn("[FLY3] Coba: rejoin dulu, langsung exc script ini tanpa exc script lain")
   return
end

warn("[FLY3] PHYS DITEMUKAN! x=",phys.x,"y=",phys.y)

-- FLY dengan RenderStepped (sebelum frame dirender)
local Fly={On=false,TargetY=phys.y-1}
local conn=RS.RenderStepped:Connect(function()
   if Fly.On and phys then
      phys.y=Fly.TargetY
      phys.vy=0
      phys.grounded=false
   end
end)

warn("[FLY3] TES HOVER 6 detik di Y=",phys.y-1)
Fly.TargetY=phys.y-1
Fly.On=true
task.wait(6)

warn("[FLY3] TES NAIK ke Y=",phys.y-6)
Fly.TargetY=phys.y-6
task.wait(4)

Fly.On=false
conn:Disconnect()
warn("[FLY3] SELESAI x=",phys.x,"y=",phys.y)
warn("[FLY3] Apakah karakter melayang dan naik?")
