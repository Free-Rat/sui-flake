{
  lib,
  stdenv,
  rustPlatform,
  pkg-config,
  cmake,
  clang,
  openssl,
  llvmPackages,
  rustfmt,
  jemalloc,
  zlib,
  snappy,
  lz4,
  zstd,
  protobuf,
  sui-src,
}:
rustPlatform.buildRustPackage rec {
  pname = "sui-cli-impure";
  version = "1.71.0";

  src = builtins.path {
    path = sui-src;
    name = "sui-source";
    filter = name: type: !(lib.hasSuffix ".git" name) && !(lib.hasInfix "/.git/" name) && !(lib.hasInfix "/target/" name);
  };

  cargoLock = {
    lockFile = ./Cargo.lock;
    allowBuiltinFetchGit = true;
  };

  cargoBuildFlags = [
    "--package"
    "sui"
    "--features"
    "tracing"
  ];

  nativeBuildInputs = [
    pkg-config
    cmake
    clang
    llvmPackages.libclang
    rustPlatform.bindgenHook
    rustfmt
    protobuf
  ];

  buildInputs = [
    openssl
    zlib
    snappy
    lz4
    zstd
    jemalloc
  ];

  LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";
  CXX_x86_64_unknown_linux_gnu = "${stdenv.cc}/bin/clang++";
  CC_x86_64_unknown_linux_gnu = "${stdenv.cc}/bin/clang";
  CXXFLAGS_x86_64_unknown_linux_gnu = "-include cstdint";

  PROTOC = "${protobuf}/bin/protoc";

  GIT_REVISION = "1b164b191f124b6a43b4328b55db06bfb873cb76";

  doCheck = false;

  meta = with lib; {
    description = "Sui CLI";
    homepage = "https://github.com/MystenLabs/sui";
    license = licenses.asl20;
    platforms = platforms.unix;
  };
}
