-- Tes exploit ToggleTile untuk anti-gravity
-- Jalankan dari LUAR area anti-gravity
local RS = game:GetService("ReplicatedStorage")
local Unr = RS:FindFirstChild("ByteNetUnreliable")
local WR = RS:WaitForChild("WorldRemotes", 10)
local ToggleTile = WR:FindFirstChild("ToggleTile")

if not ToggleTile then
   warn("[TT] WorldRemotes.ToggleTile tidak ditemukan!")
   return
end

-- Baca posisi Y dari ByteNetUnreliable
local Pos = {x=nil, y=nil}
pcall(function()
   local old
   old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
      if self==Unr and getnamecallmethod()=="FireServer" then
         local b = ...
         if typeof(b)=="buffer" and buffer.len(b)>=9 and buffer.readu8(b,0)==2 then
            Pos.y = buffer.readf32(b, 1)
            Pos.x = buffer.readf32(b, 5)
         end
      end
      return old(self, ...)
   end))
end)

-- Tunggu posisi terbaca
task.wait(2)
warn(string.format("[TT] posisi sebelum: X=%.2f Y=%.2f", Pos.x or -1, Pos.y or -1))

local yBefore = Pos.y

-- Panggil ToggleTile di koordinat anti-gravity block (dari log: 24, 37)
warn("[TT] memanggil ToggleTile(24, 37)...")
ToggleTile:FireServer(24, 37)
task.wait(3)

warn(string.format("[TT] posisi sesudah: X=%.2f Y=%.2f", Pos.x or -1, Pos.y or -1))
local yAfter = Pos.y

if yBefore and yAfter then
   local diff = math.abs(yAfter - yBefore)
   if diff < 0.3 then
      warn("[TT] BERHASIL: Y stabil setelah ToggleTile, anti-gravity aktif!")
   else
      warn(string.format("[TT] Y berubah %.2f tile, anti-gravity tidak aktif", diff))
   end
end

-- Coba juga koordinat lain (misal di dekat karakter)
if Pos.x and Pos.y then
   warn("[TT] mencoba ToggleTile di posisi karakter sendiri...")
   ToggleTile:FireServer(math.floor(Pos.x), math.floor(Pos.y))
   task.wait(3)
   warn(string.format("[TT] Y setelah coba di posisi sendiri: %.2f", Pos.y or -1))
end

warn("[TT] selesai. Kirim screenshot ini ke chat.")
