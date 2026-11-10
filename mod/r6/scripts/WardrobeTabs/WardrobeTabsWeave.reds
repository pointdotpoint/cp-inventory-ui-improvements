module EquipmentEx

// WEAVE (Nexus 28273) replaces Equipment-EX's EquipmentEx.reds with a fork that opens much
// faster with thousands of items: it sorts by a cached key and builds each item's
// UIInventoryItem (InventoryGridItemData.Item) only when its card is first shown
// (EnsureUIItem), keeping the ID and name in m_cachedItemID / m_cachedItemName. So with WEAVE
// Item is null on every card not yet shown, and the mod reads items through these helpers.
// Each has a WEAVE and a plain Equipment-EX version, picked when the scripts compile.

@if(ModuleExists("WEAVE"))
public func WardrobeTabsItemID(item: ref<InventoryGridItemData>) -> ItemID {
    if IsDefined(item.Item) {
        return item.Item.GetID();
    }
    return item.m_cachedItemID;
}

@if(!ModuleExists("WEAVE"))
public func WardrobeTabsItemID(item: ref<InventoryGridItemData>) -> ItemID {
    if IsDefined(item.Item) {
        return item.Item.GetID();
    }
    let none: ItemID;
    return none;
}

// The item's name before CleanName, as plain Equipment-EX gives it: the built item's name, or
// for an item not built yet WEAVE's cached name. That cache is blank for names that never
// resolve (some mods' items), where the card shows "LocKey#...", so those take the record's
// key the same way.
@if(ModuleExists("WEAVE"))
public func WardrobeTabsRawName(item: ref<InventoryGridItemData>) -> String {
    if IsDefined(item.Item) {
        return GetLocalizedText(item.Item.GetName());
    }
    if StrLen(StrReplaceAll(item.m_cachedItemName, " ", "")) > 0 {
        return item.m_cachedItemName;
    }
    let record: ref<Item_Record> = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(item.m_cachedItemID));
    if !IsDefined(record) {
        return "";
    }
    return GetLocalizedText(LocKeyToString(record.DisplayName()));
}

@if(!ModuleExists("WEAVE"))
public func WardrobeTabsRawName(item: ref<InventoryGridItemData>) -> String {
    if !IsDefined(item.Item) {
        return "";
    }
    return GetLocalizedText(item.Item.GetName());
}

public func WardrobeTabsItemEquipped(outfits: ref<OutfitSystem>, item: ref<InventoryGridItemData>) -> Bool {
    if IsDefined(item.Item) {
        return item.Item.IsEquipped();
    }
    return outfits.IsEquipped(WardrobeTabsItemID(item));
}

// Builds the item now: worn items need their icon for the body column.
@if(ModuleExists("WEAVE"))
public func WardrobeTabsEnsureBuilt(item: ref<InventoryGridItemData>) -> Void {
    if !IsDefined(item.Item) {
        item.EnsureUIItem();
    }
}

@if(!ModuleExists("WEAVE"))
public func WardrobeTabsEnsureBuilt(item: ref<InventoryGridItemData>) -> Void {}

// An item the mod built itself (a worn item missing from the list) gets the fields WEAVE's
// filters and card controller read, and is marked built so WEAVE leaves its Item alone.
@if(ModuleExists("WEAVE"))
public func WardrobeTabsMarkBuilt(item: ref<InventoryGridItemData>, data: InventoryItemData, slotID: TweakDBID, player: ref<GameObject>, name: String) -> Void {
    item.m_rawItemData = data;
    item.m_hasRawData = true;
    item.m_slotIDForMake = slotID;
    item.m_playerRef = player;
    item.m_isBuilt = true;
    item.m_isEquipped = true;
    item.m_cachedItemID = data.ID;
    item.m_cachedItemName = name;
    item.SortKey = TDBID.ToStringDEBUG(ItemID.GetTDBID(data.ID));
    item.IsVisible = true;
}

@if(!ModuleExists("WEAVE"))
public func WardrobeTabsMarkBuilt(item: ref<InventoryGridItemData>, data: InventoryItemData, slotID: TweakDBID, player: ref<GameObject>, name: String) -> Void {}

// WEAVE's copy of the worn item shown first in its slot (its showEquippedItemsAtFront
// setting, inserted at index 0): the mod marks the worn item itself, so the copy is dropped.
@if(ModuleExists("WEAVE"))
public func WardrobeTabsDropDisplayCopies(slot: ref<InventoryGridSlotData>) -> Void {
    while ArraySize(slot.Children) > 0 && slot.Children[0].m_isEquippedDisplayCopy {
        ArrayErase(slot.Children, 0);
    }
}

@if(!ModuleExists("WEAVE"))
public func WardrobeTabsDropDisplayCopies(slot: ref<InventoryGridSlotData>) -> Void {}

// WEAVE's InventoryGridDataView.UpdateView skips its filter pass unless one of its own
// filters changed, so after the mod refills the grid the new items would keep stale
// visibility. Marking it dirty forces the pass, as Equipment-EX's UpdateView always runs it.
@if(ModuleExists("WEAVE"))
public func WardrobeTabsForceFilterPass(view: ref<InventoryGridDataView>) -> Void {
    view.InvalidateEquippedState();
}

@if(!ModuleExists("WEAVE"))
public func WardrobeTabsForceFilterPass(view: ref<InventoryGridDataView>) -> Void {}

// Whether the worn items are outfit `name` (n"" = no outfit active), decided as Equipment-EX's
// OutfitSystem.IsEquipped(name) does: by the items' hash. WEAVE's IsEquipped(name) compares
// with the outfit last loaded by name instead, which a save or UPDATE does not set, so after
// UPDATE the bar showed the look as edited; the hash works with both.
public func WardrobeTabsOutfitWorn(system: ref<OutfitSystem>, name: CName) -> Bool {
    return system.m_state.IsActive() ? system.m_state.IsOutfit(name) : Equals(name, n"");
}
