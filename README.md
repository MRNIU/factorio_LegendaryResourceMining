# Legendary Resource Mining

Legendary Resource Mining extends the vanilla big mining drill instead of adding a replacement entity.

Legendary-quality big mining drills can be placed on empty ground and use the normal mining-drill resource filter to select a finite hidden resource. The hidden resource uses the original resource's mining result and mining time, so drill speed, productivity, quality, modules, fluids, and resource drain continue to follow the vanilla mining drill rules.

By default, accepted resources are restricted to resources enabled for the current planet. A startup setting can instead allow all supported item resources, including resources that normally belong to another planet. Pure fluid resources are ignored.

The vanilla mining drill filter UI is global, so resources outside the current planet may still appear in the picker. When the setting is left at the default planet-scoped mode, invalid selections are cleared instead of mined.

The resource amount starts from 1,000,000 and is scaled by the surface map generation size and richness settings for the selected resource. Changing the filter or rebuilding the drill starts from a fresh amount.

If the mod is removed, placed drills remain vanilla `big-mining-drill` entities. The temporary hidden resources and runtime behavior are removed with the mod.
