// -----------------------------------------------------------------------------
// DFRevisedBackpackMenuUI
// -----------------------------------------------------------------------------
//
// - Handles the UI meters in the Revised Backpack Inventory, if installed.
//

module DarkFutureCore.UI

@if(ModuleExists("RevisedBackpack"))
import RevisedBackpack.{
    RevisedCustomEventBackpackOpened,
    RevisedCustomEventItemHoverOver,
    RevisedCustomEventItemHoverOut,
    RevisedCustomEventCategorySelected
}

import Codeware.UI.VirtualResolutionWatcher

import DarkFutureCore.Settings.{
	DFSettings,
	SettingChangedEvent
}
import DarkFutureCore.Logging.*
import DarkFutureCore.System.*
import DarkFutureCore.Main.DFTimeSkipData
import DarkFutureCore.Main.{ 
	DFNeedsDatum,
	DFNeedChangeDatum
}
import DarkFutureCore.Needs.{
	DFHydrationSystem,
	DFNutritionSystem,
	DFEnergySystem
}
import DarkFutureCore.Services.{
	DFGameStateService,
	DFPlayerStateService
}
import DarkFutureCore.UI.{
	DFNeedsMenuBar,
	DFNeedsMenuBarSetupData
}

class DFRevisedBackpackUISystemEventListeners extends DFSystemEventListener {
	private func GetSystemInstance() -> wref<DFRevisedBackpackUISystem> {
		return DFRevisedBackpackUISystem.Get();
	}

    public cb func OnLoad() {
		super.OnLoad();

		GameInstance.GetCallbackSystem().RegisterCallback(NameOf<RevisedCustomEventBackpackOpened>(), this, n"OnRevisedBackpackOpenedEvent", true);
		GameInstance.GetCallbackSystem().RegisterCallback(NameOf<RevisedCustomEventItemHoverOver>(), this, n"OnRevisedCustomEventItemHoverOverEvent", true);
        GameInstance.GetCallbackSystem().RegisterCallback(NameOf<RevisedCustomEventItemHoverOut>(), this, n"OnRevisedCustomEventItemHoverOutEvent", true);
        GameInstance.GetCallbackSystem().RegisterCallback(NameOf<RevisedCustomEventCategorySelected>(), this, n"OnRevisedCustomEventCategorySelectedEvent", true);
    }
	
	private cb func OnRevisedBackpackOpenedEvent(event: ref<RevisedCustomEventBackpackOpened>) {
		this.GetSystemInstance().OnRevisedBackpackOpened(event.opened);
	}

	private cb func OnRevisedCustomEventItemHoverOverEvent(event: ref<RevisedCustomEventItemHoverOver>) {
		this.GetSystemInstance().OnRevisedBackpackItemHoverOver(event.data);
	}

    private cb func OnRevisedCustomEventItemHoverOutEvent(event: ref<RevisedCustomEventItemHoverOut>) {
		this.GetSystemInstance().OnRevisedBackpackItemHoverOut();
	}

    private cb func OnRevisedCustomEventCategorySelectedEvent(event: ref<RevisedCustomEventCategorySelected>) {
		this.GetSystemInstance().OnRevisedRevisedBackpackCategorySelectedEvent(event.categoryId);
	}
}

public final class DFRevisedBackpackUISystem extends DFSystem {
	private let widgetSlot: ref<inkCompoundWidget>;
	private let virtualResolutionWatcher: ref<VirtualResolutionWatcher>;
    private let GameStateService: wref<DFGameStateService>;
    private let HydrationSystem: wref<DFHydrationSystem>;
    private let NutritionSystem: wref<DFNutritionSystem>;
    private let EnergySystem: wref<DFEnergySystem>;
    private let PlayerStateService: wref<DFPlayerStateService>;
    private let barCluster: ref<inkVerticalPanel>;
    private let energyBar: ref<DFNeedsMenuBar>;
    private let nutritionBar: ref<DFNeedsMenuBar>;
    private let hydrationBar: ref<DFNeedsMenuBar>;
    private let barClusterfadeInAnimProxy: ref<inkAnimProxy>;
    private let barClusterfadeInAnim: ref<inkAnimDef>;
    private let barClusterfadeOutAnimProxy: ref<inkAnimProxy>;
    private let barClusterfadeOutAnim: ref<inkAnimDef>;

	public final static func GetInstance(gameInstance: GameInstance) -> ref<DFRevisedBackpackUISystem> {
		let instance: ref<DFRevisedBackpackUISystem> = GameInstance.GetScriptableSystemsContainer(gameInstance).Get(NameOf<DFRevisedBackpackUISystem>()) as DFRevisedBackpackUISystem;
		return instance;
	}

	public final static func Get() -> ref<DFRevisedBackpackUISystem> {
		return DFRevisedBackpackUISystem.GetInstance(GetGameInstance());
	}

    //
    //  Revised Backpack Custom Event Handlers
    //
    public final func OnRevisedBackpackOpened(opened: Bool) -> Void {
        DFLog(this, "RevisedBackpack: OnRevisedBackpackOpened, opened: " + ToString(opened));
        if opened {
            let inkSystem: ref<inkSystem> = GameInstance.GetInkSystem();
            let inkHUD: ref<inkCompoundWidget> = inkSystem.GetLayer(n"inkMenuLayer").GetVirtualWindow();
            let fullScreenSlot: ref<inkCompoundWidget> = inkHUD.GetWidgetByPathName(n"Root/RevisedBackpackNeedBarFullScreenSlot") as inkCompoundWidget;

            if !IsDefined(fullScreenSlot) {
                fullScreenSlot = this.CreateFullScreenSlot(inkHUD);
            }

            this.widgetSlot = this.CreateWidgetSlot(fullScreenSlot);
            this.CreateNeedsBarCluster(this.widgetSlot);
            this.SetOriginalValuesInUI();
            this.UpdateAllBarsAppearance();

            // Watch for changes to client resolution. Set the correct resolution now to scale all widgets.
            this.virtualResolutionWatcher = new VirtualResolutionWatcher();
            this.virtualResolutionWatcher.Initialize(GetGameInstance());
            this.virtualResolutionWatcher.ScaleWidget(fullScreenSlot);

            this.widgetSlot.SetVisible(this.Settings.mainSystemEnabled);
        
        } else {
            this.widgetSlot.SetVisible(false);
            this.widgetSlot = null;
        }
    }

    public final func OnRevisedBackpackItemHoverOver(itemData: ref<gameItemData>) -> Void {
        DFLog(this, "RevisedBackpack: OnRevisedBackpackItemHoverOver, itemData: " + ToString(itemData));
        if this.Settings.mainSystemEnabled && !StatusEffectSystem.ObjectHasStatusEffect(this.HydrationSystem.player, t"DarkFutureStatusEffect.Weakened") {
            if IsDefined(itemData) {
                if itemData.HasTag(n"Consumable") {
                    let itemRecord: wref<Item_Record> = TweakDBInterface.GetItemRecord(itemData.GetID().GetTDBID());
                    let needsData: DFNeedsDatum = GetConsumableNeedsData(itemRecord);

                    // Show the increase in Hydration and Nutrition.
                    this.hydrationBar.SetUpdatedValue(this.HydrationSystem.GetNeedValue() + needsData.hydration.value, MinF(MaxF(needsData.hydration.ceiling, this.HydrationSystem.GetNeedValue()), this.HydrationSystem.GetNeedMax()));
					this.nutritionBar.SetUpdatedValue(this.NutritionSystem.GetNeedValue() + needsData.nutrition.value, MinF(MaxF(needsData.nutrition.ceiling, this.NutritionSystem.GetNeedValue()), this.NutritionSystem.GetNeedMax()));

                    // Show the change in Energy if player meets the energy management effect criteria.
                    this.energyBar.SetUpdatedValue(this.EnergySystem.GetNeedValue() + this.EnergySystem.GetItemEnergyChangePreviewAmount(itemRecord, needsData), this.HydrationSystem.GetNeedMax());
                };
            };
        }
    }

    public final func OnRevisedBackpackItemHoverOut() -> Void {
        DFLog(this, "RevisedBackpack: OnRevisedBackpackItemHoverOut");
        if this.Settings.mainSystemEnabled {
            this.hydrationBar.SetOriginalValue(this.HydrationSystem.GetNeedValue());
            this.nutritionBar.SetOriginalValue(this.NutritionSystem.GetNeedValue());
            this.energyBar.SetOriginalValue(this.EnergySystem.GetNeedValue());

            this.hydrationBar.SetUpdatedValue(this.HydrationSystem.GetNeedValue(), this.HydrationSystem.GetNeedMax());
            this.nutritionBar.SetUpdatedValue(this.NutritionSystem.GetNeedValue(), this.NutritionSystem.GetNeedMax());
            this.energyBar.SetUpdatedValue(this.EnergySystem.GetNeedValue(), this.EnergySystem.GetNeedMax());
        }
    }

    public final func OnRevisedRevisedBackpackCategorySelectedEvent(categoryId: Int32) -> Void {
        DFLog(this, "RevisedBackpack: OnRevisedRevisedBackpackCategorySelectedEvent, categoryId: " + ToString(categoryId));
        if this.GameStateService.IsValidGameState(this, true) {
            // 10 = All Items, 50 = Consumables
            if Equals(categoryId, 10) || Equals(categoryId, 50) {
                this.SetBarClusterFadeIn();
                this.UpdateAllBarsAppearance();
            } else {
                this.SetBarClusterFadeOut();
            }
        } else {
            this.barCluster.SetOpacity(0.0);
        }
    }


	//
	//  DFSystem Required Methods
	//
	private func SetupDebugLogging() -> Void {}

	public final func GetSystemToggleSettingValue() -> Bool {
		// This system does not have a system-specific toggle.
		return true;
	}
    
	private final func GetSystemToggleSettingString() -> String {
		// This system does not have a system-specific toggle.
		return "INVALID";
	}

	public func GetSystems() -> Void {
        let gameInstance = GetGameInstance();
        this.Settings = DFSettings.GetInstance(gameInstance);
        this.HydrationSystem = DFHydrationSystem.GetInstance(gameInstance);
        this.NutritionSystem = DFNutritionSystem.GetInstance(gameInstance);
        this.EnergySystem = DFEnergySystem.GetInstance(gameInstance);
        this.GameStateService = DFGameStateService.GetInstance(gameInstance);
        this.PlayerStateService = DFPlayerStateService.GetInstance(gameInstance);
    }

	private func GetBlackboards(attachedPlayer: ref<PlayerPuppet>) -> Void {}
	public func SetupData() -> Void {}
	private func RegisterListeners() -> Void {}
	private func RegisterAllRequiredDelayCallbacks() -> Void {}
	private func UnregisterListeners() -> Void {}
	public func UnregisterAllDelayCallbacks() -> Void {}
	public func OnTimeSkipStart() -> Void {}
	public func OnTimeSkipCancelled() -> Void {}
	public func OnTimeSkipFinished(data: DFTimeSkipData) -> Void {}
	public func InitSpecific(attachedPlayer: ref<PlayerPuppet>) -> Void {}
	public func DoPostSuspendActions() -> Void {}
	public func DoPostResumeActions() -> Void {}
	public func OnSettingChangedSpecific(changedSettings: array<String>) -> Void {}

	private final func CreateFullScreenSlot(inkHUD: ref<inkCompoundWidget>) -> ref<inkCompoundWidget> {
		// Create a full-screen slot with dimensions 3840x2160, so that when it is rescaled by Codeware VirtualResolutionWatcher,
		// all of its contents and relative positions are also resized.

		let fullScreenSlot: ref<inkCompoundWidget> = new inkCanvas();
		fullScreenSlot.SetName(n"RevisedBackpackNeedBarFullScreenSlot");
		fullScreenSlot.SetSize(Vector2(3840.0, 2160.0));
		fullScreenSlot.SetRenderTransformPivot(Vector2(0.0, 0.0));
		fullScreenSlot.Reparent(inkHUD.GetWidgetByPathName(n"Root") as inkCompoundWidget);

		return fullScreenSlot;
	}

	private final func CreateWidgetSlot(parent: ref<inkCompoundWidget>) -> ref<inkCompoundWidget> {
		// Create the slot.
		let widgetSlot: ref<inkCompoundWidget> = new inkCanvas();
		widgetSlot.SetName(n"RevisedBackpackNeedBarWidgetSlot");
		widgetSlot.SetFitToContent(true);
		widgetSlot.Reparent(parent);

		return widgetSlot;
	}

	private final func CreateNeedsBarCluster(parent: ref<inkCompoundWidget>) -> Void {
        this.barCluster = new inkVerticalPanel();
        this.barCluster.SetOpacity(0.0);
        this.barCluster.SetName(n"RevisedBackpackNeedsBarCluster");
        this.barCluster.SetAnchor(inkEAnchor.TopCenter);
        this.barCluster.SetAnchorPoint(Vector2(0.5, 0.5));
        this.barCluster.SetScale(Vector2(0.85, 0.85));
        this.barCluster.SetTranslation(Vector2(1920.0, 240.0));
        this.barCluster.Reparent(parent, 12);

        let rowOne: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        rowOne.SetName(n"RevisedBackpackNeedsBarClusterRowOne");
        rowOne.SetSize(Vector2(100.0, 60.0));
        rowOne.SetHAlign(inkEHorizontalAlign.Center);
        rowOne.SetVAlign(inkEVerticalAlign.Center);
        rowOne.SetAnchor(inkEAnchor.Fill);
        rowOne.SetAnchorPoint(Vector2(0.5, 0.5));
        rowOne.SetMargin(inkMargin(0.0, 0.0, 0.0, 36.0));
        rowOne.Reparent(this.barCluster);

        let hydrationIconPath: ResRef = r"base\\gameplay\\gui\\common\\icons\\mappin_icons.inkatlas";
        let hydrationIconName: CName = n"bar";
        
        let nutritionIconPath: ResRef = r"base\\gameplay\\gui\\common\\icons\\mappin_icons.inkatlas";
        let nutritionIconName: CName = n"food_vendor";

        let energyIconPath: ResRef = r"base\\gameplay\\gui\\common\\icons\\mappin_icons.inkatlas";
        let energyIconName: CName = n"wait";

        let barSetupData: DFNeedsMenuBarSetupData;

        barSetupData = DFNeedsMenuBarSetupData(rowOne, n"hydrationBar", hydrationIconPath, hydrationIconName, GetLocalizedTextByKey(n"DarkFutureUILabelHydration"), 400.0, 100.0, 0.0, 0.0, false);
        this.hydrationBar = new DFNeedsMenuBar();
        this.hydrationBar.Init(barSetupData);
        
        barSetupData = DFNeedsMenuBarSetupData(rowOne, n"nutritionBar", nutritionIconPath, nutritionIconName, GetLocalizedTextByKey(n"DarkFutureUILabelNutrition"), 400.0, 100.0, 0.0, 0.0, false);
        this.nutritionBar = new DFNeedsMenuBar();
        this.nutritionBar.Init(barSetupData);

        barSetupData = DFNeedsMenuBarSetupData(rowOne, n"energyBar", energyIconPath, energyIconName, GetLocalizedTextByKey(n"DarkFutureUILabelEnergy"), 400.0, 0.0, 0.0, 0.0, false);
        this.energyBar = new DFNeedsMenuBar();
        this.energyBar.Init(barSetupData);
    }

    private final func SetBarClusterFadeOut() -> Void {
        this.StopAnimProxyIfDefined(this.barClusterfadeOutAnimProxy);
        this.StopAnimProxyIfDefined(this.barClusterfadeInAnimProxy);

        this.barClusterfadeOutAnim = new inkAnimDef();
        let fadeOutInterp: ref<inkAnimTransparency> = new inkAnimTransparency();
        fadeOutInterp.SetStartTransparency(this.barCluster.GetOpacity());
        fadeOutInterp.SetEndTransparency(0.0);
        fadeOutInterp.SetDuration(0.075);
        this.barClusterfadeOutAnim.AddInterpolator(fadeOutInterp);
        this.barClusterfadeOutAnimProxy = this.barCluster.PlayAnimation(this.barClusterfadeOutAnim);
    }

    private final func SetBarClusterFadeIn() -> Void {
        this.StopAnimProxyIfDefined(this.barClusterfadeInAnimProxy);

        this.barClusterfadeInAnim = new inkAnimDef();
        let fadeInInterp: ref<inkAnimTransparency> = new inkAnimTransparency();
        fadeInInterp.SetStartTransparency(this.barCluster.GetOpacity());
        fadeInInterp.SetEndTransparency(1.0);
        fadeInInterp.SetDuration(0.075);
        this.barClusterfadeInAnim.AddInterpolator(fadeInInterp);
        this.barClusterfadeInAnimProxy = this.barCluster.PlayAnimation(this.barClusterfadeInAnim);
    }

    private final func UpdateAllBarsAppearance() -> Void {
        let useProjectE3UI: Bool = this.Settings.compatibilityProjectE3UI;
        this.hydrationBar.UpdateAppearance(useProjectE3UI);
        this.nutritionBar.UpdateAppearance(useProjectE3UI);
        this.energyBar.UpdateAppearance(useProjectE3UI);
    }

    private final func StopAnimProxyIfDefined(animProxy: ref<inkAnimProxy>) -> Void {
        if IsDefined(animProxy) {
            animProxy.Stop();
        }
    }

    private final func SetOriginalValuesInUI() -> Void {
        if this.Settings.mainSystemEnabled {
            this.hydrationBar.SetOriginalValue(this.HydrationSystem.GetNeedValue());
            this.nutritionBar.SetOriginalValue(this.NutritionSystem.GetNeedValue());
            this.energyBar.SetOriginalValue(this.EnergySystem.GetNeedValue());
        }
    }
}