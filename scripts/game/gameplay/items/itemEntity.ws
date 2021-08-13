/***********************************************************************/
/** Witcher Script file
/***********************************************************************/
/** Copyright © 2013-2014 CDProjektRed
/** Author : Dexio ?
/** 		 Bartosz Bigaj
/**			 Tomek Kozera
/***********************************************************************/

import class CItemEntity extends CEntity
{
	// Get entity item is attached to
	import final function GetParentEntity() : CEntity;
	
	//Get tags of an item represented by this entity
	import final function GetItemTags( out tags : array<name> );

	import final function GetMeshComponent() : CComponent;

	//sets item sound info for attacks/parrying/hits, called when equipment changes
	event OnGrab()
	{
		SetupDrawHolsterSounds();
	}
	
	//sets item sound info for attacks/parrying/hits, called when equipment changes
	event OnPut()
	{
		SetupDrawHolsterSounds();
	}
	
	event OnAttachmentUpdate(parentEntity : CEntity, itemName : name)
	{
		var actorParent : CActor;
		var dm 	: CDefinitionsManagerAccessor;
		
		actorParent = (CActor)parentEntity;
		if( actorParent )
		{
			if(theGame && actorParent.IsHuman())
			{
				if(itemName != '')
				{
					dm = theGame.GetDefinitionsManager();
					if(dm)
					{	
						if( IFT_Armors == dm.GetFilterTypeByItem(itemName) )
						{
							actorParent.AddTimer('DelaySoundInfoUpdate', 1);
						}	
					}
				}
				else //some armors doesnt have it set, weirdo
				{
					actorParent.AddTimer('DelaySoundInfoUpdate', 1);
				}
			}
		}
	}
	
	public function SetupDrawHolsterSounds()
	{
		var parentEntity : CEntity;
		var identification : name;
		var component : CComponent;
		
		parentEntity = (CEntity) GetParentEntity();
		if( parentEntity )
		{
			component = GetMeshComponent();

			if( component )
			{
				identification = GetMeshSoundTypeIdentification( component );
				parentEntity.SoundSwitch( "weapon_type", identification );
				identification = GetMeshSoundSizeIdentification( component );
				parentEntity.SoundSwitch( "weapon_size", identification );
			}
		}
	}
	
	import final function GetItemCategory() : name; 
	
	event OnItemCollision( object : CObject, physicalActorindex : int, shapeIndex : int )
	{
		var victim : CGameplayEntity;
		var owner : CActor;
		var ent : CEntity;
		var component : CComponent;
		component = (CComponent) object;
		if( !component )
		{
			return false;
		}
		
		ent = component.GetEntity();
		owner = (CActor)GetParentEntity();
		
		if ( ent != this && owner && ent != owner )
		{
			victim = (CGameplayEntity)component.GetEntity();
			
			if ( victim )
			{
				if ( physicalActorindex == 0 && shapeIndex == 0 && ((CMovingAgentComponent)component).HasRagdoll() )
					return false;
					
				owner.OnCollisionFromItem(victim, this);
			}
			return true;
		}	
	}
	
	event OnGiantWeaponCollision( object : CObject, physicalActorindex : int, shapeIndex : int )
	{
		var victim : CActor;
		var owner : CActor;
		var ent : CEntity;
		var component : CComponent;
		component = (CComponent) object;
		if( !component )
		{
			return false;
		}
		
		ent = component.GetEntity();
		owner = (CActor)GetParentEntity();
		
		if ( ent != this && owner && ent != owner )
		{
			victim = (CActor)component.GetEntity();
			
			if ( victim )
			{
				if ( physicalActorindex == 0 && shapeIndex == 0 && ((CMovingAgentComponent)component).HasRagdoll() )
					return false;
					
				owner.OnCollisionFromGiantWeapon(victim, this);
			}
			return true;
		}	
	}
}

class W3EffectItem extends CItemEntity
{
	editable var effectName : name;
	
	event OnGrab()
	{	
		if ( effectName != '' )
		{
			DestroyEffect(effectName);
			PlayEffectSingle(effectName, this );
		}
		super.OnGrab();
	}
	
	event OnPut()
	{
		if ( effectName != '' )
		{
			StopEffectIfActive(effectName);
		}
		super.OnPut();
	}
}

/*
enum EUsableItemType
{
	UI_Torch,
	UI_Horn,
	UI_Bell,
	UI_OilLamp,
	UI_Mask,
	UI_FiendLure,
	UI_Meteor,
	UI_None,
	UI_Censer,
	UI_Apple,
	UI_Cookie,
	UI_Basket
}
*/

class W3UsableItem extends CItemEntity
{
	editable var itemType : EUsableItemType;
	editable var blockedActions : array<EInputActionBlock>;
	var wasOnHiddenCalled : bool;
	
	hint itemType = "Kind of animations to be used";
	hint blockedActions = "List of actions blocked when actively using this item";
	
	event OnDestroyed()
	{
		if ( !wasOnHiddenCalled )
		{
			OnHidden( GetParentEntity() );
		}
	}
	event OnUsed( usedBy : CEntity )
	{
		var i : int;
		
		if( usedBy == thePlayer )
		{
			blockedActions.PushBack( EIAB_Parry );
			blockedActions.PushBack( EIAB_Counter );
			
			for( i = 0; i < blockedActions.Size(); i += 1)
			{
				thePlayer.BlockAction( blockedActions[i], 'UsableItem' );
			}
		}
	}
	
	event OnHidden( hiddenBy : CEntity )
	{
		var i : int;
		
		wasOnHiddenCalled = true;
		
		if( hiddenBy == thePlayer )
		{
			thePlayer.BlockAllActions( 'UsableItem', false );
		}
	}
	
	function SetVisibility( isVisible : bool )
	{
		var comps : array <CComponent>;
		var dComp : CDrawableComponent;
		var i : int;

		comps = GetComponentsByClassName( 'CDrawableComponent' );
		
		for( i=0; i < comps.Size (); i+=1 )
		{
			dComp = (CDrawableComponent)comps[i];
			
			if( dComp && dComp.GetName() != "shadow_capsule" )
			{
				dComp.SetVisible( isVisible );	
			}	
		}
	}
}
	
class W3LightSource extends W3UsableItem
{
	var worldName : String;
	
	event OnUsed( usedBy : CEntity )
	{
		blockedActions.PushBack( EIAB_HeavyAttacks );
		blockedActions.PushBack( EIAB_SpecialAttackHeavy );
		
		super.OnUsed( usedBy );
		
		worldName =  theGame.GetWorld().GetDepotPath();
		if( StrFindFirst( worldName, "bob" ) < 0 )
		{
			this.PlayEffect( 'light_on' );
		}
		else
		{
			this.PlayEffect( 'light_on_bob' );
		}
		
		if( usedBy == thePlayer )
		{
			thePlayer.UnblockAction( EIAB_Signs, 'UsableItem' );
			thePlayer.AddTag( theGame.params.TAG_OPEN_FIRE );
		}
	}

	event OnHidden( usedBy : CEntity )
	{
		if( usedBy == thePlayer )
		{
			thePlayer.RemoveTag( theGame.params.TAG_OPEN_FIRE );
		}
		
		super.OnHidden ( usedBy );
		this.StopEffect( 'light_on' );	
		this.StopEffect( 'light_on_bob' );	
	}
}

class W3ShieldUsableItem extends W3UsableItem
{
	editable var factAddedOnUse : string;
	editable var factValue : int;
	editable var factTimeValid : int;
	editable var removeFactOnHide : bool;
	
	var i : int;
	
	event OnUsed( usedBy : CEntity )
	{
		for( i = 0; i < blockedActions.Size(); i += 1)
		{
			thePlayer.BlockAction( blockedActions[i], 'UsableItem' );
		}
		FactsAdd( factAddedOnUse, factValue, factTimeValid );
	}
	
	event OnHidden( hiddenBy : CEntity )
	{
		if( removeFactOnHide )
		{
			FactsRemove( factAddedOnUse );		
		}
	}
}

class W3QuestUsableItem extends W3UsableItem
{
	editable var factAddedOnUse : string;
	editable var factValue : int;
	editable var factTimeValid : int;
	editable var removeFactOnHide : bool;
	
	event OnUsed( usedBy : CEntity )
	{
		super.OnUsed(usedBy);
		FactsAdd( factAddedOnUse, factValue, factTimeValid );
	}
	
	event OnHidden( hiddenBy : CEntity )
	{
		super.OnHidden(hiddenBy);
		if ( removeFactOnHide )
		{
			FactsRemove( factAddedOnUse );		
		}
	}
}

class W3MeteorItem extends W3QuestUsableItem
{
	private var collisionGroups : array<name>;
	
	editable var meteorResourceName 	: name;
	
	default meteorResourceName = 'ciri_meteor';
	default itemType = UI_Meteor;
	
	private var meteorEntityTemplate : CEntityTemplate;
	
	event OnSpawned( spawnData : SEntitySpawnData )
	{
		super.OnSpawned(spawnData);
		meteorEntityTemplate = (CEntityTemplate)LoadResource(meteorResourceName);
		
		collisionGroups.PushBack('Terrain');
		collisionGroups.PushBack('Static');
	}
	
	event OnUsed( usedBy : CEntity )
	{
		var userPosition : Vector;
		var meteorPosition : Vector;
		var userRotation : EulerAngles;
		
		var meteorEntity :  W3MeteorProjectile;
		
		super.OnUsed( usedBy );
		
		if ( usedBy == thePlayer )
		{
			if ( thePlayer.IsInInterior() )
			{
				thePlayer.DisplayHudMessage(GetLocStringByKeyExt( "menu_cannot_perform_action_here" ));
				return false;
			}
		}
		
		userPosition = usedBy.GetWorldPosition();
		userRotation = usedBy.GetWorldRotation();
		
		//spawn huge ass meteor and aim it to position of the user
		meteorPosition = userPosition;
		meteorPosition.Z += 50;
		
		meteorEntity = (W3MeteorProjectile)theGame.CreateEntity(meteorEntityTemplate, meteorPosition, userRotation);
		
		// meteor shouldn't have owner, becouse we want to deal dmg to player
		meteorEntity.Init(NULL);
		meteorEntity.decreasePlayerDmgBy = 0.7;
		meteorEntity.ShootProjectileAtPosition( meteorEntity.projAngle, meteorEntity.projSpeed, userPosition, 500, collisionGroups );
	}
}

class W3EyeOfLoki extends W3QuestUsableItem
{
	editable var environment : name;
	hint environment = "Environment to activate when mask is put while active.";
	editable var effect : CName;
	hint effect = "Effect to play when mask is put while active.";
	editable var activeWhenFact : CName;
	hint activeWhenFact = "Mask is active (playes fx when used) when this fact is true";
	editable var soundOnStart : name;
	hint soundOnStart = "Sound to play when mask is put";
	editable var soundOnStop : name;
	hint soundOnStop = "Sound to play when mask is hidden";

	var envID : int;
	var active : bool;
	
	default itemType = UI_Mask;
	
	event OnUsed( usedBy : CEntity )
	{
		var environmentRes : CEnvironmentDefinition;
	
		//blockedActions.PushBack( EIAB_Signs );
		//blockedActions.PushBack( EIAB_CallHorse );
		//blockedActions.PushBack( EIAB_Fists );
		blockedActions.PushBack( EIAB_Roll );
		//blockedActions.PushBack( EIAB_ThrowBomb );
		blockedActions.PushBack( EIAB_RunAndSprint );
		//blockedActions.PushBack( EIAB_Dive );
		blockedActions.PushBack( EIAB_Parry );
		//blockedActions.PushBack( EIAB_Explorations );
		blockedActions.PushBack( EIAB_Counter );
		blockedActions.PushBack( EIAB_HeavyAttacks );
		blockedActions.PushBack( EIAB_SpecialAttackHeavy );
		//blockedActions.PushBack( EIAB_Crossbow );
		//blockedActions.PushBack( EIAB_Climb );
		blockedActions.PushBack( EIAB_Slide );
	
		super.OnUsed( usedBy );
		
		if( FactsQuerySum( activeWhenFact ) )
		{
			active = true;
			
			thePlayer.SoundEvent( soundOnStart );
			
			theGame.GetGameCamera().PlayEffect( effect );
			
			environmentRes = (CEnvironmentDefinition)LoadResource( environment, true );
			envID = ActivateEnvironmentDefinition( environmentRes, 1000, 1, 1.f );
			theGame.SetEnvironmentID(envID);
		}
	}
	
	event OnHidden( hiddenBy : CEntity )
	{
		if( active ) 
		{
			active = false;
			
			theGame.GetGameCamera().StopEffect( effect );

			DeactivateEnvironment( envID, 1 );
			
			thePlayer.SoundEvent( soundOnStop );
			
		}
		super.OnHidden( hiddenBy );	
	}
}

class W3MagicOilLamp extends W3QuestUsableItem 
{
	event OnUsed( usedBy : CEntity )
	{
		super.OnUsed ( usedBy );
		this.PlayEffect( 'light_on' );
	}
	event OnHidden( usedBy : CEntity )
	{
		super.OnHidden ( usedBy );
		this.StopEffect( 'light_on' );
		
	}
	
}
class W3Potestaquisitor extends W3QuestUsableItem
{
	editable var detectableTag : name;
	hint detectableTag = "Tag for CEntities that cause a reaction";
	editable var detectableRange : float;
	default detectableRange = 40.0;
	hint detectableRange = "Range at which reactions start. Scales at quarters";
	editable var closestRange : float;
	default closestRange = 2.0;
	hint closestRange = "Range at which final reaction starts";
	editable var potestaquisitorFact : string;
	default potestaquisitorFact = "potestaquisitorLevel";
	hint potestaquisitorFact = "Fact name for detection. Is removed when detection is stopped";
	editable var soundEffectType : EFocusModeSoundEffectType;
	hint soundEffectType = "Sound effect to be played on detected CEntities";
	editable var effect : name;
	hint effect = "Effect to play on potestaquisitor when it is taken out.";	
	
	var registeredAnomalies : array< CGameplayEntity >;
	var previousClosestAnomaly : CGameplayEntity;
	
	event OnUsed( usedBy : CEntity )
	{
		this.PlayEffect( effect );
		StartScanningAnomalies(true);
		super.OnUsed(usedBy);
	}
	
	event OnHidden( hiddenBy : CEntity )
	{
		this.StopEffect( effect );
		StartScanningAnomalies(false);
		super.OnHidden(hiddenBy);
	}
	
	private function StartScanningAnomalies (shouldStart:bool)
	{
		if (shouldStart)
		{
			registeredAnomalies.Clear();
			ScanningAnomalies (0.0);
			AddTimer('ScanningAnomalies',0.5,true);//, , , true);
		}
		else
		{
			RemoveTimer('ScanningAnomalies');
			StopScanningAnomalies();
		}
	}
	
	private timer function ScanningAnomalies ( dt : float, optional id : int)
	{
		var i, closestAnomalyIndex, registeredAnomaliesSize, foundAnomaliesSize : int;
		var foundAnomalies : array< CGameplayEntity >;
		var foundAnomaliesDistances : array< float >;
		var currentClosestAnomaly : CGameplayEntity;
		var dist : float;
		
		//Find any anomalies in range and add them to registeredAnomalies, if they're not in there yet.
		FindGameplayEntitiesInRange(foundAnomalies, thePlayer, detectableRange, 100000, detectableTag);
		
		foundAnomaliesSize = foundAnomalies.Size();
		
		for ( i = 0; i < foundAnomaliesSize; i += 1 )
		{
			if(!registeredAnomalies.Contains(foundAnomalies[i]))
				{
					registeredAnomalies.PushBack(foundAnomalies[i]);
					foundAnomalies[i].SetFocusModeSoundEffectType(soundEffectType);//PlayEffect (detectableEffectName);
					foundAnomalies[i].SoundEvent( "qu_nml_401_vacuum_detector_loop_start" );
				} 
		}
		
		//Does anomaly still have detectableTag?
		for ( i = 0; i < registeredAnomaliesSize; i += 1 )
		{
			if (!registeredAnomalies[i].HasTag(detectableTag)) 
			{
				registeredAnomalies.Remove(registeredAnomalies[i]);
			}
		}

		registeredAnomaliesSize = registeredAnomalies.Size();
		foundAnomaliesDistances.Resize( registeredAnomaliesSize );
				
		if ( registeredAnomaliesSize > 0 )
		{
			// Remove all Anomalies which are no longer tagged detectableTag
			for ( i = registeredAnomaliesSize -1; i > -1; i -= 1 )
			{	
				if (!registeredAnomalies[i].HasTag(detectableTag)) 
				{
					registeredAnomalies.Remove(registeredAnomalies[i]);
				}
			}	
			foundAnomaliesSize = foundAnomalies.Size();
			
			//Find the closest registered Anomaly and start tracking Geralt's distance to it.
			for ( i = 0; i < registeredAnomaliesSize; i += 1 )
			{
				foundAnomaliesDistances[i] = VecDistance( registeredAnomalies[i].GetWorldPosition(), this.GetWorldPosition() );
			}
			closestAnomalyIndex = ArrayFindMinF( foundAnomaliesDistances );
			
			//Setting anomalies to allow dynamic changing of closest anomalies
			currentClosestAnomaly = registeredAnomalies[closestAnomalyIndex];

			dist = foundAnomaliesDistances[closestAnomalyIndex];
			
			//Stop old anomaly sounds if we switched
			
			if (previousClosestAnomaly.GetName() != currentClosestAnomaly.GetName()) 
			{
				previousClosestAnomaly.StopAllEffects();
				previousClosestAnomaly.SoundEvent( "qu_nml_401_vacuum_detector_intensity_1" );
				FactsRemove(potestaquisitorFact);
			}
			
			if (dist < detectableRange)
			{
				if (dist > detectableRange*0.75)
				{
					if (FactsQuerySum(potestaquisitorFact) != 1) FactsSet(potestaquisitorFact,1,-1);
					currentClosestAnomaly.SoundEvent( "qu_nml_401_vacuum_detector_intensity_1" );
					this.UpdateEffect('signal_01');
				
				}
				else if (dist > detectableRange*0.50)
				{	
					if (FactsQuerySum(potestaquisitorFact) != 2) FactsSet(potestaquisitorFact,2,-1);
					currentClosestAnomaly.SoundEvent( "qu_nml_401_vacuum_detector_intensity_2" );
					this.UpdateEffect('signal_02');
				}
				else if (dist > detectableRange*0.25)
				{
					if (FactsQuerySum(potestaquisitorFact) != 3) FactsSet(potestaquisitorFact,3,-1);
					currentClosestAnomaly.SoundEvent( "qu_nml_401_vacuum_detector_intensity_3" );
					this.PlayEffect( 'signal_03' );
				}
				else if (dist > closestRange)
				{
					if (FactsQuerySum(potestaquisitorFact) != 4) FactsSet(potestaquisitorFact,4,-1);
					currentClosestAnomaly.SoundEvent( "qu_nml_401_vacuum_detector_intensity_4" );
					this.UpdateEffect('signal_04');
				}
				else
				{
					if (FactsQuerySum(potestaquisitorFact) != 5) FactsSet(potestaquisitorFact,5,-1);
					currentClosestAnomaly.SoundEvent( "qu_nml_401_vacuum_detector_intensity_5" );
					this.UpdateEffect('signal_activated');
				}
			}
			else
			{
				if ( FactsDoesExist ( potestaquisitorFact ))
				{
					FactsRemove ( potestaquisitorFact );
				}
			}
			previousClosestAnomaly = currentClosestAnomaly;
		}
	}
	
	private function UpdateEffect (effectName:name)
	{
		this.StopAllEffects();
		this.PlayEffect( effectName );
	}
	
	private function StopScanningAnomalies()
	{
		var i : int;
		var soundOffEffectType : EFocusModeSoundEffectType;

		for ( i = 0; i < registeredAnomalies.Size(); i += 1 )
		{
			soundOffEffectType = FMSET_None;
			registeredAnomalies[i].SetFocusModeSoundEffectType(soundOffEffectType);
			registeredAnomalies[i].SoundEvent( "qu_nml_401_vacuum_detector_loop_stop" );
		}
		
		FactsRemove(potestaquisitorFact);
	}
}

//scares off sirens
class W3HornvalHorn extends W3QuestUsableItem
{
	
	
	editable var range : float;
	editable var duration : float;
	
	default itemType = UI_Horn;
	
	event OnUsed( usedBy : CEntity )
	{
		var i 				: int;
		var actorsAround 	: array<CActor>;
		var actor 			: CActor;
		var params			: SCustomEffectParams;
		
		super.OnUsed(usedBy);
		
		//theGame.GetBehTreeReactionManager().CreateReactionEvent( thePlayer, 'FearsomeEvent', duration, range, 1, -1, true, true);
		
		params.effectType 	= EET_HeavyKnockdown;
		params.creator 		= thePlayer;
		
		actorsAround = GetActorsInRange( thePlayer, range, -1, '', true );
		for( i = 0; i < actorsAround.Size(); i += 1 )
		{
			actor = actorsAround[ i ];
			if( actor.HasAbility('mon_siren_base') )
			{	
				params.duration 	= duration + RandF()* 2;
				actor.AddEffectCustom( params );
			}
		}
	}	
}

//attracts bies / fiend
class W3FiendLure extends W3QuestUsableItem
{
	editable var range 			: float;
	editable var duration 		: float;
	editable var cloudEntity 	: CEntityTemplate;
	
	event OnUsed( usedBy : CEntity )
	{
		var l_cloudEntity 	: CEntity;
		var l_destruct		: W3DestructSelfEntity;
		
		super.OnUsed(usedBy);
		
		l_cloudEntity = theGame.CreateEntity( cloudEntity, thePlayer.GetWorldPosition(), thePlayer.GetWorldRotation() );
		
		l_destruct = (W3DestructSelfEntity) l_cloudEntity;		
		if( l_destruct )
		{
			l_destruct.SetTimer( duration );
		}
		
		theGame.GetBehTreeReactionManager().CreateReactionEventIfPossible( l_cloudEntity, 'BiesLure', duration, range, 1, -1, true, true );
	}
}
