# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Top navigation", type: :request do
  it "links to the seasons index for signed-out visitors" do
    get about_path

    expect(response.body).to include(%(<a href="#{seasons_path}"))
  end

  it "links to the seasons index for signed-in users" do
    post registration_path, params: {
      user: {email_address: "nav@example.com", password: "supersecret", password_confirmation: "supersecret"}
    }

    get about_path

    expect(response.body).to include(%(<a href="#{seasons_path}"))
  end
end
