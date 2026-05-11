# frozen_string_literal: true

class Views::Sessions::New < Views::Base
  include Phlex::Rails::Helpers::FormWith

  def view_template
    render Views::Layouts::Application.new(title: "Sign in") do
      main(class: "py-8") do
        div(class: "card bg-base-100 shadow max-w-md mx-auto") do
          div(class: "card-body") do
            h1(class: "card-title text-2xl") { "Sign in" }
            form_with(url: session_path, class: "space-y-3 mt-2") do |form|
              field(form, :email_address, "Email", :email_field,
                required: true, autofocus: true, autocomplete: "email")
              field(form, :password, "Password", :password_field,
                required: true, autocomplete: "current-password")
              div(class: "card-actions justify-end pt-2") do
                form.submit "Sign in", class: "btn btn-primary"
              end
            end
            p(class: "mt-4 text-sm") {
              a(href: new_password_path, class: "link link-hover") { "Forgot password?" }
            }
          end
        end
      end
    end
  end

  private

  def field(form, name, label, type, **opts)
    div(class: "space-y-1") do
      form.label name, label, class: "label label-text font-medium"
      form.send(type, name, class: "input w-full", **opts)
    end
  end
end
