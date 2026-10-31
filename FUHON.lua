local LP = game:GetService("Players").LocalPlayer
local pg = LP.PlayerGui
local kw = {"slot", "hotbar", "inventory", "item", "backpack", "select", "tile", "world"}

local found = 0
for _, d in ipairs(pg:GetDescendants()) do
   if d:IsA("GuiButton") or d:IsA("ImageButton") or d:IsA("TextButton") then
      local nm = d.Name:lower()
      for _, k in ipairs(kw) do
         if nm:find(k) then
            found += 1
            if found <= 25 then
               warn("[GUI]", d:GetFullName(), d.ClassName,
                  ("pos=%d,%d size=%d,%d"):format(d.AbsolutePosition.X, d.AbsolutePosition.Y, d.AbsoluteSize.X, d.AbsoluteSize.Y))
            end
            break
         end
      end
   end
end
warn("[GUI] selesai, total ditemukan:", found)
