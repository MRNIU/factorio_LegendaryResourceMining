# AGENTS.md

本 Mod 名称：`LegendaryResourceMining`

## 定位

`LegendaryResourceMining` 扩展原版 `big-mining-drill`，只让传奇品质的大型采矿机获得“无可见矿点、手动选择资源”的能力。它不创建替代矿机物品或实体，因此移除 Mod 后，已经放置的矿机会尽量保留为原版实体。

## 架构

- `settings.lua`：启动设置，决定资源选择范围。
- `data.lua`：data 阶段创建隐藏资源分类和隐藏资源副本，并给原版 `big-mining-drill` 增加资源筛选槽。
- `control.lua`：control 阶段跟踪传奇大矿机，把玩家选择的原版资源筛选器映射到隐藏资源副本。
- `constants.lua`：跨阶段常量。

## 关键设计

- 只处理品质为 `legendary` 的 `big-mining-drill`。
- 玩家仍然使用游戏原生矿机筛选器，不做自定义 GUI。
- 隐藏资源副本复制原资源的 `minable` 数据，保证矿物产物、开采时间和所需流体跟原版一致。
- 储量有限，以 `1,000,000 * size * richness` 计算。切换筛选器或拆掉重建时重新计算。
- 纯流体资源不生成隐藏副本。

## 验证重点

Codex 在 WSL 里不能启动 Factorio，所以涉及运行时 API 的行为必须进游戏手工验证：

1. 传奇大矿机能否在没有可见资源的地面放置。
2. 放置后用原生筛选器选择资源是否会开始采矿。
3. 非传奇大矿机是否保持原版行为。
4. 当前星球限制和“允许所有资源”启动设置是否符合预期。
