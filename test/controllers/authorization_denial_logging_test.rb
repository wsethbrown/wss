require "test_helper"

# B2 / S16: every Pundit denial is logged at warn with the user id, the policy
# query, and the record's class and id, so a "why can't I…" complaint can be
# traced from the logs.
class AuthorizationDenialLoggingTest < ActionDispatch::IntegrationTest
  class DenyingController < ApplicationController
    def show
      authorize Society.find(params[:id]), :update?
      head :ok
    end
  end

  def capture_log
    io = StringIO.new
    old = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = old
  end

  test "the application-wide denial handler logs user, policy and record" do
    sign_in users(:jane)
    society = societies(:whiskey_lovers) # created by john; jane cannot edit it

    log = nil
    with_routing do |set|
      set.draw do
        root to: "home#index"
        get "denying/:id", to: "authorization_denial_logging_test/denying#show"
      end
      log = capture_log { get "/denying/#{society.id}" }
    end

    assert_response :redirect
    assert_match(
      /Authorization denied: user #{users(:jane).id} SocietyPolicy#update\? on Society #{society.id} \(AuthorizationDenialLoggingTest::DenyingController#show\)/,
      log
    )
  end

  test "the societies denial handler logs user, policy and record" do
    sign_in users(:jane)
    society = societies(:whiskey_lovers)
    log = capture_log { get edit_society_path(society) }

    assert_redirected_to societies_url
    assert_match(
      /Authorization denied: user #{users(:jane).id} SocietyPolicy#edit\? on Society #{society.id} \(SocietiesController#edit\)/,
      log
    )
  end
end
