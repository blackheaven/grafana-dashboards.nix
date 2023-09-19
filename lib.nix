{ pkgs }:
let
  lib = pkgs.lib;
in
rec
{
  /*
    Fetch a Dashboard from https://grafana.com/grafana/dashboards/
  */
  fetchDashboard = { name, hash, id, version }:
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
    pkgs.runCommand "save-dashboard-${name}" ''
      mkdir -p "$out"
      cp ${path} "$out/${name}.json";
    '';

  /*
    Apply transformations from a path
  */
  changePath = { name, transformations, path }:
    builtins.toFile name (builtins.toJSON (transformations (builtins.fromJSON (builtins.readFile path))));

  /*
    Update templatings list
  */
  updateTemplatings = f: prev:
    prev // { templating = prev.templating // { lists = f prev.templating.lists; }; };

  /*
    Prepend templatings
  */
  prependTemplatins = news:
    updateTemplatings (prevs: news ++ prevs);

  /*
    Append templatings
  */
  appendTemplatins = news:
    updateTemplatings (prevs: prevs ++ news);

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
    updateTemplatings (builtins.filter (t: !(predicate t)));

  /*
    Create a predicate for templatings operation based on the name (from a predicate)
  */
  withTemplatingName = predicate: t:
    predicate t.name;

  /*
    Create a predicate for templatings operation based on the name (exactly matching the name)
  */
  withTemplatingNamed = name:
    withTemplatingName (templatingName: templatingName == name);

  /*
    Create a predicate for templatings operation based on the label (from a predicate)
  */
  withTemplatingLabel = predicate: t:
    predicate t.label;

  /*
    Create a predicate for templatings operation based on the label (exactly matching the label)
  */
  withTemplatingLabelled = label:
    withTemplatingLabel (templatingLabel: templatingLabel == label);

  /*
    Fill template value
  */
  fillTemplating = name: value: prev:
    lib.attrsets.mapAttrsRecursive
      (path: builtins.replaceStrings [ "\$${name}" "\${${name}}" ] [ value value ])
      (filterOutTemplating (withTemplatingNamed name) prev);
}
