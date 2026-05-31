# frozen_string_literal: true

class Views::Layouts::Application < Views::Base
  include Phlex::Rails::Helpers::CSRFMetaTags
  include Phlex::Rails::Helpers::CSPMetaTag
  include Phlex::Rails::Helpers::StylesheetLinkTag
  include Phlex::Rails::Helpers::JavascriptImportmapTags
  include Phlex::Rails::Helpers::Flash
  include Phlex::Rails::Helpers::ButtonTo
  include Components::Helpers::CurrentUser

  def initialize(title: "Team Draft", turbo_cache_control: nil)
    @title = title
    @turbo_cache_control = turbo_cache_control
  end

  def view_template(&)
    doctype
    html(lang: "en") do
      head do
        title { @title }
        meta(name: "viewport", content: "width=device-width,initial-scale=1")
        meta(name: "apple-mobile-web-app-capable", content: "yes")
        meta(name: "mobile-web-app-capable", content: "yes")
        meta(name: "turbo-refresh-method", content: "morph")
        meta(name: "turbo-refresh-scroll", content: "preserve")
        if @turbo_cache_control
          meta(name: "turbo-cache-control", content: @turbo_cache_control)
        end
        csrf_meta_tags
        csp_meta_tag
        stylesheet_link_tag :tailwind, data_turbo_track: "reload"
        javascript_importmap_tags
      end
      body(class: "min-h-screen flex flex-col bg-base-200 text-base-content") do
        render_nav
        div(class: "mx-auto w-full max-w-3xl px-4 flex-1") do
          render_flash
          yield
        end
        render_footer
      end
    end
  end

  private

  def render_nav
    div(class: "bg-base-100 shadow-sm border-b border-base-300") do
      div(class: "navbar mx-auto w-full max-w-3xl px-4") do
        div(class: "navbar-start") do
          a(href: root_path, class: "btn btn-ghost text-xl normal-case") { "Team Draft" }
        end
        div(class: "navbar-end") do
          render_nav_auth
        end
      end
    end
  end

  def render_nav_auth
    user = current_user
    if user
      div(class: "flex items-center gap-1") do
        a(href: root_path, class: "btn btn-ghost btn-sm") { "Leagues" }
        a(href: about_path, class: "btn btn-ghost btn-sm") { "About" }
        render_user_menu(user)
      end
    else
      div(class: "flex items-center gap-1") do
        a(href: about_path, class: "btn btn-ghost btn-sm") { "About" }
        a(href: new_session_path, class: "btn btn-ghost btn-sm") { "Sign in" }
      end
    end
  end

  def render_user_menu(user)
    div(class: "dropdown dropdown-end") do
      div(tabindex: 0, role: "button", class: "btn btn-ghost btn-circle", aria_label: "Account menu") do
        render Views::Components::Icon.new(:user_circle, class_name: "size-6")
      end
      ul(tabindex: 0, class: "menu menu-sm dropdown-content bg-base-100 rounded-box z-1 mt-3 w-56 p-2 shadow") do
        li(class: "menu-title") { span { user.email_address } }
        li { a(href: rankings_path) { "My Rankings" } }
        if user.admin?
          li { a(href: admin_root_path) { "Admin" } }
        end
        li do
          a(href: session_path, data: {turbo_method: :delete}) { "Sign out" }
        end
      end
    end
  end

  def render_footer
    footer(class: "mt-12 py-6 text-sm text-base-content/60 border-t border-base-300") do
      div(class: "mx-auto w-full max-w-3xl px-4 flex flex-wrap items-center justify-between gap-3") do
        div(class: "flex flex-wrap items-center gap-x-4 gap-y-1") do
          a(href: privacy_path, class: "link link-hover") { "Privacy" }
        end
        a(
          href: "https://github.com/coat/teamdraft",
          class: "link link-hover inline-flex items-center gap-1",
          target: "_blank",
          rel: "noopener"
        ) { "github.com/coat/teamdraft" }
      end
    end
  end

  def render_flash
    notice = flash[:notice]
    alert = flash[:alert]
    return if notice.blank? && alert.blank?
    div(class: "mt-4 space-y-2", role: "status") do
      if notice.present?
        div(class: "alert alert-success") { p { notice } }
      end
      if alert.present?
        div(class: "alert alert-warning") { p { alert } }
      end
    end
  end
end
