{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    quickshell = {
      url = "github:quickshell-mirror/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    quickshell,
  }: let
    version =
      builtins.replaceStrings ["\n"] [""]
      (builtins.readFile "${self}/VERSION");
    forEachSystem = nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux"];
  in {
    packages = forEachSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      qsPkgs = quickshell.packages.${system};
    in {
      default = pkgs.callPackage ./nix/package.nix {
        inherit version;
        quickshell = qsPkgs.default;
      };
    });

    homeModules.default = import ./nix/hm-module.nix self;
  };
}
