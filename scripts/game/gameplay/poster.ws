//Right now class is empty poster class handels all functionalities
statemachine class W3Signboard  extends W3Poster
{
}

statemachine class W3Poster extends CGameplayEntity
{	
	var descriptionGenerated			 	: bool;	
	editable var description			 	: string;
	editable var camera					 	: CEntityTemplate;
	editable var factOnRead				 	: string;
	editable var factOnInteraction			: string;
	editable var blendInTime				: float; default blendInTime = 0.f;
	editable var blendOutTime				: float; default blendOutTime = 0.f;
	editable var fadeStartDuration			: float; default fadeStartDuration =  1.5;
	editable var fadeEndDuration			: float; default fadeEndDuration =  1.5;
	editable var focusModeHighlight			: EFocusModeVisibility; default focusModeHighlight = FMV_Interactive;
	editable var alignLeft					: bool; default alignLeft = false;
	
	private var restoreUsableItemAtEnd		: bool;
	
	var spawnedCamera	  : CStaticCamera;

	default autoState = 'PosterNotObserved';
	
	event OnSpawned( spawnData : SEntitySpawnData )
	{
		GotoStateAuto();
		SetFocusModeVisibility( focusModeHighlight );
	}
	
	event OnInteraction( actionName : string, activator : CEntity )
	{
		if( activator == thePlayer )
		{
			if ( spawnedCamera )
			{
				RemoveTimer( 'DestroyCamera' );
				spawnedCamera.Destroy();
			}
			PushState( 'PosterObserved' );
		}
	}
	
	function LeavePosterPreview()

	{
		GotoStateAuto();
	}
	
	function GetDescription() : string
	{
		return description;
	}
	
	function IsTextAlignedToLeft() : bool
	{
		return alignLeft;
	}
	
	//Is description generated by the class or taken whole from the loc strings
	function GetIsDescriptionGenerated() : bool
	{
		return descriptionGenerated;
	}
	
	function OnStartedObservingPoster()
	{
		var itemL : W3UsableItem;
		
		
		thePlayer.SetActivePoster( this );
		
		if ( thePlayer.IsHoldingItemInLHand () )
		{
			itemL = thePlayer.GetCurrentlyUsedItemL ();
			if ( itemL )
			{
				itemL.SetVisibility ( false );
				itemL.DestroyAllEffects();
				itemL.OnHidden( thePlayer );
				restoreUsableItemAtEnd = true;
			}
			
		}
		if ( factOnInteraction != "" && !FactsDoesExist ( factOnInteraction ) )
		{
			FactsAdd ( factOnInteraction, 1, -1 );
		}
		theInput.StoreContext( 'EMPTY_CONTEXT' );
		thePlayer.BlockAction(EIAB_Interactions, 'Poster' );
		thePlayer.SetHideInGame( true );

		spawnedCamera = (CStaticCamera)theGame.CreateEntity( camera, GetWorldPosition(), GetWorldRotation() );
		spawnedCamera.deactivationDuration = blendOutTime;
		spawnedCamera.activationDuration = blendInTime;
		spawnedCamera.fadeStartDuration = fadeStartDuration;
		spawnedCamera.fadeEndDuration = fadeEndDuration;
		spawnedCamera.Run();
		
		theGame.RequestMenu( 'PosterMenu', this );
	}
	
	function OnEndedObservingPoster()
	{
		thePlayer.RemoveActivePoster();
		//spawnedCamera.timeout	= blendOutTime + 1.0f;
		spawnedCamera.Stop();
		AddTimer( 'RestoreGameplay', blendOutTime, false, , , true );
	}
	
	timer function DestroyCamera (  dt : float , id : int) 
	{
		spawnedCamera.Destroy();
	}
	
	timer function RestoreGameplay (  dt : float , id : int) 
	{
		var cameraTimeout : float;
		var itemL : W3UsableItem;
		
		cameraTimeout = spawnedCamera.fadeEndDuration + blendOutTime;
		
		thePlayer.SetHideInGame( false );
		theInput.RestoreContext( 'EMPTY_CONTEXT', false );
		thePlayer.UnblockAction(EIAB_Interactions, 'Poster' );
		AddTimer( 'DestroyCamera', cameraTimeout, false );
		
		if ( factOnRead != "" && !FactsDoesExist ( factOnRead ) )
		{
			FactsAdd ( factOnRead, 1, -1 );
		}
		
		if ( restoreUsableItemAtEnd )
		{
			itemL = thePlayer.GetCurrentlyUsedItemL ();
			if ( itemL )
			{
				itemL.SetVisibility ( true );
				itemL.OnUsed( thePlayer );
				restoreUsableItemAtEnd = false;
			}
		}
	}
}

state PosterNotObserved in W3Poster
{
	event OnEnterState( prevStateName : name )
	{
		super.OnEnterState( prevStateName );
	}
	
	event OnLeaveState( nextStateName : name )
	{
		super.OnLeaveState( nextStateName );
	}
}

state PosterObserved in W3Poster
{
	event OnEnterState( prevStateName : name )
	{
		super.OnEnterState( prevStateName );
		parent.OnStartedObservingPoster();
	}
	
	event OnLeaveState( nextStateName : name )
	{
		parent.OnEndedObservingPoster();
		super.OnLeaveState( nextStateName );
	}
}

// custom class that allows to save some of the poster's properties
class W3SavedPoster extends W3Poster
{
	saved var savedFocusModeHighlight	: EFocusModeVisibility;
	
	event OnSpawned( spawnData : SEntitySpawnData )
	{
		// if restored, use "saved" focusmodeHighlight
		if ( spawnData.restored )
		{
			focusModeHighlight = savedFocusModeHighlight;
		}
		// otherwise just copy initial value to be stored
		else
		{
			savedFocusModeHighlight = focusModeHighlight;
		}
		super.OnSpawned( spawnData );
	}	
}
