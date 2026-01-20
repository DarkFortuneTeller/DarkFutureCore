// -----------------------------------------------------------------------------
// DFMainSystem
// -----------------------------------------------------------------------------
//
// - The Dark Future Main System.
// - Handles mod-wide system startup and shutdown.
//

module DarkFutureCore.Main

import DarkFutureCore.Logging.*
import DarkFutureCore.Settings.*
import DarkFutureCore.Services.{
    DFGameStateService,
    DFNotificationService,
    DFPlayerStateService,
    DFTutorial,
    DFUIDisplay,
    DFNotification
}
import DarkFutureCore.Gameplay.{
    DFInteractionSystem,
    DFVehicleSleepSystem,
    DFRandomEncounterSystem,
    DFStashCraftingSystem,
    DFModCompatSystem
}
import DarkFutureCore.Needs.{
    DFHydrationSystem,
    DFNutritionSystem,
    DFEnergySystem
}
import DarkFutureCore.UI.{
    DFHUDSystem,
    DFRevisedBackpackUISystem,
    DFHUDBarType
}

public struct DFNeedChangeDatum {
	public let value: Float;
	public let floor: Float;
	public let ceiling: Float;
    public let valueOnStatusEffectApply: Float;
}

public struct DFNeedsDatum {
  	public let hydration: DFNeedChangeDatum;
  	public let nutrition: DFNeedChangeDatum;
	public let energy: DFNeedChangeDatum;
	public let nerve: DFNeedChangeDatum;
}

public struct DFAddictionUpdateDatum {
    public let addictionAmount: Float;
    public let addictionStage: Int32;
    public let withdrawalLevel: Int32;
    public let remainingBackoffDuration: Float;
    public let remainingWithdrawalDuration: Float;
    public let isWithdrawalLevelWorsened: Bool;
}

public struct DFAddictionDatum {
    public let alcohol: DFAddictionUpdateDatum;
    public let nicotine: DFAddictionUpdateDatum;
    public let narcotic: DFAddictionUpdateDatum;
    public let newAddictionTreatmentDuration: Float;
}

public struct DFHumanityLossDatum {
    public let newTimeUntilNextCyberpsychosisAllowed: Float;
    public let newEndotrisineDuration: Float;
}

public struct DFFutureHoursData {
    public let futureNeedsData: array<DFNeedsDatum>;
    public let futureAddictionData: array<DFAddictionDatum>;
    public let futureHumanityLossData: array<DFHumanityLossDatum>;
}

public enum DFTimeSkipType {
    TimeSkip = 0,
    FullSleep = 1,
    LimitedSleep = 2
}

public struct DFTimeSkipData {
    public let targetNeedValues: DFNeedsDatum;
    public let targetAddictionValues: DFAddictionDatum;
    public let targetHumanityLossValues: DFHumanityLossDatum;
    public let hoursSkipped: Int32;
    public let timeSkipType: DFTimeSkipType;
}

public enum DFTempEnergyItemType {
    Caffeine = 0,
    Stimulant = 1
}

@wrapMethod(RadialWheelController)
protected cb func OnLateInit(evt: ref<LateInit>) -> Bool {
    //DFProfile();
	let val: Bool = wrappedMethod(evt);

	// Now that we know that the Radial Wheel is done initializing, it's now safe to act on systems
    // that might apply status effects.
	DFMainSystem.Get().OnRadialWheelLateInitDone();
    
    let widgetSlot: ref<inkWidget> = inkWidgetRef.Get(this.statusEffects.slotAnchorRef);
	DFHUDSystem.Get().SetRadialWheelStatusEffectListWidget(widgetSlot);

	return val;
}

@wrapMethod(DeathMenuGameController)
protected cb func OnInitialize() -> Bool {
    //DFProfile();
	let val: Bool = wrappedMethod();
	
	let DFMainSystem: ref<DFMainSystem> = DFMainSystem.Get();
	DFMainSystem.DispatchPlayerDeathEvent();

	return val;
}

@wrapMethod(PlayerDevelopmentData)
private final const func ModifyProficiencyLevel(proficiencyIndex: Int32, isDebug: Bool, opt levelIncrease: Int32) -> Void {
    //DFProfile();
    wrappedMethod(proficiencyIndex, isDebug, levelIncrease);

    let strengthSkillIndex: Int32 = this.GetProficiencyIndexByType(gamedataProficiencyType.StrengthSkill);
    if Equals(strengthSkillIndex, proficiencyIndex) {
        DFLogNoSystem(true, this, "ModifyProficiencyLevel: Updating Strength Skill Proficiency Carry Weight bonus.");
        DFMainSystem.Get().UpdateStrengthSkillBonuses();
    }
}

public class MainSystemPlayerDeathEvent extends CallbackSystemEvent {
    public static func Create() -> ref<MainSystemPlayerDeathEvent> {
        //DFProfile();
        return new MainSystemPlayerDeathEvent();
    }
}

public class MainSystemTimeSkipStartEvent extends CallbackSystemEvent {
    public static func Create() -> ref<MainSystemTimeSkipStartEvent> {
        //DFProfile();
        return new MainSystemTimeSkipStartEvent();
    }
}

public class MainSystemTimeSkipCancelledEvent extends CallbackSystemEvent {
    public static func Create() -> ref<MainSystemTimeSkipCancelledEvent> {
        //DFProfile();
        return new MainSystemTimeSkipCancelledEvent();
    }
}

public class MainSystemTimeSkipFinishedEvent extends CallbackSystemEvent {
    private let data: DFTimeSkipData;

    public func GetData() -> DFTimeSkipData {
        //DFProfile();
        return this.data;
    }

    public static func Create(data: DFTimeSkipData) -> ref<MainSystemTimeSkipFinishedEvent> {
        //DFProfile();
        let event = new MainSystemTimeSkipFinishedEvent();
        event.data = data;
        return event;
    }
}

public class MainSystemItemConsumedEvent extends CallbackSystemEvent {
    private let itemRecord: wref<Item_Record>;
    private let animateUI: Bool;
    private let noAnimation: Bool;

    public func GetItemRecord() -> wref<Item_Record> {
        //DFProfile();
        return this.itemRecord;
    }

    public func GetAnimateUI() -> Bool {
        //DFProfile();
        return this.animateUI;
    }

    public func GetNoAnimation() -> Bool {
        //DFProfile();
        return this.noAnimation;
    }

    public static func Create(itemRecord: wref<Item_Record>, animateUI: Bool, noAnimation: Bool) -> ref<MainSystemItemConsumedEvent> {
        //DFProfile();
        let event = new MainSystemItemConsumedEvent();
        event.itemRecord = itemRecord;
        event.animateUI = animateUI;
        event.noAnimation = noAnimation;
        return event;
    }
}

public class MainSystemLifecycleInitEvent extends CallbackSystemEvent {
    public static func Create() -> ref<MainSystemLifecycleInitEvent> {
        //DFProfile();
        return new MainSystemLifecycleInitEvent();
    }
}

public class MainSystemLifecycleInitDoneEvent extends CallbackSystemEvent {
    public static func Create() -> ref<MainSystemLifecycleInitDoneEvent> {
        //DFProfile();
        return new MainSystemLifecycleInitDoneEvent();
    }
}

public class MainSystemLifecycleResumeEvent extends CallbackSystemEvent {
    public static func Create() -> ref<MainSystemLifecycleResumeEvent> {
        //DFProfile();
        return new MainSystemLifecycleResumeEvent();
    }
}

public class MainSystemLifecycleResumeDoneEvent extends CallbackSystemEvent {
    public static func Create() -> ref<MainSystemLifecycleResumeDoneEvent> {
        //DFProfile();
        return new MainSystemLifecycleResumeDoneEvent();
    }
}

public class MainSystemLifecycleSuspendEvent extends CallbackSystemEvent {
    public static func Create() -> ref<MainSystemLifecycleSuspendEvent> {
        //DFProfile();
        return new MainSystemLifecycleSuspendEvent();
    }
}

public class MainSystemLifecycleSuspendDoneEvent extends CallbackSystemEvent {
    public static func Create() -> ref<MainSystemLifecycleSuspendDoneEvent> {
        //DFProfile();
        return new MainSystemLifecycleSuspendDoneEvent();
    }
}

class DFMainSystemEventListeners extends ScriptableService {
    private func GetSystemInstance() -> wref<DFMainSystem> {
        //DFProfile();
		return DFMainSystem.Get();
	}

	public cb func OnLoad() {
        //DFProfile();
        GameInstance.GetCallbackSystem().RegisterCallback(NameOf<SettingChangedEvent>(), this, n"OnSettingChangedEvent", true);
    }

    private cb func OnSettingChangedEvent(event: ref<SettingChangedEvent>) {
        //DFProfile();
		this.GetSystemInstance().OnSettingChanged(event.GetData());
	}
}

public final class DFMainSystem extends ScriptableSystem {
    private let debugEnabled: Bool = false;

    private let player: ref<PlayerPuppet>;

    // Callback Handles
    private let playerAttachedCallbackID: Uint32;

    private let lateInitDone: Bool = false;

    // Version tracking
    private const let version: Float = 2.0;
    private persistent let lastKnownVersion: Float = 0.0;
    private persistent let hasShownActivationMessage: Bool = false;
    private persistent let hasShownUpgradeMessage_20: Bool = false;


    public final static func GetInstance(gameInstance: GameInstance) -> ref<DFMainSystem> {
        //DFProfile();
		let instance: ref<DFMainSystem> = GameInstance.GetScriptableSystemsContainer(gameInstance).Get(NameOf<DFMainSystem>()) as DFMainSystem;
		return instance;
	}

    public final static func Get() -> ref<DFMainSystem> {
        //DFProfile();
        return DFMainSystem.GetInstance(GetGameInstance());
	}

    //
    //  Startup and Shutdown
    //
    public func OnAttach() -> Void {
        //DFProfile();
        DFLogNoSystem(this.debugEnabled, this, "OnAttach");
        this.playerAttachedCallbackID = GameInstance.GetPlayerSystem(GetGameInstance()).RegisterPlayerPuppetAttachedCallback(this, n"PlayerAttachedCallback");
    }

    private final func PlayerAttachedCallback(playerPuppet: ref<GameObject>) -> Void {
        //DFProfile();
		if IsDefined(playerPuppet) {
            DFLogNoSystem(this.debugEnabled, this, "PlayerAttachedCallback playerPuppet TweakDBID: " + TDBID.ToStringDEBUG((playerPuppet as PlayerPuppet).GetRecord().GetID()));
            this.player = playerPuppet as PlayerPuppet;

            // Player Replacer / Act 2 Handling - If Late Init is already Done, start all systems.
            if this.lateInitDone {
                this.StartAll();
                this.RefreshAlwaysOnEffects();
            }
        }
    }

    public final func OnRadialWheelLateInitDone() -> Void {
        //DFProfile();
        if !this.lateInitDone {
            this.lateInitDone = true;
            this.StartAll();
            this.RefreshAlwaysOnEffects();
        }
	}

    private final func StartAll() -> Void {
        //DFProfile();
        let gameInstance = GetGameInstance();
        if !IsDefined(this.player) {
            DFLogNoSystem(true, this, "ERROR: PLAYER NOT DEFINED ON DFMainSystem:StartAll()", DFLogLevel.Error);
            return;
        }
        DFLogNoSystem(this.debugEnabled, this, "!!!!! DFMainSystem:StartAll !!!!!");

        // Settings
        DFSettings.GetInstance(gameInstance).Init(this.player);

        // Lifecycle Hook - Start
        this.DispatchLifecycleInitEvent();

        // Services
        DFGameStateService.GetInstance(gameInstance).Init(this.player);
        DFNotificationService.GetInstance(gameInstance).Init(this.player);
        DFPlayerStateService.GetInstance(gameInstance).Init(this.player);

        // Gameplay Systems
        DFVehicleSleepSystem.GetInstance(gameInstance).Init(this.player);
        DFInteractionSystem.GetInstance(gameInstance).Init(this.player);
        DFStashCraftingSystem.GetInstance(gameInstance).Init(this.player);
        DFRandomEncounterSystem.GetInstance(gameInstance).Init(this.player);

        // Basic Needs
        DFHydrationSystem.GetInstance(gameInstance).Init(this.player);
        DFNutritionSystem.GetInstance(gameInstance).Init(this.player);
        DFEnergySystem.GetInstance(gameInstance).Init(this.player);

        // UI
        DFHUDSystem.GetInstance(gameInstance).Init(this.player);
        DFRevisedBackpackUISystem.GetInstance(gameInstance).Init(this.player);

        // Compatibility
        DFModCompatSystem.GetInstance(gameInstance).Init(this.player);

        // Reconcile settings changes
        DFSettings.GetInstance(gameInstance).ReconcileSettings();

        // Lifecycle Hook - Done
        this.DispatchLifecycleInitDoneEvent();

        // Invalid Config Check
        this.CheckForInvalidConfiguration();

        // Codex Entries
        this.UpdateCodexEntries();

        // Activation Message
        this.TryToShowActivationMessageAndBars();

        // Maintenance
        this.DoStartUpMaintenanceTasks();

        // Version Updates
        this.lastKnownVersion = this.version;
    }

    private final func ResumeAll() -> Void {
        //DFProfile();
        DFLogNoSystem(this.debugEnabled, this, "!!!!! DFMainSystem:ResumeAll !!!!!");
        let gameInstance = GetGameInstance();

        // Lifecycle Hook - Start
        this.DispatchLifecycleResumeEvent();

        // Services
        DFGameStateService.GetInstance(gameInstance).Resume();
        DFNotificationService.GetInstance(gameInstance).Resume();
        DFPlayerStateService.GetInstance(gameInstance).Resume();

        // Gameplay Systems
        DFVehicleSleepSystem.GetInstance(gameInstance).Resume();
        DFInteractionSystem.GetInstance(gameInstance).Resume();
        DFStashCraftingSystem.GetInstance(gameInstance).Resume();
        DFRandomEncounterSystem.GetInstance(gameInstance).Resume();

        // Basic Needs
        DFHydrationSystem.GetInstance(gameInstance).Resume();
        DFNutritionSystem.GetInstance(gameInstance).Resume();
        DFEnergySystem.GetInstance(gameInstance).Resume();

        // UI
        DFHUDSystem.GetInstance(gameInstance).Resume();
        DFRevisedBackpackUISystem.GetInstance(gameInstance).Resume();

        // Compatibility
        DFModCompatSystem.GetInstance(gameInstance).Resume();

        // Lifecycle Hook - Done
        this.DispatchLifecycleResumeDoneEvent();

        // Invalid Config Check
        this.CheckForInvalidConfiguration();
    }

    private final func SuspendAll() -> Void {
        //DFProfile();
        DFLogNoSystem(this.debugEnabled, this, "!!!!! DFMainSystem:SuspendAll !!!!!");

        let gameInstance = GetGameInstance();

        // Lifecycle Hook - Start
        this.DispatchLifecycleSuspendEvent();

        // Compatibility
        DFModCompatSystem.GetInstance(gameInstance).Suspend();

        // UI
        DFRevisedBackpackUISystem.GetInstance(gameInstance).Suspend();
        DFHUDSystem.GetInstance(gameInstance).Suspend();
        
        // Basic Needs
        DFEnergySystem.GetInstance(gameInstance).Suspend();
        DFNutritionSystem.GetInstance(gameInstance).Suspend();
        DFHydrationSystem.GetInstance(gameInstance).Suspend();
        
        // Gameplay Systems
        DFRandomEncounterSystem.GetInstance(gameInstance).Suspend();
        DFStashCraftingSystem.GetInstance(gameInstance).Suspend();
        DFInteractionSystem.GetInstance(gameInstance).Suspend();
        DFVehicleSleepSystem.GetInstance(gameInstance).Suspend();

        // Services
        DFPlayerStateService.GetInstance(gameInstance).Suspend();
        DFNotificationService.GetInstance(gameInstance).Suspend();
        DFGameStateService.GetInstance(gameInstance).Suspend();

        // Lifecycle Hook - Done
        this.DispatchLifecycleSuspendDoneEvent();
    }

    private final func RefreshAlwaysOnEffects() -> Void {
        //DFProfile();
        let settings: ref<DFSettings> = DFSettings.Get();
        if settings.mainSystemEnabled {
            if Equals(settings.reducedCarryWeight, DFReducedCarryWeightAmount.Full) {
                if !StatusEffectSystem.ObjectHasStatusEffect(this.player, t"DarkFutureStatusEffect.DarkFutureAlwaysOnCarryCapacityFull") {
                    StatusEffectHelper.ApplyStatusEffect(this.player, t"DarkFutureStatusEffect.DarkFutureAlwaysOnCarryCapacityFull");
                }
            } else {
                StatusEffectHelper.RemoveStatusEffect(this.player, t"DarkFutureStatusEffect.DarkFutureAlwaysOnCarryCapacityFull");
            }

            if Equals(settings.reducedCarryWeight, DFReducedCarryWeightAmount.Half) {
                if !StatusEffectSystem.ObjectHasStatusEffect(this.player, t"DarkFutureStatusEffect.DarkFutureAlwaysOnCarryCapacityHalf") {
                    StatusEffectHelper.ApplyStatusEffect(this.player, t"DarkFutureStatusEffect.DarkFutureAlwaysOnCarryCapacityHalf");
                }
            } else {
                StatusEffectHelper.RemoveStatusEffect(this.player, t"DarkFutureStatusEffect.DarkFutureAlwaysOnCarryCapacityHalf");
            }

		} else {
            StatusEffectHelper.RemoveStatusEffect(this.player, t"DarkFutureStatusEffect.DarkFutureAlwaysOnCarryCapacity");
        }

        this.UpdateStrengthSkillBonuses();
    }

    public final func OnSettingChanged(changedSettings: array<String>) -> Void {
        //DFProfile();
        let settings: ref<DFSettings> = DFSettings.Get();
        if ArrayContains(changedSettings, "reducedCarryWeight") {
            this.RefreshAlwaysOnEffects();
        }

        if ArrayContains(changedSettings, "mainSystemEnabled") {
            if settings.mainSystemEnabled {
                this.ResumeAll();
            } else {
                this.SuspendAll();
            }
            this.RefreshAlwaysOnEffects();
        }
    }

    public final func UpdateStrengthSkillBonuses() -> Void {
        //DFProfile();
        let developmentData: ref<PlayerDevelopmentData> = PlayerDevelopmentSystem.GetInstance(this.player).GetDevelopmentData(this.player);
        let newLevel: Int32 = developmentData.GetProficiencyLevel(gamedataProficiencyType.StrengthSkill);
        StatusEffectHelper.RemoveStatusEffectsWithTag(this.player, n"DarkFutureStrengthSkillCarryWeightPenalty");
        DFLogNoSystem(this.debugEnabled, this, "    Solo Skill: " + ToString(newLevel));

        let strengthSkillLevel5NewBonus: Int32;
        let strengthSkillLevel25NewBonus: Int32;

        let reducedCarryWeightSettingValue: DFReducedCarryWeightAmount = DFSettings.Get().reducedCarryWeight;
        if Equals(reducedCarryWeightSettingValue, DFReducedCarryWeightAmount.Full) {
            strengthSkillLevel5NewBonus = 20;
            strengthSkillLevel25NewBonus = 30;
            if newLevel >= 25 {
                StatusEffectHelper.ApplyStatusEffect(this.player, t"DarkFutureStatusEffect.StrengthSkillPenaltyFull25");

            } else if newLevel >= 5 {
                StatusEffectHelper.ApplyStatusEffect(this.player, t"DarkFutureStatusEffect.StrengthSkillPenaltyFull5");
            }

        } else if Equals(reducedCarryWeightSettingValue, DFReducedCarryWeightAmount.Half) {
            strengthSkillLevel5NewBonus = 25;
            strengthSkillLevel25NewBonus = 50;
            if newLevel >= 25 {
                StatusEffectHelper.ApplyStatusEffect(this.player, t"DarkFutureStatusEffect.StrengthSkillPenaltyHalf25");

            } else if newLevel >= 5 {
                StatusEffectHelper.ApplyStatusEffect(this.player, t"DarkFutureStatusEffect.StrengthSkillPenaltyHalf5");
            }
        
        } else if Equals(reducedCarryWeightSettingValue, DFReducedCarryWeightAmount.Off) {
            strengthSkillLevel5NewBonus = 50;
            strengthSkillLevel25NewBonus = 100;
        }

        // Update the descriptions in the Skill Proficiencies UI
        TweakDBManager.SetFlat(t"Proficiencies.StrengthSkill_inline1.intValues", [strengthSkillLevel5NewBonus]);
        TweakDBManager.SetFlat(t"Proficiencies.StrengthSkill_inline7.intValues", [strengthSkillLevel25NewBonus]);
        TweakDBManager.UpdateRecord(t"Proficiencies.StrengthSkill_inline1");
        TweakDBManager.UpdateRecord(t"Proficiencies.StrengthSkill_inline7");
    }

    public final func CheckForInvalidConfiguration() -> Void {
        let settings: ref<DFSettings> = DFSettings.Get();
        if settings.basicNeedThresholdValue1 > settings.basicNeedThresholdValue2 &&
           settings.basicNeedThresholdValue2 > settings.basicNeedThresholdValue3 &&
           settings.basicNeedThresholdValue3 > settings.basicNeedThresholdValue4 {

            // Valid.
        } else {
            let warning: DFTutorial;
            warning.title = GetLocalizedTextByKey(n"DarkFutureErrorInvalidConfigurationTitle");
            warning.message = GetLocalizedTextByKey(n"DarkFutureErrorInvalidConfigurationBasicNeedThresholds");
            warning.iconID = t"";
            DFNotificationService.Get().QueueTutorial(warning);
        }
    }

    public final func UpdateCodexEntries() -> Void {
        let gameInstance = GetGameInstance();
        let journalManager: ref<JournalManager> = GameInstance.GetJournalManager(gameInstance);
        let Settings: ref<DFSettings> = DFSettings.GetInstance(gameInstance);

        // Always on.
        journalManager.ChangeEntryState("codex/tutorials/playercharacter/basic_needs", "gameJournalCodexEntry", gameJournalEntryState.Active, JournalNotifyOption.Notify);
        journalManager.ChangeEntryState("codex/tutorials/playercharacter/sleeping_in_vehicles", "gameJournalCodexEntry", gameJournalEntryState.Active, JournalNotifyOption.Notify);
        journalManager.ChangeEntryState("codex/tutorials/playercharacter/basic_needs/desc", "gameJournalCodexDescription", gameJournalEntryState.Active, JournalNotifyOption.Notify);
        journalManager.ChangeEntryState("codex/tutorials/playercharacter/sleeping_in_vehicles/desc", "gameJournalCodexDescription", gameJournalEntryState.Active, JournalNotifyOption.Notify);

        // Base Game - Fast Travel
        if Equals(Settings.fastTravelSettingV2, DFFastTravelSetting.Enabled) {
            journalManager.ChangeEntryState("codex/tutorials/exploration/fasttravel", "gameJournalCodexEntry", gameJournalEntryState.Active, JournalNotifyOption.Notify);
            journalManager.ChangeEntryState("codex/tutorials/exploration/fasttravel/fasttravel_desc", "gameJournalCodexDescription", gameJournalEntryState.Active, JournalNotifyOption.Notify);

            journalManager.ChangeEntryState("codex/tutorials/exploration/fasttravel_metrogatesonly", "gameJournalCodexEntry", gameJournalEntryState.Inactive, JournalNotifyOption.Notify);
            journalManager.ChangeEntryState("codex/tutorials/exploration/fasttravel_metrogatesonly/desc", "gameJournalCodexDescription", gameJournalEntryState.Inactive, JournalNotifyOption.Notify);

        } else if Equals(Settings.fastTravelSettingV2, DFFastTravelSetting.Disabled) {
            journalManager.ChangeEntryState("codex/tutorials/exploration/fasttravel", "gameJournalCodexEntry", gameJournalEntryState.Inactive, JournalNotifyOption.Notify);
            journalManager.ChangeEntryState("codex/tutorials/exploration/fasttravel/fasttravel_desc", "gameJournalCodexDescription", gameJournalEntryState.Inactive, JournalNotifyOption.Notify);

            journalManager.ChangeEntryState("codex/tutorials/exploration/fasttravel_metrogatesonly", "gameJournalCodexEntry", gameJournalEntryState.Inactive, JournalNotifyOption.Notify);
            journalManager.ChangeEntryState("codex/tutorials/exploration/fasttravel_metrogatesonly/desc", "gameJournalCodexDescription", gameJournalEntryState.Inactive, JournalNotifyOption.Notify);
        } else if Equals(Settings.fastTravelSettingV2, DFFastTravelSetting.DisabledAllowMetro) {
            journalManager.ChangeEntryState("codex/tutorials/exploration/fasttravel", "gameJournalCodexEntry", gameJournalEntryState.Inactive, JournalNotifyOption.Notify);
            journalManager.ChangeEntryState("codex/tutorials/exploration/fasttravel/fasttravel_desc", "gameJournalCodexDescription", gameJournalEntryState.Inactive, JournalNotifyOption.Notify);

            journalManager.ChangeEntryState("codex/tutorials/exploration/fasttravel_metrogatesonly", "gameJournalCodexEntry", gameJournalEntryState.Active, JournalNotifyOption.Notify);
            journalManager.ChangeEntryState("codex/tutorials/exploration/fasttravel_metrogatesonly/desc", "gameJournalCodexDescription", gameJournalEntryState.Active, JournalNotifyOption.Notify);
        }
    }

    private final func DoStartUpMaintenanceTasks() -> Void {}

    public final func DispatchPlayerDeathEvent() -> Void {
        //DFProfile();
        DFLogNoSystem(this.debugEnabled, this, "!!!!! DFMainSystem:DispatchPlayerDeathEvent !!!!!");
        GameInstance.GetCallbackSystem().DispatchEvent(MainSystemPlayerDeathEvent.Create());
    }

    public final func DispatchTimeSkipStartEvent() -> Void {
        //DFProfile();
        GameInstance.GetCallbackSystem().DispatchEvent(MainSystemTimeSkipStartEvent.Create());
    }

    public final func DispatchTimeSkipCancelledEvent() -> Void {
        //DFProfile();
        GameInstance.GetCallbackSystem().DispatchEvent(MainSystemTimeSkipCancelledEvent.Create());
    }

    public final func DispatchTimeSkipFinishedEvent(data: DFTimeSkipData) -> Void {
        //DFProfile();
        GameInstance.GetCallbackSystem().DispatchEvent(MainSystemTimeSkipFinishedEvent.Create(data));
    }

    public final func DispatchItemConsumedEvent(itemRecord: wref<Item_Record>, animateUI: Bool, opt noAnimation: Bool) -> Void {
        //DFProfile();
        GameInstance.GetCallbackSystem().DispatchEvent(MainSystemItemConsumedEvent.Create(itemRecord, animateUI, noAnimation));
    }

    //
    //  Lifecycle Events for Dark Future Add-Ons and Mods
    //
    public final func DispatchLifecycleInitEvent() -> Void {
        //DFProfile();
        GameInstance.GetCallbackSystem().DispatchEvent(MainSystemLifecycleInitEvent.Create());
    }

    public final func DispatchLifecycleInitDoneEvent() -> Void {
        //DFProfile();
        GameInstance.GetCallbackSystem().DispatchEvent(MainSystemLifecycleInitDoneEvent.Create());
    }

    public final func DispatchLifecycleResumeEvent() -> Void {
        //DFProfile();
        GameInstance.GetCallbackSystem().DispatchEvent(MainSystemLifecycleResumeEvent.Create());
    }

    public final func DispatchLifecycleResumeDoneEvent() -> Void {
        //DFProfile();
        GameInstance.GetCallbackSystem().DispatchEvent(MainSystemLifecycleResumeDoneEvent.Create());
    }

    public final func DispatchLifecycleSuspendEvent() -> Void {
        //DFProfile();
        GameInstance.GetCallbackSystem().DispatchEvent(MainSystemLifecycleSuspendEvent.Create());
    }

    public final func DispatchLifecycleSuspendDoneEvent() -> Void {
        //DFProfile();
        GameInstance.GetCallbackSystem().DispatchEvent(MainSystemLifecycleSuspendDoneEvent.Create());
    }

    private final func GetActivationMessageImage() -> TweakDBID {
        return t"UIIcon.DarkFutureTutorialWelcome";
    }

    private final func TryToShowActivationMessageAndBars() -> Void {
        //DFProfile();

        // Legacy 1.x Upgrade Handling
        if DFGameStateService.Get().hasShownActivationMessage {
            this.hasShownActivationMessage = true;
        }

        if !this.hasShownActivationMessage {
			this.hasShownActivationMessage = true;
            this.ShowSystemMessage(
                n"DarkFutureTutorialActivateTitle",
                n"DarkFutureTutorialActivate_Core",
                t"",
                r"darkfuture\\movies\\dark_future_welcome.bk2"
            );

            // Also ping the UI once on first start-up.
            let uiToShow: DFUIDisplay;
			uiToShow.bar = DFHUDBarType.Hydration; // To force all bars to display

            let oneTimeBarDisplay: DFNotification;
            oneTimeBarDisplay.allowPlaybackInCombat = false;
            oneTimeBarDisplay.ui = uiToShow;

            DFNotificationService.Get().QueueNotification(oneTimeBarDisplay);
		}
	}

    private final func ShowSystemMessage(titleKey: CName, messageKey: CName, opt image: TweakDBID, opt videoPath: ResRef) -> Void {
        let tutorial: DFTutorial;
        tutorial.title = GetLocalizedTextByKey(titleKey);
        tutorial.message = GetLocalizedTextByKey(messageKey);
        if NotEquals(image, t"") {
            tutorial.iconID = image;
        } else if NotEquals(videoPath, r"") {
            tutorial.videoType = VideoType.Tutorial_1360x768;
            let raRef: ResourceAsyncRef = ResourceAsyncRef();
            ResourceAsyncRef.SetPath(raRef, videoPath);
            tutorial.video = raRef;
        }
        DFNotificationService.Get().QueueTutorial(tutorial);
    }
}
