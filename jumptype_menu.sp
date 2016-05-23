#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

#define DATA "1.1"

#define HEIGHT 1.1
#define LENGTH 1.75

new salto[MAXPLAYERS+1];

new g_iToolsVelocity;

Handle cvar_jumptype;
int g_jumptype;

public Plugin:myinfo = 
{
	name = "SM Jump type Menu",
	author = "Franc1sco franug",
	description = "Change your jump type with a menu for selection",
	version = DATA,
	url = "http://steamcommunity.com/id/franug"
}

public OnPluginStart()
{
	CreateConVar("sm_jumptype_version", DATA, "", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	RegConsoleCmd("sm_bhop", DOMenu);
	HookEvent("player_jump", Event_OnPlayerJump);
	
	cvar_jumptype = CreateConVar("sm_jumptype_only", "2", "0 = only easy hop. 1 = only long jump. 2 = you can choose both");
	g_jumptype = GetConVarInt(cvar_jumptype);
	
	HookConVarChange(cvar_jumptype, changed);
	
	g_iToolsVelocity = FindSendPropInfo("CBasePlayer", "m_vecVelocity[0]");
	
	for(int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
}

public changed(Handle:cvar, const String:oldvalue[], const String:newvalue[])
{
	g_jumptype = GetConVarInt(cvar_jumptype);
	for(int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
}

public void OnConfigsExecuted()
{
	BhopOn();
}

void BhopOn()
{
	SetCvar("sv_enablebunnyhopping", "1"); 
	SetCvar("sv_staminamax", "0");
	SetCvar("sv_airaccelerate", "3000");
	SetCvar("sv_staminajumpcost", "0");
	SetCvar("sv_staminalandcost", "0");
}

stock void SetCvar(char[] scvar, char[] svalue)
{
	Handle cvar = FindConVar(scvar);
	if(cvar != INVALID_HANDLE) SetConVarString(cvar, svalue, true);
}

public Action:DOMenu(client,args)
{
	if (g_jumptype != 2)return Plugin_Continue;
	
	new Handle:menu = CreateMenu(DIDMenuHandler);
	SetMenuTitle(menu, "Choose jump type");
	
	if(salto[client] == 0) AddMenuItem(menu, "longjump", "Enable Long Jump");
	else AddMenuItem(menu, "bhop", "Enable Easy Hop");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public DIDMenuHandler(Handle:menu, MenuAction:action, client, itemNum) 
{
	if ( action == MenuAction_Select ) 
	{
		new String:info[32];
		
		GetMenuItem(menu, itemNum, info, sizeof(info));
		
		if ( strcmp(info,"longjump") == 0 ) 
		{
			salto[client] = 1;
			DOMenu(client,0);
		}
		else
		{
			salto[client] = 0;
			DOMenu(client,0);
		}
		
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public OnClientPutInServer(client)
{
	if (g_jumptype == 2)
		salto[client] = 1;
	else salto[client] = g_jumptype;
}

public Action:Event_OnPlayerJump(Handle:event, const String:name[], bool:dontBroadcast) 
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (salto[client] == 0) SetEntPropFloat(client, Prop_Send, "m_flStamina", 0.0);
	else CreateTimer(0.0, EventPlayerJumpPost, client);
	//else JumpBoostOnClientJumpPost(client);
}

public Action:EventPlayerJumpPost(Handle:timer, any:client)
{
    // If client isn't in-game, then stop.
    if (!IsClientInGame(client))
    {
        return;
    }
    
    // Forward event to modules.
    JumpBoostOnClientJumpPost(client);
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (IsClientInGame(client) && IsPlayerAlive(client) && salto[client] == 0)
	{
		if (buttons & IN_JUMP)
		{
			if (!(GetEntityFlags(client) & FL_ONGROUND))
			{
				if (!(GetEntityMoveType(client) & MOVETYPE_LADDER))
				{
					new iType = GetEntProp(client, Prop_Data, "m_nWaterLevel");
					if (iType <= 1)
					{
							buttons &= ~IN_JUMP;
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

/**
 * Client is jumping.
 * 
 * @param client    The client index.
 */
JumpBoostOnClientJumpPost(client)
{
    // Get class jump multipliers.
    new Float:distancemultiplier = LENGTH;
    new Float:heightmultiplier = HEIGHT;
    
    // If both are set to 1.0, then stop here to save some work.
    if (distancemultiplier == 1.0 && heightmultiplier == 1.0)
    {
        return;
    }
    
    new Float:vecVelocity[3];
    
    // Get client's current velocity.
    ToolsClientVelocity(client, vecVelocity, false);
    
    // Only apply horizontal multiplier if it's not a bhop.
    if (!JumpBoostIsBHop(vecVelocity))
    {
        // Apply horizontal multipliers to jump vector.
        vecVelocity[0] *= distancemultiplier;
        vecVelocity[1] *= distancemultiplier;
    }
    
    // Apply height multiplier to jump vector.
    vecVelocity[2] *= heightmultiplier;
    
    // Set new velocity.
    ToolsClientVelocity(client, vecVelocity, true, false);
}

/**
 * This function detects excessive bunnyhopping.
 * Note: This ONLY catches bunnyhopping that is worse than CS:S already allows.
 * 
 * @param vecVelocity   The velocity of the client jumping.
 * @return              True if the client is bunnyhopping, false if not.
 */
stock bool:JumpBoostIsBHop(const Float:vecVelocity[])
{
    // Calculate the magnitude of jump on the xy plane.
    new Float:magnitude = SquareRoot(Pow(vecVelocity[0], 2.0) + Pow(vecVelocity[1], 2.0));
    
    // Return true if the magnitude exceeds the max.
    new Float:bunnyhopmax = 300.0;
    return (magnitude > bunnyhopmax);
}

stock ToolsClientVelocity(client, Float:vecVelocity[3], bool:apply = true, bool:stack = true)
{
    // If retrieve if true, then get client's velocity.
    if (!apply)
    {
        // x = vector component.
        for (new x = 0; x < 3; x++)
        {
            vecVelocity[x] = GetEntDataFloat(client, g_iToolsVelocity + (x*4));
        }
        
        // Stop here.
        return;
    }
    
    // If stack is true, then add client's velocity.
    if (stack)
    {
        // Get client's velocity.
        new Float:vecClientVelocity[3];
        
        // x = vector component.
        for (new x = 0; x < 3; x++)
        {
            vecClientVelocity[x] = GetEntDataFloat(client, g_iToolsVelocity + (x*4));
        }
        
        AddVectors(vecClientVelocity, vecVelocity, vecVelocity);
    }
    
    // Apply velocity on client.
    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vecVelocity);
}