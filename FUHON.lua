-- Growtopia Hub v4 (HT + PT baris-per-baris + Spy)
-- Fly dihapus: menyebabkan kick anti-cheat noclip
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
   Rayfield:Notify({Title="Error",Content="Remote SetTile tidak ditemukan",Duration=6})
   return
end

-- ====== STATE ======
local C = {
   -- HT
   X1=0,X2=3,Y=36,Delay=0.15,Grow=75,Margin=15,Seed=3,
   PlantAt=nil,HTOn=false,Move=false,Win=3,Tol=0.6,
   -- PT
   PX1=0,PX2=99,PY1=0,PY2=0,PSeed=3,PDelay=0.25,PTOn=false,
   PTDone=0,PTTotal=0,
}
local Pos = {x=nil,y=nil}
local InvTable = nil
local Spy = {On=false,Logs={}}
local IGNORE = {ByteNetUnreliable=true,SaveInventory=true}
local SAVE = "growtopia_hub_plantat.txt"

-- ====== UTIL ======
local function notify(t,c) Rayfield:Notify({Title=t,Content=c,Duration=4,Image=4483362458}) end
local function savePlant()
   pcall(function() if writefile then writefile(SAVE,C.PlantAt and tostring(C.PlantAt) or "") end end)
end
local function loadPlant()
   pcall(function() if isfile and isfile(SAVE) then C.PlantAt=tonumber(readfile(SAVE)) end end)
end
local function parseDur(text)
   text=tostring(text):lower():gsub("%s","")
   local plain=tonumber(text) if plain then return plain end
   local total,found=0,false
   for num,unit in text:gmatch("(%d+%.?%d*)([a-z])") do
      local m=(unit=="h"or unit=="j")and 3600 or unit=="m"and 60 or(unit=="s"or unit=="d")and 1 or nil
      if m then total+=tonumber(num)*m found=true end
   end
   return found and total or nil
end
local function fmt(sec)
   sec=math.max(0,math.ceil(sec))
   return ("%dj %dm %dd"):format(sec//3600,(sec%3600)//60,sec%60)
end

-- ====== INVENTORY ======
local function findSlot(id)
   if not InvTable then return nil end
   for _,s in pairs(InvTable) do if type(s)=="table" and s[1]==id then return s end end
   return nil
end
local function seedCount(id) local s=findSlot(id) return s and s[2] or -1 end
local function tryDecrement(id)
   local s=findSlot(id)
   if s and s[2]>0 then s[2]=s[2]-1 return true end
   return false -- belum ada data atau habis; biarkan SetTile tetap dipanggil
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
      local dx=tx-Pos.x if math.abs(dx)<=C.Tol then return true end
      local btn=dx>0 and R or L
      pressBtn(btn,true)
      local t0=os.clock()
      while os.clock()-t0<0.6 do
         task.wait(0.03)
         local d2=tx-Pos.x
         if(dx>0 and d2<=C.Tol)or(dx<0 and d2>=-C.Tol)then break end
      end
      pressBtn(btn,false) task.wait(0.2)
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
-- PT tidak butuh InvTable untuk jalan; decrement hanya kalau data ada
local function plantTile(x,y,id)
   tryDecrement(id)            -- kurangi jika bisa, skip kalau belum ada data
   SetTile:FireServer("fg",x,y,id)
   C.PTDone+=1
   return true
end

local PTStatus
local function setPTStatus(t) pcall(function() PTStatus:Set({Title="Status PT",Content=t}) end) end

local function autoPlantAll()
   C.PTDone=0
   C.PTTotal=(C.PX2-C.PX1+1)*(C.PY2-C.PY1+1)
   setPTStatus(("Mulai: 0/%d tile"):format(C.PTTotal))
   for y=C.PY1,C.PY2 do
      for x=C.PX1,C.PX2 do
         if not C.PTOn then
            setPTStatus(("Dihentikan: %d/%d tile"):format(C.PTDone,C.PTTotal))
            return
         end
         -- cek seed hanya kalau InvTable sudah ada
         if InvTable then
            local cnt=seedCount(C.PSeed)
            if cnt==0 then
               C.PTOn=false
               setPTStatus("Seed habis di tile "..x..","..y)
               notify("PT","Seed habis, Auto Plant berhenti")
               return
            end
         end
         plantTile(x,y,C.PSeed)
         if C.PTDone%10==0 then
            setPTStatus(("%d/%d tile (y=%d x=%d)"):format(C.PTDone,C.PTTotal,y,x))
         end
         task.wait(C.PDelay)
      end
   end
   setPTStatus(("Selesai: %d/%d tile"):format(C.PTDone,C.PTTotal))
   notify("PT","Auto Plant selesai!")
end

-- ====== SPY ======
local function hex(b)
   local ok,s=pcall(function()
      local o={}
      for i=0,math.min(buffer.len(b),32)-1 do o[#o+1]=string.format("%02X",buffer.readu8(b,i)) end
      return table.concat(o," ")
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
local Win=Rayfield:CreateWindow({
   Name="Growtopia Hub v4",
   LoadingTitle="Memuat Hub...",
   LoadingSubtitle="oleh Pemula",
   ConfigurationSaving={Enabled=false},
   KeySystem=false,
})

-- HOME
local Home=Win:CreateTab("Home",4483362458)
Home:CreateSection("Growtopia Hub v4")
Home:CreateParagraph({Title="Fitur",Content="HT: Auto Harvest dengan timer\nPT: Auto Plant baris per baris (tanpa klik manual)\nSpy: Rekam remote\n\nNote: Fly dihapus karena menyebabkan kick anti-cheat noclip."})

-- HT
local HTTab=Win:CreateTab("HT",4483362458)
HTTab:CreateSection("Baris Tree")
HTTab:CreateInput({Name="X mulai",PlaceholderText="0",RemoveTextAfterFocusLost=false,Callback=function(t) C.X1=tonumber(t)or C.X1 end})
HTTab:CreateInput({Name="X akhir",PlaceholderText="3",RemoveTextAfterFocusLost=false,Callback=function(t) C.X2=tonumber(t)or C.X2 end})
HTTab:CreateInput({Name="Y",PlaceholderText="36",RemoveTextAfterFocusLost=false,Callback=function(t) C.Y=tonumber(t)or C.Y end})
HTTab:CreateInput({Name="Waktu tumbuh (contoh: 3j47m)",PlaceholderText="3j47m",RemoveTextAfterFocusLost=false,
   Callback=function(t)
      local d=parseDur(t)
      if d then C.Grow=d notify("Waktu tumbuh",fmt(d)) else notify("Format salah","Contoh: 3j47m, 1m10s, 70") end
   end})
HTTab:CreateInput({Name="ID seed",PlaceholderText="3",RemoveTextAfterFocusLost=false,Callback=function(t) C.Seed=tonumber(t)or C.Seed end})
HTTab:CreateSlider({Name="Delay antar tile",Range={0.1,1},Increment=0.05,CurrentValue=0.15,Flag="HD",Callback=function(v) C.Delay=v end})
HTTab:CreateSection("Gerak Otomatis")
HTTab:CreateToggle({Name="Gerak otomatis saat harvest",CurrentValue=false,Flag="AutoMove",Callback=function(v) C.Move=v end})
HTTab:CreateSlider({Name="Tile per posisi berdiri",Range={1,5},Increment=1,CurrentValue=3,Flag="Win",Callback=function(v) C.Win=v end})
HTTab:CreateSection("Kontrol")
local HTStatus=HTTab:CreateParagraph({Title="Status",Content="Menunggu plant manual..."})
local function setHTStatus(t) pcall(function() HTStatus:Set({Title="Status",Content=t}) end) end
HTTab:CreateButton({Name="Mulai timer sekarang",Callback=function()
   C.PlantAt=os.time() savePlant() notify("Timer","Mulai dihitung")
end})
HTTab:CreateButton({Name="Harvest 1x sekarang",Callback=function() task.spawn(harvestRow) end})
HTTab:CreateToggle({Name="Auto Harvest",CurrentValue=false,Flag="AutoHT",Callback=function(v)
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
            else setHTStatus("Panen dalam "..fmt(sisa)) end
         end
         task.wait(1)
      end
   end)
end})

-- PT
local PTTab=Win:CreateTab("PT",4483362458)
PTTab:CreateSection("Area Tanam")
PTTab:CreateParagraph({Title="Cara pakai",Content="Isi koordinat area, nyalakan toggle. Script tanam dari (X1,Y1) ke (X2,Y1) lalu turun ke Y2. Tidak butuh klik manual atau gerak karakter."})
PTTab:CreateInput({Name="X mulai",PlaceholderText="0",RemoveTextAfterFocusLost=false,Callback=function(t) C.PX1=tonumber(t)or C.PX1 end})
PTTab:CreateInput({Name="X akhir",PlaceholderText="99",RemoveTextAfterFocusLost=false,Callback=function(t) C.PX2=tonumber(t)or C.PX2 end})
PTTab:CreateInput({Name="Y mulai",PlaceholderText="0",RemoveTextAfterFocusLost=false,Callback=function(t) C.PY1=tonumber(t)or C.PY1 end})
PTTab:CreateInput({Name="Y akhir",PlaceholderText="0",RemoveTextAfterFocusLost=false,Callback=function(t) C.PY2=tonumber(t)or C.PY2 end})
PTTab:CreateInput({Name="ID seed",PlaceholderText="3",RemoveTextAfterFocusLost=false,Callback=function(t) C.PSeed=tonumber(t)or C.PSeed end})
PTTab:CreateSlider({Name="Delay antar tile",Range={0.1,2},Increment=0.05,CurrentValue=0.25,Flag="PD",Callback=function(v) C.PDelay=v end})
PTTab:CreateSection("Kontrol")
PTStatus=PTTab:CreateParagraph({Title="Status PT",Content="Belum dimulai."})
PTTab:CreateButton({Name="Cek posisi karakter",Callback=function()
   if Pos.x then notify("Posisi",("X=%.1f Y=%.1f"):format(Pos.x,Pos.y))
   else notify("Belum terbaca","Gerak sebentar dulu") end
end})
PTTab:CreateButton({Name="Tes plant 1 tile (X1,Y1)",Callback=function()
   plantTile(C.PX1,C.PY1,C.PSeed)
   notify("Tes plant",("SetTile dikirim ke %d,%d id%d"):format(C.PX1,C.PY1,C.PSeed))
end})
PTTab:CreateToggle({Name="Auto Plant (baris per baris)",CurrentValue=false,Flag="AutoPT",Callback=function(v)
   C.PTOn=v
   if not v then return end
   task.spawn(function()
      autoPlantAll()
      C.PTOn=false
   end)
end})

-- SPY
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
         if self==Unr then
            local b=...
            if typeof(b)=="buffer" and buffer.len(b)>=9 and buffer.readu8(b,0)==2 then
               Pos.y=buffer.readf32(b,1)
               Pos.x=buffer.readf32(b,5)
            end
         end
         if self==SaveInv then
            local a1=...
            if type(a1)=="table" and not InvTable then
               InvTable=a1
               warn("[HUB] invTable ditangkap,",#InvTable,"slot")
            end
         end
         if self==SetTile then
            local _,_,_,id=...
            if id==C.Seed then C.PlantAt=os.time() task.spawn(savePlant) end
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
if not hookOk then warn("[HUB] Hook gagal:",hookErr) end

loadPlant()
if C.PlantAt then notify("Timer dipulihkan","Timer plant terakhir dilanjutkan") end
notify("Berhasil!","Hub v4 dimuat.")
warn("[HUB] selesai")
