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

      sui-src = /home/freerat/projects/sui;

      sui-cli-impure = pkgs.callPackage ./sui-cli-impure {
        stdenv = pkgs.clangStdenv;
        inherit sui-src;
      };

      sui-cli = pkgs.callPackage ./sui-cli {
        stdenv = pkgs.clangStdenv;
      };
    in
    {
      packages.${system} = {
        inherit sui-cli sui-cli-impure;
        default = sui-cli-impure;
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          bash
          git
          pkg-config
          cmake
          clang
          llvmPackages.libclang
          openssl.dev
          zlib
          snappy
          lz4
          zstd
          jemalloc
          protobuf
          rustfmt
          rustc
          cargo
        ];

        LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
        CXXFLAGS = "-include cstdint";

        shellHook = ''
          echo "sui dev shell ready"
        '';
      };
    };
}
