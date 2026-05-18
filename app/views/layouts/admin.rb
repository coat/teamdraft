# frozen_string_literal: true

class Views::Layouts::Admin < Views::Base
  include Phlex::Rails::Helpers::CSRFMetaTags
  include Phlex::Rails::Helpers::CSPMetaTag
  include Phlex::Rails::Helpers::StylesheetLinkTag
  include Phlex::Rails::Helpers::JavascriptImportmapTags
  include Phlex::Rails::Helpers::Flash
  include Phlex::Rails::Helpers::ButtonTo
  include Components::Helpers::CurrentUser

  def initialize(title:, section: nil, breadcrumbs: [], turbo_cache_control: nil)
    @title = title
    @section = section
    @breadcrumbs = breadcrumbs
    @turbo_cache_control = turbo_cache_control
  end

  def view_template(&)
    doctype
    html(lang: "en", data_theme: "light") do
      head do
        title { "Admin · #{@title}" }
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
      body(class: "min-h-screen bg-base-200 text-base-content") do
        div(class: "drawer lg:drawer-open") do
          input(id: "admin-drawer", type: "checkbox", class: "drawer-toggle")
          div(class: "drawer-content flex flex-col min-h-screen") do
            render_topbar
            div(class: "mx-auto w-full max-w-7xl px-4 sm:px-6 lg:px-8 py-6 flex-1 space-y-4") do
              render_breadcrumbs
              render_flash
              yield
            end
          end
          div(class: "drawer-side z-30") do
            label(for: "admin-drawer", aria_label: "close sidebar", class: "drawer-overlay")
            render Views::Components::Admin::Sidebar.new(current_section: @section)
          end
        end
      end
    end
  end

  private

  def render_topbar
    div(class: "bg-base-100 border-b border-base-300") do
      div(class: "mx-auto w-full max-w-7xl px-4 sm:px-6 lg:px-8") do
        div(class: "navbar min-h-0 py-2") do
          div(class: "navbar-start gap-2") do
            label(for: "admin-drawer", class: "btn btn-ghost btn-sm lg:hidden", aria_label: "Open menu") do
              svg(xmlns: "http://www.w3.org/2000/svg", class: "h-5 w-5", fill: "none", viewBox: "0 0 24 24", stroke: "currentColor") do |s|
                s.path(stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M4 6h16M4 12h16M4 18h16")
              end
            end
            a(href: admin_root_path, class: "btn btn-ghost btn-sm normal-case text-base font-semibold") { "Team Draft Admin" }
          end
          div(class: "navbar-end gap-1 text-sm") do
            a(href: root_path, class: "btn btn-ghost btn-sm") { "Back to app" }
            user = current_user
            if user
              span(class: "hidden sm:inline opacity-70 px-2") { user.email_address }
              button_to "Sign out", session_path, method: :delete,
                form: {class: "inline"},
                class: "btn btn-ghost btn-sm"
            end
          end
        end
      end
    end
  end

  def render_breadcrumbs
    render Views::Components::Admin::Breadcrumbs.new(trail: @breadcrumbs)
  end

  def render_flash
    notice = flash[:notice]
    alert = flash[:alert]
    return if notice.blank? && alert.blank?
    div(class: "space-y-2", role: "status") do
      if notice.present?
        div(class: "alert alert-success") { p { notice } }
      end
      if alert.present?
        div(class: "alert alert-warning") { p { alert } }
      end
    end
  end
end
