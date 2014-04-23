%% The MIT License

%% Copyright (c) 2010-2013 alisdair sullivan <alisdairsullivan@yahoo.ca>

%% Permission is hereby granted, free of charge, to any person obtaining a copy
%% of this software and associated documentation files (the "Software"), to deal
%% in the Software without restriction, including without limitation the rights
%% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%% copies of the Software, and to permit persons to whom the Software is
%% furnished to do so, subject to the following conditions:

%% The above copyright notice and this permission notice shall be included in
%% all copies or substantial portions of the Software.

%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
%% THE SOFTWARE.


-module(jsxn).

-export([encode/1, encode/2, decode/1, decode/2]).
-export([is_json/1, is_json/2, is_term/1, is_term/2]).
-export([format/1, format/2, minify/1, prettify/1]).
-export([encoder/3, decoder/3, parser/3]).
-export([resume/3]).
-export([init/1, handle_event/2]).

-export_type([json_term/0, json_text/0, token/0]).
-export_type([encoder/0, decoder/0, parser/0, internal_state/0]).
-export_type([config/0]).


-type json_term() :: [{binary() | atom(), json_term()}] | [{}]
    | [json_term()] | []
    | #{}
    | true | false | null
    | integer() | float()
    | binary() | atom().

-type json_text() :: binary().

-type config() :: jsx_config:config().

-spec encode(Source::json_term()) -> json_text() | {incomplete, encoder()}.
-spec encode(Source::json_term(), Config::jsx_to_json:config()) -> json_text() | {incomplete, encoder()}.

encode(Source) -> jsx:encode(Source, []).
encode(Source, Config) -> jsx:encode(Source, Config).


-spec decode(Source::json_text()) -> json_term() | {incomplete, decoder()}.
-spec decode(Source::json_text(), Config::jsx_to_term:config()) -> json_term()  | {incomplete, decoder()}.

decode(Source) -> decode(Source, []).
decode(Source, Config) -> (jsx:decoder(?MODULE, Config, jsx_config:extract_config(Config)))(Source).


-spec format(Source::json_text()) -> json_text() | {incomplete, decoder()}.
-spec format(Source::json_text(), Config::jsx_to_json:config()) -> json_text() | {incomplete, decoder()}.

format(Source) -> jsx:format(Source, []).
format(Source, Config) -> jsx:format(Source, Config).


-spec minify(Source::json_text()) -> json_text()  | {incomplete, decoder()}.

minify(Source) -> jsx:format(Source, []).


-spec prettify(Source::json_text()) -> json_text() | {incomplete, decoder()}.

prettify(Source) -> jsx:format(Source, [space, {indent, 2}]).


-spec is_json(Source::any()) -> true | false.
-spec is_json(Source::any(), Config::jsx_verify:config()) -> true | false.

is_json(Source) -> jsx:is_json(Source, []).
is_json(Source, Config) -> jsx:is_json(Source, Config).


-spec is_term(Source::any()) -> true | false.
-spec is_term(Source::any(), Config::jsx_verify:config()) -> true | false.

is_term(Source) -> jsx:is_term(Source, []).
is_term(Source, Config) -> jsx:is_term(Source, Config).


-type decoder() :: fun((json_text() | end_stream) -> any()).

-spec decoder(Handler::module(), State::any(), Config::list()) -> decoder().

decoder(Handler, State, Config) -> jsx:decoder(Handler, State, Config).


-type encoder() :: fun((json_term() | end_stream) -> any()).

-spec encoder(Handler::module(), State::any(), Config::list()) -> encoder().

encoder(Handler, State, Config) -> jsx:encoder(Handler, State, Config).


-type token() :: [token()]
    | start_object
    | end_object
    | start_array
    | end_array
    | {key, binary()}
    | {string, binary()}
    | binary()
    | {number, integer() | float()}
    | {integer, integer()}
    | {float, float()}
    | integer()
    | float()
    | {literal, true}
    | {literal, false}
    | {literal, null}
    | true
    | false
    | null
    | end_json.


-type parser() :: fun((token() | end_stream) -> any()).

-spec parser(Handler::module(), State::any(), Config::list()) -> parser().

parser(Handler, State, Config) -> jsx:parser(Handler, State, Config).

-opaque internal_state() :: tuple().

-spec resume(Term::json_text() | token(), InternalState::internal_state(), Config::list()) -> any().

resume(Term, {decoder, State, Handler, Acc, Stack}, Config) ->
    jsx_decoder:resume(Term, State, Handler, Acc, Stack, jsx_config:parse_config(Config));
resume(Term, {parser, State, Handler, Stack}, Config) ->
    jsx_parser:resume(Term, State, Handler, Stack, jsx_config:parse_config(Config)).



-record(config, {
    labels = binary
}).

-type state() :: {[any()], #config{}}.
-spec init(Config::proplists:proplist()) -> state().

init(Config) -> jsx_to_term:init(Config).


-spec handle_event(Event::any(), State::state()) -> state().

handle_event(end_json, State) -> get_value(State);

handle_event(start_object, State) -> start_object(State);
handle_event(end_object, State) -> finish(State);

handle_event(start_array, State) -> start_array(State);
handle_event(end_array, State) -> finish(State);

handle_event({key, Key}, {_, Config} = State) -> insert(format_key(Key, Config), State);

handle_event({_, Event}, State) -> insert(Event, State).


format_key(Key, Config) ->
    case Config#config.labels of
        binary -> Key
        ; atom -> binary_to_atom(Key, utf8)
        ; existing_atom -> binary_to_existing_atom(Key, utf8)
        ; attempt_atom ->
            try binary_to_existing_atom(Key, utf8) of
                Result -> Result
            catch
                error:badarg -> Key
            end
    end.


%% internal state is a stack and a config object
%%  `{Stack, Config}`
%% the stack is a list of in progress objects/arrays
%%  `[Current, Parent, Grandparent,...OriginalAncestor]`
%% an object has the representation on the stack of
%%  `{object, #{NthKey => NthValue, NMinus1Key => NthMinus1Value,...FirstKey => FirstValue}}`
%% of if there's a key with a yet to be matched value
%%  `{object, Key, #{NthKey => NthValue},...}}`
%% an array looks like
%%  `{array, [NthValue, NthMinus1Value,...FirstValue]}`


%% allocate a new object on top of the stack
start_object({Stack, Config}) -> {[{object, #{}}] ++ Stack, Config}.

%% allocate a new array on top of the stack
start_array({Stack, Config}) -> {[{array, []}] ++ Stack, Config}.

%% finish an object or array and insert it into the parent object if it exists or
%%  return it if it is the root object
finish({[{object, EmptyMap}], Config}) when is_map(EmptyMap), map_size(EmptyMap) < 1 ->
    {#{}, Config};
finish({[{object, EmptyMap}|Rest], Config}) when is_map(EmptyMap), map_size(EmptyMap) < 1 ->
    insert(#{}, {Rest, Config});
finish({[{object, Pairs}], Config}) -> {Pairs, Config};
finish({[{object, Pairs}|Rest], Config}) -> insert(Pairs, {Rest, Config});
finish({[{array, Values}], Config}) -> {lists:reverse(Values), Config};
finish({[{array, Values}|Rest], Config}) -> insert(lists:reverse(Values), {Rest, Config});
finish(_) -> erlang:error(badarg).

%% insert a value when there's no parent object or array
insert(Value, {[], Config}) -> {Value, Config};
%% insert a key or value into an object or array, autodetects the 'right' thing
insert(Key, {[{object, Pairs}|Rest], Config}) ->
    {[{object, Key, Pairs}] ++ Rest, Config};
insert(Value, {[{object, Key, Pairs}|Rest], Config}) ->
    {[{object, maps:put(Key, Value, Pairs)}] ++ Rest, Config};
insert(Value, {[{array, Values}|Rest], Config}) ->
    {[{array, [Value] ++ Values}] ++ Rest, Config};
insert(_, _) -> erlang:error(badarg).

get_value({Value, _Config}) -> Value;
get_value(_) -> erlang:error(badarg).


-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").

basic_decode_test_() ->
    [
        {"empty object", ?_assertEqual(#{}, decode(<<"{}">>))},
        {"simple object", ?_assertEqual(
            #{<<"key">> => <<"value">>},
            decode(<<"{\"key\": \"value\"}">>)
        )},
        {"nested object", ?_assertEqual(
            #{<<"key">> => #{<<"key">> => <<"value">>}},
            decode(<<"{\"key\": {\"key\": \"value\"}}">>)
        )},
        {"complex object", ?_assertEqual(
            #{<<"key">> => [
                    #{<<"key">> => <<"value">>},
                    #{<<"key">> => []},
                    #{<<"key">> => 1.0},
                    true,
                    false,
                    null
                ],
                <<"another key">> => #{}
            },
            decode(<<"{\"key\": [
                    {\"key\": \"value\"},
                    {\"key\": []},
                    {\"key\": 1.0},
                    true,
                    false,
                    null
                ], \"another key\": {}
            }">>)
        )},
        {"empty list", ?_assertEqual([], decode(<<"[]">>))},
        {"raw value", ?_assertEqual(1.0, decode(<<"1.0">>))}
    ].

-endif.