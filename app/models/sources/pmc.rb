class Pmc < Source
  def get_query_url(work)
    return {} unless work.doi.present?
    fail ArgumentError, "Source url is missing." if url.blank?

    url % { doi: work.doi_escaped }
  end

  def parse_data(result, work, options={})
    # properly handle not found errors
    result = { 'data' => [] } if result[:status] == 404

    return result if result[:error]

    extra = Array(result["views"])
    html = get_sum(extra, 'full-text')
    pdf = get_sum(extra, 'pdf')
    total = html + pdf
    events_url = total > 0 ? get_events_url(work) : nil

    { events: {
        source: name,
        work: work.pid,
        pdf: pdf,
        html: html,
        total: total,
        events_url: events_url,
        extra: extra,
        months: get_events_by_month(extra) } }
  end

  def get_events_by_month(extra)
    extra.map do |event|
      html = event['full-text'].to_i
      pdf = event['pdf'].to_i

      { month: event['month'].to_i,
        year: event['year'].to_i,
        html: html,
        pdf: pdf,
        total: html + pdf }
    end
  end

  def process_feed(month, year, options={})
    raise ArgumentError("Missing: month") unless month.present?
    raise ArgumentError("Missing: year") unless year.present?

    publisher_configs.each do |publisher|
      publisher_id = publisher[0]
      journals = publisher[1].journals.to_s.split(" ")

      journals.each do |journal|
        PmcJob.perform_later(publisher_id, month, year, journal, options)
        Rails.logger.info "Queueing pmc import for #{journal}, month #{month}, and year #{year} [#{options}]"
      end
    end
    publisher_configs.map { |publisher| publisher[0] }
  end

  # Retrieve usage stats in XML and store in /tmp/files directory
  def get_feed(publisher_id, month, year, journal, options={})
    # check that we have publisher-specific configuration
    pc = publisher_config(publisher_id)
    if pc.username.nil? || pc.password.nil?
      Rails.logger.warn "Username and password required for PMC source (publisher_id=#{publisher_id})"
    end

    data = { year: year, month: month, jrid: journal, user: pc.username, password: pc.password }.map{|k,v| "#{k}=#{v}"}.join('&')

    filename = "pmcstat_#{journal}_#{month}_#{year}.xml"

    save_to_file(feed_url, filename, options.merge(
      data: data,
      headers: { "Content-Type" => "application/x-www-form-urlencoded;charset=UTF-8" }))
  end

  # Parse usage stats and store in CouchDB. Returns an empty array if no error occured
  def parse_feed(publisher_id, month, year, journal, options={})
    filename = "pmcstat_#{journal}_#{month}_#{year}.xml"
    file = File.open("#{Rails.root}/tmp/files/#{filename}", 'r') { |f| f.read }
    document = Nokogiri::XML(file)

    if document.xpath("//article").count == 0
      message = "PMC Usage stats for journal #{journal}, month #{month} and year #{year}: no article nodes found. *** SKIPPED ***"
      Alert.where(message: message).where(unresolved: true).first_or_create(
        :exception => "",
        :class_name => "PmcDataError",
        :status => 500,
        :source_id => id)
      nil
    else
      # go through all the works in the xml document
      document.xpath("//article").each do |work|
        response = parse_work(work, month, year)
        next unless response[:doi].present?

        save_work(response[:doi], response[:data])
      end
      filename
    end
  end

  def parse_work(work, month, year)
    work = work.to_hash
    work = work["article"]

    doi = work.fetch("meta-data", {}).fetch("doi", nil)
    # sometimes doi metadata are missing
    return { doi: nil, data: nil } unless doi.present?

    view = work["usage"]
    view['year'] = year.to_s
    view['month'] = month.to_s

    # try to get the existing information about the given work
    data = get_result(url_db + CGI.escape(doi))

    if data['views'].nil?
      data = { 'views' => [view] }
    else
      # update existing entry
      data['views'].delete_if { |view| view['month'] == month.to_s && view['year'] == year.to_s }
      data['views'] << view
    end
    { doi: doi, data: data }
  end

  def save_work(doi, data)
    save_lagotto_data(url_db + CGI.escape(doi), data: data)
  end

  def put_database
    put_lagotto_data(url_db)
  end

  def get_events_url(work)
    events_url % { :pmcid => work.pmcid } if work.pmcid.present?
  end

  def url
    url_db + "%{doi}"
  end

  def config_fields
    [:url_db, :feed_url, :events_url, :journals, :username, :password]
  end

  def feed_url
    "https://www.ncbi.nlm.nih.gov/pmc/utils/publisher/pmcstat/pmcstat.cgi"
  end

  def events_url
    "http://www.ncbi.nlm.nih.gov/pmc/works/PMC%{pmcid}"
  end

  def cron_line
    config.cron_line || "0 5 9 * *"
  end

  def by_publisher?
    true
  end
end
