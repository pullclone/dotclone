# Pinned SSH host keys for common Git providers.
# Sources:
# - GitHub: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
# - GitLab: https://docs.gitlab.com/ee/user/gitlab_com/#ssh-host-keys-fingerprints
# - Bitbucket: https://bitbucket.org/site/ssh
# - Codeberg: https://docs.codeberg.org/security/ssh-fingerprint/
{
  github = {
    hostNames = [
      "github.com"
      "ssh.github.com"
    ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
  };

  gitlab = {
    hostNames = [ "gitlab.com" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfuCHKVTjquxvt6CM6tdG4SLp1Btn/nOeHHE5UOzRdf";
  };

  bitbucket = {
    hostNames = [ "bitbucket.org" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIazEu89wgQZ4bqs3d63QSMzYVa0MuJ2e2gKTKqu+UUO";
  };

  codeberg = {
    hostNames = [ "codeberg.org" ];
    # Verified against the official Codeberg fingerprint list.
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIVIC02vnjFyL+I4RHfvIGNtOgJMe769VTF1VR4EB3ZB";
  };
}
