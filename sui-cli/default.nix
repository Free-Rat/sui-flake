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
  protobuf,
}:
rustPlatform.buildRustPackage rec {
  pname = "sui-cli";
  version = "1.69.2";

  src = fetchFromGitHub {
    owner = "MystenLabs";
    repo = "sui";
    rev = "mainnet-v${version}";
    hash = "sha256-c/IZTOGF5f5YxQGuqzQ2YQUJpMzKWR5LMhopfwQM2R0=";
  };

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "alloy-multiprovider-strategy-0.1.0" = "sha256-a+Ilc9cy8S1/hR/0ymM+7wKvRVXp4LTN/s9FUL8EwU8=";
      "msim-0.1.0" = "sha256-UBnvrpIb8PF2b8mI7ygSf+BjnuYuU987oIFNjCPrlDE=";
      "async-task-4.3.0" = "sha256-zMTWeeW6yXikZlF94w9I93O3oyZYHGQDwyNTyHUqH8g=";
      "real_tokio-1.49.0" = "sha256-qRndfrzPM/bCBxSqnv4CwJ+m5jy5C3lj9GbzKeXd/WI=";
      "datatest-stable-0.1.3" = "sha256-VAdrD5qh6OfabMUlmiBNsVrUDAecwRmnElmkYzba+H0=";
      "fastcrypto-0.1.9" = "sha256-2B2m71Kumx/9e04yj+QIn/KG+sGZOK27SeYgheJOb84=";
      "async-graphql-7.0.1" = "sha256-dbqzmp7ydPoTu91TGtHh47eb9nCTdnFBzWvZ0WHxPis=";
      "nexlint-0.1.0" = "sha256-L9vf+djTKmcz32IhJoBqAghQ8mS3sc9I2C3BBDdUxkQ=";
      "anemo-0.0.0" = "sha256-qgOYGKxpehXQRHqvVTtYhS5NwbiRFz9ThmR++JjmI6I=";
      "minibytes-0.1.0" = "sha256-n5rG5P06IXrP/+A+WvvwWYq0GDzN8B7ldu84JqAHZmk=";
      "json_to_table-0.6.0" = "sha256-UKMTa/9WZgM58ChkvQWs1iKWTs8qk71gG+Q/U/4D4x4=";
      "sui-crypto-0.2.0" = "sha256-EK5FC5eHk4Ut1zo4TvHv1nVq7r8w+N5SgAvk9CaQMYw=";
    };
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

  GIT_REVISION = "33ef98b2337036b06f9da3927715a411dcddfc40";

  doCheck = false;

  meta = with lib; {
    description = "Sui CLI - a byzantine fault tolerant blockchain";
    longDescription = ''
      Sui is a decentralized, permissionless, and carbon-neutral blockchain
      that provides fast, safe, and composable asset ownership.
      This package provides the sui CLI tool.
    '';
    homepage = "https://github.com/MystenLabs/sui";
    changelog = "https://github.com/MystenLabs/sui/releases/tag/mainnet-v${version}";
    license = licenses.asl20;
    platforms = platforms.unix;
    maintainers = with maintainers; [ ];
    mainProgram = "sui";
  };
}
