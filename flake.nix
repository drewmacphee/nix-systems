{
  description = "Kids Laptop NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    
    home-manager = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      # Helper function to create a system configuration
      mkSystem = hostname: nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/${hostname}/configuration.nix
          # Set the hostname
          { networking.hostName = hostname; }
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.users.drew = import ./home/drew.nix;
            home-manager.users.emily = import ./home/emily.nix;
            home-manager.users.bella = import ./home/bella.nix;
          }
        ];
      };
    in
    {
      nixosConfigurations = {
        bazztop = mkSystem "bazztop";
        # Add more machines here as needed:
        # othermachine = mkSystem "othermachine";
      };
    };
}
