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

  hardware.enableAllFirmware = true;
  nixpkgs.config.allowUnfree = true;

  isoImage.isoName = lib.mkForce "gather-facts-${config.isoImage.isoBaseName}-${pkgs.stdenv.hostPlatform.system}.iso";

  services.getty.helpLine = ''
    An UNATTENDED script is about to run to gather
    facts about CPU, RAM, storage, etc., and send
    then to an ONLINE EXTERNAL server.

    The system will POWER OFF after it is done.
  '';

  systemd.services.install = {
    description = "Bootstrap a NixOS installation";
    wantedBy = ["multi-user.target"];
    after = ["network.target" "polkit.service"];
    path = ["/run/current-system/sw/"];
    script = ''
      SEPARATOR="----------"

      echo "$SEPARATOR lspcu $SEPARATOR" >> facts
      lscpu >> facts

      echo "lsblk" >> facts

      curl --data-binary @facts brentwood.nl:13420/gatherfacts
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
