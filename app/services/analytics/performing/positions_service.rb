# frozen_string_literal: true

module Analytics
  module Performing
    class PositionsService
      prepend BasicService

      def call(user:, portfolio_ids:, exchange_rates:, options: {})
        @exchange_rates = exchange_rates
        @options        = options

        fetch_positions(user)
        filter_positions(portfolio_ids)
        perform_analytics
      end

      private

      def fetch_positions(user)
        @positions = Positions::Fetching::ForAnalyticsService.new.call(user: user)
      end

      def filter_positions(portfolio_ids)
        @positions =
          @positions
          .buying
          .where(portfolio: portfolio_ids)
          .with_unsold_securities
          .includes(:quote)
      end

      def perform_analytics
        @result = @positions.group_by(&:quote).each_with_object(default_stats) do |(quote, positions), acc|
          perform_real_positions_calculation(quote, positions.reject(&:plan), acc)
          perform_plan_positions_calculation(quote, positions.find(&:plan), acc)
        end
      end

      def perform_real_positions_calculation(quote, positions, acc)
        return if positions.empty?

        stats = perform_calculation(quote, positions)
        update_total_stats(acc, quote, stats)
        update_security_stats(acc, quote, stats)
      end

      # rubocop: disable Metrics/AbcSize
      # rubocop: disable Metrics/MethodLength
      def perform_plan_positions_calculation(quote, position, acc)
        return if position.nil?

        security_symbol = security_symbol(quote)
        currency_symbol = quote_currency_symbol(quote)
        selling_total_price = position.amount * position.price
        dividents = dividents_amount_price(quote, position.amount)

        acc[security_symbol][:plans][quote.id] = {
          plan:                   true,
          amount:                 position.amount,
          price:                  position.price,
          selling_total_price:    selling_total_price,
          dividents_amount_price: dividents,
          position_id:            position.id
        }
        acc[security_symbol][:plans][quote.id][:quote] = {
          security_name:         quote.security.name[I18n.locale.to_s],
          security_sector:       quote.security.sector&.name ? quote.security.sector.name[I18n.locale.to_s] : nil,
          security_sector_color: quote.security.sector&.color,
          price:                 quote.price,
          price_currency:        quote.price_currency,
          face_value_cents:      quote.face_value_cents
        }
        acc[security_symbol][:plan][:price] += selling_total_price * @exchange_rates[currency_symbol]
        acc[security_symbol][:plan][:dividents] += dividents * @exchange_rates[currency_symbol]
      end
      # rubocop: enable Metrics/AbcSize
      # rubocop: enable Metrics/MethodLength

      def perform_calculation(quote, positions)
        calculate_basis_stats(positions)
          .then { |stats| calculate_selling_stats(quote, stats) }
      end

      def calculate_basis_stats(positions)
        positions.each_with_object(basis_stats) do |position, acc|
          next update_selling_stats(acc, position) if position.selling_position?

          update_buying_stats(acc, position)
        end
      end

      def update_selling_stats(acc, position)
        acc[:selling_sold_price] += position.amount * position.price
      end

      def update_buying_stats(acc, position)
        unsold_amount = position.amount - position.sold_amount
        acc[:unsold_amount]       += unsold_amount
        acc[:buying_unsold_price] += unsold_amount * position.price
      end

      # rubocop: disable Metrics/AbcSize
      def calculate_selling_stats(quote, stats)
        # selling price for unsold securities
        selling_unsold_price = quote.price * stats[:unsold_amount]
        # selling price for unsold securities + selling price for sold securities
        selling_total_price  = selling_unsold_price + stats[:selling_sold_price]
        # difference between selling and buying price of unsold securities
        selling_unsold_income_price = selling_unsold_price - stats[:buying_unsold_price]
        # average prices
        buying_unsold_average_price =
          stats[:unsold_amount].zero? ? 0 : (stats[:buying_unsold_price].to_f / stats[:unsold_amount]).round(4)
        exchange_profit =
          buying_unsold_average_price.zero? ? 0 : ((quote.price / buying_unsold_average_price - 1) * 100).round(2)

        stats.merge(
          selling_unsold_price:        selling_unsold_price,
          selling_total_price:         selling_total_price,
          dividents_amount_price:      dividents_amount_price(quote, stats[:unsold_amount]),
          selling_unsold_income_price: selling_unsold_income_price,
          buying_unsold_average_price: buying_unsold_average_price,
          exchange_profit:             exchange_profit
        )
      end

      def dividents_amount_price(quote, unsold_amount)
        return (quote.average_year_dividents_amount.to_f * unsold_amount).round(2) if quote.security.is_a?(Share)
        return 0 if quote.security.is_a?(Foundation)

        quote.coupons_sum_for_time_range * unsold_amount
      end

      def update_total_stats(acc, quote, stats)
        currency_symbol = quote_currency_symbol(quote)

        acc[:total][:summary][:price] += stats[:selling_total_price] * @exchange_rates[currency_symbol]
        acc[:total][:summary][:price] += stats[:dividents_amount_price] * @exchange_rates[currency_symbol]
      end

      def update_security_stats(acc, quote, stats)
        security_symbol = security_symbol(quote)
        currency_symbol = quote_currency_symbol(quote)

        acc[security_symbol][:stats][quote.id] = stats
        acc[security_symbol][:stats][quote.id][:quote] = {
          security_name:         quote.security.name[I18n.locale.to_s],
          security_sector:       quote.security.sector&.name ? quote.security.sector.name[I18n.locale.to_s] : nil,
          security_sector_color: quote.security.sector&.color,
          price:                 quote.price,
          price_currency:        quote.price_currency,
          face_value_cents:      quote.face_value_cents
        }
        acc[security_symbol][:total][:buy_price] += stats[:buying_unsold_price] * @exchange_rates[currency_symbol]
        acc[security_symbol][:total][:price] += stats[:selling_total_price] * @exchange_rates[currency_symbol]
        acc[security_symbol][:total][:dividents] += stats[:dividents_amount_price] * @exchange_rates[currency_symbol]
      end
      # rubocop: enable Metrics/AbcSize

      def quote_currency_symbol(quote)
        quote.price_currency.to_sym
      end

      def security_symbol(quote)
        quote.security.type.downcase.to_sym
      end

      def default_stats
        {
          share:      default_security_hash,
          foundation: default_security_hash,
          bond:       default_security_hash,
          total:      { summary: { price: 0 } }
        }
      end

      def default_security_hash
        {
          stats: {},
          plans: {},
          total: {
            buy_price: 0,
            price:     0,
            dividents: 0
          },
          plan:  {
            price:     0,
            dividents: 0
          }
        }
      end

      def basis_stats
        {
          unsold_amount:       0, # unsold amount of securities
          buying_unsold_price: 0, # buying total price of unsold securities
          selling_sold_price:  0 # selling total price of sold securities
        }
      end
    end
  end
end