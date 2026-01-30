{ lib, ... }:
{
  programs.ssh.extraConfig = ''
    CanonicalizeHostname yes
    CanonicalDomains company.internal company.com
    CanonicalizeMaxDots 1
    CanonicalizeFallbackLocal yes
  '';

  programs.ssh.matchBlocks."*.company.internal" = {
    user = "corpuser";
    identityFile = "~/.ssh/corp_ed25519";
    identitiesOnly = true;

    extraOptions = {
      GSSAPIAuthentication = "yes";
      GSSAPIDelegateCredentials = "no";
      UpdateHostKeys = "no";
      UserKnownHostsFile = "~/.ssh/known_hosts.internal";
    };
  };
}
