# frozen_string_literal: true

class Views::Passwords::Edit < Views::Base
  include Phlex::Rails::Helpers::FormWith

  def initialize(token:)
    @token = token
  end

  def view_template
    render Views::Layouts::Application.new(title: "Choose a new password") do
      main(class: "py-8") do
        div(class: "card bg-base-100 shadow max-w-md mx-auto") do
          div(class: "card-body") do
            h1(class: "card-title text-2xl") { "Choose a new password" }
            form_with(url: password_path(@token), method: :patch, class: "space-y-3 mt-2") do |form|
              field(form, :password, "New password",
                required: true, autofocus: true, autocomplete: "new-password")
              field(form, :password_confirmation, "Confirm password",
                required: true, autocomplete: "new-password")
              div(class: "card-actions justify-end pt-2") do
                form.submit "Update password", class: "btn btn-primary"
              end
            end
          end
        end
      end
    end
  end

  private

  def field(form, name, label, **opts)
    div(class: "space-y-1") do
      form.label name, label, class: "label label-text font-medium"
      form.password_field name, class: "input w-full", **opts
    end
  end
end
