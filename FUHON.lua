-- Growtopia Hub v5 (Safe Mode Loader)
warn("[HUB] mulai")

-- Cek apakah fungsi HttpGet dan loadstring tersedia
if not game.HttpGet or not loadstring then
   warn("[HUB] Executor Anda tidak mendukung HttpGet atau loadstring!")
   return
end

local success, Rayfield = pcall(function()
   return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)

if not success or not Rayfield then
   warn("[HUB] Gagal mengunduh Rayfield UI Library. Pastikan koneksi atau executor mendukung.")
   return
end

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
   Rayfield:Notify({Title="Error", Content="Remote SetTile tidak ditemukan", Duration=6})
   return
end

-- STATE
local C = {
   X1=0, X2=3, Y=36, Delay=0.15, Grow=75, Margin=15, Seed=3,
   PlantAt=nil, HTOn=false, Move=false, Win=3, Tol=0.6,
   PX1=0, PX2=99, PY1=36, PY2=36, PSeed=3, PDelay=0.25, PTOn=false, PTMove=true,
   REACH=2,
}
local Pos = {x=nil, y=nil}
local InvTable = nil
local AG = {On=false}
local Spy = {On=false, Logs={}}
local IGNORE = {ByteNetUnreliable=true, SaveInventory=true}
local SAVE = "gthub_plantat.txt"

-- UTIL
local function notify(t, c)
   Rayfield:Notify({Title=t, Content=c, Duration=4, Image=4483362458})
end
local function savePlant()
   pcall(function() if writefile then writefile(SAVE, C.PlantAt and tostring(C.PlantAt) or "") end end)
end
local function loadPlant()
   pcall(function() if isfile and isfile(SAVE) then C.PlantAt = tonumber(readfile(SAVE)) end end)
end
local function parseDur(text)
   text = tostring(text):lower():gsub("%s", "")
   local plain = tonumber(text)
   if plain then return plain end
   local total, found = 0, false
   for num, unit in text:gmatch("(%d+%.?%d*)([a-z])") do
      local m = (unit=="h" or unit=="j") and 3600 or unit=="m" and 60 or (unit=="s" or unit=="d") and 1 or nil
      if m then total = total + tonumber(num)*m found = true end
   end
   return found and total or nil
end
local function fmt(sec)
   sec = math.max(0, math.ceil(sec))
   return string.format("%dj %dm %dd", sec//3600, (sec%3600)//60, sec%60)
end

-- INVENTORY
local function findSlot(id)
   if not InvTable then return nil end
   for _, s in pairs(InvTable) do if type(s)=="table" and s[1]==id then return s end end
   return nil
end
local function seedCount(id) local s = findSlot(id) return s and s[2] or -1 end
local function tryDecrement(id) local s = findSlot(id) if s and s[2]>0 then s[2] = s[2]-1 end end

-- TOMBOL LAYAR
local function getMobileBtn(name)
   local gui = LP.PlayerGui:FindFirstChild("MobileGui")
   return gui and gui:FindFirstChild(name)
end
local function pressScreen(btn, down)
   if not btn then return end
   local p, s = btn.AbsolutePosition, btn.AbsoluteSize
   local x = p.X + s.X/2
   local y = p.Y + s.Y/2 + GS:GetGuiInset().Y
   VIM:SendMouseButtonEvent(x, y, 0, down, game, 0)
end

-- GERAK X
local function goToX(tx)
   local L, R = getMobileBtn("Left"), getMobileBtn("Right")
   if not (L and R and Pos.x) then return false end
   for _ = 1, 20 do
      local dx = tx - Pos.x
      if math.abs(dx) <= C.Tol then return true end
      local btn = dx > 0 and R or L
      pressScreen(btn, true)
      local t0 = os.clock()
      while os.clock()-t0 < 0.6 do
         task.wait(0.03)
         local d2 = tx - Pos.x
         if (dx>0 and d2<=C.Tol) or (dx<0 and d2>=-C.Tol) then break end
      end
      pressScreen(btn, false)
      task.wait(0.15)
   end
   return math.abs(tx - Pos.x) <= C.Tol*2
end

-- GERAK Y
local function jump()
   local J = getMobileBtn("Jump")
   pressScreen(J, true) task.wait(0.08) pressScreen(J, false)
end
local function goToY(ty)
   if not Pos.y then return false end
   for _ = 1, 30 do
      local dy = ty - Pos.y
      if math.abs(dy) <= C.Tol then return true end
      if dy < 0 then
         jump() task.wait(0.4)
      else
         local R = getMobileBtn("Right")
         pressScreen(R, true) task.wait(0.15) pressScreen(R, false)
         task.wait(0.3)
      end
   end
   return math.abs(ty - Pos.y) <= C.Tol*2
end

-- ANTI-GRAVITY
local function startAG()
   task.spawn(function()
      local J = getMobileBtn("Jump")
      if not J then warn("[AG] Jump button tidak ditemukan") return end
      while AG.On do
         pressScreen(J, true) task.wait(0.06) pressScreen(J, false)
         task.wait(0.18)
      end
   end)
end

-- HARVEST
local function harvestRow()
   local lo, hi = math.min(C.X1, C.X2), math.max(C.X1, C.X2)
   local home = Pos.x
   local x = lo
   while x <= hi do
      local stop = math.min(x + C.Win - 1, hi)
      if C.Move then goToX((x+stop)/2 + 0.5) end
      for t = x, stop do SetTile:FireServer("fg", t, C.Y, 0) task.wait(C.Delay) end
      x = stop + 1
   end
   if C.Move and home then goToX(home) end
end

-- PLANT
local function plantTile(x, y, id)
   tryDecrement(id)
   SetTile:FireServer("fg", x, y, id)
end

local PTStatus
local function setPT(t) pcall(function() PTStatus:Set({Title="Status PT", Content=t}) end) end

local function autoPlantWithMove()
   local STEP = C.REACH*2 + 1
   local done, total = 0, 0
   for _y = C.PY1, C.PY2, STEP do
      local y2 = math.min(_y+STEP-1, C.PY2)
      for _x = C.PX1, C.PX2, STEP do
         local x2 = math.min(_x+STEP-1, C.PX2)
         total = total + (x2-_x+1)*(y2-_y+1)
      end
   end
   setPT(string.format("Mulai: %d/%d tile", 0, total))
   for _y = C.PY1, C.PY2, STEP do
      if not C.PTOn then break end
      local y1, y2 = _y, math.min(_y+STEP-1, C.PY2)
      local cy = math.floor((y1+y2)/2)
      if C.PTMove then goToY(cy) end
      for _x = C.PX1, C.PX2, STEP do
         if not C.PTOn then break end
         local x1, x2 = _x, math.min(_x+STEP-1, C.PX2)
         local cx = math.floor((x1+x2)/2)
         if C.PTMove then goToX(cx + 0.5) end
         for py = y1, y2 do
            for px = x1, x2 do
               if not C.PTOn then return end
               if InvTable and seedCount(C.PSeed) == 0 then
                  C.PTOn = false
                  setPT("Seed habis di tile "..px..","..py)
                  notify("PT", "Seed habis") return
               end
               plantTile(px, py, C.PSeed)
               done = done + 1
               task.wait(C.PDelay)
            end
         end
         setPT(string.format("%d/%d tile", done, total))
      end
   end
   setPT(string.format("Selesai: %d/%d tile", done, total))
   C.PTOn = false
   notify("PT", "Auto Plant selesai!")
end

-- ZOOM
local function setZoom(scale)
   pcall(function()
      local cam = LP.PlayerGui.GameGui.World.Camera
      local ui = cam:FindFirstChildOfClass("UIScale")
      if not ui then ui = Instance.new("UIScale") ui.Parent = cam end
      ui.Scale = 1/scale
   end)
end

-- WINDOW
local Win = Rayfield:CreateWindow({
   Name = "Growtopia Hub v5",
   LoadingTitle = "Memuat Hub...",
   LoadingSubtitle = "oleh Pemula",
   ConfigurationSaving = {Enabled=false},
   KeySystem = false,
})

-- TAB HT
local HTTab = Win:CreateTab("HT", 4483362458)
HTTab:CreateSection("Baris Tree")
HTTab:CreateInput({Name="X mulai", PlaceholderText="0", RemoveTextAfterFocusLost=false, Callback=function(t) C.X1=tonumber(t) or C.X1 end})
HTTab:CreateInput({Name="X akhir", PlaceholderText="3", RemoveTextAfterFocusLost=false, Callback=function(t) C.X2=tonumber(t) or C.X2 end})
HTTab:CreateInput({Name="Y", PlaceholderText="36", RemoveTextAfterFocusLost=false, Callback=function(t) C.Y=tonumber(t) or C.Y end})
HTTab:CreateInput({Name="Waktu tumbuh", PlaceholderText="3j47m", RemoveTextAfterFocusLost=false, Callback=function(t)
   local d = parseDur(t)
   if d then C.Grow=d notify("Waktu tumbuh", fmt(d)) end
end})
HTTab:CreateToggle({Name="Auto Harvest", CurrentValue=false, Flag="AutoHT", Callback=function(v)
   C.HTOn=v
   if not v then return end
   task.spawn(function()
      while C.HTOn do
         if C.PlantAt then
            local sisa = C.Grow + C.Margin - (os.time() - C.PlantAt)
            if sisa <= 0 then
               harvestRow()
               C.PlantAt=nil savePlant()
            end
         end
         task.wait(1)
      end
   end)
end})

-- TAB PT
local PTTab = Win:CreateTab("PT", 4483362458)
PTTab:CreateSection("Area Tanam")
PTTab:CreateInput({Name="X mulai", PlaceholderText="0", RemoveTextAfterFocusLost=false, Callback=function(t) C.PX1=tonumber(t) or C.PX1 end})
PTTab:CreateInput({Name="X akhir", PlaceholderText="99", RemoveTextAfterFocusLost=false, Callback=function(t) C.PX2=tonumber(t) or C.PX2 end})
PTTab:CreateInput({Name="Y mulai", PlaceholderText="36", RemoveTextAfterFocusLost=false, Callback=function(t) C.PY1=tonumber(t) or C.PY1 end})
PTTab:CreateInput({Name="Y akhir", PlaceholderText="36", RemoveTextAfterFocusLost=false, Callback=function(t) C.PY2=tonumber(t) or C.PY2 end})
PTTab:CreateToggle({Name="Auto Plant", CurrentValue=false, Flag="AutoPT", Callback=function(v)
   C.PTOn=v
   if not v then return end
   task.spawn(function() autoPlantWithMove() end)
end})

loadPlant()
notify("Berhasil!", "Hub v5 dimuat.")
warn("[HUB] selesai")
