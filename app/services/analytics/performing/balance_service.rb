# frozen_string_literal: true

module Analytics
  module Performing
    class BalanceService
      prepend BasicService

      def call(portfolio_ids:, exchange_rates:)
        @portfolio_ids  = portfolio_ids
        @exchange_rates = exchange_rates
        @result         = default_stats

        perform_analytics
      end

      private

      def perform_analytics
        Portfolios::Cash.balance.where(portfolio: @portfolio_ids).each do |cash|
          currency_symbol = cash.amount_currency.to_sym
          @result[:stats][currency_symbol] += cash.amount_cents / 100
          @result[:summary_price] += cash.amount_cents * @exchange_rates[currency_symbol] / 100
        end
      end

      def default_stats
        {
          stats:         {
            RUB: 0,
            USD: 0,
            EUR: 0
          },
          summary_price: 0
        }
      end
    end
  end
end