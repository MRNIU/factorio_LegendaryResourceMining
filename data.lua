-- Copyright The MRNIU/factorio_LegendaryResourceMining Contributors
-- data 阶段：为所有可产出物品的资源生成同分类隐藏副本和临时放置锚点。

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

local function big_drill_sprite(name, options)
    options = options or {}
    options.priority = "high"
    options.scale = 0.5

    return util.sprite_load(
        "__space-age__/graphics/entity/big-mining-drill/North/big-mining-drill-" .. name,
        options
    )
end

local function make_placement_proxy(drill)
    return {
        type                  = "simple-entity-with-owner",
        name                  = C.PLACEMENT_PROXY,
        localised_name        = { "entity-name.big-mining-drill" },
        localised_description = { "entity-description.LegendaryResourceMining-placement-proxy" },
        icon                  = drill.icon,
        icons                 = drill.icons,
        icon_size             = drill.icon_size,
        flags                 = { "placeable-neutral", "player-creation" },
        hidden                = true,
        hidden_in_factoriopedia = true,
        minable               = { mining_time = 0.3, result = C.BIG_MINING_DRILL },
        max_health            = drill.max_health,
        collision_box         = table.deepcopy(drill.collision_box),
        selection_box         = table.deepcopy(drill.selection_box),
        drawing_box_vertical_extension = drill.drawing_box_vertical_extension,
        picture               = {
            layers = {
                big_drill_sprite("N-still", { dice = 2 }),
                big_drill_sprite("N-still-shadow", { draw_as_shadow = true, dice = 2 }),
            },
        },
    }
end

local function make_hidden_resource(resource)
    local hidden = table.deepcopy(resource)

    hidden.name                  = C.HIDDEN_RESOURCE_PREFIX .. resource.name
    hidden.localised_name        = resource.localised_name or { "entity-name." .. resource.name }
    hidden.localised_description = { "entity-description.LegendaryResourceMining-hidden-resource", hidden.localised_name }
    hidden.category              = resource.category or "basic-solid"
    hidden.autoplace             = nil
    hidden.hidden                = true
    hidden.hidden_in_factoriopedia = true
    hidden.factoriopedia_alternative = resource.name
    hidden.flags                 = { "placeable-neutral", "not-on-map" }
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
    hidden.surface_conditions    = nil

    return hidden
end

local hidden_resources = {}
local anchor_base
local anchor_item

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
    anchor_base.hidden = false
    anchor_base.hidden_in_factoriopedia = true
    anchor_base.factoriopedia_alternative = nil
    anchor_base.flags = { "placeable-neutral", "not-on-map" }
    anchor_base.category = "basic-solid"
    anchor_base.selectable_in_game = false
    anchor_base.highlight = false
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
    data:extend({ make_placement_proxy(drill) })
end
