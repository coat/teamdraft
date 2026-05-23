# frozen_string_literal: true

# Parses "YYYY-MM-DDTHH:MM" strings from <input type="datetime-local"> using
# the browser-provided IANA timezone. Without a recognized zone, the raw
# value is returned so model-layer validation can surface the parse failure
# rather than this helper swallowing it.
module LocalDatetime
  module_function

  def parse(value, zone:)
    return nil if value.blank?
    return value if zone.blank?
    ActiveSupport::TimeZone[zone]&.parse(value) || value
  end
end
