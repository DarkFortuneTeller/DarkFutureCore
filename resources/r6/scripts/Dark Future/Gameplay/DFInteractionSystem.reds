// -----------------------------------------------------------------------------
// DFInteractionSystem
// -----------------------------------------------------------------------------
//
// - Gameplay System that handles various player-initiated interactions,
//	 particularly actions in V's apartments. Correctly grants bonuses,
//   applies effects, and so on as if an item had been consumed.
//
// - Also handles the bulk of Time Skip logic, which is fairly complex.
//

module DarkFutureCore.Gameplay

import DarkFutureCore.Logging.*
import DarkFutureCore.System.*
import DarkFutureCore.DelayHelper.*
import DarkFutureCore.Settings.*
import DarkFutureCore.Utils.{
	DFRunGuard,
	DFIsSleeping,
	HoursToGameTimeSeconds
}
import DarkFutureCore.Main.{
	DFMainSystem,
	DFNeedsDatum,
	DFAddictionDatum,
	DFAddictionUpdateDatum,
	DFHumanityLossDatum,
	DFFutureHoursData,
	DFNeedChangeDatum,
	DFTimeSkipData,
	DFTimeSkipType,
	DFTempEnergyItemType
}
import DarkFutureCore.Services.{
	DFGameStateService,
	DFPlayerStateService,
	DFNotificationService,
	DFNotification,
	DFAudioCue,
	DFVisualEffect,
	DFNotificationCallback
}
import DarkFutureCore.Needs.{
	DFHydrationSystem,
	DFNutritionSystem,
	DFEnergySystem,
	DFNeedChangeUIFlags,
	DFChangeNeedValueProps
}

//	QuestTrackerGameController - Detect quest objective updates.
//
@wrapMethod(QuestTrackerGameController)
protected cb func OnStateChanges(hash: Uint32, className: CName, notifyOption: JournalNotifyOption, changeType: JournalChangeType) -> Bool {
	//DFProfile();
	if Equals(className, n"gameJournalQuestObjective") {
		DFInteractionSystem.Get().OnQuestObjectiveUpdate(hash);
	}
	
	return wrappedMethod(hash, className, notifyOption, changeType);
}

public struct DFAddictionTimeSkipIterationStateDatum {
	public let addictionAmount: Float;
	public let addictionStage: Int32;
	public let primaryEffectDuration: Float;
	public let backoffDuration: Float;
	public let withdrawalLevel: Int32;
	public let withdrawalDuration: Float;
	public let stackCount: Uint32;
	public let isWithdrawalLevelWorsened: Bool;
}

public struct DFHumanityLossTimeSkipIterationStateDatum {
	public let level: Uint32;
	public let newTimeUntilNextCyberpsychosisAllowed: Float;
	public let newEndotrisineDuration: Float;
}

public struct DFJournalEntryUpdate {
	public let questID: String;
	public let phaseID: String;
	public let entryID: String;
	public let state: gameJournalEntryState;
}

public class DFInteractionSystemClearLastAttemptedChoiceForFXCheckCallback extends DFDelayCallback {
	public let InteractionSystem: wref<DFInteractionSystem>;

	public static func Create(interactionSystem: wref<DFInteractionSystem>) -> ref<DFDelayCallback> {
		//DFProfile();
		let self: ref<DFInteractionSystemClearLastAttemptedChoiceForFXCheckCallback> = new DFInteractionSystemClearLastAttemptedChoiceForFXCheckCallback();
		self.InteractionSystem = interactionSystem;
		return self;
	}

	public func InvalidateDelayID() -> Void {
		//DFProfile();
		this.InteractionSystem.clearLastAttemptedChoiceForFXCheckDelayID = GetInvalidDelayID();
	}

	public func Callback() -> Void {
		//DFProfile();
		this.InteractionSystem.OnClearLastAttemptedChoiceForFXCheck();
	}
}

@wrapMethod(PlayerPuppet)
protected cb func OnStatusEffectApplied(evt: ref<ApplyStatusEffectEvent>) -> Bool {
	//DFProfile();
	let interactionSystem: ref<DFInteractionSystem> = DFInteractionSystem.Get();
	let effectID: TweakDBID = evt.staticData.GetID();

	if IsSystemEnabledAndRunning(interactionSystem) {		
		if Equals(effectID, t"HousingStatusEffect.Energized") {
			interactionSystem.DrankCoffeeFromChoice();
		}
	}

	return wrappedMethod(evt);
}

class DFInteractionSystemEventListener extends DFSystemEventListener {
	private func GetSystemInstance() -> wref<DFInteractionSystem> {
		//DFProfile();
		return DFInteractionSystem.Get();
	}
}

public final class DFInteractionSystem extends DFSystem {
	private let MainSystem: ref<DFMainSystem>;
    private let GameStateService: ref<DFGameStateService>;
	private let PlayerStateService: ref<DFPlayerStateService>;
	private let NotificationService: ref<DFNotificationService>;
    private let HydrationSystem: ref<DFHydrationSystem>;
	private let NutritionSystem: ref<DFNutritionSystem>;
	private let EnergySystem: ref<DFEnergySystem>;
	private let VehicleSleepSystem: ref<DFVehicleSleepSystem>;

	private let QuestsSystem: ref<QuestsSystem>;
    private let BlackboardSystem: ref<BlackboardSystem>;
    private let UIInteractionsBlackboard: ref<IBlackboard>;

    private let choiceListener: ref<CallbackHandle>;
	private let choiceHubListener: ref<CallbackHandle>;

    private let lastAttemptedChoiceCaption: String;
	private let lastAttemptedChoiceIconName: CName;

    public let clearLastAttemptedChoiceForFXCheckDelayID: DelayID;
    private let clearLastAttemptedChoiceForFXCheckDelayInterval: Float = 10.0;

    // Location Memory from Prompts
	private let lastCoffeePosition: Vector4;

	// Sleeping and Waiting
	private let skippingTimeFromHubMenu: Bool = false;
	private let lastEnergyBeforeSleeping: Float = 0.0;

	private let sleepingReduceMetabolismMult: Float = 0.4;

	public let vomitFromInteractionChoiceStage2DelayID: DelayID;
	private let vomitFromInteractionChoiceStage2DelayInterval: Float = 1.5;

	// Quest-related Sleep Journal Entry Updates
	private let journalEntryUpdate_Sleep_sq026: DFJournalEntryUpdate;
	private let journalEntryUpdate_Sleep_sq027: DFJournalEntryUpdate;
	private let journalEntryUpdate_Sleep_sq030: DFJournalEntryUpdate;
	private let journalEntryUpdate_Sleep_q302: DFJournalEntryUpdate;
	private let journalEntryUpdate_Sleep_sq029: DFJournalEntryUpdate;
	private let journalEntryUpdate_Sleep_sq021: DFJournalEntryUpdate;
	private let journalEntryUpdate_Sleep_q103a: DFJournalEntryUpdate;
	private let journalEntryUpdate_Sleep_q103b: DFJournalEntryUpdate;
	private let journalEntryUpdate_Sleep_sq004: DFJournalEntryUpdate;

	// See: darkfuture/localization_interactions/*/onscreens/darkfuture_interactions_donotmodify.json
	private const let locKey_Interaction_Sleep_BaseGame: CName = n"DarkFutureInteraction_mq000_01_apartment_Sleep";
	private const let locKey_Interaction_Sleep_KressStreet: CName = n"DarkFutureInteraction_mq300_safehouse_Sleep";
	public const let locKey_Interaction_EnterRollercoaster: CName = n"DarkFutureInteraction_mq006_02_finale_EnterRollercoaster";
	private const let locKey_Interaction_Eat: CName = n"DarkFutureInteraction_q112_01_market_02_Eat";
	private const let locKey_Interaction_Q303SitAndDrink: CName = n"DarkFutureInteraction_q303_04_SitAndDrink";
	private const let locKey_Interaction_CoffeeDrink: CName = n"DarkFutureInteraction_sq017_06_capitan_caliente_Drink";
	private const let locKey_Interaction_DLC6DrinkTea: CName = n"DarkFutureInteraction_dlc6_apart_cct_dtn_DrinkTea";

    public final static func GetInstance(gameInstance: GameInstance) -> ref<DFInteractionSystem> {
		//DFProfile();
		let instance: ref<DFInteractionSystem> = GameInstance.GetScriptableSystemsContainer(gameInstance).Get(NameOf<DFInteractionSystem>()) as DFInteractionSystem;
		return instance;
	}

	public final static func Get() -> ref<DFInteractionSystem> {
		//DFProfile();
		return DFInteractionSystem.GetInstance(GetGameInstance());
	}

	public final func DoPostSuspendActions() -> Void {
		//DFProfile();
		this.lastAttemptedChoiceCaption = "";
		this.lastAttemptedChoiceIconName = n"";
		this.lastCoffeePosition = Vector4(0.0, 0.0, 0.0, 0.0);
		this.skippingTimeFromHubMenu = false;
		this.lastEnergyBeforeSleeping = 0.0;
	}
	public final func DoPostResumeActions() -> Void {}
	private final func SetupDebugLogging() -> Void {
		//DFProfile();
		this.debugEnabled = false;
	}

	public final func SetupData() -> Void {
		//DFProfile();
		this.journalEntryUpdate_Sleep_sq026 = DFJournalEntryUpdate("sq026_03_pizza", "01_pizza_night", "breakfast", gameJournalEntryState.Active);
		this.journalEntryUpdate_Sleep_sq027 = DFJournalEntryUpdate("sq027_01_basilisk_convoy", "03_ambush", "get_in_car", gameJournalEntryState.Active);
		this.journalEntryUpdate_Sleep_sq030 = DFJournalEntryUpdate("sq030_judy_romance", "hut", "stuff1", gameJournalEntryState.Active);
		this.journalEntryUpdate_Sleep_q302 = DFJournalEntryUpdate("q302_reed", "04_squot", "follow_myers3", gameJournalEntryState.Succeeded);
		this.journalEntryUpdate_Sleep_sq029 = DFJournalEntryUpdate("sq029_sobchak_romance", "breakfast", "talk_with_river", gameJournalEntryState.Active);
		this.journalEntryUpdate_Sleep_sq021 = DFJournalEntryUpdate("sq021_sick_dreams", "bbq", "sleep", gameJournalEntryState.Succeeded);
		this.journalEntryUpdate_Sleep_q103a = DFJournalEntryUpdate("q103_warhead", "roadhouse", "bed_upstairs", gameJournalEntryState.Succeeded);
		this.journalEntryUpdate_Sleep_q103b = DFJournalEntryUpdate("q103_warhead", "roadhouse", "bed_downstairs", gameJournalEntryState.Succeeded);
		this.journalEntryUpdate_Sleep_sq004 = DFJournalEntryUpdate("sq004_riders_on_the_storm", "03_escape", "panam_talk", gameJournalEntryState.Succeeded);
	}

	private final func RegisterAllRequiredDelayCallbacks() -> Void {}
	public final func OnTimeSkipStart() -> Void {}
	public final func OnTimeSkipCancelled() -> Void {}
	public final func OnTimeSkipFinished(data: DFTimeSkipData) -> Void {}
	public final func OnSettingChangedSpecific(changedSettings: array<String>) -> Void {}
    public final func InitSpecific(attachedPlayer: ref<PlayerPuppet>) -> Void {}

	public func GetSystemToggleSettingValue() -> Bool {
		//DFProfile();
        // This system does not have a system-specific toggle.
		return true;
    }

	private final func GetSystemToggleSettingString() -> String {
		//DFProfile();
		// This system does not have a system-specific toggle.
        return "INVALID";
    }

	public final func GetSystems() -> Void {
		//DFProfile();
		let gameInstance = GetGameInstance();
		
		this.MainSystem = DFMainSystem.GetInstance(gameInstance);
        this.GameStateService = DFGameStateService.GetInstance(gameInstance);
		this.PlayerStateService = DFPlayerStateService.GetInstance(gameInstance);
		this.NotificationService = DFNotificationService.GetInstance(gameInstance);
        this.HydrationSystem = DFHydrationSystem.GetInstance(gameInstance);
		this.NutritionSystem = DFNutritionSystem.GetInstance(gameInstance);
		this.EnergySystem = DFEnergySystem.GetInstance(gameInstance);
		this.VehicleSleepSystem = DFVehicleSleepSystem.GetInstance(gameInstance);
        this.BlackboardSystem = GameInstance.GetBlackboardSystem(gameInstance);
		this.QuestsSystem = GameInstance.GetQuestsSystem(gameInstance);
	}

	private final func GetBlackboards(attachedPlayer: ref<PlayerPuppet>) -> Void {
		//DFProfile();
		this.UIInteractionsBlackboard = this.BlackboardSystem.Get(GetAllBlackboardDefs().UIInteractions);
	}

	public final func UnregisterAllDelayCallbacks() -> Void {
		//DFProfile();
		this.UnregisterClearLastAttemptedChoiceForFXCheckCallback();
		this.UnregisterVomitFromInteractionChoiceStage2Callback();
	}

    private final func RegisterListeners() -> Void {
		//DFProfile();
        this.RegisterChoiceListener();
        this.RegisterChoiceHubListener();
    }

    private final func UnregisterListeners() -> Void {
		//DFProfile();
        this.UnregisterChoiceListener();
        this.UnregisterChoiceHubListener();
    }

    private final func RegisterChoiceListener() -> Void {
		//DFProfile();
		this.choiceListener = this.UIInteractionsBlackboard.RegisterListenerVariant(GetAllBlackboardDefs().UIInteractions.LastAttemptedChoice, this, n"OnLastAttemptedChoice");
	}

    private final func RegisterChoiceHubListener() -> Void {
		//DFProfile();
		this.choiceHubListener = this.UIInteractionsBlackboard.RegisterListenerVariant(GetAllBlackboardDefs().UIInteractions.DialogChoiceHubs, this, n"OnChoiceHub");
	}

    private final func UnregisterChoiceListener() -> Void {
		//DFProfile();
		this.UIInteractionsBlackboard.UnregisterListenerVariant(GetAllBlackboardDefs().UIInteractions.LastAttemptedChoice, this.choiceListener);
	}

	private final func UnregisterChoiceHubListener() -> Void {
		//DFProfile();
		this.UIInteractionsBlackboard.UnregisterListenerVariant(GetAllBlackboardDefs().UIInteractions.DialogChoiceHubs, this.choiceHubListener);
	}

    //
    //  Interaction Choices
    //
    private final func IsSleepChoice(choiceCaption: String, choiceIconName: CName) -> Bool {
		//DFProfile();
		if (Equals(choiceCaption, GetLocalizedTextByKey(this.locKey_Interaction_Sleep_BaseGame)) || Equals(choiceCaption, GetLocalizedTextByKey(this.locKey_Interaction_Sleep_KressStreet))) && Equals(choiceIconName, n"Wait") {
			return true;
		}

		return false;
	}

    private final func IsHydrationRestorationChoice(choiceCaption: String, choiceIconName: CName) -> Bool {
		//DFProfile();
		return this.IsDrinkTeaInCorpoPlazaChoice(choiceCaption) || this.IsDrinkTeaWithMrHandsChoice(choiceCaption);
	}

    private final func IsDrinkTeaInCorpoPlazaChoice(choiceCaption: String) -> Bool {
		//DFProfile();
		// Corpo Plaza Apartment Interaction
		if Equals(choiceCaption, GetLocalizedTextByKey(this.locKey_Interaction_DLC6DrinkTea)) {
			return true;
		}

		return false;
	}

	private final func IsDrinkTeaWithMrHandsChoice(choiceCaption: String) -> Bool {
		//DFProfile();
		// Phantom Liberty: Mr. Hands scene in Heavy Hearts Club
		if Equals(choiceCaption, GetLocalizedTextByKey(this.locKey_Interaction_Q303SitAndDrink)) {
			return true;
		}

		return false;
	}

    private final func IsDrinkCoffeeInDialogChoice(choiceCaption: String) -> Bool {
		//DFProfile();
		if Equals(choiceCaption, GetLocalizedTextByKey(this.locKey_Interaction_CoffeeDrink)) && Vector4.DistanceSquared(this.lastCoffeePosition, this.player.GetWorldPosition()) < 10.0 {
			return true;
		}

		return false;
	}

    private final func IsNutritionRestorationChoice(choiceCaption: String, choiceIconName: CName) -> Bool {
		//DFProfile();
		if Equals(choiceCaption, GetLocalizedTextByKey(this.locKey_Interaction_Eat)) {
			return true;
		}

		return false;
	}

	//
	//	Sleeping and Waiting
	//
	public final func SetSkippingTimeFromHubMenu(value: Bool) -> Void {
		//DFProfile();
		this.skippingTimeFromHubMenu = value;
	}

	public final func IsPlayerSleeping() -> Bool {
		//DFProfile();
		if !this.skippingTimeFromHubMenu && !this.IsImmersiveTimeskipActive() {
			return true;
		}

		return false;
	}

	public final func GetCalculatedValuesForFutureHours(timeSkipType: DFTimeSkipType) -> DFFutureHoursData {
		//DFProfile();
		let isSleeping: Bool = DFIsSleeping(timeSkipType);

		// Need Variables
		let calculatedBasicNeedsData: array<DFNeedsDatum>;
		let calculatedHydrationAtHour: Float = this.HydrationSystem.GetNeedValue();
		let calculatedNutritionAtHour: Float = this.NutritionSystem.GetNeedValue();
		let calculatedEnergyAtHour: Float = this.EnergySystem.GetNeedValue();

		// Energy Variables
		let energyRestoredFromEnergized: Float = this.EnergySystem.GetTotalEnergyRestoredFromEnergized();

		let i = 0;
		while i < 24 { // Iterate over each hour
			let needHydration = DFNeedChangeDatum(0.0, 0.0, 100.0, 0.0);
			let needNutrition = DFNeedChangeDatum(0.0, 0.0, 100.0, 0.0);
			let needEnergy = DFNeedChangeDatum(0.0, 0.0, 100.0, 0.0);

			let basicNeedsData: DFNeedsDatum;
			basicNeedsData.hydration = needHydration;
			basicNeedsData.nutrition = needNutrition;
			basicNeedsData.energy = needEnergy;

			// Accumulate all of the changes by iterating over each update cycle within the hour (60 / 12, or every 5 minutes)
			let j = 1;
			while j <= 12 {
				//
				// Nutrition and Hydration
				//
				let nutritionChangeTemp: Float = this.NutritionSystem.GetNutritionChange();
				let hydrationChangeTemp: Float = this.HydrationSystem.GetHydrationChange();

				if isSleeping {
					// Reduced metabolism - Reduce Nutrition and Hydration at reduced rate
					nutritionChangeTemp *= this.sleepingReduceMetabolismMult;
					hydrationChangeTemp *= this.sleepingReduceMetabolismMult;
				}

				calculatedNutritionAtHour = ClampF(calculatedNutritionAtHour + nutritionChangeTemp, 0.0, this.NutritionSystem.GetNeedMax());
				calculatedHydrationAtHour = ClampF(calculatedHydrationAtHour + hydrationChangeTemp, 0.0, this.HydrationSystem.GetNeedMax());
				
				//
				// Energy
				//
				let energyChangeTemp: Float = this.EnergySystem.GetEnergyChangeWithRecoverLimit(calculatedEnergyAtHour, timeSkipType);

				// Nuke any temporary Energy effects the player might have.
				energyChangeTemp -= energyRestoredFromEnergized;
				energyRestoredFromEnergized = 0.0;

				let energyMax: Float = this.EnergySystem.GetNeedMax();
				let calculatedEnergyAtHourBeforeNerveCalc = ClampF(calculatedEnergyAtHour + energyChangeTemp, 0.0, energyMax);

				//
				// Energy
				//
				calculatedEnergyAtHour = calculatedEnergyAtHourBeforeNerveCalc;

				j += 1;
			};

			// Store the target values for each need at this specific hour.
			basicNeedsData.energy.value = calculatedEnergyAtHour;
			basicNeedsData.nutrition.value = calculatedNutritionAtHour;
			basicNeedsData.hydration.value = calculatedHydrationAtHour;

			ArrayPush(calculatedBasicNeedsData, basicNeedsData);

			i += 1;
		};

		let dummyAddictionData: array<DFAddictionDatum>;
		let dummyHumanityLossData: array<DFHumanityLossDatum>;
		let calculatedData: DFFutureHoursData = DFFutureHoursData(calculatedBasicNeedsData, dummyAddictionData, dummyHumanityLossData);

		return calculatedData;
	}

    //
    //  Logic
    //
	public final func OnChoiceHub(value: Variant) {
		//DFProfile();
		if DFRunGuard(this) { return; }

		let hubs: DialogChoiceHubs = FromVariant<DialogChoiceHubs>(value);
		
		for hub in hubs.choiceHubs {
			DFLog(this, "Hub Title: " + GetLocalizedText(hub.title));
			if Equals(GetLocalizedText(hub.title), GetLocalizedTextByKey(n"Story-base-quest-side_quests-sq030-scenes-sq030_11_morning-sq030_11_ch_drink_displayNameOverride")) {
				// "Rebel! Rebel!" / "Pyramid Song" - Coffee with Kerry in Captain Caliente, coffee with Judy on the pier
				this.lastCoffeePosition = this.player.GetWorldPosition();
			}
		}
	}

    public final func OnLastAttemptedChoice(value: Variant) -> Void {
		//DFProfile();
		if DFRunGuard(this) { return; }

		let choiceData: InteractionAttemptedChoice = FromVariant<InteractionAttemptedChoice>(value);
		let choiceCaption: String = choiceData.choice.caption;
		let choiceCaptionParts: array<ref<InteractionChoiceCaptionPart>> = choiceData.choice.captionParts.parts;
		let choiceIconName: CName = n"";
		for part in choiceCaptionParts {
			let icon: wref<ChoiceCaptionIconPart_Record> = (part as InteractionChoiceCaptionIconPart).iconRecord;
			if IsDefined(icon) {
				choiceIconName = icon.EnumName();
			}
		}

		// Store the last attempted choice so that the Scene Tier Change event has an opportunity to check them.
		// Register for callback to clear these values shortly after.
		this.lastAttemptedChoiceCaption = choiceCaption;
		this.lastAttemptedChoiceIconName = choiceIconName;
		this.RegisterClearLastAttemptedChoiceForFXCheckCallback();

		if this.IsSleepChoice(choiceCaption, choiceIconName) {
			this.SleepChoiceSelected();
		
		} else if this.IsDrinkTeaInCorpoPlazaChoice(choiceCaption) {
			this.DrankTeaFromChoice();
		
		} else if this.IsDrinkTeaWithMrHandsChoice(choiceCaption) {
			this.DrankTeaFromChoice();

		} else if this.IsDrinkCoffeeInDialogChoice(choiceCaption) {
			this.DrankCoffeeFromChoice();

		} else if this.IsNutritionRestorationChoice(choiceCaption, choiceIconName) {
			this.NutritionSystem.QueueContextuallyDelayedNeedValueChange(20.0, true, false, t"DarkFutureStatusEffect.WellFed");
		}
	}

    public final func DrankCoffeeFromChoice() -> Void {
		//DFProfile();
		DFLog(this, "DrankCoffeeFromChoice");
		if this.GameStateService.IsValidGameState(this, true) {
			// Remove the base game Energized effect. It's no longer used in Dark Future due to being
			// functionally identical to Hydrated.
			if StatusEffectSystem.ObjectHasStatusEffect(this.player, t"HousingStatusEffect.Energized") {
				StatusEffectHelper.RemoveStatusEffect(this.player, t"HousingStatusEffect.Energized");
			}
			
			// Since the player can repeatedly activate the coffee machine to obtain max Hydration,
			// just grant all of it on the first use.
            this.HydrationSystem.QueueContextuallyDelayedNeedValueChange(100.0, true);

			// Treat the Energy restoration from the coffee machine like consuming normal coffee items.
			// Grant all stacks possible from coffee at once.
            this.EnergySystem.TryToApplyEnergizedStacks(this.EnergySystem.energizedMaxStacksFromCaffeine, DFTempEnergyItemType.Caffeine, true, true);
		}
	}

	public final func SmokedFromChoice() -> Void {
		//DFProfile();
		if this.GameStateService.IsValidGameState(this, true) {
			// Remove any pre-existing item effects.
			if StatusEffectSystem.ObjectHasStatusEffectWithTag(this.player, n"DarkFutureSmoking") {
				StatusEffectHelper.RemoveStatusEffectsWithTag(this.player, n"DarkFutureSmoking");
			}
			
			// Smoking status effect variant to suppress additional unneeded FX
			StatusEffectHelper.ApplyStatusEffect(this.player, t"DarkFutureStatusEffect.SmokingFromChoice");

			// Use Vargas Black Label as an example item when calculating the max override.
			let itemRecord: wref<Item_Record> = TweakDBInterface.GetItemRecord(t"DarkFutureItem.CigarettePackC");
			this.MainSystem.DispatchItemConsumedEvent(itemRecord, true, true);
		}
	}

	private final func SleepChoiceSelected() -> Void {
		//DFProfile();
		if this.GameStateService.IsValidGameState(this, true) {
			// Used to suppress VFX and notifications until the player gets up.
			this.GameStateService.SetInSleepCinematic(true);
		}
	}

    private final func DrankTeaFromChoice() -> Void {
		//DFProfile();
		if this.GameStateService.IsValidGameState(this, true) {
			this.HydrationSystem.QueueContextuallyDelayedNeedValueChange(100.0, true, false, t"DarkFutureStatusEffect.Sated");
		}
	}

    public final func ShouldAllowFX() -> Bool {
		//DFProfile();
		if this.GameStateService.IsValidGameState(this, true) {
			// Check if the last choice prompt we selected was part of an allowed workspot (sleeping, showering, etc)
			// If so, don't suppress VFX and SFX.
			if NotEquals(this.lastAttemptedChoiceCaption, "") {
				if this.IsSleepChoice(this.lastAttemptedChoiceCaption, this.lastAttemptedChoiceIconName) {
					return true;

				} else if this.IsHydrationRestorationChoice(this.lastAttemptedChoiceCaption, this.lastAttemptedChoiceIconName) {
					return true;

				} else if this.IsNutritionRestorationChoice(this.lastAttemptedChoiceCaption, this.lastAttemptedChoiceIconName) {
					return true;
				}

				return false;
			} else {
				return this.GameStateService.IsValidGameState(this);
			}
		} else {
			return false;
		}
	}

    public final func OnClearLastAttemptedChoiceForFXCheck() -> Void {
		//DFProfile();
		this.lastAttemptedChoiceCaption = "";
		this.lastAttemptedChoiceIconName = n"";
	}

	public final func GetLastAttemptedChoiceCaption() -> String {
		//DFProfile();
		return this.lastAttemptedChoiceCaption;
	}

	//
	// Misc
	//
	public final func OnQuestObjectiveUpdate(hash: Uint32) -> Void {
		//DFProfile();
		if DFRunGuard(this) { return; }

		let sleptDuringQuest: Bool = false;

		let gameInstance = GetGameInstance();
		let journalManager: ref<JournalManager> = GameInstance.GetJournalManager(gameInstance);

		let entry: wref<JournalEntry> = journalManager.GetEntry(hash);
		if IsDefined(entry) {
			let questPhase: wref<JournalQuestPhase> = journalManager.GetParentEntry(entry) as JournalQuestPhase;
			if IsDefined(questPhase) {
				let quest: wref<JournalQuest> = journalManager.GetParentEntry(questPhase) as JournalQuest;
				if IsDefined(quest) {
					let state: gameJournalEntryState = journalManager.GetEntryState(entry);
					// Check against Quest Objectives we care about.
					let journalEntryUpdate: DFJournalEntryUpdate;
					journalEntryUpdate.questID = quest.GetId();
					journalEntryUpdate.phaseID = questPhase.GetId();
					journalEntryUpdate.entryID = entry.GetId();
					journalEntryUpdate.state = state;

					DFLog(this, "questID: " + journalEntryUpdate.questID + ", phaseID: " + journalEntryUpdate.phaseID + ", entryID: " + journalEntryUpdate.entryID + ", state: " + ToString(journalEntryUpdate.state));

					if this.JournalEntryUpdateEquals(journalEntryUpdate, this.journalEntryUpdate_Sleep_sq026) {
						// Judy: Talkin' Bout A Revolution - Waking up after crashing on Judy's couch
						sleptDuringQuest = true;

					} else if this.JournalEntryUpdateEquals(journalEntryUpdate, this.journalEntryUpdate_Sleep_sq027) {
						// Panam: With A Little Help From My Friends - Waking up after sleeping under stars
						sleptDuringQuest = true;

					} else if this.JournalEntryUpdateEquals(journalEntryUpdate, this.journalEntryUpdate_Sleep_sq030) {
						// Judy: Pyramid Song - Waking up after sleeping in the cottage
						sleptDuringQuest = true;

					} else if this.JournalEntryUpdateEquals(journalEntryUpdate, this.journalEntryUpdate_Sleep_q302) {
						// Phantom Liberty: Lucretia My Reflection - Waking up after sleeping on the mattress in the safehouse
						sleptDuringQuest = true;

					} else if this.JournalEntryUpdateEquals(journalEntryUpdate, this.journalEntryUpdate_Sleep_sq029) {
						// River: Following the River - Waking up after spending the night at River's
						// River is always a friend after this quest, so we don't have to watch for a specific quest outcome.
						sleptDuringQuest = true;

					} else if this.JournalEntryUpdateEquals(journalEntryUpdate, this.journalEntryUpdate_Sleep_sq021) {
						// River: The Hunt - Waking up after sleeping at Joss' place
						sleptDuringQuest = true;
					
					} else if this.JournalEntryUpdateEquals(journalEntryUpdate, this.journalEntryUpdate_Sleep_q103a) {
						// Panam: Ghost Town - Slept in upstairs room of Sunset Motel
						sleptDuringQuest = true;

					} else if this.JournalEntryUpdateEquals(journalEntryUpdate, this.journalEntryUpdate_Sleep_q103b) {
						// Panam: Ghost Town - Slept in downstairs room of Sunset Motel
						sleptDuringQuest = true;
					
					} else if this.JournalEntryUpdateEquals(journalEntryUpdate, this.journalEntryUpdate_Sleep_sq004) {
						// Panam: Riders On The Storm - Slept in the abandoned farmhouse on the couch with Panam
						sleptDuringQuest = true;
					}
				}
			}
		}

		if sleptDuringQuest {
			this.SimulateSleepFromQuest();
		}
	}

	private final func JournalEntryUpdateEquals(journalUpdateA: DFJournalEntryUpdate, journalUpdateB: DFJournalEntryUpdate) -> Bool {
		//DFProfile();
		if Equals(journalUpdateA.questID, journalUpdateB.questID) && 
		   Equals(journalUpdateA.phaseID, journalUpdateB.phaseID) && 
		   Equals(journalUpdateA.entryID, journalUpdateB.entryID) && 
		   Equals(journalUpdateA.state, journalUpdateB.state) {
			return true;
		}
		return false;
	}

	public final func SimulateSleepFromQuest() -> Void {
		//DFProfile();
		this.EnergySystem.ClearEnergyManagementEffects();
		this.EnergySystem.QueueContextuallyDelayedNeedValueChange(100.0);
	}

    //
    //  Registration
    //
    private final func RegisterClearLastAttemptedChoiceForFXCheckCallback() -> Void {
		//DFProfile();
		RegisterDFDelayCallback(this.DelaySystem, DFInteractionSystemClearLastAttemptedChoiceForFXCheckCallback.Create(this), this.clearLastAttemptedChoiceForFXCheckDelayID, this.clearLastAttemptedChoiceForFXCheckDelayInterval);
	}

	//
	//	Unregistration
	//

	private final func UnregisterClearLastAttemptedChoiceForFXCheckCallback() -> Void {
		//DFProfile();
		UnregisterDFDelayCallback(this.DelaySystem, this.clearLastAttemptedChoiceForFXCheckDelayID);
	}

	private final func UnregisterVomitFromInteractionChoiceStage2Callback() -> Void {
		//DFProfile();
		UnregisterDFDelayCallback(this.DelaySystem, this.vomitFromInteractionChoiceStage2DelayID);
	}

	//
	//  Immersive Timeskip Detection
	//

	@if(ModuleExists("ImmersiveTimeskip.Hotkey"))
	private final func IsImmersiveTimeskipActive() -> Bool {
		//DFProfile();
		return this.player.itsTimeskipActive;
	}

	@if(!ModuleExists("ImmersiveTimeskip.Hotkey"))
	private final func IsImmersiveTimeskipActive() -> Bool {
		//DFProfile();
		return false;
	}
}
