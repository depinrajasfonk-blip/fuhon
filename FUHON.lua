-- Growtopia Hub (Home, PNB, HT, Tools/FUHON, Spy)
warn("[HUB] mulai")

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")
local GS = game:GetService("GuiService")
local LP = Players.LocalPlayer

local WR = RS:WaitForChild("WorldRemotes", 10)
local SetTile = WR and WR:WaitForChild("SetTile", 10)
local Reliable = RS:FindFirstChild("ByteNetReliable")
local Unr = RS:FindFirstChild("ByteNetUnreliable") -- paket posisi karakter

if not SetTile then
   warn("[HUB] WorldRemotes.SetTile tidak ditemukan")
   Rayfield:Notify({Title = "Error", Content = "Remote SetTile tidak ditemukan", Duration = 6})
   return
end

-- ====== KONFIGURASI PNB & HT ======
local C = {
   -- Konfigurasi PNB
   X = 0, Y = 0, Item = 0, Delay = 0.3, On = false,
   -- Konfigurasi HT (Harvest)
   X1 = 0, X2 = 3, Y_HT = 36,   -- baris tree yang dipanen
   DelayHT = 0.15,              -- jeda antar tile HT
   Grow = 75,                   -- waktu tumbuh (detik)
   Margin = 15,                 -- jeda aman tambahan (detik)
   Seed = 4587,                 -- ID seed sugarcane
   PlantAt = nil, OnHT = false,
   Move = false,                -- gerak otomatis
   Win = 3,                     -- jumlah tile yang dipanen per posisi berdiri
   Tol = 0.6,                   -- toleransi posisi (tile)
}

local Pos = {x = nil, y = nil}
local Last, Recipe, Pending = nil, nil, {}
local Spy = {On = false, Logs = {}}
local IGNORE = {ByteNetUnreliable = true, SaveInventory = true}

-- ====== WAKTU (Timer HT) ======
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

-- ====== GERAK OTOMATIS (untuk HT) ======
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
      task.wait(0.25)
   end
   return math.abs(tx - Pos.x) <= C.Tol * 2
end

-- ====== LOGIKA PNB & HARVEST ======
local function fire(id) 
   SetTile:FireServer("fg", C.X, C.Y, id) 
end

local function brk()
   if Recipe and Reliable then
      for _, s in ipairs(Recipe) do
         Reliable:FireServer(buffer.fromstring(s))
         task.wait(0.05)
      end
   end
   fire(0)
end

local function harvestRow()
   local home = Pos.x
   local lo, hi = math.min(C.X1, C.X2), math.max(C.X1, C.X2)
   local x = lo
   while x <= hi do
      local stop = math.min(x + C.Win - 1, hi)
      if C.Move then goTo((x + stop) / 2 + 0.5) end
      for t = x, stop do
         SetTile:FireServer("fg", t, C.Y_HT, 0)
         task.wait(C.DelayHT)
      end
      x = stop + 1
   end
   if C.Move and home then goTo(home) end
end

-- ====== SPY HELPER ======
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

-- ====== MEMBUAT WINDOW RAYFIELD ======
local Win = Rayfield:CreateWindow({
   Name = "Growtopia Script Hub",
   LoadingTitle = "Memuat Hub...",
   LoadingSubtitle = "oleh Pemula",
   ConfigurationSaving = {Enabled = false},
   KeySystem = false,
})

local function notify(title, content)
   Rayfield:Notify({Title = title, Content = content, Duration = 4, Image = 4483362458})
end

-- 1. TAB HOME
local HomeTab = Win:CreateTab("Home", 4483362458)
HomeTab:CreateSection("Selamat Datang")
HomeTab:CreateParagraph({
   Title = "Panduan Singkat",
   Content = "Gunakan Tab PNB untuk tempat pecah block otomatis, Tab HT untuk panen otomatis dengan timer/gerak, dan Tab Tools untuk memuat skrip tambahan."
})

-- 2. TAB PNB
local PNBTab = Win:CreateTab("PNB", 4483362458)
PNBTab:CreateSection("Pengaturan PNB")

PNBTab:CreateButton({Name = "Ambil dari place terakhir", Callback = function()
   if not Last then
      notify("Belum ada", "Place 1 block manual dulu")
      return
   end
   C.X, C.Y, C.Item = Last.x, Last.y, Last.id
   notify("Tersimpan", C.X .. "," .. C.Y .. " item " .. C.Item)
end})

PNBTab:CreateButton({Name = "Cek recipe break", Callback = function()
   notify("Recipe", Recipe and (#Recipe .. " paket tersimpan") or "Belum ada, break manual dulu")
end})

PNBTab:CreateButton({Name = "Tes Place 1x", Callback = function() fire(C.Item) end})
PNBTab:CreateButton({Name = "Tes Break 1x", Callback = function() brk() end})

PNBTab:CreateSlider({Name = "Delay (detik)", Range = {0.1, 1}, Increment = 0.05, CurrentValue = 0.3, Flag = "D",
   Callback = function(v) C.Delay = v end})

PNBTab:CreateToggle({Name = "Auto PNB", CurrentValue = false, Flag = "PNB", Callback = function(v)
   C.On = v
   if v then
      task.spawn(function()
         while C.On do
            fire(C.Item)
            task.wait(C.Delay / 2)
            brk()
            task.wait(C.Delay / 2)
         end
      end)
   end
end})

-- 3. TAB HT (Harvest)
local HTTab = Win:CreateTab("HT", 4483362458)
HTTab:CreateSection("Baris Tree")
HTTab:CreateInput({Name = "X mulai", PlaceholderText = "0", RemoveTextAfterFocusLost = false,
   Callback = function(t) C.X1 = tonumber(t) or C.X1 end})
HTTab:CreateInput({Name = "X akhir", PlaceholderText = "3", RemoveTextAfterFocusLost = false,
   Callback = function(t) C.X2 = tonumber(t) or C.X2 end})
HTTab:CreateInput({Name = "Y", PlaceholderText = "36", RemoveTextAfterFocusLost = false,
   Callback = function(t) C.Y_HT = tonumber(t) or C.Y_HT end})
HTTab:CreateInput({Name = "Waktu tumbuh (contoh: 3j47m atau 70)", PlaceholderText = "3j47m", RemoveTextAfterFocusLost = false,
   Callback = function(t)
      local d = parseDur(t)
      if d then C.Grow = d notify("Waktu tumbuh", fmt(d)) else notify("Format salah", "Contoh: 3j47m, 1m10s, atau 70") end
   end})
HTTab:CreateInput({Name = "Jeda aman tambahan (detik)", PlaceholderText = "15", RemoveTextAfterFocusLost = false,
   Callback = function(t) C.Margin = tonumber(t) or C.Margin end})
HTTab:CreateInput({Name = "ID seed", PlaceholderText = "4587", RemoveTextAfterFocusLost = false,
   Callback = function(t) C.Seed = tonumber(t) or C.Seed end})
HTTab:CreateSlider({Name = "Delay antar tile (detik)", Range = {0.1, 1}, Increment = 0.05,
   CurrentValue = 0.15, Flag = "HD", Callback = function(v) C.DelayHT = v end})

HTTab:CreateSection("Gerak Otomatis")
HTTab:CreateToggle({Name = "Gerak otomatis saat harvest", CurrentValue = false, Flag = "AutoMove",
   Callback = function(v) C.Move = v end})
HTTab:CreateSlider({Name = "Tile per posisi berdiri", Range = {1, 5}, Increment = 1,
   CurrentValue = 3, Flag = "Win", Callback = function(v) C.Win = v end})
HTTab:CreateButton({Name = "Tes jalan ke X mulai", Callback = function()
   local ok = goTo(math.min(C.X1, C.X2) + 0.5)
   notify("Gerak", ok and "Sampai" or "Gagal / belum pas")
end})
HTTab:CreateButton({Name = "Tes jalan ke X akhir", Callback = function()
   local ok = goTo(math.max(C.X1, C.X2) + 0.5)
   notify("Gerak", ok and "Sampai" or "Gagal / belum pas")
end})

HTTab:CreateSection("Kontrol HT")
local Status = HTTab:CreateParagraph({Title = "Status", Content = "Menunggu plant manual..."})
local function setStatus(t) pcall(function() Status:Set({Title = "Status", Content = t}) end) end

HTTab:CreateButton({Name = "Mulai timer sekarang", Callback = function()
   C.PlantAt = os.time()
   savePlant()
   notify("Timer", "Mulai dihitung dari sekarang")
end})
HTTab:CreateButton({Name = "Harvest 1x sekarang", Callback = function() harvestRow() end})
HTTab:CreateToggle({Name = "Auto Harvest (sesuai timer)", CurrentValue = false, Flag = "AutoHT",
   Callback = function(v)
      C.OnHT = v
      if not v then return end
      task.spawn(function()
         while C.OnHT do
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

-- 4. TAB TOOLS (Memuat Skrip FUHON dari GitHub Anda)
local ToolsTab = Win:CreateTab("Tools", 4483362458)
ToolsTab:CreateSection("Custom Script Loader")
ToolsTab:CreateButton({
   Name = "Muat Skrip FUHON",
   Callback = function()
      local success, err = pcall(function()
         loadstring(game:HttpGet("https://raw.githubusercontent.com/depinrajasfonk-blip/fuhon/refs/heads/main/FUHON.lua"))()
      end)
      
      if success then
         notify("Sukses", "Skrip FUHON berhasil dimuat!")
      else
         warn("Gagal memuat skrip:", err)
         notify("Gagal", "Gagal memuat skrip. Cek console (F9).")
      end
   end,
})

-- 5. TAB SPY
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

-- ====== HOOK METAMETHOD (Background Listener) ======
pcall(function()
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
            local _, x, y, id = ...
            -- Deteksi untuk PNB (Place terakhir)
            if id and id ~= 0 then
               Last = {x = x, y = y, id = id}
            elseif id == 0 then
               local r = {}
               for _, p in ipairs(Pending) do
                  if os.clock() - p.t < 1.5 then r[#r + 1] = p.s end
               end
               Recipe = r
               Pending = {}
            end
            -- Deteksi untuk HT (Plant seed)
            if id == C.Seed then 
               C.PlantAt = os.time() 
               task.spawn(savePlant) 
            end
         elseif self == Reliable then
            local b = ...
            if typeof(b) == "buffer" then
               Pending[#Pending + 1] = {t = os.clock(), s = buffer.tostring(b)}
               if #Pending > 30 then table.remove(Pending, 1) end
            end
         end

         -- Logika Spy
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

loadPlant()
if C.PlantAt then notify("Timer dipulihkan", "Timer plant terakhir dilanjutkan") end
notify("Berhasil!", "Growtopia Hub berhasil dimuat.")
warn("[HUB] selesai")
