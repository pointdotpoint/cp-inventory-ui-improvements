// User settings, shown in Mod Settings (jackhumbert's mod_settings) when it is installed; the
// defaults below apply otherwise. Mod Settings writes the saved values into every new
// instance, so the wardrobe takes a fresh copy each time it opens (WardrobeTabsSettings()).
// The annotations hold text keys (localization/en-us.yaml); Mod Settings looks them up.
module EquipmentEx

public class WardrobeTabsSettings {
    @runtimeProperty("ModSettings.mod", "WUI-Settings-Mod")
    @runtimeProperty("ModSettings.category", "WUI-Settings-Category")
    @runtimeProperty("ModSettings.category.order", "0")
    @runtimeProperty("ModSettings.displayName", "WUI-Settings-HoverTryOn")
    @runtimeProperty("ModSettings.description", "WUI-Settings-HoverTryOn-Desc")
    public let hoverTryOn: Bool = true;

    @runtimeProperty("ModSettings.mod", "WUI-Settings-Mod")
    @runtimeProperty("ModSettings.category", "WUI-Settings-Category")
    @runtimeProperty("ModSettings.category.order", "0")
    @runtimeProperty("ModSettings.displayName", "WUI-Settings-AreaCamera")
    @runtimeProperty("ModSettings.description", "WUI-Settings-AreaCamera-Desc")
    public let areaCamera: Bool = true;
}
