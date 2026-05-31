-- Copyright The MRNIU/factorio_LegendaryResourceMining Contributors
-- 纯常量模块，同时给 settings / data / control 阶段复用。

local M = {}

M.MOD_NAME = "LegendaryResourceMining"

M.SETTING_RESOURCE_SCOPE = "LegendaryResourceMining-resource-scope"
M.RESOURCE_SCOPE_PLANET  = "planet"
M.RESOURCE_SCOPE_ALL     = "all"

M.BIG_MINING_DRILL = "big-mining-drill"
M.LEGENDARY_QUALITY = "legendary"

M.HIDDEN_RESOURCE_CATEGORY = "legendary-resource-mining-hidden"
M.HIDDEN_RESOURCE_PREFIX   = "legendary-resource-mining-hidden-"
M.PLACEMENT_ANCHOR         = "legendary-resource-mining-placement-anchor"

M.BASE_AMOUNT = 1000000
M.MAX_RESOURCE_AMOUNT = 4294967295

return M
