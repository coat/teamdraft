# frozen_string_literal: true

# Overrides the generated season route helpers so call sites can keep
# passing a Season object even though the route has two dynamic segments
# (/seasons/:sport_key/:year). Must be included after the routes' url
# helpers so `super` resolves to the generated helper.
module SeasonPaths
  def season_path(season, **options)
    super(sport_key: season.sport.key, year: season.year, **options)
  end

  def season_url(season, **options)
    super(sport_key: season.sport.key, year: season.year, **options)
  end

  def season_team_path(season, slug:, **options)
    super(sport_key: season.sport.key, year: season.year, slug: slug, **options)
  end

  def season_team_url(season, slug:, **options)
    super(sport_key: season.sport.key, year: season.year, slug: slug, **options)
  end
end
