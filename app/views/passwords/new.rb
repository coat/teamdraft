# frozen_string_literal: true

class Views::Passwords::New < Views::Base
  include Phlex::Rails::Helpers::FormWith

  def view_template
    render Views::Layouts::Application.new(title: "Reset password") do
      main(class: "py-8") do
        div(class: "card bg-base-100 shadow max-w-md mx-auto") do
          div(class: "card-body") do
            h1(class: "card-title text-2xl") { "Reset password" }
            form_with(url: passwords_path, class: "space-y-3 mt-2") do |form|
              div(class: "space-y-1") do
                form.label :email_address, "Email", class: "label label-text font-medium"
                form.email_field :email_address, required: true, autofocus: true,
                  class: "input w-full"
              end
              div(class: "card-actions justify-end pt-2") do
                form.submit "Send reset link", class: "btn btn-primary"
              end
            end
          end
        end
      end
    end
  end
end
