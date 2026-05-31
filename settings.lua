-- Copyright The MRNIU/factorio_LegendaryResourceMining Contributors
-- 设置阶段：声明启动设置。这里决定资源选择是否限制在当前星球。

local C = require("constants")

data:extend({
    {
        type           = "string-setting",
        name           = C.SETTING_RESOURCE_SCOPE,
        setting_type   = "startup",
        default_value  = C.RESOURCE_SCOPE_PLANET,
        allowed_values = { C.RESOURCE_SCOPE_PLANET, C.RESOURCE_SCOPE_ALL },
        order          = "a-resource-scope",
    },
})
