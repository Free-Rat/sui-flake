{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
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
}:
rustPlatform.buildRustPackage {
  pname = "sui";
  version = "mainnet-v1.69.2";

  src = fetchFromGitHub {
    owner = "MystenLabs";
    repo = "sui";
    rev = "mainnet-v1.69.2";
    hash = "sha256-c/IZTOGF5f5YxQGuqzQ2YQUJpMzKWR5LMhopfwQM2R0=";
  };

  # cargoLock.lockFile = ./Cargo.lock;
  cargoHash = "sha256-rQz7vv+cQ7XLJI0LieYUsr2U7Xwsn6AL/HOzGC8irxA=";

  # the main CLI package
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
  ];

  buildInputs = [
    openssl
    # clang

    zlib
    snappy
    lz4
    zstd

    jemalloc
  ];

  # ROCKSDB_DISABLE_JEMALLOC = "1";
  LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";
  CXX_x86_64_unknown_linux_gnu = "${stdenv.cc}/bin/clang++";
  CC_x86_64_unknown_linux_gnu = "${stdenv.cc}/bin/clang";
  CXXFLAGS_x86_64_unknown_linux_gnu = "-include cstdint";
  GIT_REVISION = "7565830eeebb";
  # OPENSSL_NO_VENDOR = 1;

  meta = with lib; {
    description = "Sui CLI";
    homepage = "https://github.com/MystenLabs/sui";
    license = licenses.asl20;
    platforms = platforms.unix;
  };
}
