{ pkgs }:
let
  lib = pkgs.lib;
  assertPath = msg: x:
    lib.asserts.assertMsg
      (true)
      # (lib.strings.isConvertibleWithToString x && lib.filesystem.pathIsRegularFile (toString x))
      "${msg} -> assertion failed (expected a path, but got '${builtins.typeOf x}', ${toString (lib.strings.isConvertibleWithToString x)} ${toString (lib.filesystem.pathIsRegularFile (toString x))})";
  assertString = msg: x:
    lib.asserts.assertMsg
      (builtins.isString x)
      "${msg} -> assertion failed (expected a string, but got '${builtins.typeOf x}')";
  assertInt = msg: x:
    lib.asserts.assertMsg
      (builtins.isInt x)
      "${msg} -> assertion failed (expected a int, but got '${builtins.typeOf x}')";
  assertFunction = msg: x:
    lib.asserts.assertMsg
      (builtins.isFunction x)
      "${msg} -> assertion failed (expected a function, but got '${builtins.typeOf x}')";
  assertOptionalFunction = msg: s: attrName:
    lib.asserts.assertMsg
      (!(builtins.hasAttr attrName s) || builtins.isNull s.${attrName} || builtins.isFunction s.${attrName})
      "${msg} -> assertion failed (expected an optional function, but got '${builtins.typeOf s}')";
  assertAttrs = msg: x:
    lib.asserts.assertMsg
      (builtins.isAttrs x)
      "${msg} -> assertion failed (expected a attrsset, but got '${builtins.typeOf x}')";
  assertListOfAttrs = msg: x:
    lib.asserts.assertMsg
      (builtins.isList x && builtins.all builtins.isAttrs x)
      "${msg} -> assertion failed (expected a list of attrsets, but got '${builtins.typeOf x}')";
in
rec
{
  /*
    Definition for `services.grafana.provision.dashboards.settings.providers`
  */
  dashboardEntry = { name, path, ... }@args:
    assert assertString "dashboardEntry{name}" name;
    assert assertPath "dashboardEntry{path0}" path;
    assert assertOptionalFunction "dashboardEntry{transformations}" args "transformations";
    {
      inherit name;
      options.path =
        saveDashboard
          {
            inherit name;
            path =
              if !(builtins.hasAttr "transformations" args) || builtins.isNull args.transformations
              then path
              else
                changePath {
                  inherit path;
                  name = "transformed-dashboard-${name}";
                  transformations = args.transformations;
                };
          };
    };

  /*
    Fetch a Dashboard from https://grafana.com/grafana/dashboards/
  */
  fetchDashboard = { name, hash, id, version }:
    assert assertString "fetchDashboard{name}" name;
    assert assertString "fetchDashboard{hash}" hash;
    assert assertInt "fetchDashboard{id}" id;
    assert assertInt "fetchDashboard{version}" version;
    pkgs.fetchurl {
      inherit hash;
      name = "fetch-dashboard-${name}";
      url = "https://grafana.com/api/dashboards/${toString id}/revisions/${toString version}/download";
      recursiveHash = true;
    };

  /*
    Save a Dashboard (in a directory)
  */
  saveDashboard = { name, path }:
    assert assertString "saveDashboard{name}" name;
    assert assertPath "saveDashboard{path}" path;
    pkgs.runCommand "save-dashboard-${name}" { } ''
      mkdir -p "$out"
      cp ${path} "$out/${name}.json";
    '';

  /*
    Apply transformations from a path
  */
  changePath = { name, transformations, path }:
    assert assertString "changePath{name}" name;
    assert assertFunction "changePath{transformations}" transformations;
    assert assertPath "changePath{path}" path;
    builtins.toFile name (builtins.toJSON (transformations (builtins.fromJSON (builtins.readFile path))));

  /*
    Set title
  */
  setTitle = title: prev:
    assert assertString "setTitle \"title\" {prev}" title;
    assert assertAttrs "setTitle \"title\" {prev}" prev;
    prev // { inherit title; };

  /*
    Set uid
  */
  setUid = uid: prev:
    assert assertString "setUid \"uid\" {prev}" uid;
    assert assertAttrs "setUid \"uid\" {prev}" prev;
    prev // { inherit uid; };

  /*
    Update templatings list
  */
  updateTemplatings = f: prev:
    assert assertFunction "updateTemplatings f {prev}" f;
    assert assertAttrs "updateTemplatings f {prev}" prev;
    prev // { templating = prev.templating // { list = f prev.templating.list; }; };

  /*
    Prepend templatings
  */
  prependTemplatings = newEntries:
    assert assertListOfAttrs "prependTemplatings [newEntries]" newEntries;
    updateTemplatings (prevs: newEntries ++ prevs);

  /*
    Append templatings
  */
  appendTemplatings = newEntries:
    assert assertListOfAttrs "appendTemplatings [newEntries]" newEntries;
    updateTemplatings (prevs: prevs ++ newEntries);

  /*
    Prometheus templating
  */
  templatingPrometheus = {
    current = {
      selected = false;
      text = "default";
      value = "default";
    };
    hide = 0;
    includeAll = false;
    label = "datasource";
    multi = false;
    name = "DS_PROMETHEUS";
    options = [ ];
    query = "prometheus";
    refresh = 1;
    regex = "";
    skipUrlSync = false;
    type = "datasource";
  };

  /*
    Job templating
  */
  templatingJob = {
    current = { };
    datasource = {
      type = "prometheus";
      uid = "\${DS_PROMETHEUS}";
    };
    definition = "";
    hide = 0;
    includeAll = false;
    label = "Job";
    multi = false;
    name = "job";
    options = [ ];
    query = {
      query = "label_values(node_uname_info, job)";
      refId = "Prometheus-job-Variable-Query";
    };
    refresh = 1;
    regex = "";
    skipUrlSync = false;
    sort = 1;
    tagValuesQuery = "";
    tagsQuery = "";
    type = "query";
    useTags = false;
  };

  /*
    Node templating
  */
  templatingNode = {
    current = { };
    datasource = {
      type = "prometheus";
      uid = "\${DS_PROMETHEUS}";
    };
    definition = "label_values(node_uname_info{job=\"$job\"}, instance)";
    hide = 0;
    includeAll = false;
    label = "Host";
    multi = false;
    name = "node";
    options = [ ];
    query = {
      query = "label_values(node_uname_info{job=\"$job\"}, instance)";
      refId = "Prometheus-node-Variable-Query";
    };
    refresh = 1;
    regex = "";
    skipUrlSync = false;
    sort = 1;
    tagValuesQuery = "";
    tagsQuery = "";
    type = "query";
    useTags = false;
  };

  /*
    Filter-out templating matching the predicate
  */
  filterOutTemplating = predicate:
    assert assertFunction "filterOutTemplating predicate" predicate;
    updateTemplatings (builtins.filter (t: !(predicate t)));

  /*
    Create a predicate for templatings operation based on the name (from a predicate)
  */
  withTemplatingName = predicate: t:
    assert assertFunction "withTemplatingName predicate" predicate;
    predicate t.name;

  /*
    Create a predicate for templatings operation based on the name (exactly matching the name)
  */
  withTemplatingNamed = name:
    assert assertString "withTemplatingNamed name" name;
    withTemplatingName (templatingName: templatingName == name);

  /*
    Create a predicate for templatings operation based on the label (from a predicate)
  */
  withTemplatingLabel = predicate: t:
    assert assertFunction "withTemplatingLabel predicate" predicate;
    predicate t.label;

  /*
    Create a predicate for templatings operation based on the label (exactly matching the label)
  */
  withTemplatingLabelled = label:
    assert assertString "withTemplatingLabelled label" label;
    withTemplatingLabel (templatingLabel: templatingLabel == label);

  /*
    Fill template value
    > fillTemplating [{ key = "DS_PROMETHEUS"; value = "some-uuid" }] <attrs-set-from-transformations>
  */
  fillTemplating = replacements: prev:
    assert assertListOfAttrs "fillTemplating [replacements] {prev}" replacements;
    assert assertAttrs "fillTemplating [replacements] {prev}" prev;
    let
      go = x:
        if builtins.isString x
        then
          builtins.replaceStrings
            (builtins.concatMap (x: [ "\$${x.key}" "\${${x.key}}" ]) replacements)
            (builtins.concatMap (x: [ "\$${x.value}" "\${${x.value}}" ]) replacements)
            x
        else if builtins.isList x
        then map go x
        else if builtins.isAttrs x
        then lib.attrsets.mapAttrsRecursive (path: go) x
        else x;
    in
    go (
      filterOutTemplating
        (withTemplatingName (name: builtins.elem name (builtins.map (x: x.key) replacements)))
        prev
    );
}
