# frozen_string_literal: true

class Views::Admin::Users::Edit < Views::Base
  include Phlex::Rails::Helpers::FormWith

  def initialize(user:)
    @user = user
  end

  def view_template
    render Views::Layouts::Admin.new(
      title: "Edit #{@user.email_address}",
      section: :users,
      breadcrumbs: [
        ["Users", admin_users_path],
        [@user.email_address, admin_user_path(@user)],
        ["Edit", nil]
      ]
    ) do
      render Views::Components::Admin::PageHeader.new(title: "Edit user")

      div(class: "card bg-base-100 shadow") do
        div(class: "card-body") do
          if @user.errors.any?
            div(class: "alert alert-error", role: "alert") do
              ul(class: "list-disc list-inside") do
                @user.errors.full_messages.each { |m| li { m } }
              end
            end
          end

          form_with(url: admin_user_path(@user), method: :patch, scope: :user, class: "space-y-3") do |f|
            div(class: "space-y-1") do
              f.label :email_address, "Email", class: "label label-text font-medium"
              f.email_field :email_address, value: @user.email_address, required: true, class: "input input-bordered w-full"
            end
            div(class: "card-actions justify-end pt-2") do
              a(href: admin_user_path(@user), class: "btn btn-ghost") { "Cancel" }
              f.submit "Save", class: "btn btn-primary"
            end
          end
        end
      end
    end
  end
end
