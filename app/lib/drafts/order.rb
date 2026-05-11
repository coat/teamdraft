# frozen_string_literal: true

module Drafts
  # Maps a 1-indexed pick number to the 1-indexed draft_position whose turn
  # it is. Pure function; depends only on size + style.
  module Order
    module_function

    def position_for(pick_number:, size:, style:)
      raise ArgumentError, "pick_number must be >= 1" if pick_number < 1
      raise ArgumentError, "size must be >= 2" if size < 2

      zero_pick = pick_number - 1
      round = zero_pick / size
      pos_in_round = zero_pick % size

      index =
        if style == "snake" && round.odd?
          size - 1 - pos_in_round
        else
          pos_in_round
        end

      index + 1
    end
  end
end
