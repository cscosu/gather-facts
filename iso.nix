{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  boot.kernelPackages = pkgs.linuxKernel.packages.linux_6_1;
  boot.loader.timeout = lib.mkForce 5;

  hardware.enableAllFirmware = true;
  nixpkgs.config.allowUnfree = true;

  isoImage.isoName = lib.mkForce "gather-facts-${config.isoImage.isoBaseName}-${pkgs.stdenv.hostPlatform.system}.iso";

  environment.systemPackages = with pkgs; [
    dmidecode
    hwinfo
    magic-wormhole
  ];

  services.getty.helpLine = ''
    An UNATTENDED script is about to run to gather
    facts about CPU, RAM, storage, etc., and send
    them over MAGIC WORMHOLE (potentially an ONLINE
    EXTERNAL SERVER). The computer will require an
    ACTIVE NETWORK CONNECTION WITHOUT AUTHENTICATION
    to send the information.

    The system will POWER OFF after it is done.
  '';

  systemd.services.install = {
    description = "Bootstrap a NixOS installation";
    wantedBy = ["multi-user.target"];
    after = ["network.target" "polkit.service"];
    path = ["/run/current-system/sw/"];
    script = let
      wormhole-code-env = builtins.getEnv "WORMHOLE_CODE";
      wormhole-code =
        if wormhole-code-env == ""
        then throw "No WORMHOLE_CODE environment variable set"
        else wormhole-code-env;
    in ''
      mkdir facts

      hwinfo > facts/hwinfo
      lscpu > facts/lscpu
      lsusb > facts/lsusb
      lsblk > facts/lsblk
      lspci > facts/lspci
      lsmem > facts/lsmem
      dmidecode > facts/dmidecode

      cd facts
      zip ../facts.zip *
      cd ..

      wormhole send --code ${lib.escapeShellArg wormhole-code} facts.zip

      poweroff
    '';
    environment =
      config.nix.envVars
      // {
        inherit (config.environment.sessionVariables) NIX_PATH;
        HOME = "/root";
      };
    serviceConfig = {
      Type = "oneshot";
    };
  };
}
