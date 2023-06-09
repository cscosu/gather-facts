{
  description = "Automatic fact gatherer";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    utils,
    ...
  }:
    utils.lib.eachSystem (with utils.lib.system; [x86_64-linux]) (system: {
      packages.gather-facts =
        (nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [./iso.nix];
        })
        .config
        .system
        .build
        .isoImage;
    })
    // utils.lib.eachSystem (with utils.lib.system; [x86_64-linux]) (system: let
      pkgs = import nixpkgs {
        inherit system;
      };
    in {
      devShells.default = pkgs.mkShell {
        name = "gather-facts development environment";
        packages = with pkgs; [magic-wormhole];
      };
    });
}
