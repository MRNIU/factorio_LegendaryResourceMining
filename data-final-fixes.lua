-- Copyright The MRNIU/factorio_LegendaryResourceMining Contributors
-- data-final-fixes 阶段：最后给原版大矿机开启资源筛选槽。

local C = require("constants")

local drill = data.raw["mining-drill"] and data.raw["mining-drill"][C.BIG_MINING_DRILL]
if drill then
    drill.filter_count = math.max(drill.filter_count or 0, 1)
end

local item = data.raw.item and data.raw.item[C.BIG_MINING_DRILL]
if item and data.raw["simple-entity-with-owner"] and data.raw["simple-entity-with-owner"][C.PLACEMENT_PROXY] then
    item.place_result = C.PLACEMENT_PROXY
end
