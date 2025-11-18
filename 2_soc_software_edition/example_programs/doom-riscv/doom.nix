{ pkgs, stdenv }:
let
  pkgsCross = import pkgs.path {
    localSystem = pkgs.stdenv.buildPlatform.system;
    crossSystem = {
      config = "riscv32-none-elf";
      libc = "newlib-nano";
      #libc = "newlib";
      gcc.arch = "rv32im";
    };
  };
in
pkgs.gcc13Stdenv.mkDerivation rec {
  pname = "rve";
  version = "0.1.0";

  dontPatch = true;

  nativeBuildInputs = with pkgs; [ pkg-config gnumake ];

  buildInputs = with pkgs; [
    #riscv-pkgs.buildPackages.gcc
    pkgsCross.buildPackages.gcc
    pkgsCross.buildPackages.binutils
  ];

  hardeningDisable = [ "all" ];
  cmakeFlags = [
    "-DCMAKE_EXPORT_COMPILE_COMMANDS=TRUE"
    "-DCMAKE_BUILD_TYPE=Debug"
    #"-DCMAKE_BUILD_TYPE=RelWithDebInfo"
  ];
  shellHook = ''
  '';

  buildPhase = ''
    cd src/riscv
    make
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp doom-riscv.elf $out/bin
  '';

  doCheck = true;

  src = ./.;

}
