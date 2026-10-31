-- Growtopia Hub (Home, HT dengan gerak otomatis, Spy) - ringkas untuk di-host di GitHub
warn("[HUB] mulai")

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")
local GS = game:GetService("GuiService")
local LP = Players.LocalPlayer
local WR = RS:WaitForChild("WorldRemotes", 10)
local SetTile = WR and WR:WaitForChild("SetTile", 10)
local Unr = RS:FindFirstChild("ByteNetUnreliable") -- paket posisi karakter

if not SetTile then
   warn("[HUB] WorldRemotes.SetTile tidak ditemukan")
   Rayfield:Notify({Title = "Error", Content = "Remote SetTile tidak ditemukan", Duration = 6})
   return
end

-- ====== KONFIGURASI ======
local C = {
   X1 = 0, X2 = 3, Y = 36,   -- baris tree yang dipanen (koordinat tile)
   Delay = 0.15,             -- jeda antar tile
   Grow = 75,                -- waktu tumbuh (detik), bisa diisi "3j47m"
   Margin = 15,              -- jeda aman tambahan (detik)
   Seed = 4587,              -- ID seed sugarcane
   PlantAt = nil, On = false,
   Move = false,             -- gerak otomatis
   Win = 3,                  -- jumlah tile yang dipanen per posisi berdiri
   Tol = 0.6,                -- toleransi posisi (tile)
}
local Pos = {x = nil, y = nil}
local Spy = {On = false, Logs = {}}
local IGNORE = {ByteNetUnreliable = true, SaveInventory = true}

-- ====== WAKTU (tahan sampai berjam-jam, tersimpan walau rejoin) ======
local SAVE = "growtopia_hub_plantat.txt"
local function savePlant()
   pcall(function()
      if writefile then writefile(SAVE, C.PlantAt and tostring(C.PlantAt) or "") end
   end)
end
local function loadPlant()
   pcall(function()
      if isfile and isfile(SAVE) then C.PlantAt = tonumber(readfile(SAVE)) end
   end)
end
-- "70" = 70 detik, "1m10s", "3j47m" / "3h47m" (j/h = jam, m = menit, s/d = detik)
local function parseDur(text)
   text = tostring(text):lower():gsub("%s", "")
   local plain = tonumber(text)
   if plain then return plain end
   local total, found = 0, false
   for num, unit in text:gmatch("(%d+%.?%d*)([a-z])") do
      local mult = (unit == "h" or unit == "j") and 3600 or (unit == "m") and 60
         or (unit == "s" or unit == "d") and 1 or nil
      if mult then total += tonumber(num) * mult found = true end
   end
   return found and total or nil
end
local function fmt(sec)
   sec = math.max(0, math.ceil(sec))
   return ("%dj %dm %dd"):format(sec // 3600, (sec % 3600) // 60, sec % 60)
end

-- ====== GERAK (menekan tombol Left/Right di layar) ======
local function pressBtn(btn, down)
   local p, s = btn.AbsolutePosition, btn.AbsoluteSize
   local x, y = p.X + s.X / 2, p.Y + s.Y / 2 + GS:GetGuiInset().Y
   VIM:SendMouseButtonEvent(x, y, 0, down, game, 0)
end

local function goTo(tx)
   local gui = LP.PlayerGui:FindFirstChild("MobileGui")
   local L, R = gui and gui:FindFirstChild("Left"), gui and gui:FindFirstChild("Right")
   if not (L and R and Pos.x) then
      warn("[HUB] gerak tidak bisa: tombol atau posisi belum terbaca")
      return false
   end
   for _ = 1, 12 do
      local dx = tx - Pos.x
      if math.abs(dx) <= C.Tol then return true end
      local btn = dx > 0 and R or L
      pressBtn(btn, true)
      local t0 = os.clock()
      while os.clock() - t0 < 0.6 do
         task.wait(0.03)
         local d2 = tx - Pos.x
         if (dx > 0 and d2 <= C.Tol) or (dx < 0 and d2 >= -C.Tol) then break end
      end
      pressBtn(btn, false)
      task.wait(0.25) -- beri waktu posisi terbaru terkirim
   end
   return math.abs(tx - Pos.x) <= C.Tol * 2
end

-- ====== HARVEST ======
local function harvestRow()
   local home = Pos.x
   local lo, hi = math.min(C.X1, C.X2), math.max(C.X1, C.X2)
   local x = lo
   while x <= hi do
      local stop = math.min(x + C.Win - 1, hi)
      if C.Move then goTo((x + stop) / 2 + 0.5) end
      for t = x, stop do
         SetTile:FireServer("fg", t, C.Y, 0)
         task.wait(C.Delay)
      end
      x = stop + 1
   end
   if C.Move and home then goTo(home) end
end

-- ====== SPY (helper) ======
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
   Content = "Berdiri sejajar baris tree (ketinggian yang sama seperti kalau punch manual). Isi X, Y, waktu tumbuh. Nyalakan Auto Harvest, lalu plant seed manual."
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
HT:CreateInput({Name = "Waktu tumbuh (contoh: 3j47m atau 70)", PlaceholderText = "3j47m", RemoveTextAfterFocusLost = false,
   Callback = function(t)
      local d = parseDur(t)
      if d then C.Grow = d notify("Waktu tumbuh", fmt(d)) else notify("Format salah", "Contoh: 3j47m, 1m10s, atau 70") end
   end})
HT:CreateInput({Name = "Jeda aman tambahan (detik)", PlaceholderText = "15", RemoveTextAfterFocusLost = false,
   Callback = function(t) C.Margin = tonumber(t) or C.Margin end})
HT:CreateInput({Name = "ID seed", PlaceholderText = "4587", RemoveTextAfterFocusLost = false,
   Callback = function(t) C.Seed = tonumber(t) or C.Seed end})
HT:CreateSlider({Name = "Delay antar tile (detik)", Range = {0.1, 1}, Increment = 0.05,
   CurrentValue = 0.15, Flag = "HD", Callback = function(v) C.Delay = v end})

HT:CreateSection("Gerak Otomatis")
HT:CreateToggle({Name = "Gerak otomatis saat harvest", CurrentValue = false, Flag = "AutoMove",
   Callback = function(v) C.Move = v end})
HT:CreateSlider({Name = "Tile per posisi berdiri", Range = {1, 5}, Increment = 1,
   CurrentValue = 3, Flag = "Win", Callback = function(v) C.Win = v end})
HT:CreateButton({Name = "Tes jalan ke X mulai", Callback = function()
   local ok = goTo(math.min(C.X1, C.X2) + 0.5)
   notify("Gerak", ok and "Sampai" or "Gagal / belum pas")
end})
HT:CreateButton({Name = "Tes jalan ke X akhir", Callback = function()
   local ok = goTo(math.max(C.X1, C.X2) + 0.5)
   notify("Gerak", ok and "Sampai" or "Gagal / belum pas")
end})

HT:CreateSection("Kontrol")
local Status = HT:CreateParagraph({Title = "Status", Content = "Menunggu plant manual..."})
local function setStatus(t) pcall(function() Status:Set({Title = "Status", Content = t}) end) end

HT:CreateButton({Name = "Mulai timer sekarang", Callback = function()
   C.PlantAt = os.time()
   savePlant()
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
               local sisa = C.Grow + C.Margin - (os.time() - C.PlantAt)
               if sisa <= 0 then
                  setStatus("Harvesting...")
                  harvestRow()
                  C.PlantAt = nil
                  savePlant()
                  setStatus("Selesai. Plant lagi untuk mulai timer baru.")
               else
                  setStatus("Panen dalam " .. fmt(sisa))
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

-- ====== HOOK (posisi, deteksi plant, spy; dipasang terakhir) ======
local hookOk, hookErr = pcall(function()
   local old
   old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
      if getnamecallmethod() == "FireServer" and typeof(self) == "Instance" and not checkcaller() then
         if self == Unr then
            local b = ...
            if typeof(b) == "buffer" and buffer.len(b) >= 9 and buffer.readu8(b, 0) == 2 then
               Pos.y = buffer.readf32(b, 1)
               Pos.x = buffer.readf32(b, 5)
            end
         elseif self == SetTile then
            local _, _, _, id = ...
            if id == C.Seed then C.PlantAt = os.time() task.spawn(savePlant) end
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

loadPlant()
if C.PlantAt then notify("Timer dipulihkan", "Timer plant terakhir dilanjutkan") end
notify("Berhasil!", "Menu berhasil dimuat.")
warn("[HUB] selesai")
