-- Memuat UI Library (Rayfield)
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

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

-- 2. Tab PNB (Place & Break)
local PNBTab = Window:CreateTab("PNB", 4483362458)
PNBTab:CreateSection("Pengaturan PNB")
PNBTab:CreateToggle({
   Name = "Auto PNB (Place & Break)",
   CurrentValue = false,
   Flag = "AutoPNB",
   Callback = function(Value)
      if Value then
         print("Auto PNB diaktifkan!")
      else
         print("Auto PNB dimatikan!")
      end
   end,
})

-- 3. Tab PT (Plant)
local PTTab = Window:CreateTab("PT", 4483362458)
PTTab:CreateSection("Pengaturan Plant")
PTTab:CreateButton({
   Name = "Auto Plant Seed",
   Callback = function()
      print("Menanam bibit secara otomatis...")
   end,
})

-- 4. Tab HT (Harvest)
local HTTab = Window:CreateTab("HT", 4483362458)
HTTab:CreateSection("Pengaturan Harvest")
HTTab:CreateButton({
   Name = "Auto Harvest (Panen)",
   Callback = function()
      print("Memanen tanaman secara otomatis...")
   end,
})

-- Notifikasi Berhasil
Rayfield:Notify({
   Title = "Berhasil!",
   Content = "Menu berhasil dimuat.",
   Duration = 5,
   Image = 4483362458,
})
  
