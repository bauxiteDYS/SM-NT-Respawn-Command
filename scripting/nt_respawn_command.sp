#include <sourcemod>
#include <sdktools>
#include <neotokyo>

#define LIFE_ALIVE 0
#define OBS_MODE_NONE 0
#define DAMAGE_YES 2
#define TRAIN_NEW 0xc0
#define SOLID_BBOX 2
#define EF_NODRAW 0x020
#define SF_NORESPAWN (1 << 30)
#define DEATH_COMPLETE_SEC 10.0

bool canRespawn[NEO_MAXPLAYERS+1];

public Plugin myinfo = {
	name = "Respawn command",
	author = "bauxite, rain",
	description = "A !respawn command",
	version = "0.1.0",
	url = "",
};

public void OnPluginStart()	
{
	RegAdminCmd("sm_respawn", RespawnMe, ADMFLAG_GENERIC, "");
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
}

public void OnMapStart()
{
	for(int client = 0; client <= MaxClients; client++)
	{
		canRespawn[client] = false;
	}
}

public void OnClientDisconnect_Post(int client)
{
	canRespawn[client] = false;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int useridClient = GetEventInt(event, "userid");
	int client = GetClientOfUserId(useridClient);
	
	if(client <= 0 || client > MaxClients)
	{
		return;
	}
	
	canRespawn[client] = false;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int useridClient = GetEventInt(event, "userid");
	int client = GetClientOfUserId(useridClient);
	
	if(client <= 0 || client > MaxClients)
	{
		return;
	}

	canRespawn[client] = false;

	CreateTimer(DEATH_COMPLETE_SEC, Timer_PlayerDeathComplete, useridClient, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_PlayerDeathComplete(Handle Timer, int userid)
{
	int client = GetClientOfUserId(userid);
	
	if(client <= 0 || client > MaxClients)
	{
		return Plugin_Stop;
	}
	
	canRespawn[client] = true;
	
	return Plugin_Stop;
}

public Action RespawnMe(int client, int args)
{
	if(client <= 0 || client > MaxClients)
	{
		return Plugin_Handled;
	}
	
	if(!IsClientInGame(client) || IsPlayerAlive(client))
	{
		return Plugin_Handled;
	}
	
	if(!canRespawn[client])
	{
		return Plugin_Handled;
	}
	
	RespawnDeadPlayer(client);
	
	canRespawn[client] = false;
	
	return Plugin_Handled;
}

void RespawnDeadPlayer(int client)
{
	SetPlayerProps(client);
	
	static Handle call = INVALID_HANDLE;
	if (call == INVALID_HANDLE)
	{
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetSignature(SDKLibrary_Server,
			"\x56\x8B\xF1\x8B\x06\x8B\x90\xBC\x04\x00\x00\x57\xFF\xD2\x8B\x06",
			16
		);
		call = EndPrepSDKCall();
		if (call == INVALID_HANDLE)
		{
			SetFailState("Failed to prepare SDK call");
		}
	}
	SDKCall(call, client);
}

void SetPlayerProps(int client)
{
	SetEntProp(client, Prop_Send, "m_iLives", 1);
	SetEntProp(client, Prop_Send, "m_iObserverMode", OBS_MODE_NONE);
	SetEntProp(client, Prop_Send, "m_iHealth", 100);
	SetEntProp(client, Prop_Send, "m_lifeState", LIFE_ALIVE);
	SetEntProp(client, Prop_Send, "deadflag", 0);
	SetEntPropFloat(client, Prop_Send, "m_flDeathTime", 0.0);
	SetEntProp(client, Prop_Send, "m_bDucked", false);
	SetEntProp(client, Prop_Send, "m_bDucking", false);
	SetEntProp(client, Prop_Send, "m_bDrawViewmodel", true);
	SetEntProp(client, Prop_Send, "m_nRenderFX", 0);
	SetEntPropFloat(client, Prop_Send, "m_flNextAttack", GetGameTime());
	SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 0.0);
	SetEntPropFloat(client, Prop_Send, "m_flFallVelocity", 0.0);
	SetEntProp(client, Prop_Send, "m_nSolidType", SOLID_BBOX);
	SetEntProp(client, Prop_Data, "m_fInitHUD", 1);
	SetEntPropFloat(client, Prop_Data, "m_DmgTake", 0.0);
	SetEntPropFloat(client, Prop_Data, "m_DmgSave", 0.0);
	SetEntProp(client, Prop_Data, "m_afPhysicsFlags", 0);
	SetEntProp(client, Prop_Data, "m_bitsDamageType", 0);
	SetEntProp(client, Prop_Data, "m_bitsHUDDamage", -1);
	SetEntProp(client, Prop_Data, "m_takedamage", DAMAGE_YES);
	SetEntityMoveType(client, MOVETYPE_WALK);
	// declaring as variables for older sm compat
	float campvsorigin[3];
	float hackedgunpos[3] = { 0.0, 32.0, 0.0 };
	SetEntPropVector(client, Prop_Data, "m_vecCameraPVSOrigin", campvsorigin);
	SetEntPropVector(client, Prop_Data, "m_HackedGunPos", hackedgunpos);
	SetEntProp(client, Prop_Data, "m_bPlayerUnderwater", false);
	SetEntProp(client, Prop_Data, "m_iTrain", TRAIN_NEW);
	SetInvisible(client, false);
	SetEntityFlags(client, GetEntityFlags(client) & ~FL_GODMODE);
	ChangeEdictState(client, 0);
}

void SetInvisible(int client, bool is_invisible)
{
	if (is_invisible)
	{
		SetEntProp(client, Prop_Send, "m_fEffects",
			GetEntProp(client, Prop_Send, "m_fEffects") | EF_NODRAW);
	}
	else
	{
		SetEntProp(client, Prop_Send, "m_fEffects",
			GetEntProp(client, Prop_Send, "m_fEffects") & ~EF_NODRAW);
	}
}
