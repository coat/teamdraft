# frozen_string_literal: true

# Renders the per-event scoring breakdown shown inside row-level disclosure
# panels on the league standings (`Views::Leagues::Show`) and season
# standings (`Views::Seasons::Show`) tables. Labels come from the sport's
# ScoringRule#label column so each sport renders with its own terminology
# (e.g. "World Series appearance" vs "Super Bowl appearance").
module Views::Components::ScoringBreakdownHelpers
  # Invoice-style layout: each line is right-aligned so the point values
  # land flush with the table's Points column. `tabular-nums` keeps the
  # digit widths consistent down the column; `w-10` reserves a fixed
  # value gutter so two- and one-digit totals line up.
  def render_scoring_breakdown(rules, events)
    nonzero = events.reject { |_, points| points.zero? }
    if nonzero.empty?
      p(class: "text-sm text-base-content/70 py-2 text-right") { "No scoring yet." }
    else
      div(class: "py-2 text-sm space-y-1") do
        rules.ordered_rules.each do |rule|
          points = nonzero[rule.event_type]
          next unless points
          div(class: "flex items-baseline justify-end gap-3") do
            span(class: "opacity-70") { rule.label }
            span(class: "font-mono tabular-nums w-10 text-right") { points.to_s }
          end
        end
      end
    end
  end
end
