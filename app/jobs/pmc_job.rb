class PmcJob < ActiveJob::Base
  queue_as :high

  def perform(publisher_id, month, year, journal, options={})
    source = Source.visible.where(name: "pmc").first
    return nil if publisher_id.nil? || month.nil? || year.nil? || journal.nil? || source.nil?

    if options == true
      dates = [{month: month, year: year}]
    else
      dates = source.date_range(month: month, year: year)
    end

    # we have to do this sequentally, as we are updating a single CouchDB document for a work for every month
    dates.each do |date|
      filename = source.get_feed(publisher_id, date[:month], date[:year], journal, options)
      source.parse_feed(publisher_id, date[:month], date[:year], journal, options) if filename.present?
    end
  end
end
