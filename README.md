# grafana-dashboards.nix

Nix tool used to fetch and transform Grafana Dashboards

## Example

### Fill a template variable

```nix
lib.dashboardEntry {
  name = "node-explorer-full";
  path =
    lib.fetchDashboard {
      name = "node-exporter-full";
      hash = "sha256-ZiIsNaxPE5skpDykcugveAa3S8sCjR9bA9hbzyz7kvY=";
      id = 1860;
      version = 32;
    };
  transformations = lib.fillTemplating [{ key =  "job"; value = "nodes"; }];
};
```

### Add a template variable

```nix
lib.dashboardEntry {
  name = "node-explorer-full";
  path =
    lib.fetchDashboard {
      name = "node-exporter-full";
      hash = "sha256-ZiIsNaxPE5skpDykcugveAa3S8sCjR9bA9hbzyz7kvY=";
      id = 1860;
      version = 32;
    };
  transformations = lib.prependTemplatings [lib.templatingJob];
};
```

### Import in NixOS

```nix
inputs.nixpkgs.lib.nixosSystem {
  inherit system;
  modules = [ ./configuration.nix ];
  specialArgs = { grafanaDashboardsLib = inputs.grafana-dashboards.lib { inherit pkgs; }; };
};
```
