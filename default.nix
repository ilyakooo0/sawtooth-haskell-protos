{ sources ? import nix/sources.nix
, nixpkgs ? import sources.nixpkgs { }
}:
let
  proto3-suite = import sources.proto3-suite { };
  sawtooth-haskell-protos-src = nixpkgs.stdenv.mkDerivation {
    name = "sawtooth-haskell-protos-src";
    buildInputs = [ proto3-suite.proto3-suite ];
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
  sawtooth-haskell-protos-overlay = hself: hsuper: {
    sawtooth-haskell-protos = hsuper.callCabal2nix "sawtooth-haskell-protos" sawtooth-haskell-protos-src { };
    haskell-src = nixpkgs.haskell.lib.doJailbreak (hsuper.callHackageDirect
      {
        pkg = "haskell-src";
        ver = "1.0.3.1";
        sha256 = "11s2qnnhchcbi6szvcglv4xxz3l6zw9w3pziycpwrigjvpigymd2";
      } { }
    );
    insert-ordered-containers = hsuper.callHackageDirect
      {
        pkg = "insert-ordered-containers";
        ver = "0.2.3.1";
        sha256 = "0zxxjwzcsyc7a572f584w83aqygdc3q05pfarghj2v437nsnap29";
      } { };
    swagger2 = hsuper.callHackageDirect
      {
        pkg = "swagger2";
        ver = "2.6";
        sha256 = "0x0s34q9bmrik0vmzpc08r4jq5kbpb8x7h19ixhaakiafpjfm59l";
      } { };
    proto3-suite = nixpkgs.haskell.lib.dontCheck (hsuper.callHackageDirect
      {
        pkg = "proto3-suite";
        ver = "0.4.0.2";
        sha256 = "11bppmb524q6qvgyddi9s7pf1n1zs4ypqkqs2qb6i8nsgmxndd1l";
      } { }
    );
    proto3-wire = hsuper.callHackageDirect
      {
        pkg = "proto3-wire";
        ver = "1.2.0";
        sha256 = "1jqz6zsli5zvlissy7mkgyrzkapjvgijx7kjva4fxjwdyd0hqix7";
      } { };
    http-media = nixpkgs.haskell.lib.doJailbreak (hsuper.callHackageDirect
      {
        pkg = "http-media";
        ver = "0.8.0.0";
        sha256 = "080xkljq1iq0i8wagg8kbzbp523p2awa98wpn9i4ph1dq8y8346y";
      } { }
    );
    parameterized = nixpkgs.haskell.lib.dontCheck hsuper.parameterized;
  };
in
{
  inherit sawtooth-haskell-protos-src sawtooth-haskell-protos-overlay;
  build = (nixpkgs.haskell.packages.ghc882.override {
    overrides = sawtooth-haskell-protos-overlay;
  }).sawtooth-haskell-protos;
}
