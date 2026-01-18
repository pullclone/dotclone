{ ... }:

{
  services.usbguard = {
    enable = true;
    ruleFile = "/etc/usbguard/rules.conf";
  };

  environment.etc."usbguard/rules.conf".source = ../../etc/usbguard/rules.conf;
}
