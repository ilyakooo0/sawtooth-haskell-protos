{ sources ? import nix/sources.nix { inherit system; }
, nixpkgs ? import sources.nixpkgs { inherit system; }
, system ? builtins.currentSystem
, ghc ? "ghc8103"
}:
let
  unbreak = x: x.overrideDerivation (_: {
    broken = false;
  });
  overrides = (hself: hsuper: {
    proto3-suite = nixpkgs.haskell.lib.dontCheck (
      nixpkgs.haskell.lib.doJailbreak (
        hsuper.callCabal2nix "proto3-suite"
          sources.proto3-suite { }
      )
    );
    proto3-wire =
      hsuper.callHackageDirect
        {
          pkg = "proto3-wire";
          ver = "1.2.0";
          sha256 = "1jqz6zsli5zvlissy7mkgyrzkapjvgijx7kjva4fxjwdyd0hqix7";
        } { };
    haskell-src = nixpkgs.haskell.lib.doJailbreak (unbreak hsuper.haskell-src);
    parameterized = nixpkgs.haskell.lib.dontCheck (nixpkgs.haskell.lib.doJailbreak (unbreak hsuper.parameterized));
  });
  haskell = nixpkgs.haskell.packages.${ghc}.override {
    inherit overrides;
  };
  sawtooth-haskell-protos-src = nixpkgs.stdenv.mkDerivation {
    name = "sawtooth-haskell-protos-src";
    buildInputs = [ haskell.proto3-suite ];
    src = sources.sawtooth-core + "/protos";
    buildPhase = ''
      for f in *.proto
      do
        sed -i -e "/syntax = \"proto3\";/a package $(basename $f .proto);" -e 's/import "/import "data\/sawtooth\//' $f
      done

      mkdir -p data/sawtooth
      mv *.proto data/sawtooth

      for f in data/sawtooth/**.proto
      do
        compile-proto-file --includeDir data/sawtooth --includeDir $(pwd) --proto $f --out out/src
      done

      cp ${./package.yaml} out/package.yaml
    '';
    installPhase = ''
      mkdir $out
      cp -a out/. $out/
    '';
  };
  sawtooth-haskell-protos =
    nixpkgs.haskellPackages.callCabal2nix "sawtooth-haskell-protos" sawtooth-haskell-protos-src { };
  sawtooth-haskell-protos-overlay = nixpkgs.lib.composeExtensions overrides (hself: hsuper: {
    sawtooth-haskell-protos = hsuper.callCabal2nix "sawtooth-haskell-protos" sawtooth-haskell-protos-src { };
  });
in
{
  inherit sawtooth-haskell-protos-src sawtooth-haskell-protos-overlay;
  build = (nixpkgs.haskell.packages.${ghc}.override {
    overrides = sawtooth-haskell-protos-overlay;
  }).sawtooth-haskell-protos;
}
