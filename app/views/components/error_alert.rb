# frozen_string_literal: true

# Renders model validation errors (or any pre-built message list) as a
# daisyUI `alert-error` block with a disc-bulleted list.
#
# Pass `messages:` directly, or `records:` to merge `errors.full_messages`
# from one or more ActiveModel-ish objects (nils are skipped).
#
# Renders nothing if the message list is empty, so callers don't need to
# guard with `errors.any?` themselves.
class Views::Components::ErrorAlert < Views::Base
  # The id lets invalid fields point here via aria-describedby.
  def initialize(messages: nil, records: nil, class_name: nil, id: "form-errors")
    @messages = build_messages(messages, records)
    @class_name = class_name
    @id = id
  end

  def view_template
    return if @messages.empty?
    div(id: @id, class: alert_classes, role: "alert") do
      ul(class: "list-disc list-inside") do
        @messages.each { |msg| li { msg } }
      end
    end
  end

  private

  def build_messages(messages, records)
    return Array(messages) if messages
    Array(records).flat_map { |r| r&.errors&.full_messages || [] }
  end

  def alert_classes
    ["alert alert-error", @class_name].compact.join(" ")
  end
end
