%%%=============================================================================
%%% @doc A health potion (pot).
%%% consuming it regenerates 25 health
%%% @end
%%%=============================================================================
-module(object).
-extends(thing).
-export([start/4]).
-include("defs.hrl").

%%%%%%%%%%%%%
%%% Types %%%
%%%%%%%%%%%%%

%%%%%%%%%%%%%%%
%%% Records %%%
%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Public functions %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%

-spec start ( Type      :: atom()
            , Name      :: string()
            , Value     :: any()
            , Room_Proc :: #room_proc{}
            ) -> #thing_proc{}.
%% @doc Start an object's process with a given name. The process will run until
%% the object is interacted with. Returns the thing_proc of the object.
%% @end
start(Type, Name, Value, Room_Proc)->
    case Type of
        potion ->
            #thing_proc { pid = spawn(fun() -> potionloop(Value, Room_Proc) end)
                        , name = Name};
			
        weapon ->
            #thing_proc { pid = spawn(fun() -> weaponloop(Value, Room_Proc) end)
                        , name = Name};
			
	pickable ->
            #thing_proc { pid = spawn(fun() -> pickableloop(Room_Proc) end)
                        , name = Name};
		
        _Any ->
            #thing_proc { pid = spawn(fun() -> rockloop() end)
                        , name = Name}
			
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Private functions %%%
%%%%%%%%%%%%%%%%%%%%%%%%%    

-spec rockloop() -> no_return().
%% @doc An inanimate rock.
%% @end
rockloop() ->
    receive
        _Any -> rockloop()
    end.

pickableloop(Room_Proc) ->
    receive
        Event when  is_record(Event, event)  andalso Event#event.object#thing_proc.pid == self() andalso Event#event.verb == take ->
			    room:broadcast
			( Room_Proc
			, #event{ verb = take
				, subject = Event#event.object
				, object = Event#event.subject
			       }
			, Event#event.object);
        _Any-> pickableloop(Room_Proc)
    end.
-spec potionloop( HealAmount    :: pos_integer()
                , Room_Proc     :: #room_proc{}
                ) -> no_return().
%% @doc A health potion.    
%% @end
%% @todo: the potion never gets used up.
potionloop(HealAmount, Room_Proc)->
    receive 
        Event when  is_record(Event, event)
                    andalso Event#event.object#thing_proc.pid == self() ->
            case Event#event.verb of 
                drink ->
                    room:broadcast
                        ( Room_Proc
                        , #event{ verb = heal
                                , subject = Event#event.object
                                , object = Event#event.subject
                                , payload = [{heal, HealAmount}]}
                        , Event#event.object);
                _Any ->
                    %% @todo tell room an invalid verb was sent
                    potionloop(HealAmount, Room_Proc)
            end;
        _Any-> potionloop(HealAmount, Room_Proc)
    end.

-spec weaponloop( AttackBonus   :: pos_integer()
                , Room_Proc     :: #room_proc{}
                ) -> no_return().
%% @doc A weapon.
%% @end
weaponloop(AttackBonus, Room_Proc) ->     
    receive 
        Event when  is_record(Event, event)
                    andalso Event#event.object#thing_proc.pid == self() ->
            case Event#event.verb of 
                take ->
                    room:broadcast
                        ( Room_Proc
                        , #event{ verb = inc_attack
                                , subject = Event#event.object
                                , object = Event#event.subject
                                , payload = [{inc_attack, AttackBonus}]}
                        , Event#event.object);
                                    
                _Any ->
                    %% @todo tell room an invalid verb was sent
                    weaponloop(AttackBonus, Room_Proc)
            end;
        _Any-> weaponloop(AttackBonus, Room_Proc)
    end.
