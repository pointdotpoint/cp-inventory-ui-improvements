// User settings, shown in Mod Settings (jackhumbert's mod_settings) when it is installed; the
// defaults below apply otherwise. Mod Settings writes the saved values into every new
// instance, so the wardrobe takes a fresh copy each time it opens (WardrobeTabsSettings()).
module EquipmentEx

public class WardrobeTabsSettings {
    @runtimeProperty("ModSettings.mod", "Wardrobe Tabs")
    @runtimeProperty("ModSettings.category", "Wardrobe")
    @runtimeProperty("ModSettings.category.order", "0")
    @runtimeProperty("ModSettings.displayName", "Preview items on hover")
    @runtimeProperty("ModSettings.description", "Resting the cursor on an item card puts it on V in the preview until the cursor moves off.")
    public let hoverTryOn: Bool = true;

    @runtimeProperty("ModSettings.mod", "Wardrobe Tabs")
    @runtimeProperty("ModSettings.category", "Wardrobe")
    @runtimeProperty("ModSettings.category.order", "0")
    @runtimeProperty("ModSettings.displayName", "Move camera to the selected area")
    @runtimeProperty("ModSettings.description", "Picking HEAD, BODY, ARMS, LEGS or FEET frames that part of V; OUTFITS shows the whole body.")
    public let areaCamera: Bool = true;
}
