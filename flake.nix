{
  description = "Flake with Sui CLI";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      sui_main = pkgs.callPackage ./cli {
        stdenv = pkgs.clangStdenv;
      };
    in
    {
      # Expose the package
      packages.${system}.sui = sui_main;

      # Optional: make it the default package
      defaultPackage.${system} = sui_main;

      # Dev shell
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          bash
          git
          sui_main
        ];

        shellHook = ''
          echo "hello sui"
        '';
      };
    };
}
