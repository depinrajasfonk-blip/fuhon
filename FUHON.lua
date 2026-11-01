local RSvc = game:GetService("ReplicatedStorage")
local Unr = RSvc:FindFirstChild("ByteNetUnreliable")

-- Cari phys table
local phys = nil
local old
pcall(function()
   old = hookmetamethod(game,"__namecall",newcclosure(function(self,...)
      if self==Unr and getnamecallmethod()=="FireServer" and not phys and not checkcaller() then
         for level=1,10 do
            local ok,fn=pcall(debug.getinfo,level,"f")
            if not ok or not fn then break end
            local f=fn.func
            if type(f)=="function" and islclosure(f) then
               local ok2,ups=pcall(getupvalues,f)
               if ok2 and type(ups)=="table" then
                  for _,v in pairs(ups) do
                     if type(v)=="table" and rawget(v,"vy")~=nil and rawget(v,"y")~=nil then
                        phys=v break
                     end
                  end
               end
            end
            if phys then break end
         end
      end
      return old(self,...)
   end))
end)

-- Trigger hook
local gui=game:GetService("Players").LocalPlayer.PlayerGui
local MG=gui:FindFirstChild("MobileGui")
local R=MG and MG:FindFirstChild("Right")
local VIM=game:GetService("VirtualInputManager")
local GS=game:GetService("GuiService")
if R then
   local p,s=R.AbsolutePosition,R.AbsoluteSize
   local x,y=p.X+s.X/2,p.Y+s.Y/2+GS:GetGuiInset().Y
   VIM:SendMouseButtonEvent(x,y,0,true,game,0) task.wait(0.5)
   VIM:SendMouseButtonEvent(x,y,0,false,game,0)
end
task.wait(1)
if not phys then warn("PHYS tidak ditemukan") return end
warn("PHYS OK x=",phys.x,"y=",phys.y)

-- Fly state
local Fly = {On=false, TargetY=phys.y}

-- Pasang __newindex untuk intercept semua write ke phys
local mt = {}
pcall(function() mt = getrawmetatable(phys) or {} end)
local orig = rawget(mt,"__newindex")
mt.__newindex = function(t, k, v)
   if Fly.On then
      if k=="vy" then rawset(t,k,0) return end  -- cegah gravity
      if k=="y"  then rawset(t,k,Fly.TargetY) return end  -- kunci Y
      if k=="grounded" then rawset(t,k,false) return end   -- jangan snap ke ground
   end
   if orig then orig(t,k,v) else rawset(t,k,v) end
end
pcall(setrawmetatable, phys, mt)
warn("Metatable dipasang")

-- Tes hover
warn("TES HOVER 5 detik di Y=",phys.y)
Fly.TargetY = phys.y - 2  -- sedikit angkat dari ground supaya tidak snap
Fly.On = true
task.wait(5)

-- Tes naik
warn("TES NAIK ke Y=",phys.y-5)
Fly.TargetY = phys.y - 5
task.wait(4)

-- Stop
Fly.On = false
warn("SELESAI - apakah karakter melayang?")
