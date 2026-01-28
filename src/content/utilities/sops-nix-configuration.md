---
title: "sops-nix Configuration"
description: "Configure sops-nix to save and distribute secrets securely in NixOS"
category: "nix"
tags: ["nix", "security", "secrets", "secret management", "declarative"]
created: 2026-01-28
---

# sops-nix Configuration

Modify the existing `flake.nix` as such:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixd.url = "github:nix-community/nixd/main";
    nixfmt.url = "github:NixOS/nixfmt/master";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    ...
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      sops-nix,
      ...
    }:
    ...
    {
      nixosConfigurations."nixos" = nixpkgs.lib.nixosSystem {
        ...
      };
      ...
      sops-nix.nixosModules.sops
```

Then, generate age key pair (recommended over GPG)

```bash
nix-shell -p age --run "age-keygen -o ~/.config/sops/age/keys.txt"
cat ~/.config/sops/age/keys.txt | grep "public key:" | cut -d: -f2 | xargs
```

The second command should print the generated public key, which we will store in `/etc/nixos/.sops.yaml`:

```nix
creation_rules:
  - path_regex: secrets/.*\.yaml$
    key_groups:
      - age:
          - "PUBLIC_KEY"
```

Next, we create the unencrypted file in `/etc/nixos/secrets.yaml`:

```yaml
KEY_1: VALUE
KEY_2: ANOTHER_VALUE
....
```

Which we encrypt with:

`nix-shell -p sops --run "sops --config /etc/nixos/secrets.yaml --encrypt --in-place /etc/nixos/secrets/secrets-enc.yaml"`

***IMPORTANT NOTE:*** NEVER forget to keep a `.gitignore` here, and to update it with the name of the `secrets.yaml` file, since it will contain all the unencrypted secrets.

After this, we create the file `/etc/nixos/sops.nix`:

```nix
{
  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    age.keyFile = "/home/hytx/.config/sops/age/keys.txt";
    secrets = {
      deepseekAPIKey = {
        mode = "0400";
        owner = "root";
        group = "root";
        path = "/run/secrets/deepseek-api-key";
      };
      xSTFCTFDToken = {
        mode = "0400";
        owner = "root";
        group = "root";
        path = "/run/secrets/ctfd-token";
      };
      xSTFCTFDURL = {
        mode = "0400";
        owner = "root";
        group = "root";
        path = "/run/secrets/ctfd-url";
      };
      xSTFCTFDDeployHost = {
        mode = "0400";
        owner = "root";
        group = "root";
        path = "/run/secrets/ctfd-deploy-host";
      };
      INESCTECVPNConfig = {
        mode = "0400";
        owner = "root";
        group = "root";
        path = "/etc/openvpn/inesctec.conf";
        sopsFile = ./secrets/secrets.yaml;
      };
    };
  };
}
```

And import it in `configuration.nix`:

```nix
{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ...
    ./sops.nix
  ];
```

The secrets will be created in `/run/secrets/KEY_NAME`, with this configuration, being read-only only by root.

## Secret usage in Nix configuration files

Since the secrets are stored in `/run`, we need to access them out-of-band, outside of the evaluation time when rebuilding the system.

The way we do this is, instead of realizing the actual path on rebuild, we set environment variables to read from the key paths:

```nix
{ ... }:
{
  environment = {
    ...
    shellInit = ''
      ...
      if [ -f /run/secrets/KEY_1 ]; then
        export KEY_1="$(cat /run/secrets/KEY_1)"
      fi
      if [ -f /run/secrets/KEY_2 ]; then
        export KEY_2="$(cat /run/secrets/KEY_2)"
      fi
      ...
    '';
    ...
```

## Updating secrets

Simply use `nix-shell -p sops --run "sops /etc/nixos/secrets/secrets.yaml"` to live edit the secrets, do not forget to include/exclude them from the `sops.nix` file, or the rebuild will fail.