-- Growtopia Hub v5 (HT + PT auto-move 5x5 + Zoom + Spy)
warn("[HUB] mulai")

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")
local GS = game:GetService("GuiService")
local LP = Players.LocalPlayer
local WR = RS:WaitForChild("WorldRemotes",10)
local SetTile = WR and WR:WaitForChild("SetTile",10)
local Unr = RS:FindFirstChild("ByteNetUnreliable")
local SaveInv = WR and WR:FindFirstChild("SaveInventory")

if not SetTile then
   Rayfield:Notify({Title="Error",Content="Remote SetTile tidak ditemukan",Duration=6}) return
end

-- ====== STATE ======
local C = {
   X1=0,X2=3,Y=36,Delay=0.15,Grow=75,Margin=15,Seed=3,
   PlantAt=nil,HTOn=false,Move=false,Win=3,Tol=0.6,
   PX1=0,PX2=99,PY1=36,PY2=36,PSeed=3,PDelay=0.25,PTOn=false,
   PTMove=true,
   REACH=2,  -- jangkauan tile (5x5 = reach 2 di tiap arah)
}
local Pos={x=nil,y=nil}
local InvTable=nil
local Spy={On=false,Logs={}}
local IGNORE={ByteNetUnreliable=true,SaveInventory=true}
local SAVE="growtopia_hub_plantat.txt"

-- ====== UTIL ======
local function notify(t,c) Rayfield:Notify({Title=t,Content=c,Duration=4,Image=4483362458}) end
local function savePlant() pcall(function() if writefile then writefile(SAVE,C.PlantAt and tostring(C.PlantAt) or "") end end) end
local function loadPlant() pcall(function() if isfile and isfile(SAVE) then C.PlantAt=tonumber(readfile(SAVE)) end end) end
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
local function tryDecrement(id) local s=findSlot(id) if s and s[2]>0 then s[2]-=1 end end

-- ====== TOMBOL LAYAR ======
local function getMobileBtn(name)
   local gui=LP.PlayerGui:FindFirstChild("MobileGui")
   return gui and gui:FindFirstChild(name)
end
local function pressScreen(btn,down)
   if not btn then return end
   local p,s=btn.AbsolutePosition,btn.AbsoluteSize
   local x,y=p.X+s.X/2,p.Y+s.Y/2+GS:GetGuiInset().Y
   VIM:SendMouseButtonEvent(x,y,0,down,game,0)
end

-- ====== GERAK HORIZONTAL ======
local function goToX(tx)
   local L,R=getMobileBtn("Left"),getMobileBtn("Right")
   if not(L and R and Pos.x) then return false end
   for _=1,20 do
      local dx=tx-Pos.x if math.abs(dx)<=C.Tol then return true end
      local btn=dx>0 and R or L
      pressScreen(btn,true)
      local t0=os.clock()
      while os.clock()-t0<0.6 do
         task.wait(0.03)
         local d2=tx-Pos.x
         if(dx>0 and d2<=C.Tol)or(dx<0 and d2>=-C.Tol)then break end
      end
      pressScreen(btn,false) task.wait(0.15)
   end
   return math.abs(tx-Pos.x)<=C.Tol*2
end

-- ====== GERAK VERTIKAL (jump) ======
local function jump()
   local J=getMobileBtn("Jump")
   pressScreen(J,true) task.wait(0.08) pressScreen(J,false)
end
local function goToY(ty)
   if not Pos.y then return false end
   for _=1,30 do
      local dy=ty-Pos.y
      if math.abs(dy)<=C.Tol then return true end
      if dy<0 then
         -- naik: jump beberapa kali
         jump() task.wait(0.5)
      else
         -- turun: biarkan jatuh, tahan Right sedikit biar tidak stuck
         local R=getMobileBtn("Right")
         pressScreen(R,true) task.wait(0.2) pressScreen(R,false)
         task.wait(0.3)
      end
   end
   return math.abs(ty-Pos.y)<=C.Tol*2
end


-- ====== ANTI-GRAVITY (jump terus supaya tidak jatuh) ======
local AG={On=false}
local function startAG()
   task.spawn(function()
      local J=getMobileBtn("Jump")
      if not J then warn("[AG] tombol Jump tidak ditemukan") return end
      while AG.On do
         pressScreen(J,true) task.wait(0.06) pressScreen(J,false)
         task.wait(0.18)
      end
   end)
end

-- ====== HARVEST ======
local function harvestRow()
   local lo,hi=math.min(C.X1,C.X2),math.max(C.X1,C.X2)
   local home=Pos.x
   local x=lo
   while x<=hi do
      local stop=math.min(x+C.Win-1,hi)
      if C.Move then goToX((x+stop)/2+0.5) end
      for t=x,stop do SetTile:FireServer("fg",t,C.Y,0) task.wait(C.Delay) end
      x=stop+1
   end
   if C.Move and home then goToX(home) end
end

-- ====== PLANT ======
local function plantTile(x,y,id)
   tryDecrement(id)
   SetTile:FireServer("fg",x,y,id)
end

local PTStatus
local function setPT(t) pcall(function() PTStatus:Set({Title="Status PT",Content=t}) end) end

local function autoPlantWithMove()
   local STEP=C.REACH*2+1  -- 5
   local done,total=0,0
   -- calcola totale
   for y=C.PY1,C.PY2,STEP do
      local y1=y local y2=math.min(y+STEP-1,C.PY2)
      for x=C.PX1,C.PX2,STEP do
         local x1=x local x2=math.min(x+STEP-1,C.PX2)
         total+=(x2-x1+1)*(y2-y1+1)
      end
   end
   setPT(("Mulai: 0/%d tile"):format(total))

   for y=C.PY1,C.PY2,STEP do
      if not C.PTOn then break end
      local y1=y
      local y2=math.min(y+STEP-1,C.PY2)
      local cy=math.floor((y1+y2)/2)  -- posisi Y karakter
      if C.PTMove then goToY(cy) end

      for x=C.PX1,C.PX2,STEP do
         if not C.PTOn then break end
         local x1=x
         local x2=math.min(x+STEP-1,C.PX2)
         local cx=math.floor((x1+x2)/2)  -- posisi X karakter
         if C.PTMove then goToX(cx+0.5) end
         -- tanam semua tile di chunk ini
         for py=y1,y2 do
            for px=x1,x2 do
               if not C.PTOn then return end
               if InvTable and seedCount(C.PSeed)==0 then
                  C.PTOn=false
                  setPT("Seed habis di tile "..px..","..py)
                  notify("PT","Seed habis") return
               end
               plantTile(px,py,C.PSeed)
               done+=1
               task.wait(C.PDelay)
            end
         end
         setPT(("%d/%d tile (x=%d y=%d)"):format(done,total,x1,y1))
      end
   end
   setPT(("Selesai: %d/%d tile"):format(done,total))
   C.PTOn=false
   notify("PT","Auto Plant selesai!")
end

-- ====== ZOOM ======
local function setZoom(scale)
   local ok,err=pcall(function()
      local cam=LP.PlayerGui.GameGui.World.Camera
      local ui=cam:FindFirstChildOfClass("UIScale")
      if not ui then ui=Instance.new("UIScale") ui.Parent=cam end
      ui.Scale=1/scale
   end)
   if not ok then warn("[ZOOM]",err) end
end

-- ====== SPY ======
local function hex(b)
   local ok,s=pcall(function()
      local o={} for i=0,math.min(buffer.len(b),32)-1 do o[#o+1]=string.format("%02X",buffer.readu8(b,i)) end
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
   Name="Growtopia Hub v5",LoadingTitle="Memuat...",LoadingSubtitle="oleh Pemula",
   ConfigurationSaving={Enabled=false},KeySystem=false,
})

-- HOME
local Home=Win:CreateTab("Home",4483362458)
Home:CreateSection("Growtopia Hub v5")
Home:CreateParagraph({Title="Fitur",Content="HT: Auto Harvest\nPT: Auto Plant baris per baris dengan auto-move 5x5\nZoom: Perkecil layar untuk lihat lebih banyak tile\nSpy: Rekam remote"})

-- HT
local HTTab=Win:CreateTab("HT",4483362458)
HTTab:CreateSection("Baris Tree")
HTTab:CreateInput({Name="X mulai",PlaceholderText="0",RemoveTextAfterFocusLost=false,Callback=function(t) C.X1=tonumber(t)or C.X1 end})
HTTab:CreateInput({Name="X akhir",PlaceholderText="3",RemoveTextAfterFocusLost=false,Callback=function(t) C.X2=tonumber(t)or C.X2 end})
HTTab:CreateInput({Name="Y",PlaceholderText="36",RemoveTextAfterFocusLost=false,Callback=function(t) C.Y=tonumber(t)or C.Y end})
HTTab:CreateInput({Name="Waktu tumbuh (contoh: 3j47m)",PlaceholderText="3j47m",RemoveTextAfterFocusLost=false,
   Callback=function(t) local d=parseDur(t) if d then C.Grow=d notify("Waktu tumbuh",fmt(d)) else notify("Format salah","Contoh: 3j47m, 1m10s, 70") end end})
HTTab:CreateInput({Name="ID seed",PlaceholderText="3",RemoveTextAfterFocusLost=false,Callback=function(t) C.Seed=tonumber(t)or C.Seed end})
HTTab:CreateSlider({Name="Delay antar tile",Range={0.1,1},Increment=0.05,CurrentValue=0.15,Flag="HD",Callback=function(v) C.Delay=v end})
HTTab:CreateSection("Gerak Otomatis")
HTTab:CreateToggle({Name="Gerak otomatis saat harvest",CurrentValue=false,Flag="AutoMove",Callback=function(v) C.Move=v end})
HTTab:CreateSlider({Name="Tile per posisi berdiri",Range={1,5},Increment=1,CurrentValue=3,Flag="Win",Callback=function(v) C.Win=v end})
HTTab:CreateSection("Kontrol")
local HTStatus=HTTab:CreateParagraph({Title="Status",Content="Menunggu plant manual..."})
local function setHTStatus(t) pcall(function() HTStatus:Set({Title="Status",Content=t}) end) end
HTTab:CreateButton({Name="Mulai timer sekarang",Callback=function() C.PlantAt=os.time() savePlant() notify("Timer","Mulai dihitung") end})
HTTab:CreateButton({Name="Harvest 1x sekarang",Callback=function() task.spawn(harvestRow) end})
HTTab:CreateToggle({Name="Auto Harvest",CurrentValue=false,Flag="AutoHT",Callback=function(v)
   C.HTOn=v if not v then return end
   task.spawn(function()
      while C.HTOn do
         if C.PlantAt then
            local sisa=C.Grow+C.Margin-(os.time()-C.PlantAt)
            if sisa<=0 then
               setHTStatus("Harvesting...") harvestRow()
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
PTTab:CreateParagraph({Title="Cara pakai",Content="Karakter otomatis gerak setiap 5 tile (sesuai jangkauan 5x5).\nContoh: PX1=0 PX2=99 PY1=36 PY2=36 untuk 1 baris panjang.\nPY1 = PY2 kalau hanya 1 baris."})
PTTab:CreateInput({Name="X mulai",PlaceholderText="0",RemoveTextAfterFocusLost=false,Callback=function(t) C.PX1=tonumber(t)or C.PX1 end})
PTTab:CreateInput({Name="X akhir",PlaceholderText="99",RemoveTextAfterFocusLost=false,Callback=function(t) C.PX2=tonumber(t)or C.PX2 end})
PTTab:CreateInput({Name="Y mulai",PlaceholderText="36",RemoveTextAfterFocusLost=false,Callback=function(t) C.PY1=tonumber(t)or C.PY1 end})
PTTab:CreateInput({Name="Y akhir",PlaceholderText="36",RemoveTextAfterFocusLost=false,Callback=function(t) C.PY2=tonumber(t)or C.PY2 end})
PTTab:CreateInput({Name="ID seed",PlaceholderText="3",RemoveTextAfterFocusLost=false,Callback=function(t) C.PSeed=tonumber(t)or C.PSeed end})
PTTab:CreateSlider({Name="Delay antar tile (detik)",Range={0.1,2},Increment=0.05,CurrentValue=0.25,Flag="PD",Callback=function(v) C.PDelay=v end})
PTTab:CreateSection("Kontrol")
PTStatus=PTTab:CreateParagraph({Title="Status PT",Content="Belum dimulai."})
PTTab:CreateButton({Name="Cek posisi karakter",Callback=function()
   if Pos.x then notify("Posisi",("X=%.1f Y=%.1f"):format(Pos.x,Pos.y))
   else notify("Belum terbaca","Gerak sebentar dulu") end
end})
PTTab:CreateToggle({Name="Auto-move karakter saat plant",CurrentValue=true,Flag="PTMove",Callback=function(v) C.PTMove=v end})
PTTab:CreateButton({Name="Tes plant 1 tile (X1,Y1)",Callback=function()
   plantTile(C.PX1,C.PY1,C.PSeed)
   notify("Tes",("SetTile %d,%d id%d"):format(C.PX1,C.PY1,C.PSeed))
end})
PTTab:CreateToggle({Name="Auto Plant (baris per baris + auto-move)",CurrentValue=false,Flag="AutoPT",Callback=function(v)
   C.PTOn=v if not v then return end
   task.spawn(function() autoPlantWithMove() C.PTOn=false end)
end})

-- ZOOM
local ZoomTab=Win:CreateTab("Zoom",4483362458)
ZoomTab:CreateSection("Zoom Layar")
ZoomTab:CreateParagraph({Title="Info",Content="Zoom out memperkecil tampilan dunia sehingga lebih banyak tile kelihatan. Ini hanya mengubah tampilan di client, bukan posisi karakter."})
ZoomTab:CreateSlider({Name="Zoom level (1=normal, 3=jauh)",Range={1,5},Increment=0.5,CurrentValue=1,Flag="ZoomLvl",
   Callback=function(v) setZoom(v) end})
ZoomTab:CreateButton({Name="Reset Zoom",Callback=function() setZoom(1) notify("Zoom","Reset ke normal") end})

-- ANTI-GRAVITY
local AGTab=Win:CreateTab("AntiGrav",4483362458)
AGTab:CreateSection("Anti-Gravity / Fly")
AGTab:CreateParagraph({Title="Cara pakai",Content="Nyalakan toggle, karakter akan terus jump sehingga tidak jatuh dan bisa melayang. Matikan untuk kembali ke gravitasi normal.

Untuk naik: nyalakan, lalu tahan tombol Jump manual sebentar.
Untuk turun: matikan, karakter jatuh normal."})
AGTab:CreateToggle({Name="Aktifkan Anti-Gravity",CurrentValue=false,Flag="AGOn",Callback=function(v)
   AG.On=v
   if v then startAG() notify("Anti-Gravity","ON - karakter melayang") 
   else notify("Anti-Gravity","OFF - gravitasi normal") end
end})
AGTab:CreateButton({Name="Naik 1 tile",Callback=function()
   local J=getMobileBtn("Jump")
   for i=1,8 do pressScreen(J,true) task.wait(0.05) pressScreen(J,false) task.wait(0.05) end
end})
AGTab:CreateButton({Name="Cek posisi Y sekarang",Callback=function()
   if Pos.y then notify("Posisi Y",("Y=%.2f"):format(Pos.y))
   else notify("Belum terbaca","Gerak sebentar dulu") end
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
               Pos.y=buffer.readf32(b,1) Pos.x=buffer.readf32(b,5)
            end
         end
         if self==SaveInv then
            local a1=...
            if type(a1)=="table" and not InvTable then
               InvTable=a1 warn("[HUB] invTable ditangkap,",#InvTable,"slot")
            end
         end
         if self==SetTile then
            local _,_,_,id=...
            if id==C.Seed then C.PlantAt=os.time() task.spawn(savePlant) end
         end
         if Spy.On and not IGNORE[self.Name] then
            local args=table.pack(...)
            task.spawn(function()
               local t={} for i=1,args.n do t[i]=ser(args[i]) end
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
notify("Berhasil!","Hub v5 dimuat.")
warn("[HUB] selesai")
