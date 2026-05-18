# frozen_string_literal: true

class Views::Admin::Users::Show < Views::Base
  include Phlex::Rails::Helpers::ButtonTo
  include Components::Helpers::CurrentUser

  def initialize(user:, participants:)
    @user = user
    @participants = participants
  end

  def view_template
    render Views::Layouts::Admin.new(
      title: @user.email_address,
      section: :users,
      breadcrumbs: [["Users", admin_users_path], [@user.email_address, nil]]
    ) do
      render Views::Components::Admin::PageHeader.new(
        title: @user.email_address,
        subtitle: "Joined #{@user.created_at.strftime("%Y-%m-%d")}"
      ) do
        a(href: edit_admin_user_path(@user), class: "btn btn-sm btn-ghost") { "Edit" }
      end

      div(class: "flex flex-wrap gap-2") do
        if @user.admin?
          span(class: "badge badge-primary") { "admin" }
        end
        if @user.disabled?
          span(class: "badge badge-warning") { "disabled · #{@user.disabled_at.strftime("%Y-%m-%d")}" }
        else
          span(class: "badge badge-success") { "active" }
        end
      end

      render_actions_card
      render_related_panel
    end
  end

  private

  def render_actions_card
    div(class: "card bg-base-100 shadow") do
      div(class: "card-body") do
        h2(class: "card-title text-base") { "Account actions" }
        div(class: "flex flex-wrap gap-2") do
          render_admin_toggle
          render_disable_toggle
        end
        if @user == current_user
          p(class: "text-xs text-base-content/60 mt-2") do
            plain "You can't revoke your own admin access or disable your own account."
          end
        end
      end
    end
  end

  def render_admin_toggle
    if @user.admin?
      disabled = (@user == current_user)
      button_to "Revoke admin", revoke_admin_admin_user_path(@user),
        method: :patch,
        form: {class: "inline", data: {turbo_confirm: "Revoke admin from #{@user.email_address}?"}},
        class: "btn btn-warning btn-sm #{"btn-disabled" if disabled}",
        disabled: disabled
    else
      button_to "Grant admin", grant_admin_admin_user_path(@user),
        method: :patch,
        form: {class: "inline"},
        class: "btn btn-primary btn-sm"
    end
  end

  def render_disable_toggle
    if @user.disabled?
      button_to "Enable account", enable_admin_user_path(@user),
        method: :patch,
        form: {class: "inline"},
        class: "btn btn-success btn-sm"
    else
      disabled = (@user == current_user)
      button_to "Disable account", disable_admin_user_path(@user),
        method: :patch,
        form: {class: "inline", data: {turbo_confirm: "Disable #{@user.email_address}? They will be signed out and can't sign in until re-enabled."}},
        class: "btn btn-error btn-sm #{"btn-disabled" if disabled}",
        disabled: disabled
    end
  end

  def render_related_panel
    render Views::Components::Admin::RelatedPanel.new(title: "Leagues (#{@participants.size})") do
      if @participants.empty?
        p(class: "text-sm text-base-content/60") { "Not a participant in any league." }
      else
        ul(class: "menu bg-base-100 w-full p-0 [&_li>*]:rounded-lg") do
          @participants.each do |p|
            li do
              a(href: admin_league_path(p.league_season.league)) do
                span(class: "font-medium") { p.league_season.league.name }
                span(class: "text-xs opacity-60 ml-2") { "as #{p.display_name}#{p.is_owner ? " · owner" : ""}" }
              end
            end
          end
        end
      end
    end
  end
end
