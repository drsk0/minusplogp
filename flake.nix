{
  description = "minusplogp development environment";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = {allowUnfree = true; allowBroken = true;};
      };
    in
  {

  devShell.${system} = pkgs.mkShell {
    buildInputs = [
      pkgs.zola
      pkgs.nil
    ];
  };
  };

}
