# frozen_string_literal: true

module Positions
  module Importing
    class BaseService
      prepend BasicService

      private

      def set_initial_values
        @positions = []
      end

      def set_header_indeces
        @header_indeces = {
          external_id:    0,
          operation_date: 0,
          operation:      0,
          ticker:         0,
          price:          0,
          price_currency: 0,
          amount:         0
        }
      end

      def parse_xls_file(data_sheet_index:)
        @file.open do |file|
          rows = read_xls_file_rows(file, data_sheet_index)
          break unless rows

          parse_rows(rows)
        end
      end

      def read_xls_file_rows(file, data_sheet_index)
        case File.extname(file).downcase
        when '.xlsx' then Creek::Book.new(file).sheets[data_sheet_index].rows
        when '.xls' then Roo::Excel.new(file).sheet(data_sheet_index)
        end
      end

      def save_positions
        @positions.each do |position|
          next if position_exist?(position[:external_id])

          quote =
            Quote
            .joins(:security)
            .where(price_currency: position[:price_currency])
            .where(securities: { ticker: position[:ticker] })
            .first
          next unless quote

          attrs = { portfolio: @portfolio, quote: quote }
          attrs = attrs.merge(
            position.slice(:price, :price_currency, :amount, :operation, :operation_date, :external_id)
          )
          Positions::CreateService.call(attrs)
        end
      end

      def position_exist?(external_id)
        @portfolio.positions.exists?(external_id: external_id)
      end
    end
  end
end
