-- Growtopia Hub (Home, HT, Spy) - versi ringkas untuk di-host di GitHub
warn("[HUB] mulai")

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local WR = RS:WaitForChild("WorldRemotes", 10)
local SetTile = WR and WR:WaitForChild("SetTile", 10)

if not SetTile then
   warn("[HUB] WorldRemotes.SetTile tidak ditemukan")
   Rayfield:Notify({Title = "Error", Content = "Remote SetTile tidak ditemukan", Duration = 6})
   return
end

-- ====== KONFIGURASI ======
local C = {
   X1 = 0, X2 = 3, Y = 36,   -- baris tree yang dipanen
   Delay = 0.15,             -- jeda antar tile
   Grow = 75,                -- waktu tumbuh 70 dtk + jeda aman
   Seed = 4587,              -- ID seed sugarcane
   PlantAt = nil, On = false,
   Move = false, PosA = nil, PosB = nil, MoveWait = 0.12, -- gerak otomatis
}
local Spy = {On = false, Logs = {}}
local IGNORE = {ByteNetUnreliable = true, SaveInventory = true}

-- ====== FUNGSI ======
local function getHRP()
   local ch = LP.Character
   return ch and ch:FindFirstChild("HumanoidRootPart")
end

-- pindah ke posisi di antara PosA (tile X1) dan PosB (tile X2)
local function moveTo(x)
   if not (C.Move and C.PosA and C.PosB) then return end
   local hrp = getHRP()
   if not hrp then return end
   local a = (C.X2 == C.X1) and 0 or (x - C.X1) / (C.X2 - C.X1)
   hrp.CFrame = C.PosA:Lerp(C.PosB, a)
   task.wait(C.MoveWait)
end

local function harvestRow()
   local hrp = getHRP()
   local home = hrp and hrp.CFrame
   for x = math.min(C.X1, C.X2), math.max(C.X1, C.X2) do
      moveTo(x)
      SetTile:FireServer("fg", x, C.Y, 0)
      task.wait(C.Delay)
   end
   if C.Move and home then
      local h = getHRP()
      if h then h.CFrame = home end
   end
end

local function hex(b)
   local ok, s = pcall(function()
      local out = {}
      for i = 0, math.min(buffer.len(b), 32) - 1 do
         out[#out + 1] = string.format("%02X", buffer.readu8(b, i))
      end
      return table.concat(out, " ")
   end)
   return ok and s or "?"
end

local function ser(v)
   local t = typeof(v)
   if t == "buffer" then return "buffer[" .. hex(v) .. "]" end
   if t == "string" then return string.format("%q", v) end
   return t .. ":" .. tostring(v)
end

-- ====== WINDOW ======
local Win = Rayfield:CreateWindow({
   Name = "Growtopia Hub",
   LoadingTitle = "Memuat Hub...",
   LoadingSubtitle = "oleh Pemula",
   ConfigurationSaving = {Enabled = false},
   KeySystem = false,
})

local function notify(title, content)
   Rayfield:Notify({Title = title, Content = content, Duration = 4, Image = 4483362458})
end

-- ====== HOME ======
local Home = Win:CreateTab("Home", 4483362458)
Home:CreateSection("Selamat Datang")
Home:CreateParagraph({
   Title = "Cara pakai HT",
   Content = "Isi X, Y, dan waktu tumbuh di tab HT. Nyalakan Auto Harvest, lalu plant seed manual. Timer mulai otomatis."
})

-- ====== HT (Harvest) ======
local HT = Win:CreateTab("HT", 4483362458)
HT:CreateSection("Baris Tree")
HT:CreateInput({Name = "X mulai", PlaceholderText = "0", RemoveTextAfterFocusLost = false,
   Callback = function(t) C.X1 = tonumber(t) or C.X1 end})
HT:CreateInput({Name = "X akhir", PlaceholderText = "3", RemoveTextAfterFocusLost = false,
   Callback = function(t) C.X2 = tonumber(t) or C.X2 end})
HT:CreateInput({Name = "Y", PlaceholderText = "36", RemoveTextAfterFocusLost = false,
   Callback = function(t) C.Y = tonumber(t) or C.Y end})
HT:CreateInput({Name = "Waktu tumbuh (detik)", PlaceholderText = "75", RemoveTextAfterFocusLost = false,
   Callback = function(t) C.Grow = tonumber(t) or C.Grow end})
HT:CreateInput({Name = "ID seed", PlaceholderText = "4587", RemoveTextAfterFocusLost = false,
   Callback = function(t) C.Seed = tonumber(t) or C.Seed end})
HT:CreateSlider({Name = "Delay antar tile (detik)", Range = {0.1, 1}, Increment = 0.05,
   CurrentValue = 0.15, Flag = "HD", Callback = function(v) C.Delay = v end})

HT:CreateSection("Gerak Otomatis")
HT:CreateParagraph({Title = "Kalibrasi", Content = "Berdiri di tempat kamu biasa punch tile X mulai, tekan Simpan A. Pindah ke tempat punch tile X akhir, tekan Simpan B."})
HT:CreateButton({Name = "Simpan posisi A (tile X mulai)", Callback = function()
   local h = getHRP()
   if h then C.PosA = h.CFrame notify("Posisi A", "Tersimpan") end
end})
HT:CreateButton({Name = "Simpan posisi B (tile X akhir)", Callback = function()
   local h = getHRP()
   if h then C.PosB = h.CFrame notify("Posisi B", "Tersimpan") end
end})
HT:CreateButton({Name = "Tes pindah ke A", Callback = function()
   local h = getHRP()
   if h and C.PosA then h.CFrame = C.PosA end
end})
HT:CreateButton({Name = "Tes pindah ke B", Callback = function()
   local h = getHRP()
   if h and C.PosB then h.CFrame = C.PosB end
end})
HT:CreateToggle({Name = "Gerak otomatis saat harvest", CurrentValue = false, Flag = "AutoMove",
   Callback = function(v) C.Move = v end})

HT:CreateSection("Kontrol")
local Status = HT:CreateParagraph({Title = "Status", Content = "Menunggu plant manual..."})
local function setStatus(t) pcall(function() Status:Set({Title = "Status", Content = t}) end) end

HT:CreateButton({Name = "Mulai timer sekarang", Callback = function()
   C.PlantAt = os.clock()
   notify("Timer", "Mulai dihitung dari sekarang")
end})
HT:CreateButton({Name = "Harvest 1x sekarang", Callback = function() harvestRow() end})
HT:CreateToggle({Name = "Auto Harvest (sesuai timer)", CurrentValue = false, Flag = "AutoHT",
   Callback = function(v)
      C.On = v
      if not v then return end
      task.spawn(function()
         while C.On do
            if C.PlantAt then
               local sisa = C.Grow - (os.clock() - C.PlantAt)
               if sisa <= 0 then
                  setStatus("Harvesting...")
                  harvestRow()
                  C.PlantAt = nil
                  setStatus("Selesai. Plant lagi untuk mulai timer baru.")
               else
                  setStatus(("Panen dalam %d detik"):format(math.ceil(sisa)))
               end
            end
            task.wait(1)
         end
      end)
   end,
})

-- ====== SPY ======
local SpyTab = Win:CreateTab("Spy", 4483362458)
SpyTab:CreateSection("Remote Spy")
SpyTab:CreateToggle({Name = "Aktifkan Spy", CurrentValue = false, Flag = "SpyOn",
   Callback = function(v) Spy.On = v end})
SpyTab:CreateButton({Name = "Salin log terakhir", Callback = function()
   if setclipboard then
      setclipboard(table.concat(Spy.Logs, "\n"))
      notify("Spy", #Spy.Logs .. " log disalin")
   end
end})
SpyTab:CreateButton({Name = "Hapus log", Callback = function() Spy.Logs = {} end})

-- ====== HOOK (satu hook untuk deteksi plant dan spy; dipasang terakhir) ======
local hookOk, hookErr = pcall(function()
   local old
   old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
      if getnamecallmethod() == "FireServer" and typeof(self) == "Instance" and not checkcaller() then
         if self == SetTile then
            local _, _, _, id = ...
            if id == C.Seed then C.PlantAt = os.clock() end
         end
         if Spy.On and not IGNORE[self.Name] then
            local args = table.pack(...)
            task.spawn(function()
               local t = {}
               for i = 1, args.n do t[i] = ser(args[i]) end
               local line = self:GetFullName() .. "(" .. table.concat(t, ", ") .. ")"
               Spy.Logs[#Spy.Logs + 1] = line
               if #Spy.Logs > 60 then table.remove(Spy.Logs, 1) end
               warn("[SPY]", line)
            end)
         end
      end
      return old(self, ...)
   end))
end)
if not hookOk then warn("[HUB] Hook gagal:", hookErr) end

notify("Berhasil!", "Menu berhasil dimuat.")
warn("[HUB] selesai")
