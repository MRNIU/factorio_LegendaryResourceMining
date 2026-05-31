-- Copyright The MRNIU/factorio_LegendaryResourceMining Contributors
-- data-final-fixes 阶段：最后给原版大矿机追加隐藏资源分类和资源筛选槽。

local C = require("constants")

local drill = data.raw["mining-drill"] and data.raw["mining-drill"][C.BIG_MINING_DRILL]
if drill then
    drill.filter_count = math.max(drill.filter_count or 0, 1)
    drill.resource_categories = drill.resource_categories or { "basic-solid" }

    local has_hidden_category = false
    for _, category in pairs(drill.resource_categories) do
        if category == C.HIDDEN_RESOURCE_CATEGORY then
            has_hidden_category = true
            break
        end
    end

    if not has_hidden_category then
        drill.resource_categories[#drill.resource_categories + 1] = C.HIDDEN_RESOURCE_CATEGORY
    end
end
