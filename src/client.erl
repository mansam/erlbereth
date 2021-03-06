%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Client module
% Outputs game messages to the console.
% Also watches for keyboard input, passes
% to the parser, and sends to the connection manager.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-module(client).
-include("defs.hrl").
-export( [start/0, outputloop/0, inputloop/3 ] ).


outputloop() ->
	io:format("~n"),
	receive 
	{fail, GameAction} ->
		io:format(" Your action ~s failed.", [GameAction#action.verb] ),
		outputloop();

	{event, Event} when Event#event.verb == look ->
		io:format("~s.~n", [Event#event.object]),
		{_,Items} = lists:keyfind(room_content, 1, Event#event.payload),
		if
			length(Items) > 1 ->
				io:format("You see:~n", []),
				lists:foreach(fun(X)->io:format("* ~s \r\n", [X] ) end, Items);
			true	->
				io:format("There is nothing here~n",[])
		end,
		outputloop();
    
    {event, Event} when Event#event.verb == display_status ->
        {health, Health} = lists:keyfind(health, 1, Event#event.payload),
        {attack, Attack} = lists:keyfind(attack, 1, Event#event.payload),
        io:format   ( "~s's current status is:~nHealth: ~p~nAttack: ~p~n"
                    , [Event#event.subject#thing_proc.name, Health, Attack]),
        outputloop();

	{event, Event} when is_record(Event#event.object, thing_proc) ->
		io:format("~s ~sed the ~s", 
		[Event#event.subject#thing_proc.name, atom_to_list(Event#event.verb), Event#event.object#thing_proc.name]),
		outputloop();
        
    {event, Event} when is_record(Event#event.object, room_proc) ->
		io:format("~s ~ped the ~s", 
		[Event#event.subject#thing_proc.name, Event#event.verb, Event#event.object#room_proc.description]),
		outputloop();

	{chat, Message, Sender} ->
		io:format("~p whispers: ~p~n", [Sender, Message]),
		outputloop()
	end.

inputloop(Pid, Username, ConnectPid) ->
	String = string:strip(io:get_line( "$" ),both, $\n ),
	if
		String == "" ->
			inputloop(Pid, Username, ConnectPid);
		String == "quit" ->
			io:format("Exiting...");
		true ->
			Tokens = parser:parse(String),
			case Tokens of
				["say", DestUser | Message ] ->
					ConnectPid ! {send_message, DestUser, string:join(Message, " ")},
					inputloop(Pid, Username, ConnectPid);
				[Verb | DirectObject] ->
					ConnectPid ! {send_input, { Username, {list_to_atom(Verb), string:join(DirectObject, " ")} } },
					inputloop(Pid, Username, ConnectPid);
				{Verb} ->
					ConnectPid ! {send_input, { Username, {list_to_atom(Verb)} } },
					inputloop(Pid, Username, ConnectPid)
			end
	end.

getUserInfo() ->
	Uname = string:strip(io:get_line( "Enter username:" ), both, $\n ),
	Server = list_to_atom( string:strip( io:get_line( "Enter server node:"), both, $\n )  ),
	{Uname, Server}.
welcome() ->
	String = "~n**Welcome to Erlbereth**~n~nUse commands such as \"attack skeleton,\" \"take key,\" \"say sam hello, sam.\" Try \"look\" to find out where you are.~n",
	io:format(String).
start() ->
	{Uname, Server} = getUserInfo(),
	io:format(" Connecting to server ~p ~n", [Server] ),
	Success = clientConnection:connect(Server, Uname),
	case Success of
	{ok, ConnectPid} ->
		welcome(),
		Outpid = spawn( client, outputloop, [] ),
		ConnectPid ! {connect_ui, Outpid},
		inputloop(Outpid, Uname, ConnectPid);
	_ ->
		io:format("Could not connect to server")
	end.
