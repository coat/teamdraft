{
  description = "Teamdraft website development environment";

  nixConfig = {
    extra-substituters = "https://nixpkgs-ruby.cachix.org";
    extra-trusted-public-keys = "nixpkgs-ruby.cachix.org-1:vrcdi50fTolOxWCZZkw0jakOnUI1T19oYJ+PRYdK4SM=";
  };

  inputs = {
    nixpkgs.url = "nixpkgs";
    ruby-nix.url = "github:inscapist/ruby-nix";
    nixpkgs-ruby.url = "github:bobvanderlinden/nixpkgs-ruby";
    nixpkgs-ruby.inputs.nixpkgs.follows = "nixpkgs";
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
    services-flake.url = "github:juspay/services-flake";
  };

  outputs = {
    self,
    nixpkgs,
    ruby-nix,
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

          gemset =
            if builtins.pathExists ./nix/gemset.nix
            then import ./nix/gemset.nix
            else {};

          rubyVersion = builtins.head (builtins.match "(.*)\n" (builtins.readFile ./.ruby-version));
          ruby = pkgs.${rubyVersion};

          rnPkgs = import ruby-nix.inputs.nixpkgs {
            inherit system;
            overlays = [nixpkgs-ruby.overlays.default];
          };

          rubyNix = ruby-nix.lib rnPkgs;

          gemConfig = rnPkgs.defaultGemConfig;

          rubyEnv = rubyNix {
            inherit gemset ruby;
            name = appName;
            inherit gemConfig;
          };

          # ruby-lsp env is optional: only built if nix/ruby-lsp/gemset.nix
          # exists.
          hasLspGemset = builtins.pathExists ./nix/ruby-lsp/gemset.nix;

          rubyLspEnv =
            if hasLspGemset
            then
              rubyNix {
                inherit ruby gemConfig;
                name = "${appName}-ruby-lsp";
                gemset = import ./nix/ruby-lsp/gemset.nix;
              }
            else null;

          # Wrapper that points ruby-lsp at the composed Gemfile in the
          # project tree (nix/ruby-lsp/Gemfile), so Bundler.setup sees
          # ruby-lsp + project gems together. Falls through to the
          # rubyNix-built ruby-lsp binary.
          rubyLspWrapper =
            if hasLspGemset
            then
              pkgs.writeShellScriptBin "ruby-lsp" ''
                project_root=''${RUBY_LSP_PROJECT_ROOT:-$PWD}
                composed="$project_root/nix/ruby-lsp/Gemfile"
                if [ -f "$composed" ]; then
                  export BUNDLE_GEMFILE="$composed"
                fi
                exec ${rubyLspEnv.env}/bin/ruby-lsp "$@"
              ''
            else null;

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
              command = "${rubyEnv.env}/bin/bundle exec rails server -b 0.0.0.0";
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
              command = "${rubyEnv.env}/bin/bundle exec rails tailwindcss:watch";
              environment.TAILWINDCSS_INSTALL_DIR = "${pkgs.tailwindcss_4}/bin";
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
          # `nix run .#`         → full stack (services + rails)
          # `nix run .#services` → backing services only (postgres);
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
                rubyEnv.env
              ]
              ++ nixpkgs.lib.optionals hasLspGemset [
                rubyLspWrapper
                rubyLspEnv.env
              ]
              ++ (with pkgs; [
                bundix
                tailwindcss_4
              ]);
            shellHook = ''
              mkdir -p ./tmp/pg
              # libpq env so bare `psql` (no args) connects to the dev db
              # over the project-local socket. Override via RAILS_ENV-style
              # exports if you need _test, etc.
              export PGHOST="$PWD/tmp/pg"
              export PGDATABASE="${appName}_development"
              # Point tailwindcss-rails at the system Tailwind CLI from
              # nixpkgs. The bundled tailwindcss-ruby binary (a Bun-compiled
              # single-file executable) doesn't survive Nix's auto-patchelf;
              # nixpkgs builds Tailwind v4 cleanly for our glibc target.
              export TAILWINDCSS_INSTALL_DIR="${pkgs.tailwindcss_4}/bin"
            '';
          };
        }
      )
      systems
    );
}
