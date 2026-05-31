-- Copyright The MRNIU/factorio_LegendaryResourceMining Contributors
-- control 阶段：只处理传奇原版大矿机，把玩家选择的原版资源映射到隐藏资源。

local C = require("constants")

local function ensure_storage()
    storage.drills = storage.drills or {}
    storage.destroyed_to_unit = storage.destroyed_to_unit or {}
    storage.pending_anchors = storage.pending_anchors or {}
    storage.pending_proxy_builds = storage.pending_proxy_builds or {}
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

local function cursor_is_legendary_big_mining_drill(player)
    if not (player and player.valid) then return false end
    local stack = player.cursor_stack
    return stack
        and stack.valid_for_read
        and stack.name == C.BIG_MINING_DRILL
        and quality_name(stack) == C.LEGENDARY_QUALITY
end

local function cursor_is_big_mining_drill(player)
    if not (player and player.valid) then return false end
    local stack = player.cursor_stack
    return stack and stack.valid_for_read and stack.name == C.BIG_MINING_DRILL
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

local function set_filter_name(entity, resource_name)
    if entity.filter_slot_count == 0 then return false end
    local ok = pcall(function()
        entity.set_filter(1, resource_name)
    end)
    return ok
end

local function clear_filter_name(entity)
    if entity.filter_slot_count == 0 then return false end
    local ok = pcall(function()
        entity.set_filter(1, nil)
    end)
    return ok
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

    local anchor = surface.create_entity({
        name = C.PLACEMENT_ANCHOR,
        position = position,
        amount = 1,
        raise_built = false,
        create_build_effect_smoke = false,
    })

    if anchor then
        anchor.destructible = false
    end

    return anchor
end

local function create_hidden_resource(drill, hidden_name, amount)
    local position = drill.position
    local resource = drill.surface.create_entity({
        name = hidden_name,
        position = position,
        amount = amount,
        raise_built = false,
        create_build_effect_smoke = false,
    })

    if resource then
        resource.destructible = false
    end

    return resource
end

local function clear_anchors_near(surface, position)
    local area = {
        { position.x - 2, position.y - 2 },
        { position.x + 2, position.y + 2 },
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

    if selected_name ~= hidden_name then
        set_filter_name(drill, hidden_name)
    end

    if record.hidden_name ~= hidden_name then
        cleanup_record(record)
        record.hidden_name = hidden_name
        record.original_name = original_name
        record.depleted = false
        record.resource = create_hidden_resource(drill, hidden_name, amount)
        return
    end

    if record.resource and record.resource.valid then return end
    if record.depleted then return end

    record.resource = create_hidden_resource(drill, hidden_name, amount)
end

local function positions_match(a, b)
    if not (a and b) then return false end
    return math.abs(a.x - b.x) < 0.01 and math.abs(a.y - b.y) < 0.01
end

local function remember_proxy_build(event)
    local player = game.get_player(event.player_index)
    if not cursor_is_big_mining_drill(player) then return end

    ensure_storage()
    storage.pending_proxy_builds[event.player_index] = {
        tick = game.tick,
        position = event.position,
        direction = event.direction,
    }
end

local function pending_direction(event, proxy)
    local player_index = event.player_index
    local pending = player_index and storage.pending_proxy_builds[player_index]
    if pending and pending.tick == game.tick and positions_match(pending.position, proxy.position) then
        storage.pending_proxy_builds[player_index] = nil
        return pending.direction
    end

    return proxy.direction or defines.direction.north
end

local function supported_visible_resource_in_range(surface, position)
    local drill_prototype = prototypes.entity[C.BIG_MINING_DRILL]
    local categories = drill_prototype and drill_prototype.resource_categories
    if not categories then return false end

    local radius = drill_prototype.mining_drill_radius or 6.49
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

local function create_actual_drill(surface, position, direction, force, quality, player_index)
    return surface.create_entity({
        name = C.BIG_MINING_DRILL,
        position = position,
        direction = direction,
        force = force,
        quality = quality,
        player = player_index,
        raise_built = false,
        create_build_effect_smoke = false,
    })
end

local function replace_proxy(proxy, event)
    ensure_storage()

    local surface = proxy.surface
    local position = proxy.position
    local direction = pending_direction(event, proxy)
    local force = proxy.force
    local quality = quality_name(proxy)
    local legendary = quality == C.LEGENDARY_QUALITY
    local player = event.player_index and game.get_player(event.player_index)

    proxy.destroy({ raise_destroy = false })

    if not legendary and not supported_visible_resource_in_range(surface, position) then
        insert_or_spill_drill(player, surface, position, quality)
        if player then
            player.create_local_flying_text({
                text = { "message.LegendaryResourceMining-non-legendary-needs-resource" },
                position = position,
            })
        end
        return
    end

    local anchor = legendary and create_anchor_resource(surface, position) or nil
    local drill = create_actual_drill(surface, position, direction, force, quality, event.player_index)
    destroy_resource(anchor)

    if not drill then
        insert_or_spill_drill(player, surface, position, quality)
        return
    end

    if legendary then
        sync_drill(drill, event.player_index)
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

local OnTick

OnTick = function()
    ensure_storage()
    for index = #storage.pending_anchors, 1, -1 do
        local pending = storage.pending_anchors[index]
        if game.tick > pending.tick then
            destroy_resource(pending.entity)
            table.remove(storage.pending_anchors, index)
        end
    end

    if not next(storage.pending_anchors) then
        script.on_event(defines.events.on_tick, nil)
    end
end

local function queue_anchor_cleanup(anchor)
    ensure_storage()
    storage.pending_anchors[#storage.pending_anchors + 1] = {
        entity = anchor,
        tick = game.tick,
    }
    script.on_event(defines.events.on_tick, OnTick)
end

local function built_entity(event)
    local entity = event.created_entity or event.entity or event.destination
    if entity and entity.valid and entity.name == C.PLACEMENT_PROXY then
        replace_proxy(entity, event)
        return
    end

    if not is_legendary_big_mining_drill(entity) then return end

    clear_anchors_near(entity.surface, entity.position)
    sync_drill(entity, event.player_index)
end

local function entity_from_event(event)
    return event.entity or event.destination or event.created_entity
end

script.on_init(function()
    storage.drills = {}
    storage.destroyed_to_unit = {}
    storage.pending_anchors = {}
    storage.pending_proxy_builds = {}
end)

script.on_configuration_changed(function()
    ensure_storage()
    sync_all_drills()
    scan_existing_drills()
end)

script.on_load(function()
    if storage.pending_anchors and next(storage.pending_anchors) then
        script.on_event(defines.events.on_tick, OnTick)
    end
end)

script.on_event(defines.events.on_pre_build, remember_proxy_build)
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

script.on_nth_tick(120, sync_all_drills)
