local RS = game:GetService("RunService")
local RSvc = game:GetService("ReplicatedStorage")
local Unr = RSvc:FindFirstChild("ByteNetUnreliable")

-- Cari phys table
local phys = nil
local old
pcall(function()
   old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
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

-- gerak sebentar untuk trigger
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
warn("PHYS OK: x=",phys.x,"y=",phys.y)

-- Fly dengan Heartbeat (jauh lebih cepat dari task.wait)
local Fly = {On=false, TargetY=phys.y, TargetX=nil, Speed=5}
local conn = RS.Heartbeat:Connect(function()
   if not Fly.On or not phys then return end
   phys.y = Fly.TargetY        -- kunci Y
   phys.vy = 0                 -- cegah velocity akumulasi
   phys.grounded = false
   if Fly.TargetX then
      phys.x = Fly.TargetX    -- kunci X (opsional)
      phys.vx = 0
   end
end)

-- Tes hover
warn("TES HOVER 5 detik (Y=",phys.y,")")
Fly.TargetY = phys.y
Fly.On = true
task.wait(5)

-- Tes naik 5 tile
warn("TES NAIK ke Y=",phys.y-5)
Fly.TargetY = phys.y - 5
task.wait(3)

-- Tes hover di ketinggian baru
warn("HOVER di ketinggian baru...")
Fly.TargetY = phys.y
task.wait(3)

-- Stop
Fly.On = false
conn:Disconnect()
warn("SELESAI. Apakah karakter melayang dan naik?")
