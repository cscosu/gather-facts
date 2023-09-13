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
    python3
    magic-wormhole
    lshw
    smartmontools
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

  systemd.services.gather = {
    description = "Gather information about the system";
    after = ["network.target"];
    wants = ["network.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      WorkingDirectory = "/home/nixos";
    };
    path = ["/run/current-system/sw/"];
    script = let
      wormhole-code-env = builtins.getEnv "WORMHOLE_CODE";
      wormhole-code =
        if wormhole-code-env == ""
        then throw "No WORMHOLE_CODE environment variable set"
        else wormhole-code-env;
    in ''
      set -x
      mkdir -p facts

      hwinfo > facts/hwinfo.txt
      lscpu > facts/lscpu.txt
      lsusb > facts/lsusb.txt
      lsblk > facts/lsblk.txt
      lspci > facts/lspci.txt
      lsmem > facts/lsmem.txt
      lshw > facts/lshw.txt
      lshw -short > facts/lshw-short.txt
      dmidecode > facts/dmidecode.txt

      for drive in $(lsblk -o NAME -nld); do
        if smartctl -a /dev/$drive; then
          smartctl -a /dev/$drive > facts/smart-$drive.txt
        fi
      done

      # generate a random ID in the form MXXXXXXXXC
      # where M is arbitrary, X's are digits 0-9, and the last C is the Luhn checksum digit
      ID=$(cat /dev/urandom | tr -dc 0-9 | head -c 8)
      CHECK_DIGIT=$(python3 -c "digits = list(map(int,str('$ID' + '0'))); print((10 - (sum(digits[-1::-2]) + sum([sum(divmod(2 * d, 10)) for d in digits[-2::-2]]))) % 10)")
      echo "M''${ID}''${CHECK_DIGIT}" > facts/id

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
