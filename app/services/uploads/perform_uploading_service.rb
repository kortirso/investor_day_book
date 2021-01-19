# frozen_string_literal: true

module Uploads
  class PerformUploadingService
    prepend BasicService

    def call
      uploads.each { |upload| perform_upload(upload) }
    end

    private

    def uploads
      Upload
        .where(completed: false)
        .where('created_at < ?', DateTime.now - 15.seconds)
    end

    def perform_upload(upload)
      return unless upload.file.attached?

      portfolio = upload.user.portfolios.find_by(guid: upload.guid)
      return unless portfolio

      Positions::ImportService.call(
        source:    upload.source,
        file:      upload.file,
        portfolio: portfolio
      )
      upload.update(completed: true)
    rescue StandardError => e
      Bugsnag.notify(e) do |report|
        report.severity = 'error'
        report.add_tab(:upload, { id: upload.id })
      end
    end
  end
end