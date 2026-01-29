# SSH Host CA Workflow (Scaffolding Only)

This document describes the optional scaffolding for SSH host certificate
authority (CA) trust in NyxOS. It is **off by default** and requires explicit
configuration.

## What an SSH host CA is

SSH can trust a host either by pinning its host key (classic `known_hosts`)
**or** by trusting a CA public key that signs host certificates. A host CA
workflow scales better for fleets you control because individual host keys can
rotate without requiring new pins on every client.

## When this is appropriate

Use host CA trust **only** when you control:

- the domain patterns you connect to, and
- the issuance process that signs host certificates.

If you do not control both, do **not** enable host CA trust for those domains.

## What dotclone provides

- Declarative options under `my.ssh.knownHosts.ca` to define CA bundles.
- A pure template that converts bundles into `@cert-authority` entries.
- Optional Home Manager UX preset via the `cloud-ca-ready` feature.

## What dotclone intentionally does NOT provide

- No network fetching or key discovery.
- No automatic CA enablement.
- No provider domain patterns by default.
- No installer-time trust decisions.

## Enabling a CA bundle (example)

This example is **only** a template. Replace patterns and key material with
values you control and have verified out-of-band.

```nix
my.ssh = {
  knownHosts.enable = true;
  knownHosts.ca = {
    enable = true;
    bundles = {
      fleet = {
        patterns = [ "*.cloud.example.com" "*.svc.example.com" ];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAEXAMPLECAKEY";
        comment = "example only";
      };
    };
  };

  client.features = [ "cloud-ca-ready" ];
};
```

## Safety guardrails

- CA bundles must define **non-empty** patterns and **non-empty** public keys.
- Provider domain patterns (e.g. `amazonaws.com`, `azure.com`) are rejected
  unless `my.ssh.knownHosts.ca.allowProviderPatterns = true` is set explicitly.
- Trust roots are system-owned (`programs.ssh.knownHosts`). Client UX stays in
  Home Manager templates.
