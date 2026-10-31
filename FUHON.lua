-- Memuat UI Library (Rayfield)
warn("[HUB] mulai")
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Variabel & Logika PNB
local RS = game:GetService("ReplicatedStorage")
local SetTile = RS:WaitForChild("WorldRemotes", 10):WaitForChild("SetTile", 10)
local Reliable = RS:FindFirstChild("ByteNetReliable")
local C = {X = 0, Y = 0, Item = 0, Delay = 0.3, On = false}
local Last, Recipe, Pending = nil, nil, {}

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

-- Membuat Window Utama
local Window = Rayfield:CreateWindow({
   Name = "Growtopia Script Hub",
   LoadingTitle = "Memuat Hub...",
   LoadingSubtitle = "oleh Pemula",
   ConfigurationSaving = {
      Enabled = false,
   },
   KeySystem = false,
})

-- 1. Tab Home
local HomeTab = Window:CreateTab("Home", 4483362458)
HomeTab:CreateSection("Selamat Datang")
HomeTab:CreateParagraph({Title = "Status Hub", Content = "Script berhasil dimuat dan siap digunakan."})

-- 2. Tab PNB (Place & Break dengan Logika Asli)
local PNBTab = Window:CreateTab("PNB", 4483362458)
PNBTab:CreateSection("Pengaturan PNB")

PNBTab:CreateButton({
   Name = "Ambil dari place terakhir", 
   Callback = function()
      if not Last then
         Rayfield:Notify({Title = "Belum ada", Content = "Place 1 block manual dulu", Duration = 3})
         return
      end
      C.X, C.Y, C.Item = Last.x, Last.y, Last.id
      Rayfield:Notify({Title = "Tersimpan", Content = C.X .. "," .. C.Y .. " item " .. C.Item, Duration = 3})
   end
})

PNBTab:CreateButton({
   Name = "Cek recipe break", 
   Callback = function()
      Rayfield:Notify({Title = "Recipe", Content = Recipe and (#Recipe .. " paket tersimpan") or "Belum ada, break manual dulu", Duration = 4})
   end
})

PNBTab:CreateButton({
   Name = "Tes Place 1x", 
   Callback = function() 
      fire(C.Item) 
   end
})

PNBTab:CreateButton({
   Name = "Tes Break 1x", 
   Callback = function() 
      brk() 
   end
})

PNBTab:CreateSlider({
   Name = "Delay (detik)", 
   Range = {0.1, 1}, 
   Increment = 0.05, 
   CurrentValue = 0.3, 
   Flag = "D",
   Callback = function(v) 
      C.Delay = v 
   end
})

PNBTab:CreateToggle({
   Name = "Auto PNB", 
   CurrentValue = false, 
   Flag = "PNB", 
   Callback = function(v)
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
   end
})

-- 3. Tab PT (Plant)
local PTTab = Window:CreateTab("PT", 4483362458)
PTTab:CreateSection("Pengaturan Plant")
PTTab:CreateButton({
   Name = "Auto Plant Seed",
   Callback = function()
      print("Menanam bibit secara otomatis...")
      Rayfield:Notify({Title = "Plant", Content = "Menanam bibit secara otomatis...", Duration = 3})
   end,
})

-- 4. Tab HT (Harvest)
local HTTab = Window:CreateTab("HT", 4483362458)
HTTab:CreateSection("Pengaturan Harvest")
HTTab:CreateButton({
   Name = "Auto Harvest (Panen)",
   Callback = function()
      print("Memanen tanaman secara otomatis...")
      Rayfield:Notify({Title = "Harvest", Content = "Memanen tanaman secara otomatis...", Duration = 3})
   end,
})

-- 5. Tab Tools / Memuat Skrip FUHON
local ToolsTab = Window:CreateTab("Tools", 4483362458)
ToolsTab:CreateSection("Eksplorasi & Custom Script")
ToolsTab:CreateButton({
   Name = "Muat Skrip FUHON",
   Callback = function()
      local success, err = pcall(function()
         loadstring(game:HttpGet("https://raw.githubusercontent.com/depinrajasfonk-blip/fuhon/refs/heads/main/FUHON.lua"))()
      end)
      
      if success then
         Rayfield:Notify({
            Title = "Sukses",
            Content = "Skrip FUHON berhasil dimuat!",
            Duration = 3,
            Image = 4483362458,
         })
      else
         warn("Gagal memuat skrip:", err)
         Rayfield:Notify({
            Title = "Gagal",
            Content = "Gagal memuat skrip. Cek console (F9).",
            Duration = 3,
            Image = 4483362458,
         })
      end
   end,
})

-- Hook Metamethod untuk Mendeteksi PNB & Recipe secara Otomatis di Background
pcall(function()
   local old
   old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
      if getnamecallmethod() == "FireServer" and not checkcaller() then
         if self == SetTile then
            local _, x, y, id = ...
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
         elseif self == Reliable then
            local b = ...
            if typeof(b) == "buffer" then
               Pending[#Pending + 1] = {t = os.clock(), s = buffer.tostring(b)}
               if #Pending > 30 then table.remove(Pending, 1) end
            end
         end
      end
      return old(self, ...)
   end))
end)

-- Notifikasi Berhasil
Rayfield:Notify({
   Title = "Berhasil!",
   Content = "Menu berhasil dimuat.",
   Duration = 5,
   Image = 4483362458,
})
warn("[HUB] selesai")
