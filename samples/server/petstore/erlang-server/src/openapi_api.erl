-module(openapi_api).
-moduledoc """
This module offers an API for JSON schema validation, using `jesse` under the hood.

If validation is desired, a jesse state can be loaded using `prepare_validator/1`,
and request and response can be validated using `populate_request/3`
and `validate_response/4` respectively.

For example, the user-defined `Module:accept_callback/4` can be implemented as follows:
```
-spec accept_callback(atom(), openapi_api:operation_id(), cowboy_req:req(), context()) ->
    {cowboy:http_status(), cowboy:http_headers(), json:encode_value()}.
accept_callback(Class, OperationID, Req, Context) ->
    ValidatorState = openapi_api:prepare_validator(),
    case openapi_api:populate_request(OperationID, Req0, ValidatorState) of
        {ok, Populated, Req1} ->
            {Code, Headers, Body} = openapi_logic_handler:handle_request(
                LogicHandler,
                OperationID,
                Req1,
                maps:merge(State#state.context, Populated)
            ),
            _ = openapi_api:validate_response(
                OperationID,
                Code,
                Body,
                ValidatorState
            ),
            PreparedBody = prepare_body(Code, Body),
            Response = {ok, {Code, Headers, PreparedBody}},
            process_response(Response, Req1, State);
        {error, Reason, Req1} ->
            process_response({error, Reason}, Req1, State)
    end.
```
""".

-export([prepare_validator/0, prepare_validator/1, prepare_validator/2]).
-export([populate_request/3, validate_response/4]).

-ignore_xref([populate_request/3, validate_response/4]).
-ignore_xref([prepare_validator/0, prepare_validator/1, prepare_validator/2]).

-type operation_id() :: atom().
-type request_param() :: atom().

-export_type([operation_id/0]).

-dialyzer({nowarn_function, [to_binary/1, validate_response_body/4]}).

-type rule() ::
    {type, binary} |
    {type, integer} |
    {type, float} |
    {type, boolean} |
    {type, date} |
    {type, datetime} |
    {enum, [atom()]} |
    {max, Max :: number()} |
    {exclusive_max, Max :: number()} |
    {min, Min :: number()} |
    {exclusive_min, Min :: number()} |
    {max_length, MaxLength :: integer()} |
    {min_length, MaxLength :: integer()} |
    {pattern, Pattern :: string()} |
    schema |
    required |
    not_required.

-doc #{equiv => prepare_validator/2}.
-spec prepare_validator() -> jesse_state:state().
prepare_validator() ->
    prepare_validator(<<"http://json-schema.org/draft-06/schema#">>).

-doc #{equiv => prepare_validator/2}.
-spec prepare_validator(binary()) -> jesse_state:state().
prepare_validator(SchemaVer) ->
    prepare_validator(get_openapi_path(), SchemaVer).

-doc """
Loads the JSON schema and the desired validation draft into a `t:jesse_state:state()`.
""".
-spec prepare_validator(file:name_all(), binary()) -> jesse_state:state().
prepare_validator(OpenApiPath, SchemaVer) ->
    {ok, FileContents} = file:read_file(OpenApiPath),
    R = json:decode(FileContents),
    jesse_state:new(R, [{default_schema_ver, SchemaVer}]).

-doc """
Automatically loads the entire body from the cowboy req
and validates the JSON body against the schema.
""".
-spec populate_request(
        OperationID :: operation_id(),
        Req :: cowboy_req:req(),
        ValidatorState :: jesse_state:state()) ->
    {ok, Model :: #{}, Req :: cowboy_req:req()} |
    {error, Reason :: any(), Req :: cowboy_req:req()}.
populate_request(OperationID, Req, ValidatorState) ->
    Params = request_params(OperationID),
    populate_request_params(OperationID, Params, Req, ValidatorState, #{}).

-doc """
Validates that the provided `Code` and `Body` comply with the `ValidatorState` schema
for the `OperationID` operation.
""".
-spec validate_response(
        OperationID :: operation_id(),
        Code :: 200..599,
        Body :: jesse:json_term(),
        ValidatorState :: jesse_state:state()) ->
    ok | {ok, term()} | [ok | {ok, term()}] | no_return().
validate_response('AddPet', 200, Body, ValidatorState) ->
    validate_response_body('Pet', 'Pet', Body, ValidatorState);
validate_response('AddPet', 405, Body, ValidatorState) ->
    validate_response_body('', '', Body, ValidatorState);
validate_response('DeletePet', 400, Body, ValidatorState) ->
    validate_response_body('', '', Body, ValidatorState);
validate_response('FindPetsByStatus', 200, Body, ValidatorState) ->
    validate_response_body('list', 'Pet', Body, ValidatorState);
validate_response('FindPetsByStatus', 400, Body, ValidatorState) ->
    validate_response_body('', '', Body, ValidatorState);
validate_response('FindPetsByTags', 200, Body, ValidatorState) ->
    validate_response_body('list', 'Pet', Body, ValidatorState);
validate_response('FindPetsByTags', 400, Body, ValidatorState) ->
    validate_response_body('', '', Body, ValidatorState);
validate_response('GetPetById', 200, Body, ValidatorState) ->
    validate_response_body('Pet', 'Pet', Body, ValidatorState);
validate_response('GetPetById', 400, Body, ValidatorState) ->
    validate_response_body('', '', Body, ValidatorState);
validate_response('GetPetById', 404, Body, ValidatorState) ->
    validate_response_body('', '', Body, ValidatorState);
validate_response('UpdatePet', 200, Body, ValidatorState) ->
    validate_response_body('Pet', 'Pet', Body, ValidatorState);
validate_response('UpdatePet', 400, Body, ValidatorState) ->
    validate_response_body('', '', Body, ValidatorState);
validate_response('UpdatePet', 404, Body, ValidatorState) ->
    validate_response_body('', '', Body, ValidatorState);
validate_response('UpdatePet', 405, Body, ValidatorState) ->
    validate_response_body('', '', Body, ValidatorState);
validate_response('UpdatePetWithForm', 405, Body, ValidatorState) ->
    validate_response_body('', '', Body, ValidatorState);
validate_response('UploadFile', 200, Body, ValidatorState) ->
    validate_response_body('ApiResponse', 'ApiResponse', Body, ValidatorState);
validate_response('DeleteOrder', 400, Body, ValidatorState) ->
    validate_response_body('', '', Body, ValidatorState);
validate_response('DeleteOrder', 404, Body, ValidatorState) ->
    validate_response_body('', '', Body, ValidatorState);
validate_response('GetInventory', 200, Body, ValidatorState) ->
    validate_response_body('map', 'integer', Body, ValidatorState);
validate_response('GetOrderById', 200, Body, ValidatorState) ->
    validate_response_body('Order', 'Order', Body, ValidatorState);
validate_response('GetOrderById', 400, Body, ValidatorState) ->
    validate_response_body('', '', Body, ValidatorState);
validate_response('GetOrderById', 404, Body, ValidatorState) ->
    validate_response_body('', '', Body, ValidatorState);
validate_response('PlaceOrder', 200, Body, ValidatorState) ->
    validate_response_body('Order', 'Order', Body, ValidatorState);
validate_response('PlaceOrder', 400, Body, ValidatorState) ->
    validate_response_body('', '', Body, ValidatorState);
validate_response('CreateUser', 0, Body, ValidatorState) ->
    validate_response_body('', '', Body, ValidatorState);
validate_response('CreateUsersWithArrayInput', 0, Body, ValidatorState) ->
    validate_response_body('', '', Body, ValidatorState);
validate_response('CreateUsersWithListInput', 0, Body, ValidatorState) ->
    validate_response_body('', '', Body, ValidatorState);
validate_response('DeleteUser', 400, Body, ValidatorState) ->
    validate_response_body('', '', Body, ValidatorState);
validate_response('DeleteUser', 404, Body, ValidatorState) ->
    validate_response_body('', '', Body, ValidatorState);
validate_response('GetUserByName', 200, Body, ValidatorState) ->
    validate_response_body('User', 'User', Body, ValidatorState);
validate_response('GetUserByName', 400, Body, ValidatorState) ->
    validate_response_body('', '', Body, ValidatorState);
validate_response('GetUserByName', 404, Body, ValidatorState) ->
    validate_response_body('', '', Body, ValidatorState);
validate_response('LoginUser', 200, Body, ValidatorState) ->
    validate_response_body('binary', 'string', Body, ValidatorState);
validate_response('LoginUser', 400, Body, ValidatorState) ->
    validate_response_body('', '', Body, ValidatorState);
validate_response('LogoutUser', 0, Body, ValidatorState) ->
    validate_response_body('', '', Body, ValidatorState);
validate_response('UpdateUser', 400, Body, ValidatorState) ->
    validate_response_body('', '', Body, ValidatorState);
validate_response('UpdateUser', 404, Body, ValidatorState) ->
    validate_response_body('', '', Body, ValidatorState);
validate_response(_OperationID, _Code, _Body, _ValidatorState) ->
    ok.

%%%
-spec request_params(OperationID :: operation_id()) -> [Param :: request_param()].
request_params('AddPet') ->
    [
        'Pet'
    ];
request_params('DeletePet') ->
    [
        'petId',
        'api_key'
    ];
request_params('FindPetsByStatus') ->
    [
        'status'
    ];
request_params('FindPetsByTags') ->
    [
        'tags'
    ];
request_params('GetPetById') ->
    [
        'petId'
    ];
request_params('UpdatePet') ->
    [
        'Pet'
    ];
request_params('UpdatePetWithForm') ->
    [
        'petId',
        'name',
        'status'
    ];
request_params('UploadFile') ->
    [
        'petId',
        'additionalMetadata',
        'file'
    ];
request_params('DeleteOrder') ->
    [
        'orderId'
    ];
request_params('GetInventory') ->
    [
    ];
request_params('GetOrderById') ->
    [
        'orderId'
    ];
request_params('PlaceOrder') ->
    [
        'Order'
    ];
request_params('CreateUser') ->
    [
        'User'
    ];
request_params('CreateUsersWithArrayInput') ->
    [
        'list'
    ];
request_params('CreateUsersWithListInput') ->
    [
        'list'
    ];
request_params('DeleteUser') ->
    [
        'username'
    ];
request_params('GetUserByName') ->
    [
        'username'
    ];
request_params('LoginUser') ->
    [
        'username',
        'password'
    ];
request_params('LogoutUser') ->
    [
    ];
request_params('UpdateUser') ->
    [
        'username',
        'User'
    ];
request_params(_) ->
    error(unknown_operation).

-spec request_param_info(OperationID :: operation_id(), Name :: request_param()) ->
    #{source => qs_val | binding | header | body, rules => [rule()]}.
request_param_info('AddPet', 'Pet') ->
    #{
        source => body,
        rules => [
            schema,
            required
        ]
    };
request_param_info('DeletePet', 'petId') ->
    #{
        source => binding,
        rules => [
            {type, integer},
            required
        ]
    };
request_param_info('DeletePet', 'api_key') ->
    #{
        source => header,
        rules => [
            {type, binary},
            not_required
        ]
    };
request_param_info('FindPetsByStatus', 'status') ->
    #{
        source => qs_val,
        rules => [
            {enum, ['available', 'pending', 'sold'] },
            required
        ]
    };
request_param_info('FindPetsByTags', 'tags') ->
    #{
        source => qs_val,
        rules => [
            required
        ]
    };
request_param_info('GetPetById', 'petId') ->
    #{
        source => binding,
        rules => [
            {type, integer},
            required
        ]
    };
request_param_info('UpdatePet', 'Pet') ->
    #{
        source => body,
        rules => [
            schema,
            required
        ]
    };
request_param_info('UpdatePetWithForm', 'petId') ->
    #{
        source => binding,
        rules => [
            {type, integer},
            required
        ]
    };
request_param_info('UpdatePetWithForm', 'name') ->
    #{
        source => body,
        rules => [
            {type, binary},
            not_required
        ]
    };
request_param_info('UpdatePetWithForm', 'status') ->
    #{
        source => body,
        rules => [
            {type, binary},
            not_required
        ]
    };
request_param_info('UploadFile', 'petId') ->
    #{
        source => binding,
        rules => [
            {type, integer},
            required
        ]
    };
request_param_info('UploadFile', 'additionalMetadata') ->
    #{
        source => body,
        rules => [
            {type, binary},
            not_required
        ]
    };
request_param_info('UploadFile', 'file') ->
    #{
        source => body,
        rules => [
            {type, binary},
            not_required
        ]
    };
request_param_info('DeleteOrder', 'orderId') ->
    #{
        source => binding,
        rules => [
            {type, binary},
            required
        ]
    };
request_param_info('GetOrderById', 'orderId') ->
    #{
        source => binding,
        rules => [
            {type, integer},
            {max, 5},
            {min, 1},
            required
        ]
    };
request_param_info('PlaceOrder', 'Order') ->
    #{
        source => body,
        rules => [
            schema,
            required
        ]
    };
request_param_info('CreateUser', 'User') ->
    #{
        source => body,
        rules => [
            schema,
            required
        ]
    };
request_param_info('CreateUsersWithArrayInput', 'list') ->
    #{
        source => body,
        rules => [
            schema,
            required
        ]
    };
request_param_info('CreateUsersWithListInput', 'list') ->
    #{
        source => body,
        rules => [
            schema,
            required
        ]
    };
request_param_info('DeleteUser', 'username') ->
    #{
        source => binding,
        rules => [
            {type, binary},
            required
        ]
    };
request_param_info('GetUserByName', 'username') ->
    #{
        source => binding,
        rules => [
            {type, binary},
            required
        ]
    };
request_param_info('LoginUser', 'username') ->
    #{
        source => qs_val,
        rules => [
            {type, binary},
            {pattern, "^[a-zA-Z0-9]+[a-zA-Z0-9\\.\\-_]*[a-zA-Z0-9]+$"},
            required
        ]
    };
request_param_info('LoginUser', 'password') ->
    #{
        source => qs_val,
        rules => [
            {type, binary},
            required
        ]
    };
request_param_info('UpdateUser', 'username') ->
    #{
        source => binding,
        rules => [
            {type, binary},
            required
        ]
    };
request_param_info('UpdateUser', 'User') ->
    #{
        source => body,
        rules => [
            schema,
            required
        ]
    };
request_param_info(OperationID, Name) ->
    error({unknown_param, OperationID, Name}).

-spec populate_request_params(
        operation_id(), [request_param()], cowboy_req:req(), jesse_state:state(), map()) ->
    {ok, map(), cowboy_req:req()} | {error, _, cowboy_req:req()}.
populate_request_params(_, [], Req, _, Model) ->
    {ok, Model, Req};
populate_request_params(OperationID, [ReqParamName | T], Req0, ValidatorState, Model0) ->
    case populate_request_param(OperationID, ReqParamName, Req0, ValidatorState) of
        {ok, V, Req} ->
            Model = maps:put(ReqParamName, V, Model0),
            populate_request_params(OperationID, T, Req, ValidatorState, Model);
        Error ->
            Error
    end.

-spec populate_request_param(
        operation_id(), request_param(), cowboy_req:req(), jesse_state:state()) ->
    {ok, term(), cowboy_req:req()} | {error, term(), cowboy_req:req()}.
populate_request_param(OperationID, ReqParamName, Req0, ValidatorState) ->
    #{rules := Rules, source := Source} = request_param_info(OperationID, ReqParamName),
    case get_value(Source, ReqParamName, Req0) of
        {error, Reason, Req} ->
            {error, Reason, Req};
        {Value, Req} ->
            case prepare_param(Rules, ReqParamName, Value, ValidatorState) of
                {ok, Result} -> {ok, Result, Req};
                {error, Reason} ->
                    {error, Reason, Req}
            end
    end.

-include_lib("kernel/include/logger.hrl").

validate_response_body(list, ReturnBaseType, Body, ValidatorState) ->
    [
        validate(schema, Item, ReturnBaseType, ValidatorState)
    || Item <- Body];

validate_response_body(_, ReturnBaseType, Body, ValidatorState) ->
    validate(schema, Body, ReturnBaseType, ValidatorState).

-spec validate(rule(), term(), request_param(), jesse_state:state()) ->
    ok | {ok, term()}.
validate(required, undefined, ReqParamName, _) ->
    validation_error(required, ReqParamName, undefined);
validate(required, _Value, _ReqParamName, _) ->
    ok;
validate(not_required, _Value, _ReqParamName, _) ->
    ok;
validate(_, undefined, _ReqParamName, _) ->
    ok;
validate({type, boolean}, Value, _ReqParamName, _) when is_boolean(Value) ->
    {ok, Value};
validate({type, integer}, Value, _ReqParamName, _) when is_integer(Value) ->
    ok;
validate({type, float}, Value, _ReqParamName, _) when is_float(Value) ->
    ok;
validate({type, binary}, Value, _ReqParamName, _) when is_binary(Value) ->
    ok;
validate(Rule = {type, binary}, Value, ReqParamName, _) ->
    validation_error(Rule, ReqParamName, Value);
validate(Rule = {type, boolean}, Value, ReqParamName, _) ->
    case binary_to_lower(Value) of
        <<"true">> -> {ok, true};
        <<"false">> -> {ok, false};
        _ -> validation_error(Rule, ReqParamName, Value)
    end;
validate(Rule = {type, integer}, Value, ReqParamName, _) ->
    try
        {ok, to_int(Value)}
    catch
        error:badarg ->
            validation_error(Rule, ReqParamName, Value)
    end;
validate(Rule = {type, float}, Value, ReqParamName, _) ->
    try
        {ok, to_float(Value)}
    catch
        error:badarg ->
            validation_error(Rule, ReqParamName, Value)
    end;
validate(Rule = {type, date}, Value, ReqParamName, _) ->
    case is_binary(Value) of
        true -> ok;
        false -> validation_error(Rule, ReqParamName, Value)
    end;
validate(Rule = {type, datetime}, Value, ReqParamName, _) ->
    case is_binary(Value) of
        true -> ok;
        false -> validation_error(Rule, ReqParamName, Value)
    end;
validate(Rule = {enum, Values}, Value, ReqParamName, _) ->
    try
        FormattedValue = erlang:binary_to_existing_atom(Value, utf8),
        case lists:member(FormattedValue, Values) of
            true -> {ok, FormattedValue};
            false -> validation_error(Rule, ReqParamName, Value)
        end
    catch
        error:badarg ->
            validation_error(Rule, ReqParamName, Value)
    end;
validate(Rule = {max, Max}, Value, ReqParamName, _) ->
    case Value =< Max of
        true -> ok;
        false -> validation_error(Rule, ReqParamName, Value)
    end;
validate(Rule = {exclusive_max, ExclusiveMax}, Value, ReqParamName, _) ->
    case Value > ExclusiveMax of
        true -> ok;
        false -> validation_error(Rule, ReqParamName, Value)
    end;
validate(Rule = {min, Min}, Value, ReqParamName, _) ->
    case Value >= Min of
        true -> ok;
        false -> validation_error(Rule, ReqParamName, Value)
    end;
validate(Rule = {exclusive_min, ExclusiveMin}, Value, ReqParamName, _) ->
    case Value =< ExclusiveMin of
        true -> ok;
        false -> validation_error(Rule, ReqParamName, Value)
    end;
validate(Rule = {max_length, MaxLength}, Value, ReqParamName, _) ->
    case size(Value) =< MaxLength of
        true -> ok;
        false -> validation_error(Rule, ReqParamName, Value)
    end;
validate(Rule = {min_length, MinLength}, Value, ReqParamName, _) ->
    case size(Value) >= MinLength of
        true -> ok;
        false -> validation_error(Rule, ReqParamName, Value)
    end;
validate(Rule = {pattern, Pattern}, Value, ReqParamName, _) ->
    {ok, MP} = re:compile(Pattern),
    case re:run(Value, MP) of
        {match, _} -> ok;
        _ -> validation_error(Rule, ReqParamName, Value)
    end;
validate(Rule = schema, Value, ReqParamName, ValidatorState) ->
    Definition = iolist_to_binary(["#/components/schemas/", atom_to_binary(ReqParamName)]),
    try
        _ = validate_with_schema(Value, Definition, ValidatorState),
        ok
    catch
        throw:[{schema_invalid, _, Error} | _] ->
            Info = #{
                type => schema_invalid,
                error => Error
            },
            validation_error(Rule, ReqParamName, Value, Info);
        throw:[{data_invalid, Schema, Error, _, Path} | _] ->
            Info = #{
                type => data_invalid,
                error => Error,
                schema => Schema,
                path => Path
            },
            validation_error(Rule, ReqParamName, Value, Info)
    end;
validate(Rule, _Value, ReqParamName, _) ->
    ?LOG_INFO(#{what => "Cannot validate rule", name => ReqParamName, rule => Rule}),
    error({unknown_validation_rule, Rule}).

-spec validation_error(rule(), request_param(), term()) -> no_return().
validation_error(ViolatedRule, Name, Value) ->
    validation_error(ViolatedRule, Name, Value, #{}).

-spec validation_error(rule(), request_param(), term(), Info :: #{_ := _}) -> no_return().
validation_error(ViolatedRule, Name, Value, Info) ->
    throw({wrong_param, Name, Value, ViolatedRule, Info}).

-spec get_value(body | qs_val | header | binding, request_param(), cowboy_req:req()) ->
    {any(), cowboy_req:req()} |
    {error, any(), cowboy_req:req()}.
get_value(body, _Name, Req0) ->
    {ok, Body, Req} = read_entire_body(Req0),
    case prepare_body(Body) of
        {error, Reason} ->
            {error, Reason, Req};
        Value ->
            {Value, Req}
    end;
get_value(qs_val, Name, Req) ->
    QS = cowboy_req:parse_qs(Req),
    Value = get_opt(to_qs(Name), QS),
    {Value, Req};
get_value(header, Name, Req) ->
    Headers = cowboy_req:headers(Req),
    Value =  maps:get(to_header(Name), Headers, undefined),
    {Value, Req};
get_value(binding, Name, Req) ->
    Value = cowboy_req:binding(Name, Req),
    {Value, Req}.

-spec read_entire_body(cowboy_req:req()) -> {ok, binary(), cowboy_req:req()}.
read_entire_body(Req) ->
    read_entire_body(Req, []).

-spec read_entire_body(cowboy_req:req(), iodata()) -> {ok, binary(), cowboy_req:req()}.
read_entire_body(Request, Acc) -> % {
    case cowboy_req:read_body(Request) of
        {ok, Data, NewRequest} ->
            {ok, iolist_to_binary(lists:reverse([Data | Acc])), NewRequest};
        {more, Data, NewRequest} ->
            read_entire_body(NewRequest, [Data | Acc])
    end.

prepare_body(<<>>) ->
    <<>>;
prepare_body(Body) ->
    try
        json:decode(Body)
    catch
        error:Error ->
            {error, {invalid_json, Body, Error}}
    end.

validate_with_schema(Body, Definition, ValidatorState) ->
    jesse_schema_validator:validate_with_state(
        [{<<"$ref">>, Definition}],
        Body,
        ValidatorState
    ).

-spec prepare_param([rule()], request_param(), term(), jesse_state:state()) ->
    {ok, term()} | {error, Reason :: any()}.
prepare_param(Rules, ReqParamName, Value, ValidatorState) ->
    Fun = fun(Rule, Acc) ->
        case validate(Rule, Acc, ReqParamName, ValidatorState) of
            ok -> Acc;
            {ok, Prepared} -> Prepared
        end
    end,
    try
        Result = lists:foldl(Fun, Value, Rules),
        {ok, Result}
    catch
        throw:Reason ->
            {error, Reason}
    end.

-spec to_binary(iodata() | atom() | number()) -> binary().
to_binary(V) when is_binary(V)  -> V;
to_binary(V) when is_list(V)    -> iolist_to_binary(V);
to_binary(V) when is_atom(V)    -> atom_to_binary(V, utf8);
to_binary(V) when is_integer(V) -> integer_to_binary(V);
to_binary(V) when is_float(V)   -> float_to_binary(V).

-spec to_float(binary() | list()) -> integer().
to_float(Data) when is_binary(Data) ->
    binary_to_float(Data);
to_float(Data) when is_list(Data) ->
    list_to_float(Data).

-spec to_int(binary() | list()) -> integer().
to_int(Data) when is_binary(Data) ->
    binary_to_integer(Data);
to_int(Data) when is_list(Data) ->
    list_to_integer(Data).

-spec to_header(request_param()) -> binary().
to_header(Name) ->
    to_binary(string:lowercase(atom_to_binary(Name, utf8))).

binary_to_lower(V) when is_binary(V) ->
    string:lowercase(V).

-spec to_qs(request_param()) -> binary().
to_qs(Name) ->
    atom_to_binary(Name, utf8).

-spec get_opt(any(), []) -> any().
get_opt(Key, Opts) ->
    get_opt(Key, Opts, undefined).

-spec get_opt(any(), [], any()) -> any().
get_opt(Key, Opts, Default) ->
    case lists:keyfind(Key, 1, Opts) of
        {_, Value} -> Value;
        false -> Default
    end.

get_openapi_path() ->
    {ok, AppName} = application:get_application(?MODULE),
    filename:join(priv_dir(AppName), "openapi.json").

-include_lib("kernel/include/file.hrl").

-spec priv_dir(Application :: atom()) -> file:name_all().
priv_dir(AppName) ->
    case code:priv_dir(AppName) of
        Value when is_list(Value) ->
            Value ++ "/";
        _Error ->
            select_priv_dir([filename:join(["apps", atom_to_list(AppName), "priv"]), "priv"])
     end.

select_priv_dir(Paths) ->
    case lists:dropwhile(fun test_priv_dir/1, Paths) of
        [Path | _] -> Path;
        _          -> exit(no_priv_dir)
    end.

test_priv_dir(Path) ->
    case file:read_file_info(Path) of
        {ok, #file_info{type = directory}} ->
            false;
        _ ->
            true
    end.
