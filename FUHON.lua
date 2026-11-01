-- Tes fly via modifikasi phys.vy
-- Jalankan di world mana pun
local VIM = game:GetService("VirtualInputManager")
local GS = game:GetService("GuiService")
local LP = game:GetService("Players").LocalPlayer

-- Cari tabel physics
local phys = nil
for _, s in ipairs(getgc(true)) do
   if type(s) == "table" and rawget(s,"vy") ~= nil and rawget(s,"grounded") ~= nil then
      phys = s break
   end
end

if not phys then warn("[FLY] phys table tidak ditemukan") return end
warn("[FLY] phys table ditemukan! vy=", phys.vy, "grounded=", phys.grounded)

-- Cek semua field di phys (cari gravity)
local gravField = nil
for k, v in pairs(phys) do
   warn("[PHYS FIELD]", k, "=", tostring(v), type(v))
   if tostring(k):lower():find("grav") then gravField = k end
end
if gravField then warn("[FLY] gravity field:", gravField, "=", phys[gravField]) end

-- Fly state
local Fly = {On=false, Mode="hover", Speed=3}

-- 3 mode:
-- "hover": vy = 0 terus (diam di udara)
-- "up": vy = -Speed (naik)
-- "down": vy = Speed (turun)

local function startFly()
   task.spawn(function()
      while Fly.On do
         if Fly.Mode == "hover" then
            phys.vy = 0
            phys.grounded = false
         elseif Fly.Mode == "up" then
            phys.vy = -Fly.Speed
            phys.grounded = false
         elseif Fly.Mode == "down" then
            phys.vy = Fly.Speed
         end
         task.wait(0.03)
      end
   end)
end

-- Kalau ada gravity field, coba set ke 0 juga
if gravField then
   warn("[FLY] mencoba set", gravField, "= 0")
   local orig = phys[gravField]
   phys[gravField] = 0
   task.wait(2)
   warn("[FLY]", gravField, "setelah set:", phys[gravField])
   phys[gravField] = orig -- kembalikan dulu
end

-- Tes hover dulu (5 detik)
warn("[FLY] TES HOVER 5 detik...")
Fly.On = true Fly.Mode = "hover"
startFly()
task.wait(5)

-- Tes naik (3 detik)
warn("[FLY] TES NAIK 3 detik...")
Fly.Mode = "up" Fly.Speed = 5
task.wait(3)

-- Hover lagi
warn("[FLY] HOVER lagi...")
Fly.Mode = "hover"
task.wait(3)

-- Tes turun (3 detik)
warn("[FLY] TES TURUN 3 detik...")
Fly.Mode = "down" Fly.Speed = 3
task.wait(3)

-- Stop
Fly.On = false
warn("[FLY] selesai. Kirim screenshot posisi karakter ke chat.")
