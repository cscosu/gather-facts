# Gather facts

Create ISO images with a startup script to gather facts about CPU, RAM, storage, etc., and send the facts back to another computer.

## Usage

Create an ISO with a wormhole code baked in

```
WORMHOLE_CODE=123-my-s3cr3t-code nix build .#packages.x86_64-linux.gather-facts --impure
```

Boot off of the created iso image (found in `result/iso`), then listen on any other computer to download the facts about the computer you booted off of.

```
wormhole receive 123-my-s3cr3t-code --accept-file
```

(optionally, use a compatible wormhole client like [Warp](https://gitlab.gnome.org/World/warp) instead)
