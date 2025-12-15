# This file will be generated during NixOS installation
# Run: nixos-generate-config --show-hardware-config > hardware-configuration.nix
# This is a placeholder template

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ]; # or "kvm-amd" for AMD
  boot.extraModulePackages = [ ];

  # Update these with your actual disk layout
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };

  swapDevices = [ ];

  # Enable if needed
  # hardware.cpu.intel.updateMicrocode = true;
  # hardware.cpu.amd.updateMicrocode = true;
}
