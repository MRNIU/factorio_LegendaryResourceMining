-- Copyright The MRNIU/factorio_LegendaryResourceMining Contributors
-- data 阶段：给原版大矿机增加隐藏资源分类，并为所有可产出物品的资源生成隐藏副本。

local C = require("constants")

local function is_managed_resource_name(name)
    return name == C.PLACEMENT_ANCHOR
        or string.sub(name, 1, #C.HIDDEN_RESOURCE_PREFIX) == C.HIDDEN_RESOURCE_PREFIX
end

local function product_type(product)
    if product.type then return product.type end
    if product[2] ~= nil then return "item" end
    return "item"
end

local function product_name(product)
    return product.name or product[1]
end

local function first_item_product(resource)
    local minable = resource.minable
    if not minable then return nil end

    if minable.result then
        return minable.result
    end

    if minable.results then
        for _, product in pairs(minable.results) do
            if product_type(product) ~= "fluid" then
                return product_name(product)
            end
        end
    end

    return nil
end

local function empty_resource_stages()
    return {
        sheet = {
            filename        = "__core__/graphics/empty.png",
            priority        = "extra-high",
            width           = 1,
            height          = 1,
            frame_count     = 1,
            variation_count = 1,
        },
    }
end

local function make_hidden_resource(resource)
    local hidden = table.deepcopy(resource)

    hidden.name                  = C.HIDDEN_RESOURCE_PREFIX .. resource.name
    hidden.localised_name        = resource.localised_name or { "entity-name." .. resource.name }
    hidden.localised_description = { "entity-description.LegendaryResourceMining-hidden-resource", hidden.localised_name }
    hidden.category              = C.HIDDEN_RESOURCE_CATEGORY
    hidden.autoplace             = nil
    hidden.hidden                = true
    hidden.hidden_in_factoriopedia = true
    hidden.factoriopedia_alternative = resource.name
    hidden.flags                 = { "not-on-map" }
    hidden.selectable_in_game    = false
    hidden.highlight             = false
    hidden.map_color             = { r = 0, g = 0, b = 0, a = 0 }
    hidden.map_grid              = false
    hidden.randomize_visual_position = false
    hidden.stages                = empty_resource_stages()
    hidden.stage_counts          = { 1 }
    hidden.stages_effect         = nil
    hidden.effect_animation_period = nil
    hidden.effect_animation_period_deviation = nil
    hidden.effect_darkness_multiplier = nil
    hidden.min_effect_alpha      = nil
    hidden.max_effect_alpha      = nil
    hidden.infinite              = false
    hidden.minimum               = nil
    hidden.normal                = nil
    hidden.infinite_depletion_amount = nil
    hidden.resource_patch_search_radius = 0

    return hidden
end

local hidden_resources = {}
local anchor_base
local anchor_item

data:extend({
    {
        type   = "resource-category",
        name   = C.HIDDEN_RESOURCE_CATEGORY,
        hidden = true,
    },
})

for resource_name, resource in pairs(data.raw.resource or {}) do
    if not is_managed_resource_name(resource_name) then
        local item = first_item_product(resource)
        if item and data.raw.item[item] then
            local hidden = make_hidden_resource(resource)
            hidden_resources[#hidden_resources + 1] = hidden

            if not anchor_base then
                anchor_base = table.deepcopy(hidden)
                anchor_item = item
            end
        end
    end
end

if anchor_base then
    anchor_base.name = C.PLACEMENT_ANCHOR
    anchor_base.localised_name = { "entity-name.LegendaryResourceMining-placement-anchor" }
    anchor_base.localised_description = { "entity-description.LegendaryResourceMining-placement-anchor" }
    anchor_base.minable = {
        mining_time = 1000000,
        result = anchor_item,
    }
    hidden_resources[#hidden_resources + 1] = anchor_base
end

if #hidden_resources > 0 then
    data:extend(hidden_resources)
end

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
