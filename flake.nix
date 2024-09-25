{
  description = "An empty project that uses Zig.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
    zig.url = "github:mitchellh/zig-overlay";

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    ...
  } @ inputs: let
    overlays = [
      (final: prev: {
        zigpkgs = inputs.zig.packages.${prev.system};
      })
    ];

    systems = builtins.attrNames inputs.zig.packages;
  in
    flake-utils.lib.eachSystem systems (
      system: let
        pkgs = import nixpkgs {inherit overlays system;};
      in rec {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs =  [
            pkgs.zigpkgs."0.13.0"
            pkgs.openocd-rp2040
            pkgs.picocom
            pkgs.picotool
            pkgs.just
            pkgs.llvm_18
            pkgs.gdb
          ];
        };
        devShell = self.devShells.${system}.default;
      }
    );
}