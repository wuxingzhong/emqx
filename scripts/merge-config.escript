#!/usr/bin/env escript

%% This script reads up emqx.conf and split the sections
%% and dump sections to separate files.
%% Sections are grouped between CONFIG_SECTION_BGN and
%% CONFIG_SECTION_END pairs
%%
%% NOTE: this feature is so far not used in opensource
%% edition due to backward-compatibility reasons.

-mode(compile).

main(_) ->
    {ok, BaseConf} = file:read_file("apps/emqx_machine/etc/emqx_machine.conf"),
    Apps = filelib:wildcard("*", "apps/") -- ["emqx_machine"],
    Conf = lists:foldl(fun(App, Acc) ->
        Filename = filename:join([apps, App, "etc", App]) ++ ".conf",
        case filelib:is_regular(Filename) of
            true ->
                {ok, Bin1} = file:read_file(Filename),
                [Acc, io_lib:nl(), Bin1];
            false -> Acc
        end
    end, BaseConf, Apps),
    ok = file:write_file("apps/emqx_machine/etc/emqx.conf.all", Conf).