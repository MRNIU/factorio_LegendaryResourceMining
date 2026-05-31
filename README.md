# Legendary Resource Mining

Legendary Resource Mining extends the vanilla big mining drill instead of adding a replacement entity.

Legendary-quality big mining drills can use the normal mining-drill resource filter to select a finite hidden resource. The hidden resource uses the original resource's mining result and mining time, so drill speed, productivity, quality, modules, fluids, and resource drain continue to follow the vanilla mining drill rules.

By default, selectable resources are restricted to resources enabled for the current planet. A startup setting can instead allow all supported item resources, including resources that normally belong to another planet. Pure fluid resources are ignored.

The resource amount starts from 1,000,000 and is scaled by the surface map generation size and richness settings for the selected resource. Changing the filter or rebuilding the drill starts from a fresh amount.

If the mod is removed, placed drills remain vanilla `big-mining-drill` entities. The hidden resources and runtime behavior are removed with the mod.
