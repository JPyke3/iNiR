{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    version =
      builtins.replaceStrings ["\n"] [""]
      (builtins.readFile "${self}/VERSION");
    forEachSystem = nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux"];
  in {
    packages = forEachSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.callPackage ./nix/package.nix {inherit version;};
    });

    homeModules.default = import ./nix/hm-module.nix self;
  };
}
