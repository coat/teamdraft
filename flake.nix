{
  description = "Teamdraft website development environment";

  nixConfig = {
    extra-substituters = "https://nixpkgs-ruby.cachix.org";
    extra-trusted-public-keys = "nixpkgs-ruby.cachix.org-1:vrcdi50fTolOxWCZZkw0jakOnUI1T19oYJ+PRYdK4SM=";
  };

  inputs = {
    nixpkgs.url = "nixpkgs";
    nixpkgs-ruby.url = "github:bobvanderlinden/nixpkgs-ruby";
    nixpkgs-ruby.inputs.nixpkgs.follows = "nixpkgs";
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
    services-flake.url = "github:juspay/services-flake";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-ruby,
    process-compose-flake,
    services-flake,
  }: let
    appName = "teamdraft";
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
  in
    builtins.foldl' nixpkgs.lib.recursiveUpdate {} (
      builtins.map (
        system: let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [nixpkgs-ruby.overlays.default];
          };

          rubyVersion = builtins.head (builtins.match "(.*)\n" (builtins.readFile ./.ruby-version));
          ruby = pkgs.${rubyVersion};

          rubyEnvSetup = ''
            export BUNDLE_PATH="$PWD/.direnv/state/.bundle"
            export GEM_HOME="$BUNDLE_PATH/${ruby.rubyEngine}/${ruby.version.libDir}"
            export GEM_PATH="$GEM_HOME/gems:''${GEM_PATH:-}"
            export PATH="$GEM_HOME/bin:$PATH"
          '';

          servicesModule = {
            services.postgres."pg" = {
              enable = true;
              socketDir = "./tmp/pg";
              dataDir = "./tmp/pg/data";
              listen_addresses = "127.0.0.1";
              initialDatabases = [
                {name = "${appName}_development";}
                {name = "${appName}_test";}
              ];
            };
          };

          # Rails server + Tailwind CSS watcher depend on pg being healthy.
          # Kept separate from `servicesModule` so `nix run .#services` can
          # bring up only the backing services (for devs running `bin/dev`
          # standalone).
          railsModule = {
            settings.processes.rails = {
              command = ''
                ${rubyEnvSetup}
                ${ruby}/bin/bundle check >/dev/null || ${ruby}/bin/bundle install
                exec ${ruby}/bin/bundle exec rails server -b 0.0.0.0
              '';
              # libpq treats PGHOST as a hostname unless it starts with `/`,
              # so pass TCP here (postgres listens on 127.0.0.1 too). The
              # devShell shellHook sets PGHOST to the absolute socket dir
              # for interactive `psql`/`bin/dev` use.
              environment = {
                PGHOST = "127.0.0.1";
                TAILWINDCSS_INSTALL_DIR = "${pkgs.tailwindcss_4}/bin";
              };
              depends_on."pg".condition = "process_healthy";
            };
            settings.processes.tailwind = {
              command = ''
                ${rubyEnvSetup}
                exec ${ruby}/bin/bundle exec rails tailwindcss:watch
              '';
              environment.TAILWINDCSS_INSTALL_DIR = "${pkgs.tailwindcss_4}/bin";
            };

            settings.processes.jobs = {
              command = ''
                ${rubyEnvSetup}
                exec ${ruby}/bin/bundle exec rails solid_queue:start
              '';
              environment.PGHOST = "127.0.0.1";
              depends_on."pg".condition = "process_healthy";
            };
          };

          evalServices = extraModules:
            (import process-compose-flake.lib {inherit pkgs;}).evalModules {
              modules =
                [
                  services-flake.processComposeModules.default
                  servicesModule
                ]
                ++ extraModules;
            };

          servicesMod = evalServices [];
          devMod = evalServices [railsModule];
        in {
          # `nix run .#`         -> full stack (services + rails)
          # `nix run .#services` -> backing services only (postgres);
          #                        run `bin/dev` separately for the app.
          packages.${system} = {
            default = devMod.config.outputs.package;
            services = servicesMod.config.outputs.package;
          };

          devShells.${system}.default = pkgs.mkShell {
            inputsFrom = [
              servicesMod.config.services.outputs.devShell
            ];
            buildInputs =
              [
                ruby
              ]
              ++ (with pkgs; [
                # Native-extension build deps for `bundle install`: psych
                # needs libyaml, pg needs libpq when built from source.
                pkg-config
                libyaml
                libpq
                tailwindcss_4
              ]);
            shellHook = ''
              ${rubyEnvSetup}
              bundle check >/dev/null 2>&1 || bundle install
              mkdir -p ./tmp/pg
              export PGHOST="$PWD/tmp/pg"
              export PGDATABASE="${appName}_development"

              # Point tailwindcss-rails at the Tailwind CLI from nixpkgs.
              # The tailwindcss-ruby gem ships a Bun-compiled single-file
              # executable that expects an FHS system and won't run on
              # NixOS; nixpkgs builds Tailwind v4 for our glibc target.
              export TAILWINDCSS_INSTALL_DIR="${pkgs.tailwindcss_4}/bin"
            '';
          };
        }
      )
      systems
    );
}
