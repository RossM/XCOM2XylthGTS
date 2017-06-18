class UIScreenListener_UIChooseClass extends UIScreenListener;

var localized string m_NumInBarracks, m_NumAvailable;

event OnInit(UIScreen Screen)
{
	local XComGameStateHistory History;
	local UIChooseClass ChooseClassScreen;
	//local UISoldierHeader Header;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_Unit UnitState, HQUnitState;
	local XComGameState_Unit_XylthGTS XylthGTSState;
	local XComGameState NewGameState;
	local X2SoldierClassTemplate ClassTemplate;
	local array<X2SoldierClassTemplate> UnshuffledClassTemplates, ShuffledClassTemplates;
	local X2SoldierClassTemplateManager SoldierClassManager;
	local array<Commodity> Commodities;
	local Commodity ClassComm;
	local array<SoldierClassCount> ClassCounts, AvailableCounts;
	local SoldierClassCount SoldierClassStruct, EmptyStruct;
	local int i, r, iClass, Index;

	History = `XCOMHISTORY;
	SoldierClassManager = class'X2SoldierClassTemplateManager'.static.GetSoldierClassTemplateManager();

	ChooseClassScreen = UIChooseClass(Screen);

	// Spawn a soldier header
	//Header = ChooseClassScreen.Spawn(class'UISoldierHeader', ChooseClassScreen);
	//Header.InitSoldierHeader(ChooseClassScreen.m_UnitRef);

	XComHQ = `XCOMHQ;

	UnitState = XComGameState_Unit(History.GetGameStateForObjectID(ChooseClassScreen.m_UnitRef.ObjectID));
	XylthGTSState = XComGameState_Unit_XylthGTS(UnitState.FindComponentObject(class'XComGameState_Unit_XylthGTS'));

	if (XylthGTSState != none)
	{
		for (i = 0; i < XylthGTSState.AvailableClasses.Length && i < class'ConfigOptions'.default.MaxChoices; i++)
		{
			ClassTemplate = SoldierClassManager.FindSoldierClassTemplate(XylthGTSState.AvailableClasses[i]);
			if (ClassTemplate != none)
				ShuffledClassTemplates.AddItem(ClassTemplate);
		}
	}
	else
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Create XylthGTS State");

		XylthGTSState = XComGameState_Unit_XylthGTS(NewGameState.CreateStateObject(class'XComGameState_Unit_XylthGTS'));
		UnitState = XComGameState_Unit(NewGameState.CreateStateObject(UnitState.class, UnitState.ObjectID));
		NewGameState.AddStateObject(XylthGTSState);
		NewGameState.AddStateObject(UnitState);
		UnitState.AddComponentObject(XylthGTSState);

		UnshuffledClassTemplates = ChooseClassScreen.GetClasses();

		for (i = 0; UnshuffledClassTemplates.Length > 0; i++)
		{
			r = `SYNC_RAND(UnshuffledClassTemplates.Length);

			ClassTemplate = UnshuffledClassTemplates[r];
			XylthGTSState.AvailableClasses.AddItem(ClassTemplate.DataName);
			UnshuffledClassTemplates.Remove(r, 1);

			if (i < class'ConfigOptions'.default.MaxChoices)
				ShuffledClassTemplates.AddItem(ClassTemplate);
		}

		`GAMERULES.SubmitGameState(NewGameState);
	}

	if (ShuffledClassTemplates.Length == 0)
		return;

	ShuffledClassTemplates.Sort(class'UIChooseClass'.static.SortClassesByName);

	ChooseClassScreen.m_arrClasses = ShuffledClassTemplates;

	// Count existing soldiers
	for (iClass = 0; iClass < ShuffledClassTemplates.Length; iClass++)
	{
		SoldierClassStruct = EmptyStruct;
		SoldierClassStruct.SoldierClassName = ShuffledClassTemplates[iClass].DataName;
		SoldierClassStruct.Count = 0;
		ClassCounts.AddItem(SoldierClassStruct);
		AvailableCounts.AddItem(SoldierClassStruct);
	}

	// Grab current crew information
	for(i = 0; i < XComHQ.Crew.Length; i++)
	{
		HQUnitState = XComGameState_Unit(History.GetGameStateForObjectID(XComHQ.Crew[i].ObjectID));

		if(HQUnitState != none && HQUnitState.IsASoldier() && HQUnitState.GetRank() > 0)
		{
			Index = ClassCounts.Find('SoldierClassName', HQUnitState.GetSoldierClassTemplate().DataName);

			if(Index != INDEX_NONE)
			{
				// Add to class count
				ClassCounts[Index].Count++;
				if (HQUnitState.GetStatus() == eStatus_Active || HQUnitState.GetStatus() == eStatus_PsiTraining)
					AvailableCounts[Index].Count++;
			}
		}
	}

	// Logic from UIChooseClass.ConvertClassesToCommodities
	for (iClass = 0; iClass < ChooseClassScreen.m_arrClasses.Length; iClass++)
	{
		ClassTemplate = ChooseClassScreen.m_arrClasses[iClass];

		ClassComm.Title = ClassTemplate.DisplayName;
		ClassComm.Image = ClassTemplate.IconImage;
		ClassComm.Desc = ClassTemplate.ClassSummary;
		ClassComm.OrderHours = XComHQ.GetTrainRookieDays() * 24;

		// Add number of this soldier in the soldier barracks to description
		Index = ClassCounts.Find('SoldierClassName', ClassTemplate.DataName);
		if(Index != INDEX_NONE)
		{
			ClassComm.Desc = 
				class'UIUtilities_Text'.static.GetColoredText(Repl(m_NumInBarracks, "%COUNT", ClassCounts[Index].Count),
					ClassCounts[Index].Count > 0 ? eUIState_Good : eUIState_Bad) @
				class'UIUtilities_Text'.static.GetColoredText(Repl(m_NumAvailable, "%COUNT", AvailableCounts[Index].Count),
					AvailableCounts[Index].Count > 0 ? eUIState_Good : eUIState_Bad) $
				"\n" $ ClassComm.Desc;
		}

		Commodities.AddItem(ClassComm);
	}

	ChooseClassScreen.arrItems = Commodities;
	ChooseClassScreen.PopulateData();
}

defaultproperties
{
	ScreenClass = UIChooseClass;
}