# frozen_string_literal: true

class Views::Registrations::New < Views::Base
  include Phlex::Rails::Helpers::FormWith

  def initialize(user:)
    @user = user
  end

  def view_template
    render Views::Layouts::Application.new(title: "Create account") do
      main(class: "py-8") do
        div(class: "card bg-base-100 shadow max-w-md mx-auto") do
          div(class: "card-body") do
            h1(class: "card-title text-2xl") { "Create your account" }
            p(class: "text-sm text-base-content/70") do
              plain "Save your seat across devices. Already have an account? "
              a(href: new_session_path, class: "link link-primary") { "Sign in" }
              plain "."
            end

            render_errors if @user.errors.any?

            form_with(model: @user, url: registration_path, scope: :user, class: "space-y-3 mt-2") do |form|
              field(form, :email_address, "Email", :email_field,
                required: true, autofocus: true, autocomplete: "email")
              field(form, :password, "Password", :password_field,
                required: true, autocomplete: "new-password", minlength: 8)
              p(class: "text-xs text-base-content/60 -mt-1") do
                plain "Please pick a unique password - don't reuse one from another site."
              end
              field(form, :password_confirmation, "Confirm password", :password_field,
                required: true, autocomplete: "new-password")
              div(class: "card-actions justify-end pt-2") do
                form.submit "Create account", class: "btn btn-primary"
              end
            end
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

  def render_errors
    div(class: "alert alert-error mt-3", role: "alert") do
      ul(class: "list-disc list-inside") do
        @user.errors.full_messages.each { |msg| li { msg } }
      end
    end
  end
end
