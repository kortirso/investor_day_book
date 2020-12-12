# frozen_string_literal: true

class AnalyticsController < ApplicationController
  before_action :portfolios
  before_action :positions

  def index; end

  private

  def portfolios
    @portfolios = current_user.portfolios.includes(:cashes)
    @first_portfolio_cashes = @portfolios.first.cashes.balance
  end

  def positions
    @positions = Positions::Fetching::ForAnalyticsService.call(user: current_user).result
  end
end
