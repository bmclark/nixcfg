# Firefox: privacy-focused primary browser with Dracula theming.
# Two profiles: "default" (hardened, daily driver) and "relaxed" (for sites that break).
# Cross-platform (NixOS + macOS).
#
# Extensions are installed as pinned Nix packages from NUR
# (pkgs.nur.repos.rycee.firefox-addons) rather than as force_installed
# enterprise-policy .xpi downloads. This makes them reproducible and
# offline-capable: the exact extension build comes from the Nix store,
# not a runtime fetch from addons.mozilla.org on first launch.
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.features.desktop.firefox;

  addons = pkgs.nur.repos.rycee.firefox-addons;

  # Installed on both profiles.
  #
  # tampermonkey: installs declaratively, but userscripts (e.g. 4chan X) live
  # in Tampermonkey's own internal script storage, which uses an undocumented,
  # version-dependent format -- not something to hand-write JSON for and risk
  # silently corrupting. One-time manual step after first rebuild: open the
  # Tampermonkey dashboard and install https://www.4chan-x.net/builds/4chan-X.user.js
  # (Utilities > Import from URL, or just visit the URL directly and click
  # Install). Tampermonkey handles auto-updates for it after that.
  sharedExtensionPackages = with addons; [
    ublock-origin
    privacy-badger
    bitwarden
    dracula-dark-colorscheme
    darkreader
    xbrowsersync
    multi-account-containers
    facebook-container
    tampermonkey
    temporary-containers # auto-containerizes anything not explicitly assigned
    sponsorblock
    consent-o-matic
    reddit-enhancement-suite
    old-reddit-redirect # RES's features are built for/work best on old Reddit
    stylus
  ];

  # Installed only on the hardened "default" profile: these are the ones
  # most likely to break sites, which is exactly what the "relaxed"
  # profile exists to avoid. skip-redirect joins clearurls here since
  # rewriting redirect chains carries the same breakage risk (e.g. OAuth
  # login flows).
  hardenedOnlyExtensionPackages = with addons; [
    localcdn
    clearurls
    cookie-autodelete
    canvasblocker
    skip-redirect
  ];

  # ExtensionSettings' "*".installation_mode = "blocked" below doesn't just
  # block *new* manual installs from about:addons -- it actively uninstalls
  # any extension already present that has no explicit per-ID entry,
  # including our own Nix-managed ones. Each declared extension needs an
  # explicit "allowed" entry (derived from its addonId passthru) so the
  # wildcard block only catches ad-hoc installs, not these.
  allowedExtensionSettings = listToAttrs (map
    (pkg: nameValuePair pkg.addonId {installation_mode = "allowed";})
    (sharedExtensionPackages ++ hardenedOnlyExtensionPackages));

  # Multi-Account Containers identities, declared via containers.json.
  # Defined on both profiles so container isolation is consistent
  # regardless of which profile you're browsing in.
  containers = {
    Personal = {
      id = 1;
      color = "blue";
      icon = "fingerprint";
    };
    Work = {
      id = 2;
      color = "orange";
      icon = "briefcase";
    };
    Banking = {
      id = 3;
      color = "green";
      icon = "dollar";
    };
    Shopping = {
      id = 4;
      color = "pink";
      icon = "cart";
    };
    Reddit = {
      id = 5;
      color = "turquoise";
      icon = "circle";
    };
    "4chan" = {
      id = 6;
      color = "purple";
      icon = "chill";
    };
  };

  # DuckDuckGo as default search engine (app-provided, no custom engine
  # definition needed).
  search = {
    force = true;
    default = "ddg";
    order = ["ddg"];
  };

  # Toolbar layout: pin uBlock Origin, Bitwarden, Multi-Account Containers,
  # and Dark Reader (frequently toggled per-site) in that order; everything
  # else lives in the extensions overflow menu. Widget IDs are derived from
  # each extension's addon ID via Firefox's makeWidgetId() (lowercase, non
  # [a-z0-9_-] chars -> "_").
  #
  # This pref is somewhat fragile across Firefox versions -- if the pinned
  # icons don't come out exactly right after first launch, right-click the
  # toolbar -> "Customize Toolbar" to fix manually.
  uiCustomizationState = builtins.toJSON {
    placements = {
      nav-bar = [
        "back-button"
        "forward-button"
        "stop-reload-button"
        "home-button"
        "customizableui-special-spring1"
        "urlbar-container"
        "customizableui-special-spring2"
        "ublock0_raymondhill_net-browser-action" # uBlock Origin
        "_446900e4-71c2-419f-a6a7-df9c091e268b_-browser-action" # Bitwarden
        "_testpilot-containers-browser-action" # Multi-Account Containers
        "addon_darkreader_org-browser-action" # Dark Reader
        "unified-extensions-button"
        "downloads-button"
      ];
    };
    currentVersion = 21;
    newElementCount = 0;
  };

  # Settings shared by both profiles: toolbar/UI layout, general browsing
  # behavior, and the pref that lets Nix-installed extensions self-enable
  # without a manual about:addons click after first switch.
  sharedUiSettings = {
    "extensions.autoDisableScopes" = 0;
    "browser.uidensity" = 1; # compact
    "browser.uiCustomization.state" = uiCustomizationState;

    # Dracula as the active browser chrome theme.
    "extensions.activeThemeID" = "{b743f56d-1cc1-4048-8ba6-f9c2ab7aa54d}";

    # Startup: restore the previous session, but Home/Ctrl+Home and new
    # tabs are blank rather than Firefox's curated/sponsored content.
    "browser.startup.page" = 3;
    "browser.startup.homepage" = "about:blank";
    "browser.newtabpage.enabled" = false;

    # Downloads: auto-save to ~/Downloads, no per-file prompt.
    "browser.download.folderList" = 1;
    "browser.download.useDownloadDir" = true;

    # PDFs open in Firefox's built-in viewer.
    "pdfjs.disabled" = false;

    # Tabs: new tabs (incl. Ctrl+T, not just links) open next to the
    # current tab; Ctrl+Tab cycles most-recently-used instead of visual
    # order, with preview thumbnails; warn before closing multiple tabs.
    "browser.tabs.insertAfterCurrent" = true;
    "browser.ctrlTab.sortByRecentlyUsed" = true;
    "browser.ctrlTab.previews" = true;
    "browser.tabs.warnOnClose" = true;

    # Global Privacy Control: legally-recognized "do not sell/share my
    # data" signal (honored in CA, CO, CT, and others).
    "privacy.globalprivacycontrol.enabled" = true;

    # Address/payment-card autofill disabled -- Bitwarden is the source of
    # truth for that data too. Form history (separate pref) is already off
    # in the hardened settings below.
    "extensions.formautofill.addresses.enabled" = false;
    "extensions.formautofill.creditCards.enabled" = false;

    # Auto-reject cookie consent banners where Firefox can detect and
    # handle them; falls back to showing the banner normally otherwise.
    "cookiebanners.service.mode" = 1;
    "cookiebanners.service.mode.privateBrowsing" = 1;

    # DRM (Widevine) left at Firefox's default (enabled) -- streaming
    # sites (Netflix, Spotify web player, etc.) need it to play video.
    # media.eme.enabled intentionally left unset.
  };

  # Declarative bookmarks scaffold (currently empty/unused).
  # Bookmark content is personal and intentionally left undeclared here --
  # fill in `settings` below and flip `force = true` when ready:
  #
  # bookmarks = {
  #   force = true;
  #   settings = [
  #     {
  #       name = "Example folder";
  #       toolbar = true;
  #       bookmarks = [
  #         { name = "Example"; url = "https://example.com"; }
  #       ];
  #     }
  #   ];
  # };

  # Arkenfox-inspired hardening settings (medium-heavy)
  # These go on the "default" hardened profile.
  hardenedSettings =
    sharedUiSettings
    // {
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

      # --- Referrer trimming (arkenfox-style) ---
      "network.http.referer.XOriginPolicy" = 2; # only send referrer when hosts match
      "network.http.referer.XOriginTrimmingPolicy" = 2; # cross-origin referrer = origin only

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
  relaxedSettings =
    sharedUiSettings
    // {
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
        # Bitwarden is the single source of truth for saved logins.
        PasswordManagerEnabled = false;
        OverrideFirstRunPage = "";
        OverridePostUpdatePage = "";
        DontCheckDefaultBrowser = true;
        DisplayBookmarksToolbar = "always";
        DisplayMenuBar = "default-off";
        SearchBar = "unified";

        # Block ad-hoc/manual extension installs from about:addons; the
        # extensions actually in use are installed declaratively below via
        # profiles.<name>.extensions.packages. Each of those needs its own
        # "allowed" entry here too, or Firefox uninstalls it on startup for
        # matching the wildcard block (see allowedExtensionSettings above).
        ExtensionSettings =
          {
            "*".installation_mode = "blocked";
          }
          // allowedExtensionSettings;
      };

      # ---- PROFILES ----
      profiles = {
        # Hardened daily driver with arkenfox-style settings
        default = {
          id = 0;
          isDefault = true;
          settings = hardenedSettings;
          inherit search containers;
          # Multi-Account Containers rewrites containers.json itself (e.g.
          # self-healing internal UUIDs), replacing the Nix-managed symlink
          # with a plain file. Without this, home-manager tries to back
          # that up on the next switch and can fail if a stale backup from
          # a previous activation already exists at that path.
          containersForce = true;
          extensions.packages = sharedExtensionPackages ++ hardenedOnlyExtensionPackages;
        };

        # Relaxed profile for sites that break under heavy hardening
        # Launch with: firefox -P relaxed
        relaxed = {
          id = 1;
          settings = relaxedSettings;
          inherit search containers;
          containersForce = true;
          extensions.packages = sharedExtensionPackages;
        };
      };
    };
  };
}
