-- Growtopia Hub v3 (HT + PT row-by-row + Fly + Spy)
warn("[HUB] mulai")

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")
local GS = game:GetService("GuiService")
local LP = Players.LocalPlayer
local WR = RS:WaitForChild("WorldRemotes", 10)
local SetTile = WR and WR:WaitForChild("SetTile", 10)
local Unr = RS:FindFirstChild("ByteNetUnreliable")
local SaveInv = WR and WR:FindFirstChild("SaveInventory")

if not SetTile then
   warn("[HUB] SetTile tidak ditemukan")
   Rayfield:Notify({Title="Error",Content="Remote SetTile tidak ditemukan",Duration=6})
   return
end

-- ====== STATE ======
local C = {
   -- HT
   X1=0, X2=3, Y=36, Delay=0.15, Grow=75, Margin=15, Seed=3,
   PlantAt=nil, HTOn=false,
   -- PT row-by-row
   PX1=0, PX2=99, PY1=0, PY2=0, PSeed=3, PDelay=0.2, PTOn=false,
   -- Fly
   FlyOn=false, FX=0, FY=0,
   -- Move HT
   Move=false, Win=3, Tol=0.6,
}
local Pos = {x=nil, y=nil}
local InvTable = nil
local Spy = {On=false, Logs={}}
local IGNORE = {ByteNetUnreliable=true, SaveInventory=true}
local SAVE = "growtopia_hub_plantat.txt"

-- ====== HELPER ======
local function notify(t,c) Rayfield:Notify({Title=t,Content=c,Duration=4,Image=4483362458}) end

local function savePlant()
   pcall(function() if writefile then writefile(SAVE, C.PlantAt and tostring(C.PlantAt) or "") end end)
end
local function loadPlant()
   pcall(function() if isfile and isfile(SAVE) then C.PlantAt = tonumber(readfile(SAVE)) end end)
end
local function parseDur(text)
   text = tostring(text):lower():gsub("%s","")
   local plain = tonumber(text)
   if plain then return plain end
   local total,found = 0,false
   for num,unit in text:gmatch("(%d+%.?%d*)([a-z])") do
      local mult=(unit=="h"or unit=="j")and 3600 or unit=="m"and 60 or(unit=="s"or unit=="d")and 1 or nil
      if mult then total+=tonumber(num)*mult found=true end
   end
   return found and total or nil
end
local function fmt(sec)
   sec=math.max(0,math.ceil(sec))
   return ("%dj %dm %dd"):format(sec//3600,(sec%3600)//60,sec%60)
end

-- ====== INVENTORY ======
local function findSlot(seedId)
   if not InvTable then return nil end
   for _,slot in pairs(InvTable) do
      if type(slot)=="table" and slot[1]==seedId then return slot end
   end
   return nil
end
local function seedCount(id)
   local s=findSlot(id) return s and s[2] or 0
end

-- ====== GERAK HT ======
local function pressBtn(btn,down)
   local p,s=btn.AbsolutePosition,btn.AbsoluteSize
   local x,y=p.X+s.X/2,p.Y+s.Y/2+GS:GetGuiInset().Y
   VIM:SendMouseButtonEvent(x,y,0,down,game,0)
end
local function goTo(tx)
   local gui=LP.PlayerGui:FindFirstChild("MobileGui")
   local L,R=gui and gui:FindFirstChild("Left"),gui and gui:FindFirstChild("Right")
   if not(L and R and Pos.x) then return false end
   for _=1,12 do
      local dx=tx-Pos.x
      if math.abs(dx)<=C.Tol then return true end
      local btn=dx>0 and R or L
      pressBtn(btn,true)
      local t0=os.clock()
      while os.clock()-t0<0.6 do
         task.wait(0.03)
         local d2=tx-Pos.x
         if(dx>0 and d2<=C.Tol)or(dx<0 and d2>=-C.Tol)then break end
      end
      pressBtn(btn,false)
      task.wait(0.2)
   end
   return math.abs(tx-Pos.x)<=C.Tol*2
end

-- ====== HARVEST ======
local function harvestRow()
   local lo,hi=math.min(C.X1,C.X2),math.max(C.X1,C.X2)
   local home=Pos.x
   local x=lo
   while x<=hi do
      local stop=math.min(x+C.Win-1,hi)
      if C.Move then goTo((x+stop)/2+0.5) end
      for t=x,stop do SetTile:FireServer("fg",t,C.Y,0) task.wait(C.Delay) end
      x=stop+1
   end
   if C.Move and home then goTo(home) end
end

-- ====== PLANT ======
local function plantTile(x,y,id)
   local slot=findSlot(id)
   if not slot then warn("[PT] seed "..id.." tidak ada di inventory") return false end
   if slot[2]<=0 then warn("[PT] seed habis") return false end
   slot[2]=slot[2]-1
   SetTile:FireServer("fg",x,y,id)
   return true
end

local function autoPlantAll()
   for y=C.PY1,C.PY2 do
      for x=C.PX1,C.PX2 do
         if not C.PTOn then return end
         if seedCount(C.PSeed)<=0 then
            notify("PT","Seed habis")
            C.PTOn=false
            return
         end
         plantTile(x,y,C.PSeed)
         task.wait(C.PDelay)
      end
   end
end

-- ====== SPY ======
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
   if t=="buffer" then return "buf["..hex(v).."]" end
   if t=="string" then return string.format("%q",v) end
   return t..":"..tostring(v)
end

-- ====== WINDOW ======
local Win = Rayfield:CreateWindow({
   Name="Growtopia Hub v3",
   LoadingTitle="Memuat Hub...",
   LoadingSubtitle="oleh Pemula",
   ConfigurationSaving={Enabled=false},
   KeySystem=false,
})

-- ====== HOME ======
local Home=Win:CreateTab("Home",4483362458)
Home:CreateSection("Growtopia Hub v3")
Home:CreateParagraph({Title="Fitur",Content="HT: Auto Harvest (timer)\nPT: Auto Plant baris per baris\nFly: Pindah ke tile manapun\nSpy: Rekam remote"})

-- ====== HT ======
local HTTab=Win:CreateTab("HT",4483362458)
HTTab:CreateSection("Baris Tree")
HTTab:CreateInput({Name="X mulai",PlaceholderText="0",RemoveTextAfterFocusLost=false,Callback=function(t) C.X1=tonumber(t)or C.X1 end})
HTTab:CreateInput({Name="X akhir",PlaceholderText="3",RemoveTextAfterFocusLost=false,Callback=function(t) C.X2=tonumber(t)or C.X2 end})
HTTab:CreateInput({Name="Y",PlaceholderText="36",RemoveTextAfterFocusLost=false,Callback=function(t) C.Y=tonumber(t)or C.Y end})
HTTab:CreateInput({Name="Waktu tumbuh (contoh: 3j47m atau 70)",PlaceholderText="3j47m",RemoveTextAfterFocusLost=false,
   Callback=function(t)
      local d=parseDur(t)
      if d then C.Grow=d notify("Waktu tumbuh",fmt(d)) else notify("Format salah","Contoh: 3j47m, 1m10s, atau 70") end
   end})
HTTab:CreateInput({Name="ID seed",PlaceholderText="3",RemoveTextAfterFocusLost=false,Callback=function(t) C.Seed=tonumber(t)or C.Seed end})
HTTab:CreateSlider({Name="Delay antar tile (detik)",Range={0.1,1},Increment=0.05,CurrentValue=0.15,Flag="HD",Callback=function(v) C.Delay=v end})
HTTab:CreateSection("Gerak Otomatis")
HTTab:CreateToggle({Name="Gerak otomatis saat harvest",CurrentValue=false,Flag="AutoMove",Callback=function(v) C.Move=v end})
HTTab:CreateSlider({Name="Tile per posisi berdiri",Range={1,5},Increment=1,CurrentValue=3,Flag="Win",Callback=function(v) C.Win=v end})
HTTab:CreateSection("Kontrol")
local HTStatus=HTTab:CreateParagraph({Title="Status",Content="Menunggu plant manual..."})
local function setHTStatus(t) pcall(function() HTStatus:Set({Title="Status",Content=t}) end) end
HTTab:CreateButton({Name="Mulai timer sekarang",Callback=function()
   C.PlantAt=os.time() savePlant() notify("Timer","Mulai dihitung dari sekarang")
end})
HTTab:CreateButton({Name="Harvest 1x sekarang",Callback=function() harvestRow() end})
HTTab:CreateToggle({Name="Auto Harvest (sesuai timer)",CurrentValue=false,Flag="AutoHT",Callback=function(v)
   C.HTOn=v
   if not v then return end
   task.spawn(function()
      while C.HTOn do
         if C.PlantAt then
            local sisa=C.Grow+C.Margin-(os.time()-C.PlantAt)
            if sisa<=0 then
               setHTStatus("Harvesting...")
               harvestRow()
               C.PlantAt=nil savePlant()
               setHTStatus("Selesai. Plant lagi untuk mulai timer baru.")
            else
               setHTStatus("Panen dalam "..fmt(sisa))
            end
         end
         task.wait(1)
      end
   end)
end})

-- ====== PT ======
local PTTab=Win:CreateTab("PT",4483362458)
PTTab:CreateSection("Area Tanam (baris per baris)")
PTTab:CreateParagraph({Title="Info",Content="Script akan tanam dari (X1,Y1) ke (X2,Y1), lalu turun ke baris Y berikutnya sampai Y2.\nServer tidak cek posisi karakter, jadi tidak perlu gerak manual."})
PTTab:CreateInput({Name="X mulai",PlaceholderText="0",RemoveTextAfterFocusLost=false,Callback=function(t) C.PX1=tonumber(t)or C.PX1 end})
PTTab:CreateInput({Name="X akhir",PlaceholderText="99",RemoveTextAfterFocusLost=false,Callback=function(t) C.PX2=tonumber(t)or C.PX2 end})
PTTab:CreateInput({Name="Y mulai",PlaceholderText="0",RemoveTextAfterFocusLost=false,Callback=function(t) C.PY1=tonumber(t)or C.PY1 end})
PTTab:CreateInput({Name="Y akhir",PlaceholderText="0",RemoveTextAfterFocusLost=false,Callback=function(t) C.PY2=tonumber(t)or C.PY2 end})
PTTab:CreateInput({Name="ID seed",PlaceholderText="3",RemoveTextAfterFocusLost=false,Callback=function(t) C.PSeed=tonumber(t)or C.PSeed end})
PTTab:CreateSlider({Name="Delay antar tile (detik)",Range={0.1,1},Increment=0.05,CurrentValue=0.2,Flag="PD",Callback=function(v) C.PDelay=v end})
PTTab:CreateSection("Kontrol")
local PTInfo=PTTab:CreateParagraph({Title="Inventory",Content="Menunggu data inventory (gerak sebentar)..."})
local function updatePTInfo()
   pcall(function() PTInfo:Set({Title="Inventory",Content=("Seed ID %d: %d tersisa"):format(C.PSeed,seedCount(C.PSeed))}) end)
end
PTTab:CreateButton({Name="Cek jumlah seed",Callback=function()
   if not InvTable then notify("Belum ada","Gerak sebentar dulu agar inventory terbaca") else updatePTInfo() end
end})
PTTab:CreateButton({Name="Plant 1 tile tes (X1,Y1)",Callback=function()
   if not InvTable then notify("Belum ada","Gerak sebentar dulu") return end
   local ok=plantTile(C.PX1,C.PY1,C.PSeed)
   updatePTInfo()
   notify("Tes plant",ok and "Berhasil" or "Gagal (seed habis / tidak ada)")
end})
PTTab:CreateToggle({Name="Auto Plant (baris per baris)",CurrentValue=false,Flag="AutoPT",Callback=function(v)
   C.PTOn=v
   if not v then return end
   if not InvTable then notify("Belum ada","Gerak sebentar dulu") C.PTOn=false return end
   task.spawn(function()
      autoPlantAll()
      if C.PTOn then
         C.PTOn=false
         notify("PT","Auto Plant selesai")
      end
   end)
end})

-- ====== FLY ======
local FlyTab=Win:CreateTab("Fly",4483362458)
FlyTab:CreateSection("Pindah ke Tile")
FlyTab:CreateParagraph({Title="Info",Content="Fly mengubah posisi yang dikirim ke server. Karakter di layar tidak bergerak, tapi server menganggap kamu ada di tile yang ditentukan. Berguna untuk tanam/panen di tile yang jauh."})
FlyTab:CreateInput({Name="Target X",PlaceholderText="0",RemoveTextAfterFocusLost=false,Callback=function(t) C.FX=tonumber(t)or C.FX end})
FlyTab:CreateInput({Name="Target Y",PlaceholderText="0",RemoveTextAfterFocusLost=false,Callback=function(t) C.FY=tonumber(t)or C.FY end})
FlyTab:CreateButton({Name="Cek posisi karakter sekarang",Callback=function()
   if Pos.x then
      notify("Posisi",("X=%.1f Y=%.1f"):format(Pos.x,Pos.y))
   else
      notify("Belum terbaca","Gerak sebentar dulu")
   end
end})
FlyTab:CreateToggle({Name="Aktifkan Fly (spoof posisi)",CurrentValue=false,Flag="FlyOn",Callback=function(v)
   C.FlyOn=v
   if v then
      notify("Fly ON",("Server anggap kamu di tile %.0f,%.0f"):format(C.FX,C.FY))
   else
      notify("Fly OFF","Posisi asli dipulihkan")
   end
end})

-- ====== SPY ======
local SpyTab=Win:CreateTab("Spy",4483362458)
SpyTab:CreateSection("Remote Spy")
SpyTab:CreateToggle({Name="Aktifkan Spy",CurrentValue=false,Flag="SpyOn",Callback=function(v) Spy.On=v end})
SpyTab:CreateButton({Name="Salin log terakhir",Callback=function()
   if setclipboard then setclipboard(table.concat(Spy.Logs,"\n")) notify("Spy",#Spy.Logs.." log disalin") end
end})
SpyTab:CreateButton({Name="Hapus log",Callback=function() Spy.Logs={} end})

-- ====== HOOK ======
local hookOk,hookErr=pcall(function()
   local old
   old=hookmetamethod(game,"__namecall",newcclosure(function(self,...)
      if getnamecallmethod()=="FireServer" and typeof(self)=="Instance" and not checkcaller() then

         -- baca posisi dari ByteNetUnreliable
         if self==Unr then
            local b=...
            if typeof(b)=="buffer" and buffer.len(b)>=9 and buffer.readu8(b,0)==2 then
               Pos.y=buffer.readf32(b,1)
               Pos.x=buffer.readf32(b,5)
               -- fly: tulis posisi target ke buffer
               if C.FlyOn then
                  pcall(function()
                     buffer.writef32(b,1,C.FY)
                     buffer.writef32(b,5,C.FX)
                  end)
               end
            end
         end

         -- tangkap invTable dari SaveInventory
         if self==SaveInv then
            local a1=...
            if type(a1)=="table" and not InvTable then
               InvTable=a1
               warn("[HUB] invTable ditangkap,",#InvTable,"slot")
            end
         end

         -- deteksi plant manual untuk timer HT
         if self==SetTile then
            local _,_,_,id=...
            if id==C.Seed then C.PlantAt=os.time() task.spawn(savePlant) end
         end

         -- spy
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
if not hookOk then warn("[HUB] Hook gagal:",hookErr) end

loadPlant()
if C.PlantAt then notify("Timer dipulihkan","Timer plant terakhir dilanjutkan") end
notify("Berhasil!","Hub v3 dimuat.")
warn("[HUB] selesai")
