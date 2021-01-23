# frozen_string_literal: true

class Quote < ApplicationRecord
  include Sourceable

  ThinkingSphinx::Callbacks.append(self, behaviours: [:real_time])

  belongs_to :security

  has_many :positions,
           class_name: 'Users::Position',
           inverse_of: :quote,
           dependent:  :destroy

  has_many :coupons, class_name: 'Bonds::Coupon', inverse_of: :quote, dependent: :destroy
end
