-- Fly v2: cari phys table + hook physics loop
local RS = game:GetService("RunService")
local RSvc = game:GetService("ReplicatedStorage")
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
   task.wait(secs or 0.3)
   VIM:SendMouseButtonEvent(x,y,0,false,game,0)
end

-- Cari phys table lewat getgc saat karakter bergerak
warn("[FLY2] mencari phys table...")
local phys = nil
for attempt = 1, 8 do
   pressBtn("Right", 0.2)
   task.wait(0.1)
   for _, s in ipairs(getgc(true)) do
      if type(s)=="table" and rawget(s,"vy")~=nil and rawget(s,"y")~=nil
         and rawget(s,"vx")~=nil and rawget(s,"grounded")~=nil then
         phys = s break
      end
   end
   if phys then break end
   warn("[FLY2] attempt", attempt, "gagal, coba lagi...")
end

if not phys then warn("[FLY2] PHYS tidak ditemukan setelah 8 percobaan") return end
warn("[FLY2] PHYS ditemukan! x=",phys.x,"y=",phys.y,"vy=",phys.vy)

local Fly = {On=false, TargetY=phys.y, Speed=4}

-- Pakai task.wait() tanpa argumen = next frame
-- Ini lebih cepat dari Heartbeat connection
local function flyLoop()
   task.spawn(function()
      while Fly.On do
         if phys then
            -- tulis Y dan vy tiap frame
            phys.y = Fly.TargetY
            phys.vy = 0
            phys.vx = phys.vx  -- biarkan X movement normal
            phys.grounded = false
         end
         task.wait()  -- tunggu 1 frame (tanpa delay)
      end
   end)
end

-- JUGA hook ByteNetUnreliable untuk paksa server lihat Y yang benar
local hookOk = pcall(function()
   local old2
   old2 = hookmetamethod(game,"__namecall",newcclosure(function(self,...)
      if self==Unr and getnamecallmethod()=="FireServer" and Fly.On then
         local b = ...
         if typeof(b)=="buffer" and buffer.len(b)>=9 and buffer.readu8(b,0)==2 then
            -- paksa Y di buffer ke target kita
            pcall(function() buffer.writef32(b, 1, Fly.TargetY) end)
         end
      end
      return old2(self,...)
   end))
end)
warn("[FLY2] buffer hook ok?", hookOk)

-- TES
warn("[FLY2] TES HOVER 6 detik di Y=", phys.y)
Fly.TargetY = phys.y - 1  -- angkat 1 tile dari ground
Fly.On = true
flyLoop()
task.wait(6)

warn("[FLY2] TES NAIK ke Y=", phys.y - 5)
Fly.TargetY = phys.y - 5
task.wait(4)

warn("[FLY2] HOVER di Y baru=", phys.y)
Fly.TargetY = phys.y
task.wait(4)

Fly.On = false
warn("[FLY2] selesai. Apakah karakter melayang dan naik?")
warn(string.format("[FLY2] posisi akhir: x=%.2f y=%.2f", phys.x, phys.y))
