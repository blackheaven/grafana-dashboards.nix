# grafana-dashboards.nix

Nix tool used to fetch and transform Grafana Dashboards

## Example

### Fill a template variable

```nix
let
  raw =
    lib.fetchDashboard {
      name = "node-exporter-full";
      hash = "sha256-ZiIsNaxPE5skpDykcugveAa3S8sCjR9bA9hbzyz7kvY=";
      id = 1860;
      version = 32;
    };
in
lib.saveDashboard {
  name = "node-explorer-full";
  path =
    lib.changePath {
      name = "final-dashboard-node-explorer-full";
      path = raw;
      transformation = lib.fillTemplating "job" "nodes;
    };
};
```
