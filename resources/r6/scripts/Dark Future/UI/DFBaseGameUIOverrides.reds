// -----------------------------------------------------------------------------
// DFBaseGameUIOverrides
// -----------------------------------------------------------------------------
//
// - A set of general UI-related base game method overrides.
//

import DarkFutureCore.Settings.{
	DFSettings,
	DFAmmoWeightSetting
}
import DarkFutureCore.System.*
import DarkFutureCore.Logging.*
import DarkFutureCore.UI.DFHUDSystem
import DarkFutureCore.DelayHelper.*
import DarkFutureCore.Services.{
	DFNotificationService,
	DFProgressionViewData
}
import DarkFutureCore.Utils.{
	GetDarkFutureHDRColor,
	DFHDRColor,
	IsCoinFlipSuccessful
}

// ===================================================
//  INVENTORY ITEMS
// ===================================================

//  UIInventoryItemsManager - Allow ammo to be seen in the inventory.
//
@wrapMethod(UIInventoryItemsManager)
public final static func GetBlacklistedTags() -> array<CName> {
	let filteredTags: array<CName> = wrappedMethod();
	let settings: ref<DFSettings> = DFSettings.Get();

	if Equals(settings.ammoWeightEnabledV2, DFAmmoWeightSetting.EnabledLimitedAmmo) || Equals(settings.ammoWeightEnabledV2, DFAmmoWeightSetting.EnabledUnlimitedAmmo) {
		if ArrayContains(filteredTags, n"Ammo") {
			ArrayRemove(filteredTags, n"Ammo");
		};
	}

	return filteredTags;
}

//  UIInventoryItemsManager - Prevent the storage of consumables in stash.
//
@wrapMethod(UIInventoryItemsManager)
public final static func GetStashBlacklistedTags() -> array<CName> {
	let settings: ref<DFSettings> = DFSettings.Get();
	let tagList: array<CName> = wrappedMethod();
	if settings.mainSystemEnabled && settings.noConsumablesInStash {
		ArrayPush(tagList, n"Consumable");
	}
	return tagList;
}

// ItemTooltipBottomModule - Show the price on ammo.
//
@wrapMethod(ItemTooltipBottomModule)
public final static func ShouldDisplayPrice(displayContext: InventoryTooltipDisplayContext, isSellable: Bool, itemData: ref<gameItemData>, itemType: gamedataItemType, opt lootItemType: LootItemType) -> Bool {
	let settings: ref<DFSettings> = DFSettings.Get();
	if NotEquals(displayContext, InventoryTooltipDisplayContext.Vendor) && (Equals(settings.ammoWeightEnabledV2, DFAmmoWeightSetting.EnabledLimitedAmmo) || Equals(settings.ammoWeightEnabledV2, DFAmmoWeightSetting.EnabledUnlimitedAmmo)) && Equals(itemType, gamedataItemType.Con_Ammo) {
		return true;
	} else {
		return wrappedMethod(displayContext, isSellable, itemData, itemType, lootItemType);
	}
}

// ItemTooltipBottomModule - Update the weight precision for consumables.
//
@addMethod(ItemTooltipBottomModule)
public final func TryToShowNewItemWeights(itemData: wref<gameItemData>) -> Void {
	let isConsumable: Bool = itemData.HasTag(n"Consumable");
	let isAmmo: Bool = itemData.HasTag(n"Ammo");

	if isConsumable {
		let itemWeight: Float = RPGManager.GetItemWeight(itemData);
		inkTextRef.SetText(this.m_weightText, s"\(FloatToStringPrec(itemWeight, 1))");
	} else if isAmmo {
		let itemWeight: Float = RPGManager.GetItemWeight(itemData);
		inkTextRef.SetText(this.m_weightText, s"\(FloatToStringPrec(itemWeight, 2))");
	}
}

// ItemTooltipBottomModule - Update the weight precision for consumables.
//
@wrapMethod(ItemTooltipBottomModule)
public final func NEW_Update(data: wref<UIInventoryItem>, player: wref<PlayerPuppet>, m_overridePrice: Int32) -> Void {
	wrappedMethod(data, player, m_overridePrice);
	if DFSettings.Get().mainSystemEnabled {
		this.TryToShowNewItemWeights(data.GetItemData());
	}
}

// ItemQuantityPickerController - Update the weight precision of consumables and ammo when dropping.
//
@replaceMethod(ItemQuantityPickerController)
protected final func UpdateWeight() -> Void {
	let itemData: ref<gameItemData>;
	if IsDefined(this.m_inventoryItem) {
		itemData = this.m_inventoryItem.GetItemData();
	} else {
		itemData = InventoryItemData.GetGameItemData(this.m_gameData);
	}
	
	let weight: Float = RPGManager.GetItemWeight(itemData) * Cast<Float>(this.m_choosenQuantity);
	let isConsumable: Bool = itemData.HasTag(n"Consumable");
	let isAmmo: Bool = itemData.HasTag(n"Ammo");

	if isConsumable {
		inkTextRef.SetText(this.m_weightText, FloatToStringPrec(weight, 1));
	} else if isAmmo {
		inkTextRef.SetText(this.m_weightText, FloatToStringPrec(weight, 2));
	} else {
		inkTextRef.SetText(this.m_weightText, FloatToStringPrec(weight, 0));
	}
}

// ItemCategoryFliter
//		Remove Healing Items from Consumables.
//		Cluster all Charged Consumables under the same category.
//		Locate Ammo under Ranged Weapons.
//
@wrapMethod(ItemCategoryFliter)
public final static func IsOfCategoryType(filter: ItemFilterCategory, data: wref<gameItemData>) -> Bool {
	let settings: ref<DFSettings> = DFSettings.Get();
	if IsDefined(data) && settings.mainSystemEnabled && settings.newInventoryFilters {
		if Equals(filter, ItemFilterCategory.Consumables) {
			return data.HasTag(n"Consumable") && !data.HasTag(n"ChargedConsumable");
		} else if Equals(filter, ItemFilterCategory.Grenades) {
			return data.HasTag(n"ChargedConsumable");
		} else if Equals(filter, ItemFilterCategory.RangedWeapons) && (Equals(settings.ammoWeightEnabledV2, DFAmmoWeightSetting.EnabledLimitedAmmo) || Equals(settings.ammoWeightEnabledV2, DFAmmoWeightSetting.EnabledUnlimitedAmmo)) {
			return data.HasTag(n"RangedWeapon") || data.HasTag(n"Ammo");
		}
	}
	return wrappedMethod(filter, data);
}

//	CraftingDataView
//		Remove Healing Items from Consumables.
//		Cluster all Charged Consumables under the same category.
//		Locate Ammo under Ranged Weapons.
//
@wrapMethod(CraftingDataView)
public func FilterItem(item: ref<IScriptable>) -> Bool {
	let settings: ref<DFSettings> = DFSettings.Get();
	if settings.mainSystemEnabled && settings.newInventoryFilters {
		let itemRecord: ref<Item_Record>;
		let itemData: ref<ItemCraftingData> = item as ItemCraftingData;
		let recipeData: ref<RecipeData> = item as RecipeData;

		if IsDefined(itemData) {
			itemRecord = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(InventoryItemData.GetID(itemData.inventoryItem)));
		} else {
			if IsDefined(recipeData) {
				itemRecord = recipeData.id;
			};
		};

		if Equals(this.m_itemFilterType, ItemFilterCategory.Consumables) {
			return itemRecord.TagsContains(n"Consumable") && !itemRecord.TagsContains(n"ChargedConsumable");
		} else if Equals(this.m_itemFilterType, ItemFilterCategory.Grenades) {
			return itemRecord.TagsContains(n"ChargedConsumable");
		} else if Equals(this.m_itemFilterType, ItemFilterCategory.RangedWeapons) && (Equals(settings.ammoWeightEnabledV2, DFAmmoWeightSetting.EnabledLimitedAmmo) || Equals(settings.ammoWeightEnabledV2, DFAmmoWeightSetting.EnabledUnlimitedAmmo)) {
			return itemRecord.TagsContains(n"RangedWeapon") || itemRecord.TagsContains(n"Ammo");
		}
	}

	return wrappedMethod(item);
}

// 	ItemFilterCategories - Set new Filter Category tooltips.
//		Note: the CName values for these new fields MUST start with UI-Filter-* in order to resolve correctly.
//
@wrapMethod(ItemFilterCategories)
public final static func GetLabelKey(filterType: ItemFilterCategory) -> CName {
	let settings: ref<DFSettings> = DFSettings.Get();
	if settings.mainSystemEnabled {
		if settings.newInventoryFilters && Equals(filterType, ItemFilterCategory.Grenades) {
			return n"UI-Filter-DarkFutureChargedConsumables";
		}

		if Equals(settings.ammoWeightEnabledV2, DFAmmoWeightSetting.EnabledLimitedAmmo) || Equals(settings.ammoWeightEnabledV2, DFAmmoWeightSetting.EnabledUnlimitedAmmo) {
			if Equals(filterType, ItemFilterCategory.RangedWeapons) {
				return n"UI-Filter-DarkFutureRangedWeaponsAmmo";
			}
		}
	}

	return wrappedMethod(filterType);
}

// ===================================================
// STATUS EFFECTS
// ===================================================

// buffListGameController - Selectively hide certain status icons based on settings.
//
/*
@wrapMethod(buffListGameController)
protected cb func OnBuffDataChanged(value: Variant) -> Bool {
	let filteredBuffDataList: array<BuffInfo> = this.GetFilteredBuffList(value);
    wrappedMethod(filteredBuffDataList);
}

// buffListGameController - Selectively hide certain status icons based on settings.
//
@wrapMethod(buffListGameController)
protected cb func OnDeBuffDataChanged(value: Variant) -> Bool {
	let filteredBuffDataList: array<BuffInfo> = this.GetFilteredBuffList(value);
    wrappedMethod(filteredBuffDataList);
}

// buffListGameController - Selectively hide certain status icons based on settings.
//
@addMethod(buffListGameController)
private final func GetFilteredBuffList(value: Variant) -> array<BuffInfo> {
	let hideDFPersistentStatusIcons: Bool = DFSettings.Get().hidePersistentStatusIcons;
	let buffDataList: array<BuffInfo> = FromVariant<array<BuffInfo>>(value);
	let filteredBuffDataList: array<BuffInfo>;
	
	for buff in buffDataList {
		let buffTags: array<CName> = TweakDBInterface.GetStatusEffectRecord(buff.buffID).GameplayTags();
		
		if hideDFPersistentStatusIcons && ArrayContains(buffTags, n"DarkFutureCanHideOnBuffBar") {
			// Filter out buffs that should be hidden on the buff bar regardless based on Dark Future settings.
		} else {
			ArrayPush(filteredBuffDataList, buff);
		}
	}

	return filteredBuffDataList;
}
*/


// buffListGameController - Avoid playing animations.
//
@replaceMethod(buffListGameController)
private final func UpdateBuffDebuffList() -> Void {
    let buffList: array<BuffInfo>;
    let buffTimeRemaining: Float;
    let buffTimeTotal: Float;
    let currBuffLoc: wref<buffListItemLogicController>;
    let currBuffWidget: wref<inkWidget>;
    let data: ref<StatusEffect_Record>;
    let incomingBuffsCount: Int32;
    let onScreenBuffsCount: Int32;
    let visibleIncomingBuffsCount: Int32;
    let i: Int32 = 0;
    while i < ArraySize(this.m_buffDataList) {
      ArrayPush(buffList, this.m_buffDataList[i]);
      i = i + 1;
    };
    i = 0;
    while i < ArraySize(this.m_debuffDataList) {
      ArrayPush(buffList, this.m_debuffDataList[i]);
      i = i + 1;
    };
    incomingBuffsCount = ArraySize(buffList);
    onScreenBuffsCount = inkCompoundRef.GetNumChildren(this.m_buffsList);
    i = 0;
    while i < onScreenBuffsCount {
      currBuffWidget = this.m_buffWidgets[i];
      currBuffLoc = currBuffWidget.GetController() as buffListItemLogicController;
      if i >= incomingBuffsCount {
        currBuffWidget.SetVisible(false);
        currBuffLoc.SetStatusEffectRecord(null);
      } else {
        data = TweakDBInterface.GetStatusEffectRecord(buffList[i].buffID);
        buffTimeRemaining = buffList[i].timeRemaining;
        buffTimeTotal = buffList[i].timeTotal;

        if !IsDefined(data) || !IsDefined(data.UiData()) || Equals(data.UiData().IconPath(), "") {
          currBuffWidget.SetVisible(false);
          currBuffLoc.SetStatusEffectRecord(null);
        } else {
          if data != currBuffLoc.GetStatusEffectRecord() {
            currBuffLoc.SetStatusEffectRecord(data);
			
			// Edit Start
			// Don't play the intro animation.
            // currBuffLoc.PlayLibraryAnimation(n"intro");
			// Edit End
          };
          currBuffLoc.SetData(StringToName(data.UiData().IconPath()), buffTimeRemaining, buffTimeTotal, Cast<Int32>(buffList[i].stackCount));
          currBuffWidget.SetVisible(true);
		  visibleIncomingBuffsCount += 1;
        };
      };
      i = i + 1;
    };
    this.SendVisibilityUpdate(inkWidgetRef.IsVisible(this.m_buffsList), visibleIncomingBuffsCount > 0);
    inkWidgetRef.SetVisible(this.m_buffsList, visibleIncomingBuffsCount > 0);
}


// inkCooldownGameController - The Status Effect Cooldown system, by default, doesn't know how to handle displaying Status Effects that
// have an infinite duration.
//
@replaceMethod(inkCooldownGameController)
public final func RequestCooldownVisualization(buffData: UIBuffInfo) -> Void {
	let i: Int32;
	// Edit Start
	// -1.00 = Infinite Duration
	let tags: array<CName> = TweakDBInterface.GetStatusEffectRecord(buffData.buffID).GameplayTags();
    if buffData.timeRemaining <= 0.0 && !ArrayContains(tags, n"DarkFutureInfiniteDurationEffect") {
		return;
	// Edit End
    };
    i = 0;
    while i < this.m_maxCooldowns {
      if Equals(this.m_cooldownPool[i].GetState(), ECooldownIndicatorState.Pooled) {
        this.m_cooldownPool[i].ActivateCooldown(buffData);
        return;
      };
      i += 1;
    };
}

// ===================================================
// BUG FIXES
// ===================================================

// The Status Effect list could sometimes erroneously display incorrect stack counts
// on debuffs in the Status Effect / Quick Switch Wheel menu.
//
@replaceMethod(inkCooldownGameController)
protected cb func OnEffectUpdate(v: Variant) -> Bool {
    let buffs: array<BuffInfo>;
    let debuffs: array<BuffInfo>;
    let effect: UIBuffInfo;
    let effects: array<UIBuffInfo>;
    let i: Int32;
    if !this.GetRootWidget().IsVisible() {
      return false;
    };
    if Equals(this.m_mode, ECooldownGameControllerMode.COOLDOWNS) {
      this.GetBuffs(buffs);
      i = 0;
      while i < ArraySize(buffs) {
        if Equals(TweakDBInterface.GetStatusEffectRecord(buffs[i].buffID).StatusEffectType().Type(), gamedataStatusEffectType.PlayerCooldown) {
          effect.buffID = buffs[i].buffID;
          effect.timeRemaining = buffs[i].timeRemaining;
          effect.isBuff = true;
          ArrayPush(effects, effect);
        };
        i += 1;
      };
    } else {
      this.GetBuffs(buffs);
      this.GetDebuffs(debuffs);
      i = 0;
      while i < ArraySize(buffs) {
        effect.buffID = buffs[i].buffID;
        effect.timeRemaining = buffs[i].timeRemaining;
        effect.stackCount = buffs[i].stackCount;
        effect.isBuff = true;
        ArrayPush(effects, effect);
        i += 1;
      };
      i = 0;
      while i < ArraySize(debuffs) {
        effect.buffID = debuffs[i].buffID;
        effect.timeRemaining = debuffs[i].timeRemaining;
		// Edit Start
		// Incorrectly references buffs[i].stackCount in base game.
        effect.stackCount = debuffs[i].stackCount;
		// Edit End
        effect.isBuff = false;
        ArrayPush(effects, effect);
        i += 1;
      };
    };
    if ArraySize(effects) > 0 {
      inkWidgetRef.SetVisible(this.m_cooldownTitle, true);
      inkWidgetRef.SetVisible(this.m_cooldownContainer, true);
      this.ParseBuffList(effects);
    };
    if ArraySize(effects) == 0 {
      inkWidgetRef.SetVisible(this.m_cooldownTitle, false);
      inkWidgetRef.SetVisible(this.m_cooldownContainer, false);
    };
}

// SingleCooldownManager - Cache the gameplay tags, for efficiency. Fix the vertical alignment of the stack count in
// cases where the duration of the Status Effect is infinite.
//
@addField(SingleCooldownManager)
private let m_gameplayTags: array<CName>;

@wrapMethod(SingleCooldownManager)
public final func ActivateCooldown(buffData: UIBuffInfo) -> Void {
	wrappedMethod(buffData);

	// Cache the gameplay tags, for efficiency.
	this.m_gameplayTags = TweakDBInterface.GetStatusEffectRecord(buffData.buffID).GameplayTags();

	// Bug Fix: Vertically align the Icon Canvas to Top to avoid stack count from displaying outside the bounds
	// of the status icon in the Radial Menu when the Status Effect has an infinite duration.
	let statusEffectIconCanvas: ref<inkCanvas> = inkWidgetRef.Get(this.m_stackCount).GetParentWidget() as inkCanvas;
	if IsDefined(statusEffectIconCanvas) {
		statusEffectIconCanvas.SetVAlign(inkEVerticalAlign.Top);
	}
}

// SingleCooldownManager - Don't display duration text on effects with an infinite duration.
//
@wrapMethod(SingleCooldownManager)
private final func SetTimeRemaining(time: Float) -> Void {
	if time == -1.0 {
		// Don't display duration text on effects with an infinite duration.
		inkTextRef.SetText(this.m_timeRemaining, "");
		inkWidgetRef.Get(this.m_sprite).SetEffectParamValue(inkEffectType.LinearWipe, n"LinearWipe_0", n"transition", AbsF(1.0));
	} else {
		wrappedMethod(time);
	}
}

// SingleCooldownManager - Set the timeLeft fraction to 1, so that the icon is always displayed "full".
//
@replaceMethod(SingleCooldownManager)
public final func Update(timeLeft: Float, stackCount: Uint32) -> Void {
	let fraction: Float;
    let updatedSize: Float;
	// Edit Start
	if timeLeft <= 0.01 && !ArrayContains(this.m_gameplayTags, n"DarkFutureInfiniteDurationEffect") {
	// Edit End
      updatedSize = 0.00;
      this.GetRootWidget().SetVisible(false);
    } else {
      this.GetRootWidget().SetVisible(true);
	  // Edit Start
	  if timeLeft == -1.00 {
		// Set the timeLeft fraction to 1, so that the icon is always displayed "full".
		fraction = 1.00;
	  } else {
		fraction = timeLeft / this.m_initialDuration;
	  }
	  // Edit End
      updatedSize = fraction;
    };
    inkWidgetRef.Get(this.m_sprite).SetEffectParamValue(inkEffectType.LinearWipe, n"LinearWipe_0", n"transition", AbsF(updatedSize));
    this.SetTimeRemaining(timeLeft);
    this.SetStackCount(Cast<Int32>(stackCount));
    if timeLeft <= this.m_outroDuration {
      this.FillOutroAnimationStart();
    };
}

// ===================================================
// MAIN MENU
// ===================================================

// SingleplayerMenuGameController - Display an invalid language settings warning if the audio
// and subtitle languages do not match.
//
@wrapMethod(SingleplayerMenuGameController)
protected cb func OnInitialize() -> Bool {
	let r = wrappedMethod();

	let srh: wref<inkISystemRequestsHandler> = this.GetSystemRequestsHandler();

	if IsDefined(srh) {
		// Invalid Language Check
		let langGroup: ref<ConfigGroup> = srh.GetUserSettings().GetGroup(n"/language");
		let subtitleVar: ref<ConfigVarListName> = langGroup.GetVar(n"Subtitles") as ConfigVarListName;
		let onscreenVar: ref<ConfigVarListName> = langGroup.GetVar(n"OnScreen") as ConfigVarListName;

		let subtitleValue = subtitleVar.GetValue();
		let onscreenValue = onscreenVar.GetValue();

		if NotEquals(subtitleValue, onscreenValue) {
			srh.RequestSystemNotificationGeneric(n"DarkFutureWarningInvalidLanguageSettingTitle", n"DarkFutureWarningInvalidLanguageSetting");
		}
	}
	
	return r;
}
