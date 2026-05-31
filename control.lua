-- Copyright The MRNIU/factorio_LegendaryResourceMining Contributors
-- control 阶段：用临时放置代理绕过原版空地限制，并把传奇大矿机筛选器映射到隐藏资源。

local C = require("constants")

local RESOURCE_OFFSETS = {
    { x = 0, y = 0 },
    { x = 3, y = 0 },
    { x = -3, y = 0 },
    { x = 0, y = 3 },
    { x = 0, y = -3 },
}

local function ensure_storage()
    storage.drills = storage.drills or {}
    storage.destroyed_to_unit = storage.destroyed_to_unit or {}
end

local function quality_name(object)
    local quality = object and object.quality
    if type(quality) == "string" then return quality end
    if type(quality) == "table" then return quality.name end
    return nil
end

local function is_legendary_big_mining_drill(entity)
    return entity
        and entity.valid
        and entity.name == C.BIG_MINING_DRILL
        and quality_name(entity) == C.LEGENDARY_QUALITY
end

local function is_placement_proxy(entity)
    return entity and entity.valid and entity.name == C.PLACEMENT_PROXY
end

local function starts_with(value, prefix)
    return string.sub(value, 1, #prefix) == prefix
end

local function hidden_name_for(resource_name)
    return C.HIDDEN_RESOURCE_PREFIX .. resource_name
end

local function original_name_for(resource_name)
    if not resource_name then return nil end

    if starts_with(resource_name, C.HIDDEN_RESOURCE_PREFIX) then
        return string.sub(resource_name, #C.HIDDEN_RESOURCE_PREFIX + 1)
    end

    return resource_name
end

local function get_filter_name(entity)
    if entity.filter_slot_count == 0 then return nil end
    local filter = entity.get_filter(1)
    if type(filter) == "string" then return filter end
    if type(filter) == "table" then return filter.name end
    return nil
end

local function refresh_drill_connections(drill)
    if drill and drill.valid then
        pcall(function()
            drill.update_connections()
        end)
    end
end

local function set_filter_name(entity, resource_name)
    if entity.filter_slot_count == 0 then return false end
    local ok = pcall(function()
        entity.mining_drill_filter_mode = "whitelist"
        entity.set_filter(1, resource_name)
    end)
    return ok and get_filter_name(entity) == resource_name
end

local function clear_filter_name(entity)
    if entity.filter_slot_count == 0 then return false end
    local ok = pcall(function()
        entity.set_filter(1, nil)
    end)
    return ok
end

local function consumed_big_mining_drill_quality(event)
    local stack = event.stack
    if stack and stack.valid_for_read and stack.name == C.BIG_MINING_DRILL then
        return quality_name(stack)
    end

    local inventory = event.consumed_items
    if not inventory then return nil end

    local ok, contents = pcall(function()
        return inventory.get_contents()
    end)
    if ok and contents then
        for _, item in pairs(contents) do
            if item.name == C.BIG_MINING_DRILL then
                return quality_name(item) or item.quality
            end
        end
    end

    local found_ok, found_stack = pcall(function()
        return inventory.find_item_stack(C.BIG_MINING_DRILL)
    end)
    if found_ok and found_stack and found_stack.valid_for_read then
        return quality_name(found_stack)
    end

    return nil
end

local function setting_resource_scope()
    local setting = settings.startup[C.SETTING_RESOURCE_SCOPE]
    return setting and setting.value or C.RESOURCE_SCOPE_PLANET
end

local named_factor = {
    none = 0,
    ["very-low"] = 0.5,
    low = 0.75,
    normal = 1,
    high = 1.5,
    ["very-high"] = 2,
    ["very-small"] = 0.5,
    small = 0.75,
    big = 1.5,
    ["very-big"] = 2,
}

local function map_gen_factor(value)
    if type(value) == "number" then
        return value
    end
    if type(value) == "string" then
        return named_factor[value] or 1
    end
    return 1
end

local function autoplace_control_name(resource_name)
    local prototype = prototypes.entity[resource_name]
    local autoplace = prototype and prototype.autoplace_specification
    return autoplace and autoplace.control or resource_name
end

local function control_entry(map_gen_settings, control_name)
    local controls = map_gen_settings and map_gen_settings.autoplace_controls
    return controls and controls[control_name]
end

local function entity_autoplace_settings(map_gen_settings)
    local autoplace_settings = map_gen_settings and map_gen_settings.autoplace_settings
    local entity_settings = autoplace_settings and autoplace_settings.entity
    return entity_settings and entity_settings.settings
end

local function control_is_enabled(entry)
    if not entry then return true end
    return map_gen_factor(entry.frequency) > 0
        and map_gen_factor(entry.size) > 0
        and map_gen_factor(entry.richness) > 0
end

local function surface_planet_prototype(surface)
    local planet = surface and surface.planet
    if planet and planet.prototype then
        return planet.prototype
    end
    return surface and prototypes.space_location[surface.name] or nil
end

local function planet_allows_resource(surface, resource_name)
    local prototype = surface_planet_prototype(surface)
    local settings = entity_autoplace_settings(prototype and prototype.map_gen_settings)

    return settings and settings[resource_name] ~= nil
end

local function amount_for_resource(surface, resource_name)
    local control_name = autoplace_control_name(resource_name)

    if setting_resource_scope() ~= C.RESOURCE_SCOPE_ALL
        and not planet_allows_resource(surface, resource_name)
    then
        return nil
    end

    local entry = control_entry(surface and surface.map_gen_settings, control_name)
    if not control_is_enabled(entry) then return nil end

    local size = map_gen_factor(entry and entry.size)
    local richness = map_gen_factor(entry and entry.richness)
    local amount = math.floor(C.BASE_AMOUNT * size * richness)

    if amount < 1 then return nil end
    return math.min(amount, C.MAX_RESOURCE_AMOUNT)
end

local function destroy_resource(entity)
    if entity and entity.valid then
        entity.destroy({ raise_destroy = false })
    end
end

local function create_anchor_resource(surface, position)
    if not prototypes.entity[C.PLACEMENT_ANCHOR] then return nil end

    local ok, anchor = pcall(function()
        return surface.create_entity({
            name = C.PLACEMENT_ANCHOR,
            position = position,
            amount = 1,
            raise_built = false,
            create_build_effect_smoke = false,
        })
    end)
    if not ok then return nil end

    if anchor then
        anchor.destructible = false
    end

    return anchor
end

local function create_hidden_resource_at(surface, position, hidden_name, amount)
    local ok, resource = pcall(function()
        return surface.create_entity({
            name = hidden_name,
            position = position,
            amount = amount,
            raise_built = false,
            create_build_effect_smoke = false,
        })
    end)
    if not ok then return nil end

    if resource then
        resource.destructible = false
    end

    return resource
end

local function create_hidden_resource(drill, hidden_name, amount)
    local position = drill.position

    for _, offset in pairs(RESOURCE_OFFSETS) do
        local resource = create_hidden_resource_at(
            drill.surface,
            { x = position.x + offset.x, y = position.y + offset.y },
            hidden_name,
            amount
        )
        if resource then
            return resource
        end
    end

    return nil
end

local function drill_search_radius()
    local drill_prototype = prototypes.entity[C.BIG_MINING_DRILL]
    return drill_prototype and drill_prototype.resource_searching_radius or 6.49
end

local function clear_anchors_near(surface, position, radius)
    radius = radius or (drill_search_radius() + 8)
    local area = {
        { position.x - radius, position.y - radius },
        { position.x + radius, position.y + radius },
    }
    for _, anchor in pairs(surface.find_entities_filtered({
        name = C.PLACEMENT_ANCHOR,
        area = area,
    })) do
        destroy_resource(anchor)
    end
end

local cleanup_record

local function reject_filter(drill, record, original_name, player_index)
    cleanup_record(record)
    clear_filter_name(drill)

    local player = player_index and game.get_player(player_index)
    if player then
        player.print({ "message.LegendaryResourceMining-resource-not-allowed", { "entity-name." .. original_name } })
    end
end

local function print_to_player(player_index, message)
    local player = player_index and game.get_player(player_index)
    if player then
        player.print(message)
    end
end

local function record_for_drill(drill)
    ensure_storage()

    local unit_number = drill.unit_number
    local record = storage.drills[unit_number]
    if not record then
        record = { drill = drill }
        storage.drills[unit_number] = record

        local registration_number = script.register_on_object_destroyed(drill)
        record.registration_number = registration_number
        storage.destroyed_to_unit[registration_number] = unit_number
    else
        record.drill = drill
    end

    return record
end

cleanup_record = function(record)
    if not record then return end
    destroy_resource(record.resource)
    record.resource = nil
    record.hidden_name = nil
    record.original_name = nil
    record.depleted = false
    record.create_failed = false
end

local function remove_drill_record(unit_number)
    ensure_storage()
    local record = storage.drills[unit_number]
    if not record then return end

    cleanup_record(record)
    if record.registration_number then
        storage.destroyed_to_unit[record.registration_number] = nil
    end
    storage.drills[unit_number] = nil
end

local function sync_drill(drill, player_index)
    if not is_legendary_big_mining_drill(drill) then return end

    local record = record_for_drill(drill)
    local selected_name = get_filter_name(drill)
    if not selected_name then
        cleanup_record(record)
        return
    end

    local original_name = original_name_for(selected_name)
    local hidden_name = hidden_name_for(original_name)
    if not prototypes.entity[hidden_name] then
        cleanup_record(record)
        return
    end

    local amount = amount_for_resource(drill.surface, original_name)
    if not amount then
        reject_filter(drill, record, original_name, player_index)
        return
    end

    if selected_name ~= hidden_name and not set_filter_name(drill, hidden_name) then
        cleanup_record(record)
        clear_filter_name(drill)
        print_to_player(player_index, { "message.LegendaryResourceMining-filter-apply-failed", { "entity-name." .. original_name } })
        return
    end
    refresh_drill_connections(drill)

    if record.hidden_name ~= hidden_name then
        cleanup_record(record)
        record.hidden_name = hidden_name
        record.original_name = original_name
        record.depleted = false
        clear_anchors_near(drill.surface, drill.position)
        record.resource = create_hidden_resource(drill, hidden_name, amount)
        refresh_drill_connections(drill)
        if not record.resource and not record.create_failed then
            record.create_failed = true
            print_to_player(player_index, { "message.LegendaryResourceMining-hidden-resource-create-failed", { "entity-name." .. original_name } })
        end
        return
    end

    if record.resource and record.resource.valid then
        refresh_drill_connections(drill)
        return
    end
    if record.depleted then return end

    clear_anchors_near(drill.surface, drill.position)
    record.resource = create_hidden_resource(drill, hidden_name, amount)
    refresh_drill_connections(drill)
    if not record.resource and not record.create_failed then
        record.create_failed = true
        print_to_player(player_index, { "message.LegendaryResourceMining-hidden-resource-create-failed", { "entity-name." .. record.original_name } })
    end
end

local function supported_visible_resource_in_range(surface, position)
    local drill_prototype = prototypes.entity[C.BIG_MINING_DRILL]
    local categories = drill_prototype and drill_prototype.resource_categories
    if not categories then return false end

    local radius = drill_prototype.resource_searching_radius or 6.49
    local area = {
        { position.x - radius, position.y - radius },
        { position.x + radius, position.y + radius },
    }

    for _, resource in pairs(surface.find_entities_filtered({ type = "resource", area = area })) do
        if resource.valid
            and resource.name ~= C.PLACEMENT_ANCHOR
            and not starts_with(resource.name, C.HIDDEN_RESOURCE_PREFIX)
        then
            local category = resource.prototype.resource_category or "basic-solid"
            if categories[category] then
                return true
            end
            for _, allowed_category in pairs(categories) do
                if allowed_category == category then
                    return true
                end
            end
        end
    end

    return false
end

local function insert_or_spill_drill(player, surface, position, quality)
    local stack = { name = C.BIG_MINING_DRILL, count = 1 }
    if quality then stack.quality = quality end

    local inserted = player and player.valid and player.insert(stack) or 0
    if inserted < 1 then
        surface.spill_item_stack({
            position = position,
            stack = stack,
            enable_looted = true,
            allow_belts = false,
        })
    end
end

local function create_big_mining_drill(surface, position, direction, force, quality, player_index)
    local parameters = {
        name = C.BIG_MINING_DRILL,
        position = position,
        direction = direction,
        force = force,
        raise_built = false,
        create_build_effect_smoke = false,
    }

    if quality then parameters.quality = quality end
    if player_index then parameters.player = player_index end

    local ok, drill = pcall(function()
        return surface.create_entity(parameters)
    end)

    if ok then return drill end
    return nil
end

local function replace_proxy_with_drill(proxy, event, use_anchor)
    local player = event.player_index and game.get_player(event.player_index)
    local surface = proxy.surface
    local position = { x = proxy.position.x, y = proxy.position.y }
    local direction = proxy.direction
    local force = proxy.force
    local quality = consumed_big_mining_drill_quality(event) or quality_name(proxy)
    local anchor

    if use_anchor then
        anchor = create_anchor_resource(surface, position)
    end

    proxy.destroy({ raise_destroy = false })

    local drill = create_big_mining_drill(surface, position, direction, force, quality, event.player_index)

    if anchor then
        destroy_resource(anchor)
    end

    if not drill then
        insert_or_spill_drill(player, surface, position, quality)
        print_to_player(event.player_index, { "message.LegendaryResourceMining-drill-create-failed" })
        return nil
    end

    return drill
end

local function reject_proxy_build(proxy, event)
    local player = event.player_index and game.get_player(event.player_index)
    local surface = proxy.surface
    local position = { x = proxy.position.x, y = proxy.position.y }
    local quality = consumed_big_mining_drill_quality(event) or quality_name(proxy)

    proxy.destroy({ raise_destroy = false })
    insert_or_spill_drill(player, surface, position, quality)

    if player then
        player.create_local_flying_text({
            text = { "message.LegendaryResourceMining-non-legendary-needs-resource" },
            position = position,
        })
    end
end

local function built_proxy(entity, event)
    local quality = consumed_big_mining_drill_quality(event) or quality_name(entity)

    if quality == C.LEGENDARY_QUALITY then
        local drill = replace_proxy_with_drill(entity, event, true)
        if drill then
            sync_drill(drill, event.player_index)
        end
        return
    end

    if supported_visible_resource_in_range(entity.surface, entity.position) then
        replace_proxy_with_drill(entity, event, false)
    else
        reject_proxy_build(entity, event)
    end
end

local function sync_all_drills()
    ensure_storage()
    for unit_number, record in pairs(storage.drills) do
        local drill = record.drill
        if drill and drill.valid then
            sync_drill(drill)
        else
            remove_drill_record(unit_number)
        end
    end
end

local function scan_existing_drills()
    ensure_storage()
    for _, surface in pairs(game.surfaces) do
        for _, drill in pairs(surface.find_entities_filtered({ name = C.BIG_MINING_DRILL })) do
            if is_legendary_big_mining_drill(drill) then
                sync_drill(drill)
            end
        end
    end
end

local function clear_all_anchor_resources()
    for _, surface in pairs(game.surfaces) do
        for _, anchor in pairs(surface.find_entities_filtered({ name = C.PLACEMENT_ANCHOR })) do
            destroy_resource(anchor)
        end
    end
end

local function clear_all_placement_proxies()
    for _, surface in pairs(game.surfaces) do
        for _, proxy in pairs(surface.find_entities_filtered({ name = C.PLACEMENT_PROXY })) do
            proxy.destroy({ raise_destroy = false })
        end
    end
end

local function reject_non_legendary_empty_build(entity, event)
    if supported_visible_resource_in_range(entity.surface, entity.position) then return end

    local player = event.player_index and game.get_player(event.player_index)
    local surface = entity.surface
    local position = entity.position
    local quality = consumed_big_mining_drill_quality(event) or quality_name(entity)

    entity.destroy({ raise_destroy = false })
    insert_or_spill_drill(player, surface, position, quality)

    if player then
        player.create_local_flying_text({
            text = { "message.LegendaryResourceMining-non-legendary-needs-resource" },
            position = position,
        })
    end
end

local function built_entity(event)
    local entity = event.created_entity or event.entity or event.destination
    if is_placement_proxy(entity) then
        built_proxy(entity, event)
        return
    end

    if not (entity and entity.valid and entity.name == C.BIG_MINING_DRILL) then return end

    clear_anchors_near(entity.surface, entity.position)

    if is_legendary_big_mining_drill(entity) then
        sync_drill(entity, event.player_index)
    else
        reject_non_legendary_empty_build(entity, event)
    end
end

local function entity_from_event(event)
    return event.entity or event.destination or event.created_entity
end

script.on_init(function()
    storage.drills = {}
    storage.destroyed_to_unit = {}
end)

script.on_configuration_changed(function()
    ensure_storage()
    storage.pending_proxy_builds = nil
    storage.pending_anchors = nil
    storage.player_anchor_fields = nil
    clear_all_anchor_resources()
    clear_all_placement_proxies()
    sync_all_drills()
    scan_existing_drills()
end)

script.on_event(defines.events.on_built_entity, built_entity)
script.on_event(defines.events.on_robot_built_entity, built_entity)
script.on_event(defines.events.script_raised_built, built_entity)
script.on_event(defines.events.script_raised_revive, built_entity)

script.on_event(defines.events.on_gui_closed, function(event)
    local entity = event.entity
    if is_legendary_big_mining_drill(entity) then
        sync_drill(entity, event.player_index)
    end
end)

script.on_event(defines.events.on_entity_settings_pasted, function(event)
    local entity = entity_from_event(event)
    if is_legendary_big_mining_drill(entity) then
        sync_drill(entity, event.player_index)
    end
end)

script.on_event(defines.events.on_resource_depleted, function(event)
    ensure_storage()
    local resource = event.entity
    if not resource then return end

    for _, record in pairs(storage.drills) do
        if record.resource == resource then
            record.resource = nil
            record.depleted = true
            return
        end
    end
end)

script.on_event(defines.events.on_object_destroyed, function(event)
    ensure_storage()
    local unit_number = storage.destroyed_to_unit[event.registration_number]
    if unit_number then
        remove_drill_record(unit_number)
    end
end)

script.on_nth_tick(30, sync_all_drills)
