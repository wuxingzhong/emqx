-module(emqx_retainer_schema).

-include_lib("typerefl/include/types.hrl").
-include_lib("hocon/include/hoconsc.hrl").

-export([roots/0, fields/1, desc/1, namespace/0]).

-define(DEFAULT_INDICES, [
    [1, 2, 3],
    [1, 3],
    [2, 3],
    [3]
]).

namespace() -> "retainer".

roots() -> ["retainer"].

fields("retainer") ->
    [
        {enable, sc(boolean(), enable, false)},
        {msg_expiry_interval,
            sc(
                emqx_schema:duration_ms(),
                msg_expiry_interval,
                "0s"
            )},
        {msg_clear_interval,
            sc(
                emqx_schema:duration_ms(),
                msg_clear_interval,
                "0s"
            )},
        {flow_control, sc(hoconsc:ref(?MODULE, flow_control), flow_control)},
        {max_payload_size,
            sc(
                emqx_schema:bytesize(),
                max_payload_size,
                "1MB"
            )},
        {stop_publish_clear_msg,
            sc(
                boolean(),
                stop_publish_clear_msg,
                false
            )},
        {backend, backend_config()}
    ];
fields(mnesia_config) ->
    [
        {type, sc(hoconsc:union([built_in_database]), mnesia_config_type, built_in_database)},
        {storage_type,
            sc(
                hoconsc:union([ram, disc]),
                mnesia_config_storage_type,
                ram
            )},
        {max_retained_messages,
            sc(
                integer(),
                max_retained_messages,
                0,
                fun is_pos_integer/1
            )},
        {index_specs, fun retainer_indices/1}
    ];
fields(flow_control) ->
    [
        {batch_read_number,
            sc(
                integer(),
                batch_read_number,
                0,
                fun is_pos_integer/1
            )},
        {batch_deliver_number,
            sc(
                range(0, 1000),
                batch_deliver_number,
                0
            )},
        {batch_deliver_limiter,
            sc(
                emqx_limiter_schema:bucket_name(),
                batch_deliver_limiter,
                undefined
            )}
    ].

desc("retainer") ->
    "Configuration related to handling `PUBLISH` packets with a `retain` flag set to 1.";
desc(mnesia_config) ->
    "Configuration of the internal database storing retained messages.";
desc(flow_control) ->
    "Retainer batching and rate limiting.";
desc(_) ->
    undefined.

%%--------------------------------------------------------------------
%% Internal functions
%%--------------------------------------------------------------------
sc(Type, DescId) ->
    hoconsc:mk(Type, #{required => true, desc => ?DESC(DescId)}).

sc(Type, DescId, Default) ->
    hoconsc:mk(Type, #{default => Default, desc => ?DESC(DescId)}).

sc(Type, DescId, Default, Validator) ->
    hoconsc:mk(Type, #{
        default => Default,
        desc => ?DESC(DescId),
        validator => Validator
    }).

is_pos_integer(V) ->
    V >= 0.

backend_config() ->
    sc(
        hoconsc:union([hoconsc:ref(?MODULE, mnesia_config)]),
        backend,
        mnesia_config
    ).

retainer_indices(type) ->
    list(list(integer()));
retainer_indices(desc) ->
    "Retainer index specifications: list of arrays of positive ascending integers. "
    "Each array specifies an index. Numbers in an index specification are 1-based "
    "word positions in topics. Words from specified positions will be used for indexing.</br>"
    "For example, it is good to have <code>[2, 4]</code> index to optimize "
    "<code>+/X/+/Y/...</code> topic wildcard subscriptions.";
retainer_indices(example) ->
    [[2, 4], [1, 3]];
retainer_indices(default) ->
    ?DEFAULT_INDICES;
retainer_indices(validator) ->
    fun is_valid_index_specs/1;
retainer_indices(_) ->
    undefined.

is_valid_index_specs(IndexSpecs) ->
    case lists:all(fun is_valid_index_spec/1, IndexSpecs) of
        true ->
            case length(IndexSpecs) =:= ordsets:size(ordsets:from_list(IndexSpecs)) of
                true -> ok;
                false -> {error, duplicate_index_specs}
            end;
        false ->
            {error, invalid_index_spec}
    end.

is_valid_index_spec(IndexSpec) ->
    length(IndexSpec) > 0 andalso
        lists:all(fun(Idx) -> Idx > 0 end, IndexSpec) andalso
        IndexSpec =:= ordsets:to_list(ordsets:from_list(IndexSpec)).
