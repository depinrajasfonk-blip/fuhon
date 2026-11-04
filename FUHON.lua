warn("[HUB] mulai")

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")
local GS = game:GetService("GuiService")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer

local WR = RS:WaitForChild("WorldRemotes", 10)
local SetTile = WR and WR:WaitForChild("SetTile", 10)
local Reliable = RS:FindFirstChild("ByteNetReliable")
local Unr = RS:FindFirstChild("ByteNetUnreliable")
local SetBusy = WR and WR:FindFirstChild("SetBusy")

if not SetTile then
   Rayfield:Notify({Title="Error", Content="SetTile tidak ditemukan", Duration=6}) return
end

-- ====== STATE ======
local C = {
   -- PNB
   X=0, Y=0, Item=0, Delay=0.3, PNBOn=false, Collect=true,
   -- HT
   X1=0, X2=3, Y_HT=36, DelayHT=0.15, Grow=75, Margin=15,
   Seed=4587, PlantAt=nil, OnHT=false, Move=false, Win=3, Tol=0.6,
}
local Pos = {x=nil, y=nil}
local Last, Recipe, Pending = nil, {}, {}
local Spy = {On=false, Logs={}}
local IGNORE = {ByteNetUnreliable=true, SaveInventory=true}
local SAVE = "growtopia_hub_plantat.txt"
local BlockBroken = false   -- flag: server konfirmasi break
local SelectMode = false    -- mode pilih tile dengan klik

-- ====== UTIL ======
local function notify(t, c) Rayfield:Notify({Title=t, Content=c, Duration=4, Image=4483362458}) end
local function savePlant() pcall(function() if writefile then writefile(SAVE, C.PlantAt and tostring(C.PlantAt) or "") end end) end
local function loadPlant() pcall(function() if isfile and isfile(SAVE) then C.PlantAt=tonumber(readfile(SAVE)) end end) end
local function parseDur(text)
   text=tostring(text):lower():gsub("%s","")
   local plain=tonumber(text) if plain then return plain end
   local total,found=0,false
   for num,unit in text:gmatch("(%d+%.?%d*)([a-z])") do
      local m=(unit=="h"or unit=="j")and 3600 or unit=="m"and 60 or(unit=="s"or unit=="d")and 1 or nil
      if m then total=total+tonumber(num)*m found=true end
   end
   return found and total or nil
end
local function fmt(sec)
   sec=math.max(0,math.ceil(sec))
   return string.format("%dj %dm %dd", sec//3600, (sec%3600)//60, sec%60)
end

-- ====== GERAK ======
local function pressBtn(btn, down)
   local p,s=btn.AbsolutePosition,btn.AbsoluteSize
   local x,y=p.X+s.X/2,p.Y+s.Y/2+GS:GetGuiInset().Y
   VIM:SendMouseButtonEvent(x,y,0,down,game,0)
end
local function goTo(tx)
   local gui=LP.PlayerGui:FindFirstChild("MobileGui")
   local L,R=gui and gui:FindFirstChild("Left"),gui and gui:FindFirstChild("Right")
   if not(L and R and Pos.x) then return false end
   for _=1,12 do
      local dx=tx-Pos.x if math.abs(dx)<=C.Tol then return true end
      local btn=dx>0 and R or L
      pressBtn(btn,true)
      local t0=os.clock()
      while os.clock()-t0<0.6 do
         task.wait(0.03)
         local d2=tx-Pos.x
         if(dx>0 and d2<=C.Tol)or(dx<0 and d2>=-C.Tol)then break end
      end
      pressBtn(btn,false) task.wait(0.25)
   end
   return math.abs(tx-Pos.x)<=C.Tol*2
end

-- ====== KLIK PILIH TILE ======
-- Hitung koordinat tile dari posisi layar
local function screenToTile(screenX, screenY)
   local ok, tiles = pcall(function()
      return LP.PlayerGui.GameGui.World.Camera.Tiles
   end)
   if not ok or not tiles then return nil, nil end
   local tp = tiles.AbsolutePosition
   local TILE = 64
   return math.floor((screenX - tp.X) / TILE),
          math.floor((screenY - tp.Y) / TILE)
end

local TileInfoLabel  -- paragraph UI untuk update info tile terpilih
local function updateTileInfo()
   pcall(function()
      TileInfoLabel:Set({
         Title = "Tile Terpilih",
         Content = string.format("X=%d  Y=%d  Item=%d\nRecipe: %d paket", C.X, C.Y, C.Item, #Recipe)
      })
   end)
end

UIS.InputBegan:Connect(function(input, gpe)
   if not SelectMode then return end
   local isClick = input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch
   if not isClick then return end
   local pos = input.Position
   local tx, ty = screenToTile(pos.X, pos.Y)
   if tx and ty then
      C.X, C.Y = tx, ty
      SelectMode = false
      notify("Tile dipilih", string.format("X=%d  Y=%d", tx, ty))
      updateTileInfo()
   end
end)

-- ====== PNB ======
local function fire(id) pcall(function() SetTile:FireServer("fg", C.X, C.Y, id) end) end

local function brk()
   if #Recipe > 0 and Reliable then
      for _, s in ipairs(Recipe) do
         pcall(function() Reliable:FireServer(buffer.fromstring(s)) end)
         task.wait(0.05)
      end
   end
   fire(0)
end

-- Tunggu server konfirmasi block hancur (max timeout detik)
local function waitBroken(timeout)
   BlockBroken = false
   local t0 = os.clock()
   while not BlockBroken and os.clock()-t0 < timeout do
      task.wait(0.05)
   end
   return BlockBroken
end

-- Auto Collect setelah break: jalan ke tile lalu kembali
local function doCollect()
   if not C.Collect or not Pos.x then return end
   if SetBusy then pcall(function() SetBusy:FireServer(1) end) end
   goTo(C.X + 0.5)
   task.wait(0.3)
   if SetBusy then pcall(function() SetBusy:FireServer(0) end) end
end

-- ====== HARVEST ======
local function harvestRow()
   local home=Pos.x
   local lo,hi=math.min(C.X1,C.X2),math.max(C.X1,C.X2)
   local x=lo
   while x<=hi do
      local stop=math.min(x+C.Win-1,hi)
      if C.Move then goTo((x+stop)/2+0.5) end
      for t=x,stop do SetTile:FireServer("fg",t,C.Y_HT,0) task.wait(C.DelayHT) end
      x=stop+1
   end
   if C.Move and home then goTo(home) end
end

-- ====== SPY HELPER ======
local function hex(b)
   local ok,s=pcall(function()
      local out={}
      for i=0,math.min(buffer.len(b),32)-1 do out[#out+1]=string.format("%02X",buffer.readu8(b,i)) end
      return table.concat(out," ")
   end)
   return ok and s or "?"
end
local function ser(v)
   local t=typeof(v)
   if t=="buffer" then return "buffer["..hex(v).."]" end
   if t=="string" then return string.format("%q",v) end
   return t..":"..tostring(v)
end

-- ====== WINDOW ======
local Win = Rayfield:CreateWindow({
   Name="Growtopia Script Hub",
   LoadingTitle="Memuat Hub...",
   LoadingSubtitle="oleh Pemula",
   ConfigurationSaving={Enabled=false},
   KeySystem=false,
})

-- ====== HOME ======
local HomeTab = Win:CreateTab("Home", 4483362458)
HomeTab:CreateSection("Selamat Datang")
HomeTab:CreateParagraph({Title="Panduan Singkat",
   Content="PNB: klik tile di layar untuk pilih lokasi, lalu aktifkan.\nHT: auto harvest dengan timer.\nSpy: rekam remote."})

-- ====== PNB ======
local PNBTab = Win:CreateTab("PNB", 4483362458)
PNBTab:CreateSection("Pilih Lokasi")

TileInfoLabel = PNBTab:CreateParagraph({Title="Tile Terpilih", Content="Belum dipilih. Tekan tombol di bawah lalu klik tile di layar."})

PNBTab:CreateButton({Name="[TAP] Pilih Tile dengan Klik Layar", Callback=function()
   SelectMode = true
   notify("Mode Pilih", "Klik tile di layar game sekarang!")
end})

PNBTab:CreateButton({Name="Ambil dari place terakhir", Callback=function()
   if not Last then notify("Belum ada","Place 1 block manual dulu") return end
   C.X, C.Y, C.Item = Last.x, Last.y, Last.id
   updateTileInfo()
   notify("Tersimpan", string.format("%d,%d item %d", C.X, C.Y, C.Item))
end})

PNBTab:CreateSection("Tes & Info")
PNBTab:CreateButton({Name="Tes Place 1x", Callback=function()
   fire(C.Item)
   notify("Place", string.format("Tile %d,%d item %d", C.X, C.Y, C.Item))
end})
PNBTab:CreateButton({Name="Tes Break 1x", Callback=function()
   brk()
   notify("Break", string.format("Tile %d,%d | %d paket recipe", C.X, C.Y, #Recipe))
end})
PNBTab:CreateButton({Name="Cek Recipe", Callback=function()
   notify("Recipe", #Recipe>0 and (#Recipe.." paket tersimpan") or "Belum ada, break manual dulu")
end})

PNBTab:CreateSection("Kontrol")
PNBTab:CreateSlider({Name="Delay satu siklus (detik)", Range={0.1,2}, Increment=0.05,
   CurrentValue=0.3, Flag="D", Callback=function(v) C.Delay=v end})
PNBTab:CreateToggle({Name="Auto Collect setelah Break", CurrentValue=true, Flag="PNBCollect",
   Callback=function(v) C.Collect=v end})

local PNBStatus = PNBTab:CreateParagraph({Title="Status PNB", Content="Tidak aktif."})
local function setPNBStatus(t) pcall(function() PNBStatus:Set({Title="Status PNB", Content=t}) end) end

PNBTab:CreateToggle({Name="Auto PNB", CurrentValue=false, Flag="PNBOn", Callback=function(v)
   C.PNBOn = v
   if not v then setPNBStatus("Dihentikan.") return end
   if C.Item == 0 then
      notify("PNB","Item ID = 0! Pilih tile dulu atau place manual.")
      C.PNBOn=false return
   end
   task.spawn(function()
      local cycle = 0
      while C.PNBOn do
         cycle = cycle + 1
         -- PLACE
         fire(C.Item)
         setPNBStatus(string.format("Siklus %d: Place %d,%d item %d", cycle, C.X, C.Y, C.Item))
         task.wait(C.Delay / 2)
         -- BREAK
         brk()
         setPNBStatus(string.format("Siklus %d: Break, menunggu konfirmasi...", cycle))
         -- TUNGGU SERVER KONFIRMASI BLOCK HANCUR (max 1.5 detik)
         local broken = waitBroken(1.5)
         if not broken then
            -- Kirim break sekali lagi kalau belum terkonfirmasi
            brk()
            waitBroken(1)
         end
         -- AUTO COLLECT
         if C.Collect then
            task.spawn(doCollect)
         end
         task.wait(C.Delay / 2)
      end
      setPNBStatus("Dihentikan.")
   end)
end})

-- ====== HT ======
local HTTab = Win:CreateTab("HT", 4483362458)
HTTab:CreateSection("Baris Tree")
HTTab:CreateInput({Name="X mulai", PlaceholderText="0", RemoveTextAfterFocusLost=false, Callback=function(t) C.X1=tonumber(t)or C.X1 end})
HTTab:CreateInput({Name="X akhir", PlaceholderText="3", RemoveTextAfterFocusLost=false, Callback=function(t) C.X2=tonumber(t)or C.X2 end})
HTTab:CreateInput({Name="Y", PlaceholderText="36", RemoveTextAfterFocusLost=false, Callback=function(t) C.Y_HT=tonumber(t)or C.Y_HT end})
HTTab:CreateInput({Name="Waktu tumbuh (contoh: 3j47m)", PlaceholderText="3j47m", RemoveTextAfterFocusLost=false,
   Callback=function(t)
      local d=parseDur(t)
      if d then C.Grow=d notify("Waktu tumbuh",fmt(d)) else notify("Format salah","Contoh: 3j47m, 70") end
   end})
HTTab:CreateInput({Name="Jeda aman tambahan (detik)", PlaceholderText="15", RemoveTextAfterFocusLost=false,
   Callback=function(t) C.Margin=tonumber(t)or C.Margin end})
HTTab:CreateInput({Name="ID seed", PlaceholderText="4587", RemoveTextAfterFocusLost=false,
   Callback=function(t) C.Seed=tonumber(t)or C.Seed end})
HTTab:CreateSlider({Name="Delay antar tile", Range={0.1,1}, Increment=0.05, CurrentValue=0.15, Flag="HD",
   Callback=function(v) C.DelayHT=v end})
HTTab:CreateSection("Gerak Otomatis")
HTTab:CreateToggle({Name="Gerak otomatis saat harvest", CurrentValue=false, Flag="AutoMove",
   Callback=function(v) C.Move=v end})
HTTab:CreateSlider({Name="Tile per posisi berdiri", Range={1,5}, Increment=1, CurrentValue=3, Flag="Win",
   Callback=function(v) C.Win=v end})
HTTab:CreateButton({Name="Tes jalan ke X mulai", Callback=function()
   notify("Gerak", goTo(math.min(C.X1,C.X2)+0.5) and "Sampai" or "Gagal")
end})
HTTab:CreateButton({Name="Tes jalan ke X akhir", Callback=function()
   notify("Gerak", goTo(math.max(C.X1,C.X2)+0.5) and "Sampai" or "Gagal")
end})
HTTab:CreateSection("Kontrol HT")
local HTStatus=HTTab:CreateParagraph({Title="Status", Content="Menunggu plant manual..."})
local function setHTStatus(t) pcall(function() HTStatus:Set({Title="Status", Content=t}) end) end
HTTab:CreateButton({Name="Mulai timer sekarang", Callback=function()
   C.PlantAt=os.time() savePlant() notify("Timer","Mulai dihitung")
end})
HTTab:CreateButton({Name="Harvest 1x sekarang", Callback=function() task.spawn(harvestRow) end})
HTTab:CreateToggle({Name="Auto Harvest (sesuai timer)", CurrentValue=false, Flag="AutoHT",
   Callback=function(v)
      C.OnHT=v if not v then return end
      task.spawn(function()
         while C.OnHT do
            if C.PlantAt then
               local sisa=C.Grow+C.Margin-(os.time()-C.PlantAt)
               if sisa<=0 then
                  setHTStatus("Harvesting...") harvestRow()
                  C.PlantAt=nil savePlant()
                  setHTStatus("Selesai. Plant lagi.")
               else setHTStatus("Panen dalam "..fmt(sisa)) end
            end
            task.wait(1)
         end
      end)
   end})

-- ====== TOOLS ======
local ToolsTab = Win:CreateTab("Tools", 4483362458)
ToolsTab:CreateSection("Custom Script Loader")
ToolsTab:CreateButton({Name="Muat Skrip FUHON", Callback=function()
   local ok,err=pcall(function()
      loadstring(game:HttpGet("https://raw.githubusercontent.com/depinrajasfonk-blip/fuhon/refs/heads/main/FUHON.lua"))()
   end)
   if ok then notify("Sukses","FUHON dimuat!") else warn("FUHON gagal:",err) notify("Gagal","Cek console F9") end
end})

-- ====== SPY ======
local SpyTab = Win:CreateTab("Spy", 4483362458)
SpyTab:CreateSection("Remote Spy")
SpyTab:CreateToggle({Name="Aktifkan Spy", CurrentValue=false, Flag="SpyOn",
   Callback=function(v) Spy.On=v end})
SpyTab:CreateButton({Name="Salin log terakhir", Callback=function()
   if setclipboard then setclipboard(table.concat(Spy.Logs,"\n")) notify("Spy",#Spy.Logs.." log disalin") end
end})
SpyTab:CreateButton({Name="Hapus log", Callback=function() Spy.Logs={} end})

-- ====== HOOK ======
pcall(function()
   local old
   old = hookmetamethod(game,"__namecall",newcclosure(function(self,...)
      if getnamecallmethod()=="FireServer" and typeof(self)=="Instance" and not checkcaller() then
         if self==Unr then
            local b=...
            if typeof(b)=="buffer" and buffer.len(b)>=9 and buffer.readu8(b,0)==2 then
               Pos.y=buffer.readf32(b,1) Pos.x=buffer.readf32(b,5)
            end
         elseif self==SetTile then
            local _,x,y,id=...
            if id and id~=0 and type(x)=="number" then
               Last={x=x,y=y,id=id}
            elseif id==0 then
               local r={}
               for _,p in ipairs(Pending) do if os.clock()-p.t<1.5 then r[#r+1]=p.s end end
               if #r>0 then Recipe=r end
               Pending={}
            end
            if id==C.Seed then C.PlantAt=os.time() task.spawn(savePlant) end
         elseif self==Reliable then
            local b=...
            if typeof(b)=="buffer" then
               Pending[#Pending+1]={t=os.clock(),s=buffer.tostring(b)}
               if #Pending>30 then table.remove(Pending,1) end
            end
         end
         if Spy.On and not IGNORE[self.Name] then
            local args=table.pack(...)
            task.spawn(function()
               local t={}
               for i=1,args.n do t[i]=ser(args[i]) end
               local line=self:GetFullName().."("..table.concat(t,", ")..")"
               Spy.Logs[#Spy.Logs+1]=line
               if #Spy.Logs>60 then table.remove(Spy.Logs,1) end
               warn("[SPY]",line)
            end)
         end
      end
      return old(self,...)
   end))
end)

-- Hook OnClientEvent: deteksi server konfirmasi block hancur
pcall(function()
   SetTile.OnClientEvent:Connect(function(layer, x, y, id)
      if x==C.X and y==C.Y and id==0 then
         BlockBroken = true
      end
   end)
end)

loadPlant()
if C.PlantAt then notify("Timer dipulihkan","Timer plant terakhir dilanjutkan") end
notify("Berhasil!","Growtopia Hub berhasil dimuat.")
warn("[HUB] selesai")
