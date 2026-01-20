// -----------------------------------------------------------------------------
// DFSettings
// -----------------------------------------------------------------------------
//
// - Mod Settings configuration.
//

module DarkFutureCore.Settings

import DarkFutureCore.Logging.*
import DarkFutureCore.Utils.DFBarColorThemeName
import DarkFutureCore.Gameplay.{
	EnhancedVehicleSystemCompatPowerBehaviorDriver,
	EnhancedVehicleSystemCompatPowerBehaviorPassenger
}

public enum DFReducedCarryWeightAmount {
	Full = 0,
	Half = 1,
	Off = 2
}

public enum DFAmmoWeightSetting {
	Disabled = 0,
	EnabledLimitedAmmo = 1,
	EnabledUnlimitedAmmo = 2
}

public enum DFSleepQualitySetting {
	Limited = 0,
	Full = 1
}

public enum DFFastTravelSetting {
	Disabled = 0,
	DisabledAllowMetro = 1,
	Enabled = 2
}

public enum DFAmmoHandicapSetting {
	DontModify = 0,
	Disabled = 1,
	Enabled = 2
}

public enum DFEconomicSetting {
	DontModify = 0,
	Modify = 1
}

public enum DFConsumableAnimationCooldownBehavior {
	Off = 0,
	ByExactVisualProp = 1,
	ByGeneralVisualProp = 2,
	ByVisualPropType = 3,
	ByAnimationType = 4,
	All = 5
}

//	ModSettings - Register if Mod Settings installed
//
@if(ModuleExists("ModSettingsModule")) 
public func RegisterDFSettingsListener(listener: ref<IScriptable>) {
	//DFProfile();
	ModSettings.RegisterListenerToClass(listener);
  	ModSettings.RegisterListenerToModifications(listener);
}

@if(ModuleExists("ModSettingsModule")) 
public func UnregisterDFSettingsListener(listener: ref<IScriptable>) {
	//DFProfile();
	ModSettings.UnregisterListenerToClass(listener);
  	ModSettings.UnregisterListenerToModifications(listener);
}

//	ModSettings - No-op if Mod Settings not installed
//
@if(!ModuleExists("ModSettingsModule")) 
public func RegisterDFSettingsListener(listener: ref<IScriptable>) {
	//DFProfile();
	//FTLog("WARN: Mod Settings was not installed, or not installed correctly; listener registration aborted.");
}
@if(!ModuleExists("ModSettingsModule")) 
public func UnregisterDFSettingsListener(listener: ref<IScriptable>) {
	//DFProfile();
	//FTLog("WARN: Mod Settings was not installed, or not installed correctly; listener unregistration aborted.");
}

public class SettingChangedEvent extends CallbackSystemEvent {
	let changedSettings: array<String>;

	public final func GetData() -> array<String> {
		//DFProfile();
		return this.changedSettings;
	}

    public static func Create(data: array<String>) -> ref<SettingChangedEvent> {
		//DFProfile();
		let self: ref<SettingChangedEvent> = new SettingChangedEvent();
		self.changedSettings = data;
        return self;
    }
}

//
//	Dark Future Settings
//
public class DFSettings extends ScriptableSystem {
	private let debugEnabled: Bool = false;

	public func OnAttach() {
		//DFProfile();
		GameInstance.GetCallbackSystem().RegisterCallback(n"Session/Start", this, n"OnSessionStart");
	}

	public final func OnSessionStart(evt: ref<GameSessionEvent>) {
		//DFProfile();
		DFLogNoSystem(this.debugEnabled, this, "OnSessionStart - Injecting TweakDB updates.");

		// Basic Needs
		//
		TweakDBManager.SetFlat(t"DarkFutureStatusEffect.Hydrated_UIData.intValues", [Cast<Int32>(this.basicNeedThresholdValue1), 5]);
		TweakDBManager.UpdateRecord(t"DarkFutureStatusEffect.Hydrated_UIData");

		TweakDBManager.SetFlat(t"DarkFutureStatusEffect.Nourishment_UIData.intValues", [Cast<Int32>(this.basicNeedThresholdValue1), 5]);
		TweakDBManager.UpdateRecord(t"DarkFutureStatusEffect.Nourishment_UIData");

		
		// Ammo Changes
		//
		if Equals(this.ammoWeightEnabledV2, DFAmmoWeightSetting.EnabledLimitedAmmo) || Equals(this.ammoWeightEnabledV2, DFAmmoWeightSetting.EnabledUnlimitedAmmo) {
			// Weight
			//
			TweakDBManager.SetFlat(t"DarkFutureWeight.AmmoHandgun.value", this.weightHandgunAmmo);
			TweakDBManager.SetFlat(t"DarkFutureWeight.AmmoRifle.value", this.weightRifleAmmo);
			TweakDBManager.SetFlat(t"DarkFutureWeight.AmmoShotgun.value", this.weightShotgunAmmo);
			TweakDBManager.SetFlat(t"DarkFutureWeight.AmmoSniper.value", this.weightSniperAmmo);

			TweakDBManager.UpdateRecord(t"DarkFutureWeight.AmmoHandgun");
			TweakDBManager.UpdateRecord(t"DarkFutureWeight.AmmoRifle");
			TweakDBManager.UpdateRecord(t"DarkFutureWeight.AmmoShotgun");
			TweakDBManager.UpdateRecord(t"DarkFutureWeight.AmmoSniper");
		}

		if Equals(this.ammoWeightEnabledV2, DFAmmoWeightSetting.EnabledUnlimitedAmmo) {
			// Quantity
			//
			TweakDBManager.SetFlat(t"DarkFutureItem.AmmoHandgunQuantityOverride.value", 99999001.0); // +999
			TweakDBManager.SetFlat(t"DarkFutureItem.AmmoRifleQuantityOverride.value", 99999001.0);	 // +999
			TweakDBManager.SetFlat(t"DarkFutureItem.AmmoShotgunQuantityOverride.value", 99999800.0); // +200
			TweakDBManager.SetFlat(t"DarkFutureItem.AmmoSniperQuantityOverride.value", 99999825.0);  // +175
			
			TweakDBManager.UpdateRecord(t"DarkFutureItem.AmmoHandgunQuantityOverride");
			TweakDBManager.UpdateRecord(t"DarkFutureItem.AmmoRifleQuantityOverride");
			TweakDBManager.UpdateRecord(t"DarkFutureItem.AmmoShotgunQuantityOverride");
			TweakDBManager.UpdateRecord(t"DarkFutureItem.AmmoSniperQuantityOverride");
		}

		// Ammo - Handicap Drops
		//
		if Equals(this.ammoHandicapDrops, DFAmmoHandicapSetting.Enabled) {
			TweakDBManager.SetFlat(t"Ammo.HandicapHandgunAmmoPreset.handicapLimit", 120);
			TweakDBManager.SetFlat(t"Ammo.HandicapHandgunAmmoPreset.handicapMaxQty", 150);
  			TweakDBManager.SetFlat(t"Ammo.HandicapHandgunAmmoPreset.handicapMinQty", 90);

			TweakDBManager.SetFlat(t"Ammo.HandicapRifleAmmoPreset.handicapLimit", 120);
			TweakDBManager.SetFlat(t"Ammo.HandicapRifleAmmoPreset.handicapMaxQty", 150);
  			TweakDBManager.SetFlat(t"Ammo.HandicapRifleAmmoPreset.handicapMinQty", 90);

			TweakDBManager.SetFlat(t"Ammo.HandicapShotgunAmmoPreset.handicapLimit", 50);
			TweakDBManager.SetFlat(t"Ammo.HandicapShotgunAmmoPreset.handicapMaxQty", 125);
			TweakDBManager.SetFlat(t"Ammo.HandicapShotgunAmmoPreset.handicapMinQty", 75);

			TweakDBManager.SetFlat(t"Ammo.HandicapSniperRifleAmmoPreset.handicapLimit", 40);
			TweakDBManager.SetFlat(t"Ammo.HandicapSniperRifleAmmoPreset.handicapMaxQty", 80);
			TweakDBManager.SetFlat(t"Ammo.HandicapSniperRifleAmmoPreset.handicapMinQty", 40);

			TweakDBManager.UpdateRecord(t"Ammo.HandicapHandgunAmmoPreset");
			TweakDBManager.UpdateRecord(t"Ammo.HandicapRifleAmmoPreset");
			TweakDBManager.UpdateRecord(t"Ammo.HandicapShotgunAmmoPreset");
			TweakDBManager.UpdateRecord(t"Ammo.HandicapSniperRifleAmmoPreset");
			
		} else if Equals(this.ammoHandicapDrops, DFAmmoHandicapSetting.Disabled) {
			TweakDBManager.SetFlat(t"Ammo.HandicapHandgunAmmoPreset.handicapLimit", 0);
			TweakDBManager.SetFlat(t"Ammo.HandicapHandgunAmmoPreset.handicapMaxQty", 0);
  			TweakDBManager.SetFlat(t"Ammo.HandicapHandgunAmmoPreset.handicapMinQty", 0);

			TweakDBManager.SetFlat(t"Ammo.HandicapRifleAmmoPreset.handicapLimit", 0);
			TweakDBManager.SetFlat(t"Ammo.HandicapRifleAmmoPreset.handicapMaxQty", 0);
  			TweakDBManager.SetFlat(t"Ammo.HandicapRifleAmmoPreset.handicapMinQty", 0);

			TweakDBManager.SetFlat(t"Ammo.HandicapShotgunAmmoPreset.handicapLimit", 0);
			TweakDBManager.SetFlat(t"Ammo.HandicapShotgunAmmoPreset.handicapMaxQty", 0);
			TweakDBManager.SetFlat(t"Ammo.HandicapShotgunAmmoPreset.handicapMinQty", 0);

			TweakDBManager.SetFlat(t"Ammo.HandicapSniperRifleAmmoPreset.handicapLimit", 0);
			TweakDBManager.SetFlat(t"Ammo.HandicapSniperRifleAmmoPreset.handicapMaxQty", 0);
			TweakDBManager.SetFlat(t"Ammo.HandicapSniperRifleAmmoPreset.handicapMinQty", 0);

			TweakDBManager.UpdateRecord(t"Ammo.HandicapHandgunAmmoPreset");
			TweakDBManager.UpdateRecord(t"Ammo.HandicapRifleAmmoPreset");
			TweakDBManager.UpdateRecord(t"Ammo.HandicapShotgunAmmoPreset");
			TweakDBManager.UpdateRecord(t"Ammo.HandicapSniperRifleAmmoPreset");
		}

		// Ammo - Price
		//
		if Equals(this.ammoPriceModify, DFEconomicSetting.Modify) {
			TweakDBManager.SetFlat(t"DarkFuturePrice.AmmoHandgunBuyMult.value", this.priceHandgunAmmo);
			TweakDBManager.SetFlat(t"DarkFuturePrice.AmmoRifleBuyMult.value", this.priceRifleAmmo);
			TweakDBManager.SetFlat(t"DarkFuturePrice.AmmoShotgunBuyMult.value", this.priceShotgunAmmo);
			TweakDBManager.SetFlat(t"DarkFuturePrice.AmmoSniperBuyMult.value", this.priceSniperAmmo);
			TweakDBManager.SetFlat(t"DarkFuturePrice.AmmoSellMult.value", this.priceAmmoSellMult);
			TweakDBManager.UpdateRecord(t"DarkFuturePrice.AmmoHandgunBuyMult");
			TweakDBManager.UpdateRecord(t"DarkFuturePrice.AmmoRifleBuyMult");
			TweakDBManager.UpdateRecord(t"DarkFuturePrice.AmmoShotgunBuyMult");
			TweakDBManager.UpdateRecord(t"DarkFuturePrice.AmmoSniperBuyMult");
			TweakDBManager.UpdateRecord(t"DarkFuturePrice.AmmoSellMult");
		}

		// Consumable Basic Needs
		//
		TweakDBManager.SetFlat(t"DarkFutureStatusEffect.ConsumableHydrationTier1_UIData.intValues", [Cast<Int32>(this.hydrationTier1)]);
		TweakDBManager.SetFlat(t"DarkFutureStatusEffect.ConsumableHydrationTier2_UIData.intValues", [Cast<Int32>(this.hydrationTier2)]);
		TweakDBManager.SetFlat(t"DarkFutureStatusEffect.ConsumableHydrationTier3_UIData.intValues", [Cast<Int32>(this.hydrationTier3)]);
		TweakDBManager.SetFlat(t"DarkFutureStatusEffect.ConsumableNutritionTier1_UIData.intValues", [Cast<Int32>(this.nutritionTier1)]);
		TweakDBManager.SetFlat(t"DarkFutureStatusEffect.ConsumableNutritionTier2_UIData.intValues", [Cast<Int32>(this.nutritionTier2)]);
		TweakDBManager.SetFlat(t"DarkFutureStatusEffect.ConsumableNutritionTier3_UIData.intValues", [Cast<Int32>(this.nutritionTier3)]);
		TweakDBManager.SetFlat(t"DarkFutureStatusEffect.ConsumableNutritionTier4_UIData.intValues", [Cast<Int32>(this.nutritionTier4)]);
		TweakDBManager.SetFlat(t"DarkFutureStatusEffect.EnergizedCaffeine1Stack_UIData.intValues", [Cast<Int32>(this.energyPerEnergizedStack), 600, 3]);
		TweakDBManager.SetFlat(t"DarkFutureStatusEffect.EnergizedCaffeine2Stack_UIData.intValues", [2, Cast<Int32>(this.energyPerEnergizedStack), 600, 3]);
		TweakDBManager.SetFlat(t"DarkFutureStatusEffect.EnergizedStimulant2Stack_UIData.intValues", [2, Cast<Int32>(this.energyPerEnergizedStack), 600, 6]);
		TweakDBManager.SetFlat(t"DarkFutureStatusEffect.EnergizedStimulant3Stack_UIData.intValues", [3, Cast<Int32>(this.energyPerEnergizedStack), 600, 6]);

		TweakDBManager.UpdateRecord(t"DarkFutureStatusEffect.ConsumableHydrationTier1_UIData");
		TweakDBManager.UpdateRecord(t"DarkFutureStatusEffect.ConsumableHydrationTier2_UIData");
		TweakDBManager.UpdateRecord(t"DarkFutureStatusEffect.ConsumableHydrationTier3_UIData");
		TweakDBManager.UpdateRecord(t"DarkFutureStatusEffect.ConsumableNutritionTier1_UIData");
		TweakDBManager.UpdateRecord(t"DarkFutureStatusEffect.ConsumableNutritionTier2_UIData");
		TweakDBManager.UpdateRecord(t"DarkFutureStatusEffect.ConsumableNutritionTier3_UIData");
		TweakDBManager.UpdateRecord(t"DarkFutureStatusEffect.ConsumableNutritionTier4_UIData");
		TweakDBManager.UpdateRecord(t"DarkFutureStatusEffect.EnergizedCaffeine1Stack_UIData");
		TweakDBManager.UpdateRecord(t"DarkFutureStatusEffect.EnergizedCaffeine2Stack_UIData");
		TweakDBManager.UpdateRecord(t"DarkFutureStatusEffect.EnergizedStimulant2Stack_UIData");
		TweakDBManager.UpdateRecord(t"DarkFutureStatusEffect.EnergizedStimulant3Stack_UIData");

		// Consumable Weight
		//
		if Equals(this.consumableWeightsModify, DFEconomicSetting.Modify) {
			TweakDBManager.SetFlat(t"DarkFutureWeight.VerySmallFood.value", this.weightFoodVerySmall);
			TweakDBManager.SetFlat(t"DarkFutureWeight.SmallFood.value", this.weightFoodSmall);
			TweakDBManager.SetFlat(t"DarkFutureWeight.MediumFood.value", this.weightFoodMedium);
			TweakDBManager.SetFlat(t"DarkFutureWeight.LargeFood.value", this.weightFoodLarge);
			TweakDBManager.SetFlat(t"DarkFutureWeight.SmallDrink.value", this.weightDrinkSmall);
			TweakDBManager.SetFlat(t"DarkFutureWeight.LargeDrink.value", this.weightDrinkLarge);
			TweakDBManager.SetFlat(t"DarkFutureWeight.SmallDrug.value", this.weightDrugSmall);
			TweakDBManager.SetFlat(t"DarkFutureWeight.MediumDrug.value", this.weightDrugMedium);
			TweakDBManager.SetFlat(t"DarkFutureWeight.LargeDrug.value", this.weightDrugLarge);
			TweakDBManager.SetFlat(t"DarkFutureWeight.FirstAidKitDrug.value", this.weightTraumaKit);

			TweakDBManager.UpdateRecord(t"DarkFutureWeight.VerySmallFood");
			TweakDBManager.UpdateRecord(t"DarkFutureWeight.SmallFood");
			TweakDBManager.UpdateRecord(t"DarkFutureWeight.MediumFood");
			TweakDBManager.UpdateRecord(t"DarkFutureWeight.LargeFood");
			TweakDBManager.UpdateRecord(t"DarkFutureWeight.SmallDrink");
			TweakDBManager.UpdateRecord(t"DarkFutureWeight.LargeDrink");
			TweakDBManager.UpdateRecord(t"DarkFutureWeight.SmallDrug");
			TweakDBManager.UpdateRecord(t"DarkFutureWeight.MediumDrug");
			TweakDBManager.UpdateRecord(t"DarkFutureWeight.LargeDrug");
			TweakDBManager.UpdateRecord(t"DarkFutureWeight.FirstAidKitDrug");
		}

		// Consumable Prices
		//
		if Equals(this.consumablePricesModify, DFEconomicSetting.Modify) {
			TweakDBManager.SetFlat(t"Price.Food.value", 6.0);
			TweakDBManager.SetFlat(t"Price.Drink.value", 8.0);
			TweakDBManager.SetFlat(t"Price.LowQualityAlcohol.value", this.priceAlcoholLowQuality);
			TweakDBManager.SetFlat(t"Price.MediumQualityAlcohol.value", this.priceAlcoholMediumQuality);
			TweakDBManager.SetFlat(t"Price.GoodQualityAlcohol.value", this.priceAlcoholGoodQuality);
			TweakDBManager.SetFlat(t"Price.TopQualityAlcohol.value", this.priceAlcoholTopQuality);
			TweakDBManager.SetFlat(t"Price.ExquisiteQualityAlcohol.value", this.priceAlcoholExquisiteQuality);

			TweakDBManager.SetFlat(t"DarkFuturePrice.NomadDrinks.value", this.priceDrinkNomad);
			TweakDBManager.SetFlat(t"DarkFuturePrice.CommonDrinks.value", this.priceDrinkCommon);
			TweakDBManager.SetFlat(t"DarkFuturePrice.UncommonDrinks.value", this.priceDrinkUncommon);
			TweakDBManager.SetFlat(t"DarkFuturePrice.RareDrinks.value", this.priceDrinkRare);
			TweakDBManager.SetFlat(t"DarkFuturePrice.EpicDrinks.value", this.priceDrinkEpic);
			TweakDBManager.SetFlat(t"DarkFuturePrice.LegendaryDrinks.value", this.priceDrinkLegendary);
			TweakDBManager.SetFlat(t"DarkFuturePrice.IllegalDrinks.value", this.priceDrinkIllegal);
			TweakDBManager.SetFlat(t"DarkFuturePrice.NomadFood.value", this.priceFoodNomad);
			TweakDBManager.SetFlat(t"DarkFuturePrice.CommonFoodSnack.value", this.priceFoodCommonSnackSmall);
			TweakDBManager.SetFlat(t"DarkFuturePrice.CommonFoodLargeSnack.value", this.priceFoodCommonSnackLarge);
			TweakDBManager.SetFlat(t"DarkFuturePrice.CommonFoodMeal.value", this.priceFoodCommonMeal);
			TweakDBManager.SetFlat(t"DarkFuturePrice.UncommonFood.value", this.priceFoodUncommon);
			TweakDBManager.SetFlat(t"DarkFuturePrice.RareFood.value", this.priceFoodRare);
			TweakDBManager.SetFlat(t"DarkFuturePrice.EpicFood.value", this.priceFoodEpic);
			TweakDBManager.SetFlat(t"DarkFuturePrice.LegendaryFoodSnack.value", this.priceFoodIllegalSnack);
			TweakDBManager.SetFlat(t"DarkFuturePrice.LegendaryFoodMeal.value", this.priceFoodIllegalMeal);
			
			TweakDBManager.SetFlat(t"DarkFuturePrice.MrWhitey.value", this.priceMrWhitey);
			TweakDBManager.SetFlat(t"DarkFuturePrice.Pharmaceuticals.value", this.pricePharmaceuticals);
			TweakDBManager.SetFlat(t"DarkFuturePrice.IllegalDrugs.value", this.priceIllegalDrugs);

			TweakDBManager.UpdateRecord(t"Price.Food");
			TweakDBManager.UpdateRecord(t"Price.Drink");
			TweakDBManager.UpdateRecord(t"Price.LowQualityAlcohol");
			TweakDBManager.UpdateRecord(t"Price.MediumQualityAlcohol");
			TweakDBManager.UpdateRecord(t"Price.GoodQualityAlcohol");
			TweakDBManager.UpdateRecord(t"Price.TopQualityAlcohol");
			TweakDBManager.UpdateRecord(t"Price.ExquisiteQualityAlcohol");

			TweakDBManager.UpdateRecord(t"DarkFuturePrice.NomadDrinks");
			TweakDBManager.UpdateRecord(t"DarkFuturePrice.CommonDrinks");
			TweakDBManager.UpdateRecord(t"DarkFuturePrice.UncommonDrinks");
			TweakDBManager.UpdateRecord(t"DarkFuturePrice.RareDrinks");
			TweakDBManager.UpdateRecord(t"DarkFuturePrice.EpicDrinks");
			TweakDBManager.UpdateRecord(t"DarkFuturePrice.LegendaryDrinks");
			TweakDBManager.UpdateRecord(t"DarkFuturePrice.IllegalDrinks");
			TweakDBManager.UpdateRecord(t"DarkFuturePrice.NomadFood");
			TweakDBManager.UpdateRecord(t"DarkFuturePrice.CommonFoodSnack");
			TweakDBManager.UpdateRecord(t"DarkFuturePrice.CommonFoodLargeSnack");
			TweakDBManager.UpdateRecord(t"DarkFuturePrice.CommonFoodMeal");
			TweakDBManager.UpdateRecord(t"DarkFuturePrice.UncommonFood");
			TweakDBManager.UpdateRecord(t"DarkFuturePrice.RareFood");
			TweakDBManager.UpdateRecord(t"DarkFuturePrice.EpicFood");
			TweakDBManager.UpdateRecord(t"DarkFuturePrice.LegendaryFoodSnack");
			TweakDBManager.UpdateRecord(t"DarkFuturePrice.LegendaryFoodMeal");
			TweakDBManager.UpdateRecord(t"DarkFuturePrice.MrWhitey");
			TweakDBManager.UpdateRecord(t"DarkFuturePrice.Pharmaceuticals");
			TweakDBManager.UpdateRecord(t"DarkFuturePrice.IllegalDrugs");
		}
	}

	private final func ToggleAmmoCrafting(craftingEnabled: Bool) {
		//DFProfile();
		let craftingSystem: ref<CraftingSystem> = CraftingSystem.GetInstance(GetGameInstance());
    	let playerCraftBook: ref<CraftBook> = craftingSystem.GetPlayerCraftBook();

		playerCraftBook.HideRecipe(t"Ammo.HandgunAmmo", !this.ammoCraftingEnabled);
		playerCraftBook.HideRecipe(t"Ammo.ShotgunAmmo", !this.ammoCraftingEnabled);
		playerCraftBook.HideRecipe(t"Ammo.RifleAmmo", !this.ammoCraftingEnabled);
		playerCraftBook.HideRecipe(t"Ammo.SniperRifleAmmo", !this.ammoCraftingEnabled);
	}

	//
	//	CHANGE TRACKING
	//
	// Internal change tracking use only. DO NOT USE.
	// Internal change tracking use only. DO NOT USE.
	private let _mainSystemEnabled: Bool = true;
	private let _showHUDUI: Bool = true;
	private let _needHUDUIAlwaysOnThreshold: Float = 75.0;
	private let _hydrationHUDUIColorTheme: DFBarColorThemeName = DFBarColorThemeName.PigeonPost;
	private let _nutritionHUDUIColorTheme: DFBarColorThemeName = DFBarColorThemeName.PigeonPost;
	private let _energyHUDUIColorTheme: DFBarColorThemeName = DFBarColorThemeName.PigeonPost;
	private let _reducedCarryWeight: DFReducedCarryWeightAmount = DFReducedCarryWeightAmount.Full;
	private let _fastTravelSettingV2: DFFastTravelSetting = DFFastTravelSetting.Disabled;
	private let _criticalNeedVFXEnabled: Bool = true;
	private let _hudUIScale: Float = 1.0;
	private let _hudUIPosX: Float = 70.0;
	private let _hudUIPosY: Float = 240.0;
	private let _updateHolocallVerticalPosition: Bool = true;
	private let _holocallVerticalPositionOffset: Float = 45.0;
	private let _updateStatusEffectListVerticalPosition: Bool = true;
	private let _statusEffectListVerticalPositionOffset: Float = 45.0;
	private let _updateRaceUIVerticalPosition: Bool = true;
	private let _raceUIVerticalPositionOffset: Float = 45.0;
	private let _needNegativeEffectsRepeatEnabled: Bool = true;
	private let _needNegativeEffectsRepeatFrequencyModerateInRealTimeSeconds: Float = 300.0;
	private let _needNegativeEffectsRepeatFrequencySevereInRealTimeSeconds: Float = 180.0;
	private let _timescale: Float = 8.0;
	private let _compatibilityProjectE3HUD: Bool = false;
	private let _compatibilityProjectE3UI: Bool = false;
	private let _forceFPPWhenSleepingInVehicle: Bool = true;
	private let _basicNeedThresholdValue1: Float = 85.0;
	private let _basicNeedThresholdValue2: Float = 75.0;
	private let _basicNeedThresholdValue3: Float = 50.0;
	private let _basicNeedThresholdValue4: Float = 25.0;
	// Internal change tracking use only. DO NOT USE.
	// Internal change tracking use only. DO NOT USE.

	public final static func GetInstance(gameInstance: GameInstance) -> ref<DFSettings> {
		//DFProfile();
		let instance: ref<DFSettings> = GameInstance.GetScriptableSystemsContainer(gameInstance).Get(NameOf<DFSettings>()) as DFSettings;
		return instance;
	}

	public final static func Get() -> ref<DFSettings> {
		//DFProfile();
		return DFSettings.GetInstance(GetGameInstance());
	}
	
	public func OnDetach() -> Void {
		//DFProfile();
		UnregisterDFSettingsListener(this);
	}

	public func Init(attachedPlayer: ref<PlayerPuppet>) -> Void {
		//DFProfile();
		DFLogNoSystem(this.debugEnabled, this, "Ready!");

		RegisterDFSettingsListener(this);
    }

	public func OnModSettingsChange() -> Void {
		//DFProfile();
		this.ReconcileSettings();
	}

	public final func ReconcileSettings() -> Void {
		//DFProfile();
		DFLogNoSystem(this.debugEnabled, this, "Beginning Settings Reconciliation...");
		let changedSettings: array<String>;

		if NotEquals(this._mainSystemEnabled, this.mainSystemEnabled) {
			this._mainSystemEnabled = this.mainSystemEnabled;
			ArrayPush(changedSettings, "mainSystemEnabled");
		}

		if NotEquals(this._showHUDUI, this.showHUDUI) {
			this._showHUDUI = this.showHUDUI;
			ArrayPush(changedSettings, "showHUDUI");
		}

		if NotEquals(this._needHUDUIAlwaysOnThreshold, this.needHUDUIAlwaysOnThreshold) {
			this._needHUDUIAlwaysOnThreshold = this.needHUDUIAlwaysOnThreshold;
			ArrayPush(changedSettings, "needHUDUIAlwaysOnThreshold");
		}

		if NotEquals(this._hydrationHUDUIColorTheme, this.hydrationHUDUIColorTheme) {
			this._hydrationHUDUIColorTheme = this.hydrationHUDUIColorTheme;
			ArrayPush(changedSettings, "hydrationHUDUIColorTheme");
		}

		if NotEquals(this._nutritionHUDUIColorTheme, this.nutritionHUDUIColorTheme) {
			this._nutritionHUDUIColorTheme = this.nutritionHUDUIColorTheme;
			ArrayPush(changedSettings, "nutritionHUDUIColorTheme");
		}

		if NotEquals(this._energyHUDUIColorTheme, this.energyHUDUIColorTheme) {
			this._energyHUDUIColorTheme = this.energyHUDUIColorTheme;
			ArrayPush(changedSettings, "energyHUDUIColorTheme");
		}

		if NotEquals(this._reducedCarryWeight, this.reducedCarryWeight) {
			this._reducedCarryWeight = this.reducedCarryWeight;
			ArrayPush(changedSettings, "reducedCarryWeight");
		}

		if NotEquals(this._criticalNeedVFXEnabled, this.criticalNeedVFXEnabled) {
			this._criticalNeedVFXEnabled = this.criticalNeedVFXEnabled;
			ArrayPush(changedSettings, "criticalNeedVFXEnabled");
		}

		if NotEquals(this._hudUIScale, this.hudUIScale) {
			this._hudUIScale = this.hudUIScale;
			ArrayPush(changedSettings, "hudUIScale");
		}

		if NotEquals(this._hudUIPosX, this.hudUIPosX) {
			this._hudUIPosX = this.hudUIPosX;
			ArrayPush(changedSettings, "hudUIPosX");
		}

		if NotEquals(this._hudUIPosY, this.hudUIPosY) {
			this._hudUIPosY = this.hudUIPosY;
			ArrayPush(changedSettings, "hudUIPosY");
		}

		if NotEquals(this._updateHolocallVerticalPosition, this.updateHolocallVerticalPosition) {
			this._updateHolocallVerticalPosition = this.updateHolocallVerticalPosition;
			ArrayPush(changedSettings, "updateHolocallVerticalPosition");
		}

		if NotEquals(this._holocallVerticalPositionOffset, this.holocallVerticalPositionOffset) {
			this._holocallVerticalPositionOffset = this.holocallVerticalPositionOffset;
			ArrayPush(changedSettings, "holocallVerticalPositionOffset");
		}

		if NotEquals(this._updateStatusEffectListVerticalPosition, this.updateStatusEffectListVerticalPosition) {
			this._updateStatusEffectListVerticalPosition = this.updateStatusEffectListVerticalPosition;
			ArrayPush(changedSettings, "updateStatusEffectListVerticalPosition");
		}

		if NotEquals(this._statusEffectListVerticalPositionOffset, this.statusEffectListVerticalPositionOffset) {
			this._statusEffectListVerticalPositionOffset = this.statusEffectListVerticalPositionOffset;
			ArrayPush(changedSettings, "statusEffectListVerticalPositionOffset");
		}

		if NotEquals(this._updateRaceUIVerticalPosition, this.updateRaceUIVerticalPosition) {
			this._updateRaceUIVerticalPosition = this.updateRaceUIVerticalPosition;
			ArrayPush(changedSettings, "updateRaceUIVerticalPosition");
		}

		if NotEquals(this._raceUIVerticalPositionOffset, this.raceUIVerticalPositionOffset) {
			this._raceUIVerticalPositionOffset = this.raceUIVerticalPositionOffset;
			ArrayPush(changedSettings, "raceUIVerticalPositionOffset");
		}

		if NotEquals(this._needNegativeEffectsRepeatEnabled, this.needNegativeEffectsRepeatEnabled) {
			this._needNegativeEffectsRepeatEnabled = this.needNegativeEffectsRepeatEnabled;
			ArrayPush(changedSettings, "needNegativeEffectsRepeatEnabled");
		}

		if NotEquals(this._needNegativeEffectsRepeatFrequencyModerateInRealTimeSeconds, this.needNegativeEffectsRepeatFrequencyModerateInRealTimeSeconds) {
			this._needNegativeEffectsRepeatFrequencyModerateInRealTimeSeconds = this.needNegativeEffectsRepeatFrequencyModerateInRealTimeSeconds;
			ArrayPush(changedSettings, "needNegativeEffectsRepeatFrequencyModerateInRealTimeSeconds");
		}

		if NotEquals(this._needNegativeEffectsRepeatFrequencySevereInRealTimeSeconds, this.needNegativeEffectsRepeatFrequencySevereInRealTimeSeconds) {
			this._needNegativeEffectsRepeatFrequencySevereInRealTimeSeconds = this.needNegativeEffectsRepeatFrequencySevereInRealTimeSeconds;
			ArrayPush(changedSettings, "needNegativeEffectsRepeatFrequencySevereInRealTimeSeconds");
		}

		if NotEquals(this._timescale, this.timescale) {
			this._timescale = this.timescale;
			ArrayPush(changedSettings, "timescale");
		}

		if NotEquals(this._compatibilityProjectE3HUD, this.compatibilityProjectE3HUD) {
			this._compatibilityProjectE3HUD = this.compatibilityProjectE3HUD;
			ArrayPush(changedSettings, "compatibilityProjectE3HUD");
		}

		if NotEquals(this._compatibilityProjectE3UI, this.compatibilityProjectE3UI) {
			this._compatibilityProjectE3UI = this.compatibilityProjectE3UI;
			ArrayPush(changedSettings, "compatibilityProjectE3UI");
		}

		if NotEquals(this._forceFPPWhenSleepingInVehicle, this.forceFPPWhenSleepingInVehicle) {
			this._forceFPPWhenSleepingInVehicle = this.forceFPPWhenSleepingInVehicle;
			ArrayPush(changedSettings, "forceFPPWhenSleepingInVehicle");
		}

		if NotEquals(this._basicNeedThresholdValue1, this.basicNeedThresholdValue1) {
			this._basicNeedThresholdValue1 = this.basicNeedThresholdValue1;
			ArrayPush(changedSettings, "basicNeedThresholdValue1");
		}

		if NotEquals(this._basicNeedThresholdValue2, this.basicNeedThresholdValue2) {
			this._basicNeedThresholdValue2 = this.basicNeedThresholdValue2;
			ArrayPush(changedSettings, "basicNeedThresholdValue2");
		}

		if NotEquals(this._basicNeedThresholdValue3, this.basicNeedThresholdValue3) {
			this._basicNeedThresholdValue3 = this.basicNeedThresholdValue3;
			ArrayPush(changedSettings, "basicNeedThresholdValue3");
		}

		if NotEquals(this._basicNeedThresholdValue4, this.basicNeedThresholdValue4) {
			this._basicNeedThresholdValue4 = this.basicNeedThresholdValue4;
			ArrayPush(changedSettings, "basicNeedThresholdValue4");
		}
		
		if ArraySize(changedSettings) > 0 {
			DFLogNoSystem(this.debugEnabled, this, "        ...the following settings have changed: " + ToString(changedSettings));
			GameInstance.GetCallbackSystem().DispatchEvent(SettingChangedEvent.Create(changedSettings));
		}

		DFLogNoSystem(this.debugEnabled, this, "        ...updating ammo crafting recipe availability...");
		this.ToggleAmmoCrafting(this.ammoCraftingEnabled);

		DFLogNoSystem(this.debugEnabled, this, "        ...done!");
	}

	// -------------------------------------------------------------------------
	// System Settings
	// -------------------------------------------------------------------------
	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryMain")
	@runtimeProperty("ModSettings.category.order", "10")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingMainSystemEnabled")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingMainSystemEnabledDesc_Core")
	public let mainSystemEnabled: Bool = true;

	// -------------------------------------------------------------------------
	// Gameplay - General
	// -------------------------------------------------------------------------
	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryGameplayGeneral")
	@runtimeProperty("ModSettings.category.order", "20")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingReducedCarryWeight")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingReducedCarryWeightDesc")
	@runtimeProperty("ModSettings.displayValues.Full", "DarkFutureReducedCarryWeightAmountFull")
    @runtimeProperty("ModSettings.displayValues.Half", "DarkFutureReducedCarryWeightAmountHalf")
	@runtimeProperty("ModSettings.displayValues.Off", "DarkFutureReducedCarryWeightAmountOff")
	public let reducedCarryWeight: DFReducedCarryWeightAmount = DFReducedCarryWeightAmount.Full;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryGameplayGeneral")
	@runtimeProperty("ModSettings.category.order", "20")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingStashCraftingEnabled")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingStashCraftingEnabledDesc")
	public let stashCraftingEnabled: Bool = true;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryGameplayGeneral")
	@runtimeProperty("ModSettings.category.order", "20")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingNoConsumablesInStash")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingNoConsumablesInStashDesc")
	public let noConsumablesInStash: Bool = true;

	// -------------------------------------------------------------------------
	// Gameplay - Fast Travel
	// -------------------------------------------------------------------------
	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryGameplayFastTravel")
	@runtimeProperty("ModSettings.category.order", "30")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingFastTravel")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingFastTravelDesc")
	@runtimeProperty("ModSettings.displayValues.Disabled", "DarkFutureFastTravelDisabled")
	@runtimeProperty("ModSettings.displayValues.DisabledAllowMetro", "DarkFutureFastTravelDisabledAllowMetro")
	@runtimeProperty("ModSettings.displayValues.Enabled", "DarkFutureFastTravelEnabled")
	public let fastTravelSettingV2: DFFastTravelSetting = DFFastTravelSetting.Disabled;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryGameplayFastTravel")
	@runtimeProperty("ModSettings.category.order", "30")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingHideFastTravelMarkers")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingHideFastTravelMarkersDesc")
	public let hideFastTravelMarkers: Bool = true;

	// -------------------------------------------------------------------------
	// Gameplay - Sleeping In Vehicles
	// -------------------------------------------------------------------------
	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryGameplayVehicleSleeping")
	@runtimeProperty("ModSettings.category.order", "45")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingSleepingInVehiclesKeybindingMain")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingSleepingInVehiclesKeybindingMainDesc")
	public let DFVehicleSleepButtonMain: EInputKey = EInputKey.IK_X;
 
	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryGameplayVehicleSleeping")
	@runtimeProperty("ModSettings.category.order", "45")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingSleepingInVehiclesKeybindingAlt")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingSleepingInVehiclesKeybindingAltDesc")
	public let DFVehicleSleepButtonAlt: EInputKey = EInputKey.IK_Pad_DigitRight;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryGameplayVehicleSleeping")
	@runtimeProperty("ModSettings.category.order", "45")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingAdvancedSettings")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingAdvancedSettingsDesc")
	public let sleepingInVehiclesAdvancedSettings: Bool = false;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryGameplayVehicleSleeping")
	@runtimeProperty("ModSettings.category.order", "45")
	@runtimeProperty("ModSettings.dependency", "sleepingInVehiclesAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingVehicleSleepQualityCity")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingVehicleSleepQualityCityDesc")
	@runtimeProperty("ModSettings.displayValues.Limited", "DarkFutureSettingSleepQualityLimited")
    @runtimeProperty("ModSettings.displayValues.Full", "DarkFutureSettingSleepQualityFull")
	public let vehicleSleepQualityCity: DFSleepQualitySetting = DFSleepQualitySetting.Limited;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryGameplayVehicleSleeping")
	@runtimeProperty("ModSettings.category.order", "45")
	@runtimeProperty("ModSettings.dependency", "sleepingInVehiclesAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingVehicleSleepQualityBadlands")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingVehicleSleepQualityBadlandsDesc")
	@runtimeProperty("ModSettings.displayValues.Limited", "DarkFutureSettingSleepQualityLimited")
    @runtimeProperty("ModSettings.displayValues.Full", "DarkFutureSettingSleepQualityFull")
	public let vehicleSleepQualityBadlandsV2: DFSleepQualitySetting = DFSleepQualitySetting.Full;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryGameplayVehicleSleeping")
	@runtimeProperty("ModSettings.category.order", "45")
	@runtimeProperty("ModSettings.dependency", "sleepingInVehiclesAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingEnergyLimitSleepInVehicle")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingEnergyLimitSleepInVehicleDesc")
	@runtimeProperty("ModSettings.step", "1.0")
	@runtimeProperty("ModSettings.min", "1.0")
	@runtimeProperty("ModSettings.max", "100.0")
	public let limitedEnergySleepingInVehicles: Float = 70.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryGameplayVehicleSleeping")
	@runtimeProperty("ModSettings.category.order", "45")
	@runtimeProperty("ModSettings.dependency", "sleepingInVehiclesAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingForceFPPWhenSleepingInVehicle")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingForceFPPWhenSleepingInVehicleDesc")
	public let forceFPPWhenSleepingInVehicle: Bool = true;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryGameplayVehicleSleeping")
	@runtimeProperty("ModSettings.category.order", "45")
	@runtimeProperty("ModSettings.dependency", "sleepingInVehiclesAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingShowSleepingInVehiclesInputHint")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingShowSleepingInVehiclesInputHintDesc")
	public let showSleepingInVehiclesInputHint: Bool = true;

	// -------------------------------------------------------------------------
	// Gameplay - Sleep Encounters
	// -------------------------------------------------------------------------
	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryGameplayVehicleSleepEncounters")
	@runtimeProperty("ModSettings.category.order", "48")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingEnableRandomEncountersWhenSleepingInVehicles")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingEnableRandomEncountersWhenSleepingInVehiclesDesc")
	public let enableRandomEncountersWhenSleepingInVehicles: Bool = true;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryGameplayVehicleSleepEncounters")
	@runtimeProperty("ModSettings.category.order", "48")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingAdvancedSettings")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingAdvancedSettingsDesc")
	public let randomEncountersAdvancedSettings: Bool = false;
	
	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryGameplayVehicleSleepEncounters")
	@runtimeProperty("ModSettings.category.order", "48")
	@runtimeProperty("ModSettings.dependency", "randomEncountersAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingRandomEncounterChanceGangDistrict")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingRandomEncounterChanceGangDistrictDesc")
	@runtimeProperty("ModSettings.step", "1.0")
	@runtimeProperty("ModSettings.min", "0.0")
	@runtimeProperty("ModSettings.max", "100.0")
	public let randomEncounterChanceGangDistrict: Float = 30.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryGameplayVehicleSleepEncounters")
	@runtimeProperty("ModSettings.category.order", "48")
	@runtimeProperty("ModSettings.dependency", "randomEncountersAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingRandomEncounterChanceCityCenter")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingRandomEncounterChanceCityCenterDesc")
	@runtimeProperty("ModSettings.step", "1.0")
	@runtimeProperty("ModSettings.min", "0.0")
	@runtimeProperty("ModSettings.max", "100.0")
	public let randomEncounterChanceCityCenter: Float = 20.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryGameplayVehicleSleepEncounters")
	@runtimeProperty("ModSettings.category.order", "48")
	@runtimeProperty("ModSettings.dependency", "randomEncountersAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingRandomEncounterChanceBadlands")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingRandomEncounterChanceBadlandsDesc")
	@runtimeProperty("ModSettings.step", "1.0")
	@runtimeProperty("ModSettings.min", "0.0")
	@runtimeProperty("ModSettings.max", "100.0")
	public let randomEncounterChanceBadlandsV2: Float = 10.0;

	// -------------------------------------------------------------------------
	// Survival - Basic Needs
	// -------------------------------------------------------------------------
	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryGameplayBasicNeeds")
	@runtimeProperty("ModSettings.category.order", "50")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingHydrationLossRatePct")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingHydrationLossRatePctDesc")
	@runtimeProperty("ModSettings.step", "0.5")
	@runtimeProperty("ModSettings.min", "0.0")
	@runtimeProperty("ModSettings.max", "800.0")
	public let hydrationLossRatePct: Float = 80.0;
	
	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryGameplayBasicNeeds")
	@runtimeProperty("ModSettings.category.order", "50")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingNutritionLossRatePct")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingNutritionLossRatePctDesc")
	@runtimeProperty("ModSettings.step", "0.5")
	@runtimeProperty("ModSettings.min", "0.0")
	@runtimeProperty("ModSettings.max", "800.0")
	public let nutritionLossRatePct: Float = 80.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryGameplayBasicNeeds")
	@runtimeProperty("ModSettings.category.order", "50")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingEnergyLossRatePct")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingEnergyLossRatePctDesc")
	@runtimeProperty("ModSettings.step", "0.5")
	@runtimeProperty("ModSettings.min", "0.0")
	@runtimeProperty("ModSettings.max", "800.0")
	public let energyLossRatePct: Float = 80.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryGameplayBasicNeeds")
	@runtimeProperty("ModSettings.category.order", "50")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingHydrationLossIsFatal")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingHydrationLossIsFatalDesc")
	public let hydrationLossIsFatal: Bool = true;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryGameplayBasicNeeds")
	@runtimeProperty("ModSettings.category.order", "50")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingNutritionLossIsFatal")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingNutritionLossIsFatalDesc")
	public let nutritionLossIsFatal: Bool = true;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryGameplayBasicNeeds")
	@runtimeProperty("ModSettings.category.order", "50")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingEnergyLossIsFatal")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingEnergyLossIsFatalDesc")
	public let energyLossIsFatal: Bool = true;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryGameplayBasicNeeds")
	@runtimeProperty("ModSettings.category.order", "50")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingAdvancedSettings")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingAdvancedSettingsDesc")
	public let basicNeedsAdvancedSettings: Bool = false;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryGameplayBasicNeeds")
	@runtimeProperty("ModSettings.category.order", "50")
	@runtimeProperty("ModSettings.dependency", "basicNeedsAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingBasicNeedThresholdValue1")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingBasicNeedThresholdValue1Desc")
	@runtimeProperty("ModSettings.step", "1.0")
	@runtimeProperty("ModSettings.min", "4.0")
	@runtimeProperty("ModSettings.max", "100.0")
	public let basicNeedThresholdValue1: Float = 85.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryGameplayBasicNeeds")
	@runtimeProperty("ModSettings.category.order", "50")
	@runtimeProperty("ModSettings.dependency", "basicNeedsAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingBasicNeedThresholdValue2")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingBasicNeedThresholdValue2Desc")
	@runtimeProperty("ModSettings.step", "1.0")
	@runtimeProperty("ModSettings.min", "3.0")
	@runtimeProperty("ModSettings.max", "100.0")
	public let basicNeedThresholdValue2: Float = 75.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryGameplayBasicNeeds")
	@runtimeProperty("ModSettings.category.order", "50")
	@runtimeProperty("ModSettings.dependency", "basicNeedsAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingBasicNeedThresholdValue3")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingBasicNeedThresholdValue3Desc")
	@runtimeProperty("ModSettings.step", "1.0")
	@runtimeProperty("ModSettings.min", "2.0")
	@runtimeProperty("ModSettings.max", "100.0")
	public let basicNeedThresholdValue3: Float = 50.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryGameplayBasicNeeds")
	@runtimeProperty("ModSettings.category.order", "50")
	@runtimeProperty("ModSettings.dependency", "basicNeedsAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingBasicNeedThresholdValue4")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingBasicNeedThresholdValue4Desc")
	@runtimeProperty("ModSettings.step", "1.0")
	@runtimeProperty("ModSettings.min", "1.0")
	@runtimeProperty("ModSettings.max", "100.0")
	public let basicNeedThresholdValue4: Float = 25.0;

	// -------------------------------------------------------------------------
	// Interface
	// -------------------------------------------------------------------------
	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryUI")
	@runtimeProperty("ModSettings.category.order", "110")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingShowHUDUI")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingShowHUDUIDesc")
	public let showHUDUI: Bool = true;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryUI")
	@runtimeProperty("ModSettings.category.order", "110")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingHydrationHUDUIColorTheme")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingHydrationHUDUIColorThemeDesc")
	@runtimeProperty("ModSettings.displayValues.Rose", "DarkFutureColorThemeNameRose")
    @runtimeProperty("ModSettings.displayValues.HotPink", "DarkFutureColorThemeNameHotPink")
	@runtimeProperty("ModSettings.displayValues.PanelRed", "DarkFutureColorThemeNamePanelRed")
	@runtimeProperty("ModSettings.displayValues.MainRed", "DarkFutureColorThemeNameMainRed")
	@runtimeProperty("ModSettings.displayValues.Magenta", "DarkFutureColorThemeNameMagenta")
	@runtimeProperty("ModSettings.displayValues.PigeonPost", "DarkFutureColorThemeNamePigeonPost")
    @runtimeProperty("ModSettings.displayValues.MainBlue", "DarkFutureColorThemeNameMainBlue")
	@runtimeProperty("ModSettings.displayValues.Aqua", "DarkFutureColorThemeNameAqua")
    @runtimeProperty("ModSettings.displayValues.SpringGreen", "DarkFutureColorThemeNameSpringGreen")
    @runtimeProperty("ModSettings.displayValues.StreetCredGreen", "DarkFutureColorThemeNameStreetCredGreen")
	@runtimeProperty("ModSettings.displayValues.Yellow", "DarkFutureColorThemeNameYellow")
	@runtimeProperty("ModSettings.displayValues.White", "DarkFutureColorThemeNameWhite")
	public let hydrationHUDUIColorTheme: DFBarColorThemeName = DFBarColorThemeName.PigeonPost;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryUI")
	@runtimeProperty("ModSettings.category.order", "110")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingNutritionHUDUIColorTheme")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingNutritionHUDUIColorThemeDesc")
	@runtimeProperty("ModSettings.displayValues.Rose", "DarkFutureColorThemeNameRose")
    @runtimeProperty("ModSettings.displayValues.HotPink", "DarkFutureColorThemeNameHotPink")
	@runtimeProperty("ModSettings.displayValues.PanelRed", "DarkFutureColorThemeNamePanelRed")
	@runtimeProperty("ModSettings.displayValues.MainRed", "DarkFutureColorThemeNameMainRed")
	@runtimeProperty("ModSettings.displayValues.Magenta", "DarkFutureColorThemeNameMagenta")
	@runtimeProperty("ModSettings.displayValues.PigeonPost", "DarkFutureColorThemeNamePigeonPost")
    @runtimeProperty("ModSettings.displayValues.MainBlue", "DarkFutureColorThemeNameMainBlue")
	@runtimeProperty("ModSettings.displayValues.Aqua", "DarkFutureColorThemeNameAqua")
    @runtimeProperty("ModSettings.displayValues.SpringGreen", "DarkFutureColorThemeNameSpringGreen")
    @runtimeProperty("ModSettings.displayValues.StreetCredGreen", "DarkFutureColorThemeNameStreetCredGreen")
	@runtimeProperty("ModSettings.displayValues.Yellow", "DarkFutureColorThemeNameYellow")
	@runtimeProperty("ModSettings.displayValues.White", "DarkFutureColorThemeNameWhite")
	public let nutritionHUDUIColorTheme: DFBarColorThemeName = DFBarColorThemeName.PigeonPost;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryUI")
	@runtimeProperty("ModSettings.category.order", "110")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingEnergyHUDUIColorTheme")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingEnergyHUDUIColorThemeDesc")
	@runtimeProperty("ModSettings.displayValues.Rose", "DarkFutureColorThemeNameRose")
    @runtimeProperty("ModSettings.displayValues.HotPink", "DarkFutureColorThemeNameHotPink")
	@runtimeProperty("ModSettings.displayValues.PanelRed", "DarkFutureColorThemeNamePanelRed")
	@runtimeProperty("ModSettings.displayValues.MainRed", "DarkFutureColorThemeNameMainRed")
	@runtimeProperty("ModSettings.displayValues.Magenta", "DarkFutureColorThemeNameMagenta")
	@runtimeProperty("ModSettings.displayValues.PigeonPost", "DarkFutureColorThemeNamePigeonPost")
    @runtimeProperty("ModSettings.displayValues.MainBlue", "DarkFutureColorThemeNameMainBlue")
	@runtimeProperty("ModSettings.displayValues.Aqua", "DarkFutureColorThemeNameAqua")
    @runtimeProperty("ModSettings.displayValues.SpringGreen", "DarkFutureColorThemeNameSpringGreen")
    @runtimeProperty("ModSettings.displayValues.StreetCredGreen", "DarkFutureColorThemeNameStreetCredGreen")
	@runtimeProperty("ModSettings.displayValues.Yellow", "DarkFutureColorThemeNameYellow")
	@runtimeProperty("ModSettings.displayValues.White", "DarkFutureColorThemeNameWhite")
	public let energyHUDUIColorTheme: DFBarColorThemeName = DFBarColorThemeName.PigeonPost;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryUI")
	@runtimeProperty("ModSettings.category.order", "110")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingAdvancedSettings")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingAdvancedSettingsDesc")
	public let interfaceAdvancedSettings: Bool = false;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryUI")
	@runtimeProperty("ModSettings.category.order", "110")
	@runtimeProperty("ModSettings.dependency", "interfaceAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingNeedHUDUIAlwaysOnThreshold")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingNeedHUDUIAlwaysOnThresholdDesc")
	@runtimeProperty("ModSettings.step", "5.0")
	@runtimeProperty("ModSettings.min", "0.0")
	@runtimeProperty("ModSettings.max", "100.0")
	public let needHUDUIAlwaysOnThreshold: Float = 75.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryUI")
	@runtimeProperty("ModSettings.category.order", "110")
	@runtimeProperty("ModSettings.dependency", "interfaceAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingNewInventoryFilters")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingNewInventoryFiltersDesc")
	public let newInventoryFilters: Bool = true;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryUI")
	@runtimeProperty("ModSettings.category.order", "110")
	@runtimeProperty("ModSettings.dependency", "interfaceAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingHUDUIMinOpacity")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingHUDUIMinOpacityDesc")
	@runtimeProperty("ModSettings.step", "1.0")
	@runtimeProperty("ModSettings.min", "0.0")
	@runtimeProperty("ModSettings.max", "100.0")
	public let hudUIMinOpacity: Float = 15.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryUI")
	@runtimeProperty("ModSettings.category.order", "110")
	@runtimeProperty("ModSettings.dependency", "interfaceAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingHUDUIScale")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingHUDUIScaleDesc")
	@runtimeProperty("ModSettings.step", "0.01")
	@runtimeProperty("ModSettings.min", "0.1")
	@runtimeProperty("ModSettings.max", "4.0")
	public let hudUIScale: Float = 1.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryUI")
	@runtimeProperty("ModSettings.category.order", "110")
	@runtimeProperty("ModSettings.dependency", "interfaceAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingHUDUIPosX")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingHUDUIPosXDesc")
	@runtimeProperty("ModSettings.step", "0.5")
	@runtimeProperty("ModSettings.min", "0.0")
	@runtimeProperty("ModSettings.max", "3840.0")
	public let hudUIPosX: Float = 70.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryUI")
	@runtimeProperty("ModSettings.category.order", "110")
	@runtimeProperty("ModSettings.dependency", "interfaceAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingHUDUIPosY")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingHUDUIPosYDesc")
	@runtimeProperty("ModSettings.step", "0.5")
	@runtimeProperty("ModSettings.min", "0.0")
	@runtimeProperty("ModSettings.max", "2160.0")
	public let hudUIPosY: Float = 240.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryUI")
	@runtimeProperty("ModSettings.category.order", "110")
	@runtimeProperty("ModSettings.dependency", "interfaceAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingUpdateHolocallPosition")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingUpdateHolocallPositionDesc")
	public let updateHolocallVerticalPosition: Bool = true;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryUI")
	@runtimeProperty("ModSettings.category.order", "110")
	@runtimeProperty("ModSettings.dependency", "interfaceAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingHolocallVerticalPositionOffset")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingHolocallVerticalPositionOffsetDesc")
	@runtimeProperty("ModSettings.step", "0.5")
	@runtimeProperty("ModSettings.min", "0.0")
	@runtimeProperty("ModSettings.max", "1600.0")
	public let holocallVerticalPositionOffset: Float = 45.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryUI")
	@runtimeProperty("ModSettings.category.order", "110")
	@runtimeProperty("ModSettings.dependency", "interfaceAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingUpdateStatusEffectListPosition")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingUpdateStatusEffectListPositionDesc")
	public let updateStatusEffectListVerticalPosition: Bool = true;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryUI")
	@runtimeProperty("ModSettings.category.order", "110")
	@runtimeProperty("ModSettings.dependency", "interfaceAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingStatusEffectListVerticalPositionOffset")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingStatusEffectListVerticalPositionOffsetDesc")
	@runtimeProperty("ModSettings.step", "0.5")
	@runtimeProperty("ModSettings.min", "0.0")
	@runtimeProperty("ModSettings.max", "1600.0")
	public let statusEffectListVerticalPositionOffset: Float = 45.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryUI")
	@runtimeProperty("ModSettings.category.order", "110")
	@runtimeProperty("ModSettings.dependency", "interfaceAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingUpdateRaceUIPosition")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingUpdateRaceUIPositionDesc")
	public let updateRaceUIVerticalPosition: Bool = true;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryUI")
	@runtimeProperty("ModSettings.category.order", "110")
	@runtimeProperty("ModSettings.dependency", "interfaceAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingRaceUIVerticalPositionOffset")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingRaceUIVerticalPositionOffsetDesc")
	@runtimeProperty("ModSettings.step", "0.5")
	@runtimeProperty("ModSettings.min", "0.0")
	@runtimeProperty("ModSettings.max", "1600.0")
	public let raceUIVerticalPositionOffset: Float = 45.0;

	// -------------------------------------------------------------------------
	// Sounds and Visual Effects
	// -------------------------------------------------------------------------
	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryFX")
	@runtimeProperty("ModSettings.category.order", "120")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingNeedNegativeSFXEnabled")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingNeedNegativeSFXEnabledDesc_Core")
	public let needNegativeSFXEnabled: Bool = true;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryFX")
	@runtimeProperty("ModSettings.category.order", "120")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingNeedPositiveSFXEnabled")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingNeedPositiveSFXEnabledDesc_Core")
	public let needPositiveSFXEnabled: Bool = true;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryFX")
	@runtimeProperty("ModSettings.category.order", "120")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingAdvancedSettings")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingAdvancedSettingsDesc")
	public let fxAdvancedSettings: Bool = false;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryFX")
	@runtimeProperty("ModSettings.category.order", "120")
	@runtimeProperty("ModSettings.dependency", "fxAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingNeedNegativeEffectsRepeatEnabled")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingNeedNegativeEffectsRepeatEnabledDesc")
	public let needNegativeEffectsRepeatEnabled: Bool = true;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryFX")
	@runtimeProperty("ModSettings.category.order", "120")
	@runtimeProperty("ModSettings.dependency", "fxAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingNeedNegativeEffectsRepeatFrequencyModerateInRealTimeSeconds")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingNeedNegativeEffectsRepeatFrequencyModerateInRealTimeSecondsDesc")
	@runtimeProperty("ModSettings.step", "1.0")
	@runtimeProperty("ModSettings.min", "10.0")
	@runtimeProperty("ModSettings.max", "1800.0")
	public let needNegativeEffectsRepeatFrequencyModerateInRealTimeSeconds: Float = 300.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryFX")
	@runtimeProperty("ModSettings.category.order", "120")
	@runtimeProperty("ModSettings.dependency", "fxAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingNeedNegativeEffectsRepeatFrequencySevereInRealTimeSeconds")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingNeedNegativeEffectsRepeatFrequencySevereInRealTimeSecondsDesc")
	@runtimeProperty("ModSettings.step", "1.0")
	@runtimeProperty("ModSettings.min", "10.0")
	@runtimeProperty("ModSettings.max", "1800.0")
	public let needNegativeEffectsRepeatFrequencySevereInRealTimeSeconds: Float = 180.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryFX")
	@runtimeProperty("ModSettings.category.order", "120")
	@runtimeProperty("ModSettings.dependency", "fxAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingOutOfBreathEffectEnabled")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingOutOfBreathEffectEnabledDesc")
	public let outOfBreathEffectEnabled: Bool = true;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryFX")
	@runtimeProperty("ModSettings.category.order", "120")
	@runtimeProperty("ModSettings.dependency", "fxAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingCriticalNeedVFXEnabled")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingCriticalNeedVFXEnabledDesc_Core")
	public let criticalNeedVFXEnabled: Bool = true;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryFX")
	@runtimeProperty("ModSettings.category.order", "120")
	@runtimeProperty("ModSettings.dependency", "fxAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingHydrationNeedVFXEnabled")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingHydrationNeedVFXEnabledDesc")
	public let hydrationNeedVFXEnabled: Bool = true;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryFX")
	@runtimeProperty("ModSettings.category.order", "120")
	@runtimeProperty("ModSettings.dependency", "fxAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingNutritionNeedVFXEnabled")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingNutritionNeedVFXEnabledDesc")
	public let nutritionNeedVFXEnabled: Bool = true;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryFX")
	@runtimeProperty("ModSettings.category.order", "120")
	@runtimeProperty("ModSettings.dependency", "fxAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingEnergyNeedVFXEnabled")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingEnergyNeedVFXEnabledDesc")
	public let energyNeedVFXEnabled: Bool = true;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryFX")
	@runtimeProperty("ModSettings.category.order", "120")
	@runtimeProperty("ModSettings.dependency", "fxAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingOutOfBreathCameraEffectEnabled")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingOutOfBreathCameraEffectEnabledDesc")
	public let outOfBreathCameraEffectEnabled: Bool = true;

	// -------------------------------------------------------------------------
	// Notifications
	// -------------------------------------------------------------------------
	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryNotifications")
	@runtimeProperty("ModSettings.category.order", "147")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingNeedMessagesEnabled")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingNeedMessagesEnabledDesc")
	public let needMessagesEnabled: Bool = true;

	// -------------------------------------------------------------------------
	// Misc
	// -------------------------------------------------------------------------
	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryMisc")
	@runtimeProperty("ModSettings.category.order", "160")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingTutorialsEnabled")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingTutorialsEnabledDesc")
	public let tutorialsEnabled: Bool = true;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryMisc")
	@runtimeProperty("ModSettings.category.order", "160")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingUpdateMessagesEnabled")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingUpdateMessagesEnabledDesc")
	public let upgradeMessagesEnabled: Bool = true;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryMisc")
	@runtimeProperty("ModSettings.category.order", "160")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingForceShowUpdateMessage")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingForceShowUpdateMessageDesc")
	public let forceShowUpgradeMessageOnNewGame: Bool = false;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryMisc")
	@runtimeProperty("ModSettings.category.order", "160")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingTimescale")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingTimescaleDesc")
	@runtimeProperty("ModSettings.step", "0.1")
	@runtimeProperty("ModSettings.min", "1.0")
	@runtimeProperty("ModSettings.max", "40.0")
	public let timescale: Float = 8.0;

	// -------------------------------------------------------------------------
	// Compatibility
	// -------------------------------------------------------------------------
	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryCompatibility")
	@runtimeProperty("ModSettings.category.order", "165")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingAdvancedSettings")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingAdvancedSettingsDesc")
	public let compatibilityAdvancedSettings: Bool = false;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryCompatibility")
	@runtimeProperty("ModSettings.category.order", "165")
	@runtimeProperty("ModSettings.dependency", "compatibilityAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingCompatibilityEnhancedVehicleSystemPowerBehaviorOnSleepVehicle")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingCompatibilityEnhancedVehicleSystemPowerBehaviorOnSleepVehicleDesc")
	@runtimeProperty("ModSettings.displayValues.DoNothing", "DarkFutureCompatEVSPowerBehaviorDoNothing")
    @runtimeProperty("ModSettings.displayValues.TurnOff", "DarkFutureCompatEVSPowerBehaviorTurnOff")
	@runtimeProperty("ModSettings.displayValues.TurnOn", "DarkFutureCompatEVSPowerBehaviorTurnOn")
	public let compatibilityEnhancedVehicleSystemPowerBehaviorOnSleep: EnhancedVehicleSystemCompatPowerBehaviorDriver = EnhancedVehicleSystemCompatPowerBehaviorDriver.TurnOff;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryCompatibility")
	@runtimeProperty("ModSettings.category.order", "165")
	@runtimeProperty("ModSettings.dependency", "compatibilityAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingCompatibilityEnhancedVehicleSystemPowerBehaviorOnWakeVehicle")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingCompatibilityEnhancedVehicleSystemPowerBehaviorOnWakeVehicleDesc")
	@runtimeProperty("ModSettings.displayValues.DoNothing", "DarkFutureCompatEVSPowerBehaviorDoNothing")
	@runtimeProperty("ModSettings.displayValues.TurnOff", "DarkFutureCompatEVSPowerBehaviorTurnOff")
    @runtimeProperty("ModSettings.displayValues.TurnOn", "DarkFutureCompatEVSPowerBehaviorTurnOn")
	public let compatibilityEnhancedVehicleSystemPowerBehaviorOnWake: EnhancedVehicleSystemCompatPowerBehaviorDriver = EnhancedVehicleSystemCompatPowerBehaviorDriver.TurnOn;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryCompatibility")
	@runtimeProperty("ModSettings.category.order", "165")
	@runtimeProperty("ModSettings.dependency", "compatibilityAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingCompatibilityEnhancedVehicleSystemPowerBehaviorAsPassenger")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingCompatibilityEnhancedVehicleSystemPowerBehaviorAsPassengerDesc")
	@runtimeProperty("ModSettings.displayValues.DoNothing", "DarkFutureCompatEVSPowerBehaviorDoNothing")
	@runtimeProperty("ModSettings.displayValues.SameAsDriver", "DarkFutureCompatEVSPowerBehaviorSameAsDriver")
	public let compatibilityEnhancedVehicleSystemPowerBehaviorAsPassenger: EnhancedVehicleSystemCompatPowerBehaviorPassenger = EnhancedVehicleSystemCompatPowerBehaviorPassenger.SameAsDriver;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryCompatibility")
	@runtimeProperty("ModSettings.category.order", "165")
	@runtimeProperty("ModSettings.dependency", "compatibilityAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingCompatibilityWannabeEdgerunner")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingCompatibilityWannabeEdgerunnerDesc")
	public let compatibilityWannabeEdgerunner: Bool = true;
	
	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryCompatibility")
	@runtimeProperty("ModSettings.category.order", "165")
	@runtimeProperty("ModSettings.dependency", "compatibilityAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingCompatibilityProjectE3HUD")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingCompatibilityProjectE3HUDDesc")
	public let compatibilityProjectE3HUD: Bool = false;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryCompatibility")
	@runtimeProperty("ModSettings.category.order", "165")
	@runtimeProperty("ModSettings.dependency", "compatibilityAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingCompatibilityProjectE3UI")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingCompatibilityProjectE3UIDesc")
	public let compatibilityProjectE3UI: Bool = false;

	// -------------------------------------------------------------------------
	// Advanced - Consumable Restoration
	// -------------------------------------------------------------------------
	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumableRestoration")
	@runtimeProperty("ModSettings.category.order", "170")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingAdvancedSettings")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingAdvancedSettingsDesc")
	public let consumableRestorationAdvancedSettings: Bool = false;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumableRestoration")
	@runtimeProperty("ModSettings.category.order", "170")
	@runtimeProperty("ModSettings.dependency", "consumableRestorationAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsHydrationTier1")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsRestorationHydrationDesc")
	@runtimeProperty("ModSettings.step", "1.0")
	@runtimeProperty("ModSettings.min", "1.0")
	@runtimeProperty("ModSettings.max", "100.0")
	public let hydrationTier1: Float = 15.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumableRestoration")
	@runtimeProperty("ModSettings.category.order", "170")
	@runtimeProperty("ModSettings.dependency", "consumableRestorationAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsHydrationTier2")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsRestorationHydrationDesc")
	@runtimeProperty("ModSettings.step", "1.0")
	@runtimeProperty("ModSettings.min", "1.0")
	@runtimeProperty("ModSettings.max", "100.0")
	public let hydrationTier2: Float = 20.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumableRestoration")
	@runtimeProperty("ModSettings.category.order", "170")
	@runtimeProperty("ModSettings.dependency", "consumableRestorationAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsHydrationTier3")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsRestorationHydrationDesc")
	@runtimeProperty("ModSettings.step", "1.0")
	@runtimeProperty("ModSettings.min", "1.0")
	@runtimeProperty("ModSettings.max", "100.0")
	public let hydrationTier3: Float = 30.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumableRestoration")
	@runtimeProperty("ModSettings.category.order", "170")
	@runtimeProperty("ModSettings.dependency", "consumableRestorationAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsNutritionTier1")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsRestorationNutritionDesc")
	@runtimeProperty("ModSettings.step", "1.0")
	@runtimeProperty("ModSettings.min", "1.0")
	@runtimeProperty("ModSettings.max", "100.0")
	public let nutritionTier1: Float = 8.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumableRestoration")
	@runtimeProperty("ModSettings.category.order", "170")
	@runtimeProperty("ModSettings.dependency", "consumableRestorationAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsNutritionTier2")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsRestorationNutritionDesc")
	@runtimeProperty("ModSettings.step", "1.0")
	@runtimeProperty("ModSettings.min", "1.0")
	@runtimeProperty("ModSettings.max", "100.0")
	public let nutritionTier2: Float = 15.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumableRestoration")
	@runtimeProperty("ModSettings.category.order", "170")
	@runtimeProperty("ModSettings.dependency", "consumableRestorationAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsNutritionTier3")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsRestorationNutritionDesc")
	@runtimeProperty("ModSettings.step", "1.0")
	@runtimeProperty("ModSettings.min", "1.0")
	@runtimeProperty("ModSettings.max", "100.0")
	public let nutritionTier3: Float = 20.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumableRestoration")
	@runtimeProperty("ModSettings.category.order", "170")
	@runtimeProperty("ModSettings.dependency", "consumableRestorationAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsNutritionTier4")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsRestorationNutritionDesc")
	@runtimeProperty("ModSettings.step", "1.0")
	@runtimeProperty("ModSettings.min", "1.0")
	@runtimeProperty("ModSettings.max", "100.0")
	public let nutritionTier4: Float = 30.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumableRestoration")
	@runtimeProperty("ModSettings.category.order", "170")
	@runtimeProperty("ModSettings.dependency", "consumableRestorationAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsEnergyTier1")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsRestorationEnergyDesc")
	@runtimeProperty("ModSettings.step", "1.0")
	@runtimeProperty("ModSettings.min", "1.0")
	@runtimeProperty("ModSettings.max", "100.0")
	public let energyPerEnergizedStack: Float = 10.0;

	// -------------------------------------------------------------------------
	// Advanced - Consumable Weight
	// -------------------------------------------------------------------------
	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumableWeight")
	@runtimeProperty("ModSettings.category.order", "180")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingAdvancedSettings")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingAdvancedSettingsDesc")
	public let consumableWeightAdvancedSettings: Bool = false;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumableWeight")
	@runtimeProperty("ModSettings.category.order", "180")
	@runtimeProperty("ModSettings.dependency", "consumableWeightAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsConsumablesModifyWeight")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsEconomicDesc")
	@runtimeProperty("ModSettings.displayValues.DontModify", "DarkFutureSettingItemsEconomicDontModify")
	@runtimeProperty("ModSettings.displayValues.Modify", "DarkFutureSettingItemsEconomicModify")
	public let consumableWeightsModify: DFEconomicSetting = DFEconomicSetting.Modify;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumableWeight")
	@runtimeProperty("ModSettings.category.order", "180")
	@runtimeProperty("ModSettings.dependency", "consumableWeightAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsWeightFoodVerySmall")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsWeightGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.1")
	@runtimeProperty("ModSettings.min", "0.0")
	@runtimeProperty("ModSettings.max", "10.0")
	public let weightFoodVerySmall: Float = 0.6;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumableWeight")
	@runtimeProperty("ModSettings.category.order", "180")
	@runtimeProperty("ModSettings.dependency", "consumableWeightAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsWeightFoodSmall")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsWeightGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.1")
	@runtimeProperty("ModSettings.min", "0.0")
	@runtimeProperty("ModSettings.max", "10.0")
	public let weightFoodSmall: Float = 1.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumableWeight")
	@runtimeProperty("ModSettings.category.order", "180")
	@runtimeProperty("ModSettings.dependency", "consumableWeightAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsWeightFoodMedium")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsWeightGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.1")
	@runtimeProperty("ModSettings.min", "0.0")
	@runtimeProperty("ModSettings.max", "10.0")
	public let weightFoodMedium: Float = 1.2;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumableWeight")
	@runtimeProperty("ModSettings.category.order", "180")
	@runtimeProperty("ModSettings.dependency", "consumableWeightAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsWeightFoodLarge")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsWeightGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.1")
	@runtimeProperty("ModSettings.min", "0.0")
	@runtimeProperty("ModSettings.max", "10.0")
	public let weightFoodLarge: Float = 1.6;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumableWeight")
	@runtimeProperty("ModSettings.category.order", "180")
	@runtimeProperty("ModSettings.dependency", "consumableWeightAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsWeightDrinkSmall")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsWeightGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.1")
	@runtimeProperty("ModSettings.min", "0.0")
	@runtimeProperty("ModSettings.max", "10.0")
	public let weightDrinkSmall: Float = 0.8;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumableWeight")
	@runtimeProperty("ModSettings.category.order", "180")
	@runtimeProperty("ModSettings.dependency", "consumableWeightAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsWeightDrinkLarge")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsWeightGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.1")
	@runtimeProperty("ModSettings.min", "0.0")
	@runtimeProperty("ModSettings.max", "10.0")
	public let weightDrinkLarge: Float = 1.2;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumableWeight")
	@runtimeProperty("ModSettings.category.order", "180")
	@runtimeProperty("ModSettings.dependency", "consumableWeightAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsWeightDrugSmall")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsWeightGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.1")
	@runtimeProperty("ModSettings.min", "0.0")
	@runtimeProperty("ModSettings.max", "10.0")
	public let weightDrugSmall: Float = 0.3;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumableWeight")
	@runtimeProperty("ModSettings.category.order", "180")
	@runtimeProperty("ModSettings.dependency", "consumableWeightAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsWeightDrugMedium")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsWeightGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.1")
	@runtimeProperty("ModSettings.min", "0.0")
	@runtimeProperty("ModSettings.max", "10.0")
	public let weightDrugMedium: Float = 0.6;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumableWeight")
	@runtimeProperty("ModSettings.category.order", "180")
	@runtimeProperty("ModSettings.dependency", "consumableWeightAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsWeightDrugLarge")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsWeightGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.1")
	@runtimeProperty("ModSettings.min", "0.0")
	@runtimeProperty("ModSettings.max", "10.0")
	public let weightDrugLarge: Float = 1.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumableWeight")
	@runtimeProperty("ModSettings.category.order", "180")
	@runtimeProperty("ModSettings.dependency", "consumableWeightAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsWeightDrugTraumaKit")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsWeightGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.1")
	@runtimeProperty("ModSettings.min", "0.0")
	@runtimeProperty("ModSettings.max", "10.0")
	public let weightTraumaKit: Float = 2.0;

	// -------------------------------------------------------------------------
	// Advanced - Consumable Prices
	// -------------------------------------------------------------------------
	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumablePrice")
	@runtimeProperty("ModSettings.category.order", "185")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingAdvancedSettings")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingAdvancedSettingsDesc")
	public let consumablePricesAdvancedSettings: Bool = false;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumablePrice")
	@runtimeProperty("ModSettings.category.order", "185")
	@runtimeProperty("ModSettings.dependency", "consumablePricesAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsConsumablesModifyPrice")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsEconomicDesc")
	@runtimeProperty("ModSettings.displayValues.DontModify", "DarkFutureSettingItemsEconomicDontModify")
	@runtimeProperty("ModSettings.displayValues.Modify", "DarkFutureSettingItemsEconomicModify")
	public let consumablePricesModify: DFEconomicSetting = DFEconomicSetting.Modify;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumablePrice")
	@runtimeProperty("ModSettings.category.order", "185")
	@runtimeProperty("ModSettings.dependency", "consumablePricesAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsPriceDrinkNomad")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsPriceGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.05")
	@runtimeProperty("ModSettings.min", "0.05")
	@runtimeProperty("ModSettings.max", "100.0")
	public let priceDrinkNomad: Float = 0.65;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumablePrice")
	@runtimeProperty("ModSettings.category.order", "185")
	@runtimeProperty("ModSettings.dependency", "consumablePricesAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsPriceDrinkCommon")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsPriceGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.05")
	@runtimeProperty("ModSettings.min", "0.05")
	@runtimeProperty("ModSettings.max", "100.0")
	public let priceDrinkCommon: Float = 1.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumablePrice")
	@runtimeProperty("ModSettings.category.order", "185")
	@runtimeProperty("ModSettings.dependency", "consumablePricesAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsPriceDrinkUncommon")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsPriceGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.05")
	@runtimeProperty("ModSettings.min", "0.05")
	@runtimeProperty("ModSettings.max", "100.0")
	public let priceDrinkUncommon: Float = 1.25;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumablePrice")
	@runtimeProperty("ModSettings.category.order", "185")
	@runtimeProperty("ModSettings.dependency", "consumablePricesAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsPriceDrinkRare")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsPriceGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.05")
	@runtimeProperty("ModSettings.min", "0.05")
	@runtimeProperty("ModSettings.max", "100.0")
	public let priceDrinkRare: Float = 2.5;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumablePrice")
	@runtimeProperty("ModSettings.category.order", "185")
	@runtimeProperty("ModSettings.dependency", "consumablePricesAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsPriceDrinkEpic")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsPriceGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.05")
	@runtimeProperty("ModSettings.min", "0.05")
	@runtimeProperty("ModSettings.max", "100.0")
	public let priceDrinkEpic: Float = 4.4;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumablePrice")
	@runtimeProperty("ModSettings.category.order", "185")
	@runtimeProperty("ModSettings.dependency", "consumablePricesAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsPriceDrinkLegendary")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsPriceGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.05")
	@runtimeProperty("ModSettings.min", "0.05")
	@runtimeProperty("ModSettings.max", "100.0")
	public let priceDrinkLegendary: Float = 10.25;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumablePrice")
	@runtimeProperty("ModSettings.category.order", "185")
	@runtimeProperty("ModSettings.dependency", "consumablePricesAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsPriceDrinkIllegal")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsPriceGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.05")
	@runtimeProperty("ModSettings.min", "0.05")
	@runtimeProperty("ModSettings.max", "100.0")
	public let priceDrinkIllegal: Float = 31.25;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumablePrice")
	@runtimeProperty("ModSettings.category.order", "185")
	@runtimeProperty("ModSettings.dependency", "consumablePricesAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsPriceFoodNomad")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsPriceGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.05")
	@runtimeProperty("ModSettings.min", "0.05")
	@runtimeProperty("ModSettings.max", "100.0")
	public let priceFoodNomad: Float = 1.5;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumablePrice")
	@runtimeProperty("ModSettings.category.order", "185")
	@runtimeProperty("ModSettings.dependency", "consumablePricesAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsPriceFoodCommonSmallSnack")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsPriceGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.05")
	@runtimeProperty("ModSettings.min", "0.05")
	@runtimeProperty("ModSettings.max", "100.0")
	public let priceFoodCommonSnackSmall: Float = 1.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumablePrice")
	@runtimeProperty("ModSettings.category.order", "185")
	@runtimeProperty("ModSettings.dependency", "consumablePricesAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsPriceFoodCommonLargeSnack")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsPriceGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.05")
	@runtimeProperty("ModSettings.min", "0.05")
	@runtimeProperty("ModSettings.max", "100.0")
	public let priceFoodCommonSnackLarge: Float = 1.5;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumablePrice")
	@runtimeProperty("ModSettings.category.order", "185")
	@runtimeProperty("ModSettings.dependency", "consumablePricesAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsPriceFoodCommonMeal")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsPriceGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.05")
	@runtimeProperty("ModSettings.min", "0.05")
	@runtimeProperty("ModSettings.max", "100.0")
	public let priceFoodCommonMeal: Float = 2.5;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumablePrice")
	@runtimeProperty("ModSettings.category.order", "185")
	@runtimeProperty("ModSettings.dependency", "consumablePricesAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsPriceFoodUncommon")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsPriceGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.05")
	@runtimeProperty("ModSettings.min", "0.05")
	@runtimeProperty("ModSettings.max", "100.0")
	public let priceFoodUncommon: Float = 3.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumablePrice")
	@runtimeProperty("ModSettings.category.order", "185")
	@runtimeProperty("ModSettings.dependency", "consumablePricesAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsPriceFoodRare")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsPriceGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.05")
	@runtimeProperty("ModSettings.min", "0.05")
	@runtimeProperty("ModSettings.max", "100.0")
	public let priceFoodRare: Float = 5.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumablePrice")
	@runtimeProperty("ModSettings.category.order", "185")
	@runtimeProperty("ModSettings.dependency", "consumablePricesAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsPriceFoodEpic")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsPriceGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.05")
	@runtimeProperty("ModSettings.min", "0.05")
	@runtimeProperty("ModSettings.max", "100.0")
	public let priceFoodEpic: Float = 9.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumablePrice")
	@runtimeProperty("ModSettings.category.order", "185")
	@runtimeProperty("ModSettings.dependency", "consumablePricesAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsPriceFoodLegendarySnack")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsPriceGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.05")
	@runtimeProperty("ModSettings.min", "0.05")
	@runtimeProperty("ModSettings.max", "100.0")
	public let priceFoodIllegalSnack: Float = 50.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumablePrice")
	@runtimeProperty("ModSettings.category.order", "185")
	@runtimeProperty("ModSettings.dependency", "consumablePricesAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsPriceFoodLegendaryMeal")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsPriceGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.05")
	@runtimeProperty("ModSettings.min", "0.05")
	@runtimeProperty("ModSettings.max", "100.0")
	public let priceFoodIllegalMeal: Float = 75.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumablePrice")
	@runtimeProperty("ModSettings.category.order", "185")
	@runtimeProperty("ModSettings.dependency", "consumablePricesAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsPriceAlcoholLowQuality")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsPriceGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.05")
	@runtimeProperty("ModSettings.min", "0.05")
	@runtimeProperty("ModSettings.max", "100.0")
	public let priceAlcoholLowQuality: Float = 1.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumablePrice")
	@runtimeProperty("ModSettings.category.order", "185")
	@runtimeProperty("ModSettings.dependency", "consumablePricesAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsPriceAlcoholMediumQuality")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsPriceGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.05")
	@runtimeProperty("ModSettings.min", "0.05")
	@runtimeProperty("ModSettings.max", "100.0")
	public let priceAlcoholMediumQuality: Float = 2.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumablePrice")
	@runtimeProperty("ModSettings.category.order", "185")
	@runtimeProperty("ModSettings.dependency", "consumablePricesAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsPriceAlcoholGoodQuality")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsPriceGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.05")
	@runtimeProperty("ModSettings.min", "0.05")
	@runtimeProperty("ModSettings.max", "100.0")
	public let priceAlcoholGoodQuality: Float = 3.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumablePrice")
	@runtimeProperty("ModSettings.category.order", "185")
	@runtimeProperty("ModSettings.dependency", "consumablePricesAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsPriceAlcoholTopQuality")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsPriceGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.05")
	@runtimeProperty("ModSettings.min", "0.05")
	@runtimeProperty("ModSettings.max", "100.0")
	public let priceAlcoholTopQuality: Float = 5.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumablePrice")
	@runtimeProperty("ModSettings.category.order", "185")
	@runtimeProperty("ModSettings.dependency", "consumablePricesAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsPriceAlcoholExquisiteQuality")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsPriceGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.05")
	@runtimeProperty("ModSettings.min", "0.05")
	@runtimeProperty("ModSettings.max", "100.0")
	public let priceAlcoholExquisiteQuality: Float = 10.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumablePrice")
	@runtimeProperty("ModSettings.category.order", "185")
	@runtimeProperty("ModSettings.dependency", "consumablePricesAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsPriceMrWhitey")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsPriceGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.05")
	@runtimeProperty("ModSettings.min", "0.05")
	@runtimeProperty("ModSettings.max", "100.0")
	public let priceMrWhitey: Float = 7.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumablePrice")
	@runtimeProperty("ModSettings.category.order", "185")
	@runtimeProperty("ModSettings.dependency", "consumablePricesAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsPricePharmaceuticals")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsPriceGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.05")
	@runtimeProperty("ModSettings.min", "0.05")
	@runtimeProperty("ModSettings.max", "100.0")
	public let pricePharmaceuticals: Float = 1.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsConsumablePrice")
	@runtimeProperty("ModSettings.category.order", "185")
	@runtimeProperty("ModSettings.dependency", "consumablePricesAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsPriceDrugsIllegal")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsPriceGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.05")
	@runtimeProperty("ModSettings.min", "0.05")
	@runtimeProperty("ModSettings.max", "100.0")
	public let priceIllegalDrugs: Float = 1.0;

	// -------------------------------------------------------------------------
	// Advanced - Ammo
	// -------------------------------------------------------------------------
	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsAmmo")
	@runtimeProperty("ModSettings.category.order", "190")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingAdvancedSettings")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingAdvancedSettingsDesc")
	public let ammoAdvancedSettings: Bool = false;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsAmmo")
	@runtimeProperty("ModSettings.category.order", "190")
	@runtimeProperty("ModSettings.dependency", "ammoAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsAmmoWeight")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsAmmoWeightDesc")
	@runtimeProperty("ModSettings.displayValues.Disabled", "DarkFutureSettingItemsAmmoWeightDisabled")
    @runtimeProperty("ModSettings.displayValues.EnabledLimitedAmmo", "DarkFutureSettingItemsAmmoWeightEnabledLimitedAmmo")
	@runtimeProperty("ModSettings.displayValues.EnabledUnlimitedAmmo", "DarkFutureSettingItemsAmmoWeightEnabledUnlimitedAmmo")
	public let ammoWeightEnabledV2: DFAmmoWeightSetting = DFAmmoWeightSetting.Disabled;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsAmmo")
	@runtimeProperty("ModSettings.category.order", "190")
	@runtimeProperty("ModSettings.dependency", "ammoAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsAmmoCrafting")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsAmmoCraftingDesc")
	public let ammoCraftingEnabled: Bool = true;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsAmmo")
	@runtimeProperty("ModSettings.category.order", "190")
	@runtimeProperty("ModSettings.dependency", "ammoAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsAmmoHandicapDrops")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsAmmoHandicapDropsDesc")
	@runtimeProperty("ModSettings.displayValues.DontModify", "DarkFutureSettingItemsAmmoHandicapDropsDontModify")
    @runtimeProperty("ModSettings.displayValues.Disabled", "DarkFutureSettingItemsAmmoHandicapDropsDisabled")
	@runtimeProperty("ModSettings.displayValues.Enabled", "DarkFutureSettingItemsAmmoHandicapDropsEnabled")
	public let ammoHandicapDrops: DFAmmoHandicapSetting = DFAmmoHandicapSetting.DontModify;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsAmmo")
	@runtimeProperty("ModSettings.category.order", "190")
	@runtimeProperty("ModSettings.dependency", "ammoAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsWeightAmmoHandgun")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsWeightGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.01")
	@runtimeProperty("ModSettings.min", "0.0")
	@runtimeProperty("ModSettings.max", "0.5")
	public let weightHandgunAmmo: Float = 0.01;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsAmmo")
	@runtimeProperty("ModSettings.category.order", "190")
	@runtimeProperty("ModSettings.dependency", "ammoAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsWeightAmmoRifle")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsWeightGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.01")
	@runtimeProperty("ModSettings.min", "0.0")
	@runtimeProperty("ModSettings.max", "0.5")
	public let weightRifleAmmo: Float = 0.01;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsAmmo")
	@runtimeProperty("ModSettings.category.order", "190")
	@runtimeProperty("ModSettings.dependency", "ammoAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsWeightAmmoShotgun")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsWeightGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.01")
	@runtimeProperty("ModSettings.min", "0.0")
	@runtimeProperty("ModSettings.max", "0.5")
	public let weightShotgunAmmo: Float = 0.03;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsAmmo")
	@runtimeProperty("ModSettings.category.order", "190")
	@runtimeProperty("ModSettings.dependency", "ammoAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsWeightAmmoSniper")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsWeightGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.01")
	@runtimeProperty("ModSettings.min", "0.0")
	@runtimeProperty("ModSettings.max", "0.5")
	public let weightSniperAmmo: Float = 0.05;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsAmmo")
	@runtimeProperty("ModSettings.category.order", "190")
	@runtimeProperty("ModSettings.dependency", "ammoAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsAmmoModifyPrice")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsEconomicDesc")
	@runtimeProperty("ModSettings.displayValues.DontModify", "DarkFutureSettingItemsEconomicDontModify")
	@runtimeProperty("ModSettings.displayValues.Modify", "DarkFutureSettingItemsEconomicModify")
	public let ammoPriceModify: DFEconomicSetting = DFEconomicSetting.Modify;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsAmmo")
	@runtimeProperty("ModSettings.category.order", "190")
	@runtimeProperty("ModSettings.dependency", "ammoAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsPriceAmmoHandgun")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsPriceGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.1")
	@runtimeProperty("ModSettings.min", "0.1")
	@runtimeProperty("ModSettings.max", "10.0")
	public let priceHandgunAmmo: Float = 1.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsAmmo")
	@runtimeProperty("ModSettings.category.order", "190")
	@runtimeProperty("ModSettings.dependency", "ammoAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsPriceAmmoRifle")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsPriceGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.1")
	@runtimeProperty("ModSettings.min", "0.1")
	@runtimeProperty("ModSettings.max", "10.0")
	public let priceRifleAmmo: Float = 1.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsAmmo")
	@runtimeProperty("ModSettings.category.order", "190")
	@runtimeProperty("ModSettings.dependency", "ammoAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsPriceAmmoShotgun")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsPriceGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.1")
	@runtimeProperty("ModSettings.min", "0.1")
	@runtimeProperty("ModSettings.max", "10.0")
	public let priceShotgunAmmo: Float = 1.5;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsAmmo")
	@runtimeProperty("ModSettings.category.order", "190")
	@runtimeProperty("ModSettings.dependency", "ammoAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsPriceAmmoSniper")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsPriceGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.1")
	@runtimeProperty("ModSettings.min", "0.1")
	@runtimeProperty("ModSettings.max", "10.0")
	public let priceSniperAmmo: Float = 2.0;

	@runtimeProperty("ModSettings.mod", "DarkFutureSettingsModName_Core")
	@runtimeProperty("ModSettings.category", "DarkFutureSettingsCategoryItemsAmmo")
	@runtimeProperty("ModSettings.category.order", "190")
	@runtimeProperty("ModSettings.dependency", "ammoAdvancedSettings")
	@runtimeProperty("ModSettings.displayName", "DarkFutureSettingItemsPriceAmmoSell")
	@runtimeProperty("ModSettings.description", "DarkFutureSettingItemsPriceGeneralDesc")
	@runtimeProperty("ModSettings.step", "0.1")
	@runtimeProperty("ModSettings.min", "0.1")
	@runtimeProperty("ModSettings.max", "10.0")
	public let priceAmmoSellMult: Float = 0.5;
}
