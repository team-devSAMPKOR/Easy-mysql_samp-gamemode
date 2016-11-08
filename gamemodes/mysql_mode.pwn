/*@ mysql_mode @ https://github.com/u4bi */
#include <a_samp>
#include <a_mysql>
#include <foreach>
 
#define DL_LOGIN    100
#define DL_REGIST   101
 
main(){}
 
forward check(playerid);
forward regist(playerid, pass[]);
forward save(playerid);
forward load(playerid);
forward ServerThread();
 
enum USER_MODEL{
    ID,
    NAME[MAX_PLAYER_NAME],
    PASS[24],
    MONEY,
    SKIN,
}
new USER[MAX_PLAYERS][USER_MODEL];
 
enum INGAME_MODEL{
    bool:LOGIN
}
new INGAME[MAX_PLAYERS][INGAME_MODEL];
 
static mysql;
 
public OnGameModeExit(){return 1;}
public OnGameModeInit(){
    mode(); server(); dbcon(); thread();
    return 1;
}
public OnPlayerRequestClass(playerid, classid){
    
    if(INGAME[playerid][LOGIN]) return SendClientMessage(playerid,-1,"already login");
 
    join(playerid, check(playerid));
    return 1;
}
public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[]){
    
    if(!response) if(dialogid == DL_LOGIN || dialogid == DL_REGIST) return Kick(playerid);
 
    switch(dialogid){
        case DL_LOGIN  : checked(playerid, inputtext);
        case DL_REGIST : regist(playerid, inputtext);
    }
    return 1;
}
public OnPlayerCommandText(playerid, cmdtext[]){
    if(!strcmp("/sav", cmdtext)){
        
        if(!INGAME[playerid][LOGIN]) return SendClientMessage(playerid,-1,"not login");
 
        save(playerid);
        SendClientMessage(playerid,-1,"data save");
        return 1;
    }
    return 0;
}
public OnPlayerDisconnect(playerid, reason){
    
    if(INGAME[playerid][LOGIN]) save(playerid);
 
    cleaning(playerid);
    return 1;
}
 
/* REG/LOG CHECK MANAGER @checked(playerid, password[]) @join(playerid, type) */
stock checked(playerid, password[]){
    
    if(strlen(password) == 0) return join(playerid, 1), SendClientMessage(playerid,-1,"password length");
    if(strcmp(password, USER[playerid][PASS])) return join(playerid, 1), SendClientMessage(playerid,-1,"login fail");
 
    SendClientMessage(playerid,-1,"login success");
    INGAME[playerid][LOGIN] = true;
    load(playerid);
    return 1;
}
stock join(playerid, type){
    switch(playerid, type){
        case 0 : ShowPlayerDialog(playerid, DL_REGIST, DIALOG_STYLE_PASSWORD, "manager", "Regist plz", "join", "quit");
        case 1 : ShowPlayerDialog(playerid, DL_LOGIN, DIALOG_STYLE_PASSWORD, "manager", "Login plz", "join", "quit");
    }
    return 1;
}
 
/*SQL @ check(playerid) @ regist(playerid, pass) @ save(playerid) @ load(playerid) @ escape(str[])*/
public check(playerid){
    new query[128], result;
    GetPlayerName(playerid, USER[playerid][NAME], MAX_PLAYER_NAME);
 
    mysql_format(mysql, query, sizeof(query), "SELECT ID, PASS FROM `userlog_info` WHERE `NAME` = '%s' LIMIT 1", escape(USER[playerid][NAME]));
    mysql_query(mysql, query);
 
    result = cache_num_rows();
    if(result){
        USER[playerid][ID]     = cache_get_field_content_int(0, "ID");
        cache_get_field_content(0, "PASS", USER[playerid][PASS], mysql, 24);
    }
    return result;
}
public regist(playerid, pass[]){
 
    format(USER[playerid][PASS],24, "%s",pass);
 
    new query[256];
    GetPlayerName(playerid, USER[playerid][NAME], MAX_PLAYER_NAME);
    mysql_format(mysql, query, sizeof(query), "INSERT INTO `userlog_info` (`NAME`,`PASS`,`MONEY`,`SKIN`) VALUES ('%s','%s',%d,%d)",
    escape(USER[playerid][NAME]), escape(USER[playerid][PASS]), USER[playerid][MONEY] = 1000, USER[playerid][SKIN] = 129);
 
    mysql_query(mysql, query);
    USER[playerid][ID] = cache_insert_id();
 
    SendClientMessage(playerid,-1,"regist success");
    INGAME[playerid][LOGIN] = true;
    spawn(playerid);
}
public save(playerid){
    new query[256];
    mysql_format(mysql, query, sizeof(query), "UPDATE `userlog_info` SET `MONEY`=%d,`SKIN`=%d WHERE `ID`=%d",
    USER[playerid][MONEY], USER[playerid][SKIN], USER[playerid][ID]);
 
    mysql_query(mysql, query);
}
public load(playerid){
    new query[256];
    mysql_format(mysql, query, sizeof(query), "SELECT * FROM `userlog_info` WHERE `ID` = %d LIMIT 1", USER[playerid][ID]);
    mysql_query(mysql, query);
 
    USER[playerid][MONEY]   = cache_get_field_content_int(0, "MONEY");
    USER[playerid][SKIN]    = cache_get_field_content_int(0, "SKIN");
    spawn(playerid);
}
stock escape(str[]){
    new result[24];
    mysql_real_escape_string(str, result);
    return result;
}
 
/* INGAME FUNCTION @ spawn(playerid) */
stock spawn(playerid){
 
    SetSpawnInfo(playerid, 0, USER[playerid][SKIN], 0.0, 0.0, 0.0, 180, 0, 0, 0, 0, 0, 0);
 
    SpawnPlayer(playerid);
    ResetPlayerMoney(playerid);
    GivePlayerMoney(playerid, USER[playerid][MONEY]);
}
 
/* INIT @ mode() @ thread() @ server() @ dbcon() @ cleaning(playerid) */
stock mode(){}
stock thread(){ SetTimer("ServerThread", 500, true); }
stock server(){
    SetGameModeText("Blank Script");
    AddPlayerClass(0,0,0,0,0,0,0,0,0,0,0);
}
/* TODO : README.MD*/
stock dbcon(){
    new db_key[4][128] = {"hostname", "username", "database", "password"}, db_value[4][128];
    new File:cfg=fopen("database.cfg", io_read), temp[64], tick =0;
 
    while(fread(cfg, temp)){
        if(strcmp(temp, db_key[tick])){
            new pos = strfind(temp, "=");
            strdel(temp, 0, pos+1);
            new len = strlen(temp);
            if(tick != 3)strdel(temp, len-2, len);
            db_value[tick] = temp;
        }
        tick++;
    }
    
    mysql = mysql_connect(db_value[0], db_value[1], db_value[2], db_value[3]);
    mysql_set_charset("euckr");
 
    if(!mysql_errno(mysql))print("db connection success.");
}
stock cleaning(playerid){
    new temp[USER_MODEL], temp2[INGAME_MODEL];
    USER[playerid] = temp;
    INGAME[playerid] = temp2;
}
 
/* SERVER THREAD*/
public ServerThread(){
    foreach (new i : Player){ eventMoney(i);
    }
}
 
/* stock */
stock eventMoney(playerid){ giveMoney(playerid, 1);
}
stock giveMoney(playerid,money){
    ResetPlayerMoney(playerid);
    GivePlayerMoney(playerid, USER[playerid][MONEY]+=money);
}