-- Copyright The MRNIU/factorio_LegendaryResourceMining Contributors
-- data-final-fixes 阶段：最后接管原版大矿机物品放置结果，避免被原版或其他 mod 的更新阶段覆盖。

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

local item = data.raw.item and data.raw.item[C.BIG_MINING_DRILL]
if item then
    item.place_result = C.PLACEMENT_PROXY
end
