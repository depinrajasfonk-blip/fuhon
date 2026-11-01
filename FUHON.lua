-- Deteksi perubahan saat anti-gravity aktif di game
-- Jalankan SEBELUM masuk area anti-grav, lalu jalan ke sana
local LP = game:GetService("Players").LocalPlayer
local RS = game:GetService("ReplicatedStorage")
local Unr = RS:FindFirstChild("ByteNetUnreliable")
local Rel = RS:FindFirstChild("ByteNetReliable")
local WEBHOOK = "https://discord.com/api/webhooks/1565395131660636311/RJCZl7WNgSUVI6T61jxA8sI0kGpx7Jkquj4Jjj9W-9p3U2Kkd7TNYFfEh3tiUA9ZAg1i"

local function sendWH(msg)
   local fn = syn and syn.request or http_request or request
   if not fn then return end
   pcall(fn, {Url=WEBHOOK, Method="POST",
      Headers={["Content-Type"]="application/json"},
      Body=game:GetService("HttpService"):JSONEncode({content="```\n"..tostring(msg):sub(1,1900).."\n```"})})
end

local logs = {}
local function log(...)
   local s = table.concat(table.pack(...), " ")
   warn("[AG-DIAG]", s)
   logs[#logs+1] = s
end

-- Snapshot posisi Y sebelum masuk area
local Pos = {x=nil, y=nil}
local prevY = nil
local frameCount = 0

-- 1. Monitor perubahan atribut player dan karakter
local function snapshotAttrs(obj, label)
   local t = {}
   for k, v in pairs(obj:GetAttributes()) do
      t[#t+1] = k.."="..tostring(v)
   end
   if #t > 0 then log(label, "attrs:", table.concat(t, ", ")) end
end

-- 2. Pantau remote baru yang muncul
local knownRemotes = {}
for _, r in ipairs(RS:GetDescendants()) do knownRemotes[r] = true end

-- 3. Pantau perubahan pada LocalPlayer dan Character
local function watchAttrs(obj, name)
   obj.AttributeChanged:Connect(function(attr)
      log(name, "attr changed:", attr, "=", tostring(obj:GetAttribute(attr)))
   end)
end
watchAttrs(LP, "LocalPlayer")
if LP.Character then watchAttrs(LP.Character, "Character") end
LP.CharacterAdded:Connect(function(c) watchAttrs(c, "Character") end)

-- 4. Pantau remote baru
RS.DescendantAdded:Connect(function(d)
   if not knownRemotes[d] then
      log("REMOTE BARU:", d:GetFullName(), d.ClassName)
   end
end)

-- 5. Hook semua FireServer: cari paket baru saat AG aktif
local Seen = {}  -- paket yang sudah pernah dilihat
local hookOk, hookErr = pcall(function()
   local old
   old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
      if getnamecallmethod() == "FireServer" and not checkcaller() then
         local key = self:GetFullName()

         -- posisi dari Unreliable
         if self == Unr then
            local b = ...
            if typeof(b)=="buffer" and buffer.len(b)>=9 then
               local id = buffer.readu8(b, 0)
               if id == 2 then
                  Pos.y = buffer.readf32(b, 1)
                  Pos.x = buffer.readf32(b, 5)
                  frameCount += 1
                  -- deteksi perubahan drastis di Y (jatuh vs tidak jatuh)
                  if prevY and math.abs(Pos.y - prevY) < 0.01 and frameCount % 30 == 0 then
                     log(string.format("HOVER: Y stabil di %.2f (tidak jatuh)", Pos.y))
                  end
                  prevY = Pos.y
               elseif not Seen[id] then
                  -- paket jenis baru dari Unreliable
                  local bytes = {}
                  for i=0, math.min(buffer.len(b),15)-1 do bytes[#bytes+1]=string.format("%02X",buffer.readu8(b,i)) end
                  log(string.format("UNREL byte0=%02X len=%d: %s", id, buffer.len(b), table.concat(bytes," ")))
                  Seen[id] = true
               end
            end
         elseif self == Rel then
            -- paket Reliable: cek byte pertama untuk tipe baru
            local b = ...
            if typeof(b)=="buffer" and buffer.len(b)>=1 then
               local id = buffer.readu8(b, 0)
               local rkey = "R"..id
               if not Seen[rkey] then
                  local bytes = {}
                  for i=0, math.min(buffer.len(b),15)-1 do bytes[#bytes+1]=string.format("%02X",buffer.readu8(b,i)) end
                  log(string.format("RELIABLE byte0=%02X len=%d: %s", id, buffer.len(b), table.concat(bytes," ")))
                  Seen[rkey] = true
               end
            end
         else
            -- remote lain yang belum pernah ketangkap
            if not Seen[key] then
               local args = table.pack(...)
               local t = {}
               for i=1,math.min(args.n,3) do
                  local v=args[i]
                  if typeof(v)=="buffer" then t[i]="buffer["..buffer.len(v).."]"
                  else t[i]=typeof(v)..":"..tostring(v) end
               end
               log("REMOTE:", key, table.concat(t,", "))
               Seen[key] = true
            end
         end
      end
      return old(self, ...)
   end))
end)
log("hook ok?", hookOk, hookErr)

-- Snapshot awal
snapshotAttrs(LP, "LP-awal")
if LP.Character then snapshotAttrs(LP.Character, "Char-awal") end

log("=== SEKARANG JALAN KE AREA ANTI-GRAVITY ===")
warn("[AG-DIAG] === JALAN KE AREA ANTI-GRAVITY SEKARANG ===")

-- Kirim tiap 15 detik selama 60 detik
for i=1,4 do
   task.wait(15)
   snapshotAttrs(LP, string.format("LP-%ds", i*15))
   if LP.Character then snapshotAttrs(LP.Character, string.format("Char-%ds", i*15)) end
   log(string.format("--- snapshot %ds (Y=%.2f) ---", i*15, Pos.y or -1))
   local chunk = table.concat(logs, "\n")
   sendWH(string.format("[%ds] Y=%.2f\n%s", i*15, Pos.y or -1, chunk:sub(-1500)))
   logs = {}
end
warn("[AG-DIAG] selesai")
