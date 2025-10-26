{ pkgs ? import <nixpkgs> {} }:

let
  texlive = pkgs.texlive.combine {
    inherit (pkgs.texlive)
      scheme-full latexmk
      # collection-langcyrillic
      moderncv;
  };
in pkgs.stdenv.mkDerivation {
  name = "cv-pdf";
  src = ./.;

  # Haskell (parseGingerFile') fails without explicitly setting UTF-8
  LANG = "en_US.UTF-8";
  LC_ALL = "en_US.UTF-8";
  LOCALE_ARCHIVE = "${pkgs.glibcLocales}/lib/locale/locale-archive";

  buildInputs = with pkgs.haskellPackages; [
    (pkgs.haskellPackages.ghcWithPackages (ps: with ps; [
      base
      aeson
      ginger
      text]))

    texlive
  ];

  # the actual build is in the Makefile to allow nix-less usage
  buildPhase = ''
    # Ensure UTF-8 environment
    export LANG="en_US.UTF-8"
    export LC_ALL="en_US.UTF-8"

    make pdf
  '';

  installPhase = ''
    # Copy the resulting PDF to $out
    mkdir -p $out
    cp cv.tex cv.pdf $out/
  '';

}
