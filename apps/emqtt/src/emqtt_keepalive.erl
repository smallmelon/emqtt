%%-----------------------------------------------------------------------------
%% Copyright (c) 2012-2015, Feng Lee <feng@emqtt.io>
%% 
%% Permission is hereby granted, free of charge, to any person obtaining a copy
%% of this software and associated documentation files (the "Software"), to deal
%% in the Software without restriction, including without limitation the rights
%% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%% copies of the Software, and to permit persons to whom the Software is
%% furnished to do so, subject to the following conditions:
%% 
%% The above copyright notice and this permission notice shall be included in all
%% copies or substantial portions of the Software.
%% 
%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
%% SOFTWARE.
%%------------------------------------------------------------------------------

-module(emqtt_keepalive).

-author('feng@emqtt.io').

-export([new/3, resume/1, cancel/1]).

-record(keepalive, {transport, socket, recv_oct, timeout_sec, timeout_msg, timer_ref}).

%%
%% @doc create a keepalive.
%%
new({Transport, Socket}, TimeoutSec, TimeoutMsg) when TimeoutSec > 0 ->
    {ok, [{recv_oct, RecvOct}]} = Transport:getstat(Socket, [recv_oct]),
	Ref = erlang:send_after(TimeoutSec*1000, self(), TimeoutMsg),
	#keepalive {transport   = Transport,
                socket      = Socket, 
                recv_oct    = RecvOct, 
                timeout_sec = TimeoutSec, 
                timeout_msg = TimeoutMsg,
                timer_ref   = Ref }.

%%
%% @doc try to resume keepalive, called when timeout.
%%
resume(KeepAlive = #keepalive {transport   = Transport, 
                               socket      = Socket, 
                               recv_oct    = RecvOct, 
                               timeout_sec = TimeoutSec, 
                               timeout_msg = TimeoutMsg, 
                               timer_ref   = Ref }) ->
    {ok, [{recv_oct, NewRecvOct}]} = Transport:getstat(Socket, [recv_oct]),
    if
        NewRecvOct =:= RecvOct -> 
            timeout;
        true ->
            %need?
            cancel(Ref),
            NewRef = erlang:send_after(TimeoutSec*1000, self(), TimeoutMsg),
            {resumed, KeepAlive#keepalive { recv_oct = NewRecvOct, timer_ref = NewRef }}
    end.

%%
%% @doc cancel keepalive
%%
cancel(#keepalive { timer_ref = Ref }) ->
    cancel(Ref);
cancel(undefined) -> 
	undefined;
cancel(Ref) -> 
	catch erlang:cancel_timer(Ref).

