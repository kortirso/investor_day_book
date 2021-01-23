# frozen_string_literal: true

module Analytics
  class ShareSectorsService
    prepend BasicService

    def call(stats:, plans:, exchange_rates:)
      @exchange_rates = exchange_rates

      initialize_variables
      collect_absolute_values(stats)
      collect_absolute_values(plans)
      count_relative_values
      sort_result
    end

    private

    def initialize_variables
      @result = {}
      @total_amount_price = 0
    end

    def collect_absolute_values(stats)
      stats.each do |quote, stats|
        sector = quote.security.sector
        next unless sector

        amount = amount(quote, stats)
        sector_name = sector_name(sector)

        update_total_price_counter(amount)
        next update_sector(sector_name, amount) if @result.has_key?(sector_name)

        add_sector(sector_name, sector.color, amount)
      end
    end

    def count_relative_values
      @result.each do |_key, value|
        value[:amount] = (100.0 * value[:amount] / @total_amount_price).round(2)
      end
    end

    def sort_result
      @result = @result.sort_by { |_key, value| -value[:amount] }.to_h
    end

    def update_total_price_counter(amount)
      @total_amount_price += amount
    end

    def add_sector(sector_name, sector_color, amount)
      @result[sector_name] = { color: sector_color, amount: amount }
    end

    def update_sector(sector_name, amount)
      @result[sector_name][:amount] += amount
    end

    def sector_name(sector)
      sector.name[I18n.locale.to_s]
    end

    def amount(quote, stats)
      stats[:selling_total_price] * @exchange_rates[quote.price_currency.to_sym]
    end
  end
end
