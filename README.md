# teamdraft

Team Draft is web application to run 2-person fantasy sports leagues, where players draft entire sports teams - not players - and score points throughout the season based on wins and playoff appearances. The idea was taken from the [Mina Kimes Show's yearly NFL Team Draft](https://www.espn.com/radio/play/_/id/46093555).

Unfortunately, this is all vibe coded using Opus 4.7 (and DeepSeek V4 Pro when I get rate-limited by Anthropic) as I need to learn how to build software this way to stay employable as a software engineer. This README is written by a human, however. No AGENTS.md as I want to experiment with agentic coding without one.

## Running

This is a Ruby on Rails app using PostgreSQL. To run locally, ensure PostgreSQL is running and:

`bin/setup`

### Nix development environment

If you are using nix, there's a flake with a devShell available. Run `nix develop` or if you have direnv installed, `direnv allow`.

To run the entire app, you can just do `nix flake run .#`. If you want to run just services like postgresql, run `nix flake run .#services` and then run `bin/dev` to run rails, jobs and tailwindcss watcher in another shell.
