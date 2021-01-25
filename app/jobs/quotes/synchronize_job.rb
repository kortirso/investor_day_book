# frozen_string_literal: true

module Quotes
  class SynchronizeJob < ApplicationJob
    queue_as :default

    private

    # skip on sunday and monday
    def skipped_day?(day_inxeces)
      Time.zone.today.wday.in?(day_inxeces)
    end
  end
end
