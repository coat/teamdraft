# frozen_string_literal: true

class Views::Pages::Privacy < Views::Pages::Base
  def page_title = "Privacy"

  def body
    p { "This website is just for fun. I don't want to store or use any of your data other than for the functionality of this website." }
    h2 { "What we store" }
    p { "Email only if you create an optional account" }
    h2 { "What we don't" }
    p { "I don't want any analytics and don't currently have any in place other than server logs." }
  end
end
