# Firefox: privacy-focused primary browser with Dracula theming.
# Two profiles: "default" (hardened, daily driver) and "relaxed" (for sites that break).
# Cross-platform (NixOS + macOS). Extensions force-installed via policies.
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.features.desktop.firefox;

  # Shared extensions for both profiles (installed via policies)
  sharedExtensions = {
    # uBlock Origin: best-in-class ad/tracker blocker
    "uBlock0@raymondhill.net" = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
      installation_mode = "force_installed";
    };
    # Privacy Badger: learns to block invisible trackers
    "jid1-MnnxcxisBPnSXQ@jetpack" = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/privacy-badger17/latest.xpi";
      installation_mode = "force_installed";
    };
    # Bitwarden: password manager
    "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
      installation_mode = "force_installed";
    };
    # Dracula theme
    "{b743f56d-1cc1-4856-b330-26025aad5063}" = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/dracula-dark-colorscheme/latest.xpi";
      installation_mode = "force_installed";
    };
    # Dark Reader: dark mode for all websites
    "addon@darkreader.org" = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi";
      installation_mode = "force_installed";
    };
    # xBrowserSync: browser-agnostic bookmark sync
    "{019b606a-6f61-4571-aa98-01f5ff4a0305}" = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/xbs/latest.xpi";
      installation_mode = "force_installed";
    };
  };

  # Arkenfox-inspired hardening settings (medium-heavy)
  # These go on the "default" hardened profile.
  hardenedSettings = {
    # --- Telemetry & data collection ---
    "toolkit.telemetry.enabled" = false;
    "toolkit.telemetry.unified" = false;
    "toolkit.telemetry.archive.enabled" = false;
    "datareporting.healthreport.uploadEnabled" = false;
    "datareporting.policy.dataSubmissionEnabled" = false;
    "app.shield.optoutstudies.enabled" = false;
    "app.normandy.enabled" = false;
    "breakpad.reportURL" = "";
    "browser.tabs.crashReporting.sendReport" = false;
    "browser.crashReports.unsubmittedCheck.autoSubmit2" = false;

    # --- WebRTC leak prevention ---
    "media.peerconnection.ice.default_address_only" = true;
    "media.peerconnection.ice.no_host" = true;

    # --- HTTPS & TLS hardening ---
    "dom.security.https_only_mode" = true;
    "dom.security.https_only_mode_send_http_background_request" = false;
    "security.tls.version.min" = 3; # TLS 1.2 minimum
    "security.OCSP.enabled" = 1;
    "security.OCSP.require" = true;
    "security.cert_pinning.enforcement_level" = 2; # strict
    "security.mixed_content.block_active_content" = true;
    "security.mixed_content.block_display_content" = true;
    "security.ssl.require_safe_negotiation" = true;

    # --- Anti-fingerprinting ---
    "privacy.resistFingerprinting" = true;
    "privacy.resistFingerprinting.letterboxing" = true;
    "webgl.disabled" = true; # WebGL is a fingerprinting vector
    "media.navigator.enabled" = false; # hide camera/mic enumeration
    "dom.battery.enabled" = false;
    "dom.webaudio.enabled" = false;

    # --- Cookie & tracking isolation ---
    "privacy.firstparty.isolate" = true;
    "network.cookie.cookieBehavior" = 1; # block third-party cookies
    "privacy.trackingprotection.enabled" = true;
    "privacy.trackingprotection.socialtracking.enabled" = true;
    "network.cookie.lifetimePolicy" = 2; # clear on close

    # --- DNS ---
    "network.trr.mode" = 2; # DNS-over-HTTPS (DoH), fallback to system
    "network.trr.uri" = "https://dns.quad9.net/dns-query"; # Quad9 (privacy + malware blocking)

    # --- Miscellaneous privacy ---
    "geo.enabled" = false;
    "browser.safebrowsing.malware.enabled" = false; # phones home to Google
    "browser.safebrowsing.phishing.enabled" = false;
    "network.prefetch-next" = false;
    "network.dns.disablePrefetch" = true;
    "network.predictor.enabled" = false;
    "network.http.speculative-parallel-limit" = 0;
    "browser.send_pings" = false;
    "browser.urlbar.speculativeConnect.enabled" = false;
    "privacy.sanitize.sanitizeOnShutdown" = true;
    "privacy.clearOnShutdown.cache" = true;
    "privacy.clearOnShutdown.cookies" = true;
    "privacy.clearOnShutdown.history" = false; # keep history
    "privacy.clearOnShutdown.sessions" = true;
    "privacy.clearOnShutdown.offlineApps" = true;
    "privacy.clearOnShutdown.formdata" = true;

    # --- UI / usability ---
    "browser.contentblocking.category" = "strict";
    "browser.newtabpage.activity-stream.showSponsored" = false;
    "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
    "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
    "extensions.pocket.enabled" = false;
    "browser.formfill.enable" = false;
    "browser.search.suggest.enabled" = false;
    "browser.urlbar.suggest.searches" = false;
  };

  # Relaxed profile: privacy-lite, fewer breakage risks
  relaxedSettings = {
    # Still disable telemetry
    "toolkit.telemetry.enabled" = false;
    "datareporting.healthreport.uploadEnabled" = false;
    "app.normandy.enabled" = false;

    # HTTPS-only but no RFP/WebGL restrictions
    "dom.security.https_only_mode" = true;
    "privacy.resistFingerprinting" = false;
    "webgl.disabled" = false;
    "dom.webaudio.enabled" = true;
    "media.navigator.enabled" = true;
    "geo.enabled" = true; # some sites need geolocation

    # Standard cookie policy (not first-party isolate)
    "privacy.firstparty.isolate" = false;
    "network.cookie.cookieBehavior" = 5; # ETP strict (Firefox default)
    "network.cookie.lifetimePolicy" = 0; # keep cookies

    # DoH still on
    "network.trr.mode" = 2;
    "network.trr.uri" = "https://dns.quad9.net/dns-query";

    # Prefetch allowed for speed
    "network.prefetch-next" = true;
    "network.dns.disablePrefetch" = false;

    # UI
    "browser.contentblocking.category" = "strict";
    "extensions.pocket.enabled" = false;
    "browser.newtabpage.activity-stream.showSponsored" = false;
    "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
  };
in {
  options.features.desktop.firefox.enable = mkEnableOption "enable firefox";

  config = mkIf cfg.enable {
    programs.firefox = {
      enable = true;
      # Keep legacy profile path (~/.mozilla/firefox) to avoid moving profile data.
      # HM's new default is $XDG_CONFIG_HOME/mozilla/firefox but requires a migration.
      configPath = ".mozilla/firefox";

      # ---- POLICIES (apply to all profiles) ----
      policies = {
        DisableTelemetry = true;
        DisableFirefoxStudies = true;
        EnableTrackingProtection = {
          Value = true;
          Locked = true;
          Cryptomining = true;
          Fingerprinting = true;
        };
        DisablePocket = true;
        DisableFirefoxAccounts = true;
        DisableAccounts = true;
        DisableFirefoxScreenshots = true;
        OverrideFirstRunPage = "";
        OverridePostUpdatePage = "";
        DontCheckDefaultBrowser = true;
        DisplayBookmarksToolbar = "never";
        DisplayMenuBar = "default-off";
        SearchBar = "unified";

        # Extensions installed globally across all profiles
        ExtensionSettings =
          {"*".installation_mode = "blocked";}
          // sharedExtensions
          // {
            # Hardened-profile-only extensions (still globally installed, toggled per-profile)
            # LocalCDN: CDN emulation for privacy
            "{b86e4813-687a-43e6-ab65-0bde4ab75758}" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/localcdn-fork-of-decentraleyes/latest.xpi";
              installation_mode = "force_installed";
            };
            # ClearURLs: strip tracking parameters from URLs
            "{74145f27-f039-47ce-a470-a662b129930a}" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/clearurls/latest.xpi";
              installation_mode = "force_installed";
            };
            # Cookie AutoDelete: auto-clear cookies after tab close
            "CookieAutoDelete@kennydo.com" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/cookie-autodelete/latest.xpi";
              installation_mode = "force_installed";
            };
            # Firefox Multi-Account Containers
            "@testpilot-containers" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/multi-account-containers/latest.xpi";
              installation_mode = "force_installed";
            };
            # CanvasBlocker: anti-fingerprinting
            "CanvasBlocker@nickerbocker.github.io" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/canvasblocker/latest.xpi";
              installation_mode = "force_installed";
            };
          };
      };

      # ---- PROFILES ----
      profiles = {
        # Hardened daily driver with arkenfox-style settings
        default = {
          id = 0;
          isDefault = true;
          settings = hardenedSettings;
        };

        # Relaxed profile for sites that break under heavy hardening
        # Launch with: firefox -P relaxed
        relaxed = {
          id = 1;
          settings = relaxedSettings;
        };
      };
    };
  };
}
