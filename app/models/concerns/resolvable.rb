module Resolvable
  extend ActiveSupport::Concern

  included do
    require "addressable/uri"

    def get_canonical_url(url, options = { timeout: 120 })
      conn = faraday_conn('html', options)

      response = conn.get url, {}, options[:headers]

      # Priority to find URL:
      # 1. <link rel=canonical />
      # 2. <meta property="og:url" />
      # 3. URL from header

      body = Nokogiri::HTML(response.body, nil, 'utf-8')
      body_url = body.at('link[rel="canonical"]')['href'] if body.at('link[rel="canonical"]')
      if !body_url && body.at('meta[property="og:url"]')
        body_url = body.at('meta[property="og:url"]')['content']
      end

      if body_url
        # normalize URL, e.g. remove percent encoding and make URL lowercase
        body_url = PostRank::URI.clean(body_url)

        # remove parameter used by IEEE
        body_url = body_url.sub("reload=true&", "")
      end

      url = response.env[:url].to_s
      if url
        # remove jsessionid used by J2EE servers
        url = url.gsub(/(.*);jsessionid=.*/, '\1')

        # normalize URL, e.g. remove percent encoding and make host lowercase
        url = PostRank::URI.clean(url)

        # remove parameter used by IEEE
        url = url.sub("reload=true&", "")

        # remove parameter used by ScienceDirect
        url = url.sub("?via=ihub", "")
      end

      # get relative URL
      path = URI.split(url)[5]

      # we will raise an error if 1. or 2. doesn't match with 3. as this confuses Facebook
      if body_url.present? && ![url, path].include?(body_url)
        options[:doi_mismatch] = true
        response.env[:message] = "Canonical URL mismatch: #{body_url} for #{url}"
        fail Faraday::ResourceNotFound, response.env
      end

      # URL must be a string that contains at least one number
      # we don't want to store publisher landing or error pages
      fail Faraday::ResourceNotFound, response.env unless url =~ /\d/

      url
    rescue *NETWORKABLE_EXCEPTIONS => e
      rescue_faraday_error(url, e, options.merge(doi_lookup: true))
    end

    def get_normalized_url(url)
      url = PostRank::URI.clean(url)
      if PostRank::URI.valid?(url)
        url
      end
    rescue Addressable::URI::InvalidURIError => e
      { error: e.message }
    end

    def doi_as_url(doi)
      Addressable::URI.encode("http://doi.org/#{doi}") if doi.present?
    end

    def pmid_as_url(pmid)
      "http://www.ncbi.nlm.nih.gov/pubmed/#{pmid}" if pmid.present?
    end

    def pmcid_as_url(pmcid)
      "http://www.ncbi.nlm.nih.gov/pmc/articles/PMC#{pmcid}" if pmcid.present?
    end

    def ark_as_url(ark)
      "http://n2t.net/#{ark}" if ark.present?
    end

    def arxiv_as_url(arxiv)
      "http://arxiv.org/abs/#{arxiv}" if arxiv.present?
    end

    def dataone_as_url(dataone)
      "https://cn.dataone.org/cn/v1/resolve/#{dataone}" if dataone.present?
    end

    def get_doi_from_id(id)
      if /(http|https):\/\/(dx\.)?doi\.org\/(\w+)/.match(id)
        uri = Addressable::URI.parse(id)
        uri.path[1..-1]
      elsif id.starts_with?("doi:")
        id[4..-1]
      end
    end

    def get_pid(options)
      id_hash = options.compact

      if id_hash.present?
        id_as_pid(id_hash)
      else
        { error: "must provide at least one persistent identifier" }
      end
    end

    def id_as_pid(id_hash)
      key, value = id_hash.first
      case key
      when :doi then doi_as_url(value)
      when :pmid then pmid_as_url(value)
      when :pmcid then pmcid_as_url(value)
      when :arxiv then arxiv_as_url(value)
      when :ark then ark_as_url(value)
      when :dataone then dataone_as_url(value)
      when :canonical_url then value
      else nil
      end
    end

    # documentation at http://www.ncbi.nlm.nih.gov/pmc/tools/id-converter-api/
    def get_persistent_identifiers(id, idtype, options = { timeout: 120 })
      return {} if id.blank?

      conn = faraday_conn('json', options)
      params = { 'tool' => "Lagotto - http://#{ENV['SERVERNAME']}",
                 'email' => ENV['ADMIN_EMAIL'],
                 'ids' => id,
                 'idtype' => idtype,
                 'format' => 'json' }
      url = "http://www.pubmedcentral.nih.gov/utils/idconv/v1.0/?" + params.to_query

      conn.options[:timeout] = options[:timeout]
      response = conn.get url, {}, options[:headers]

      if is_json?(response.body)
        json = JSON.parse(response.body)
        json.fetch("records", {}).first
      else
        { error: 'not found' }
      end
    rescue *NETWORKABLE_EXCEPTIONS => e
      rescue_faraday_error(url, e, options)
    end

    def get_metadata(id, service, options = {})
      case service
      when "crossref" then get_crossref_metadata(id, options = {})
      when "datacite" then get_datacite_metadata(id, options = {})
      when "pubmed" then get_pubmed_metadata(id, options = {})
      when "orcid" then get_orcid_metadata(id, options = {})
      when "github" then get_github_metadata(id, options = {})
      when "github_owner" then get_github_owner_metadata(id, options = {})
      when "github_release" then get_github_release_metadata(id, options = {})
      else
        { error: 'Resource not found.', status: 404 }
      end
    end

    def get_crossref_metadata(doi, options = {})
      return {} if doi.blank?

      conn = faraday_conn('json', options)
      url = "http://api.crossref.org/works/" + PostRank::URI.escape(doi)
      response = conn.get url, {}, options[:headers]

      if is_json?(response.body)
        json = JSON.parse(response.body)
        metadata = json.fetch("message", {})
        return { error: 'Resource not found.' } if metadata.blank?

        date_parts = metadata.fetch("issued", {}).fetch("date-parts", []).first
        year, month, day = date_parts[0], date_parts[1], date_parts[2]

        # use date indexed if date issued is in the future
        if year.nil? || Date.new(*date_parts) > Time.zone.now.to_date
          date_parts = metadata.fetch("indexed", {}).fetch("date-parts", []).first
          year, month, day = date_parts[0], date_parts[1], date_parts[2]
        end
        metadata["issued"] = { "date-parts" => [date_parts] }

        metadata["title"] = case metadata["title"].length
              when 0 then nil
              when 1 then metadata["title"][0]
              else metadata["title"][0].presence || metadata["title"][1]
              end

        if metadata["title"].blank? && !TYPES_WITH_TITLE.include?(metadata["type"])
          metadata["title"] = metadata["container-title"][0].presence || "No title"
        end

        publisher_id = metadata["member"][30..-1].to_i if metadata["member"]
        publisher = Publisher.where(name: publisher_id).first
        metadata["publisher_id"] = publisher.present? ? publisher.id : nil

        metadata["container-title"] = metadata.fetch("container-title", [])[0]
        metadata["type"] = CROSSREF_TYPE_TRANSLATIONS[metadata["type"]] if metadata["type"]
        metadata["author"] = metadata["author"].map { |author| author.except("affiliation") }

        metadata
      else
        { error: 'Resource not found.', status: 404 }
      end
    rescue *NETWORKABLE_EXCEPTIONS => e
      rescue_faraday_error(url, e, options)
    end

    def get_datacite_metadata(doi, options = {})
      return {} if doi.blank?

      conn = faraday_conn('json', options)
      params = { q: "doi:" + doi,
                 rows: 1,
                 fl: "doi,creator,title,publisher,publicationYear,resourceTypeGeneral,datacentre,datacentre_symbol,prefix,relatedIdentifier,xml,updated",
                 wt: "json" }
      url = "http://search.datacite.org/api?" + URI.encode_www_form(params)

      response = conn.get url, {}, options[:headers]

      if is_json?(response.body)
        json = JSON.parse(response.body)

        metadata = json.fetch("response", {}).fetch("docs", []).first

        return { error: 'Resource not found.', status: 404 } if metadata.blank?

        type = metadata.fetch("resourceTypeGeneral", nil)
        type = DATACITE_TYPE_TRANSLATIONS.fetch(type, nil) if type

        datacentre_symbol = metadata.fetch("datacentre_symbol", nil)
        publisher = Publisher.where(name: datacentre_symbol).first
        publisher_id = publisher.present? ? publisher.id : nil

        doi = metadata.fetch("doi", nil)
        doi = doi.upcase if doi.present?
        title = metadata.fetch("title", []).first
        title = title.chomp(".") if title.present?

        xml = Base64.decode64(metadata.fetch('xml', "PGhzaD48L2hzaD4=\n"))
        xml = Hash.from_xml(xml).fetch("resource", {})
        authors = xml.fetch("creators", {}).fetch("creator", [])
        authors = [authors] if authors.is_a?(Hash)

        { "author" => get_hashed_authors(authors),
          "title" => title,
          "container-title" => metadata.fetch("journal_title", nil),
          "issued" => get_date_parts_from_parts(metadata.fetch("publicationYear", nil)),
          "DOI" => doi,
          "type" => type,
          "publisher_id" => publisher_id }
      else
        { error: 'Resource not found.', status: 404 }
      end
    rescue *NETWORKABLE_EXCEPTIONS => e
      rescue_faraday_error(url, e, options)
    end

    def get_orcid_metadata(orcid, options = {})
      return {} if orcid.blank?

      conn = faraday_conn('json', options)
      url = "http://pub.orcid.org/v1.2/#{orcid}/orcid-bio"
      response = conn.get url, {}, options[:headers]

      if is_json?(response.body)
        json = JSON.parse(response.body)

        metadata = json.fetch("orcid-profile", nil)

        return { error: 'Resource not found.', status: 404 } if metadata[:error]

        metadata.extend Hashie::Extensions::DeepFetch
        personal_details = metadata.deep_fetch("orcid-bio", "personal-details") { {} }
        personal_details.extend Hashie::Extensions::DeepFetch
        author = { "family" => personal_details.deep_fetch("family-name", "value") { nil },
                   "given" => personal_details.deep_fetch("given-names", "value") { nil } }
        url = metadata.deep_fetch("orcid-identifier", "uri") { nil }
        submission_date = metadata.deep_fetch("orcid-history", "submission-date", "value") { nil }
        timestamp = get_iso8601_from_epoch(submission_date) || Time.zone.now.utc.iso8601

        { "author" => [author],
          "title" => "ORCID record for #{author.fetch('given', '')} #{author.fetch('family', '')}",
          "container-title" => "ORCID Registry",
          "issued" => get_date_parts(timestamp),
          "timestamp" => timestamp,
          "URL" => url,
          "type" => 'entry' }
      else
        { error: 'Resource not found.', status: 404 }
      end
    rescue *NETWORKABLE_EXCEPTIONS => e
      rescue_faraday_error(url, e, options)
    end

    def get_github_metadata(url, options = {})
      return {} if url.blank?

      full_name = URI.parse(url).path[1..-1]
      owner, repo, _tail = full_name.split('/', 3)

      conn = faraday_conn('json', options)
      api_url = "https://api.github.com/repos/#{owner}/#{repo}"
      response = conn.get api_url, {}, options[:headers]

      if is_json?(response.body)
        metadata = JSON.parse(response.body)

        return { error: 'Resource not found.', status: 404 } if metadata["message"] == "Not Found"

        author = get_github_owner(owner)
        timestamp = metadata.fetch('created_at', nil)

        { "author" => [get_one_author(author)],
          "title" => metadata.fetch('description', nil),
          "container-title" => "Github",
          "issued" => get_date_parts(timestamp),
          "timestamp" => timestamp,
          "URL" => url,
          "type" => 'computer_program' }
      else
        { error: 'Resource not found.', status: 404 }
      end
    rescue *NETWORKABLE_EXCEPTIONS => e
      rescue_faraday_error(url, e, options)
    end

    def get_github_owner_metadata(url, options = {})
      return {} if url.blank?

      full_name = URI.parse(url).path[1..-1]
      owner, _tail = full_name.split('/', 2)

      conn = faraday_conn('json', options)
      api_url = "https://api.github.com/users/#{owner}"
      response = conn.get api_url, {}, options[:headers]

      if is_json?(response.body)
        metadata = JSON.parse(response.body)

        return { error: 'Resource not found.', status: 404 } if metadata["message"] == "Not Found"

        author = metadata.fetch('name', nil).to_s
        timestamp = metadata.fetch('created_at', nil)

        { "author" => [get_one_author(author)],
          "title" => "Github profile for #{author}",
          "container-title" => "Github",
          "issued" => get_date_parts(timestamp),
          "timestamp" => timestamp,
          "URL" => url,
          "type" => 'entry' }
      else
        { error: 'Resource not found.', status: 404 }
      end
    rescue *NETWORKABLE_EXCEPTIONS => e
      rescue_faraday_error(url, e, options)
    end

    def get_github_release_metadata(url, options = {})
      return {} if url.blank?

      full_name = URI.parse(url).path[1..-1]
      owner, repo, _tree, release = full_name.split('/', 4)

      conn = faraday_conn('json', options)
      api_url = "https://api.github.com/repos/#{owner}/#{repo}/releases/tags/#{release}"
      response = conn.get api_url, {}, options[:headers]

      if is_json?(response.body)
        metadata = JSON.parse(response.body)

        return { error: 'Resource not found.', status: 404 } if metadata["message"] == "Not Found"

        author = get_github_owner(owner)
        timestamp = metadata.fetch('created_at', nil)

        { "author" => [get_one_author(author)],
          "title" => metadata.fetch('name', nil),
          "container-title" => "Github",
          "issued" => get_date_parts(timestamp),
          "timestamp" => timestamp,
          "URL" => url,
          "type" => 'computer_program' }
      else
        { error: 'Resource not found.', status: 404 }
      end
    rescue *NETWORKABLE_EXCEPTIONS => e
      rescue_faraday_error(url, e, options)
    end

    def get_github_owner(owner)
      conn = faraday_conn('json')
      url = "https://api.github.com/users/#{owner}"
      response = conn.get url

      if is_json?(response.body)
        metadata = JSON.parse(response.body)
        return nil if metadata["message"] == "Not Found"

        metadata.fetch('name', nil)
      else
        nil
      end
    rescue *NETWORKABLE_EXCEPTIONS
      nil
    end

    def get_pubmed_metadata(pmid, options = {})
      return {} if pmid.blank?

      conn = faraday_conn('json', options)
      url = "http://www.ebi.ac.uk/europepmc/webservices/rest/search/query=ext_id:#{pmid}&format=json"
      response = conn.get url, {}, options[:headers]

      if is_json?(response.body)
        json = JSON.parse(response.body)
        metadata = json.fetch("resultList", {}).fetch("result", []).first
        return { error: 'Resource not found.', status: 404 } if metadata.blank?

        metadata["issued"] = get_date_parts_from_parts(metadata.fetch("pubYear", nil))

        author_string = metadata.fetch("authorString", "").chomp(".")
        metadata["author"] = get_authors(author_string.split(", "), reversed: true)

        metadata["title"] = metadata.fetch("title", "").chomp(".")
        metadata["container-title"] = metadata.fetch("journalTitle", nil)
        metadata["volume"] = metadata.fetch("journalVolume", nil)
        metadata["page"] = metadata.fetch("pageInfo", nil)
        metadata["type"] = "article-journal"

        metadata
      else
        { error: 'Resource not found.', status: 404 }
      end
    rescue *NETWORKABLE_EXCEPTIONS => e
      rescue_faraday_error(url, e, options)
    end

    def get_doi_ra(doi, options = {})
      return {} if doi.blank?

      conn = faraday_conn('json', options)
      url = "http://doi.crossref.org/doiRA/" + CGI.unescape(doi)
      response = conn.get url, {}, options[:headers]

      if is_json?(response.body)
        json = JSON.parse(response.body)
        ra = json.first.fetch("RA", nil)
        if ra.present?
          ra.delete(' ').downcase
        else
          error = json.first.fetch("status", "An error occured")
          { error: error, status: 400 }
        end
      else
        { error: 'Resource not found.', status: 404 }
      end
    rescue *NETWORKABLE_EXCEPTIONS => e
      rescue_faraday_error(url, e, options)
    end

    def get_id_hash(id)
      return nil if id.nil?

      id = id.gsub("%2F", "/")
      id = id.gsub("%3A", ":")

      # workaround, as nginx and the rails router swallow double backslashes
      id = id.gsub(/(http|https):\/+(\w+)/, '\1://\2')

      case
      when id.starts_with?("doi.org/")           then { doi: CGI.unescape(id[8..-1]).upcase }
      when id.starts_with?("www.ncbi.nlm.nih.gov/pubmed/")                  then { pmid: id[28..-1] }
      when id.starts_with?("www.ncbi.nlm.nih.gov/pmc/articles/PMC")         then { pmcid: id[37..-1] }
      when id.starts_with?("arxiv.org/abs/")     then { arxiv: id[14..-1] }
      when id.starts_with?("n2t.net/ark:")       then { ark: id[8..-1] }

      when id.starts_with?("http://doi.org/")    then { doi: CGI.unescape(id[15..-1]).upcase }
      when id.starts_with?("http://dx.doi.org/") then { doi: CGI.unescape(id[18..-1]).upcase }
      when id.starts_with?("http://www.ncbi.nlm.nih.gov/pubmed/")           then { pmid: id[35..-1] }
      when id.starts_with?("http://www.ncbi.nlm.nih.gov/pmc/articles/PMC")  then { pmcid: id[44..-1] }
      when id.starts_with?("http://arxiv.org/abs/")                         then { arxiv: id[21..-1] }
      when id.starts_with?("http://n2t.net/ark:")                           then { ark: id[15..-1] }
      when id.starts_with?("http:")              then { canonical_url: PostRank::URI.clean(id) }
      when id.starts_with?("https:")             then { canonical_url: PostRank::URI.clean(id) }

      when id.starts_with?("doi:")               then { doi: CGI.unescape(id[4..-1]).upcase }
      when id.starts_with?("pmid:")              then { pmid: id[5..-1] }
      when id.starts_with?("pmcid:PMC")          then { pmcid: id[9..-1] }
      when id.starts_with?("pmcid:")             then { pmcid: id[6..-1] }
      when id.starts_with?("arxiv:")             then { arxiv: id[6..-1] }
      when id.starts_with?("wos:")               then { wos: id[4..-1] }
      when id.starts_with?("scp:")               then { scp: id[4..-1] }
      when id.starts_with?("ark:")               then { ark: id }

      when id.starts_with?("doi/")               then { doi: CGI.unescape(id[4..-1]).upcase }
      when id.starts_with?("info:doi/")          then { doi: CGI.unescape(id[9..-1]).upcase }
      when id.starts_with?("10.")                then { doi: CGI.unescape(id).upcase }
      when id.starts_with?("pmid/")              then { pmid: id[5..-1] }
      when id.starts_with?("pmcid/PMC")          then { pmcid: id[9..-1] }
      when id.starts_with?("pmcid/")             then { pmcid: id[6..-1] }
      when id.starts_with?("PMC")                then { pmcid: id[3..-1] }
      when id.starts_with?("doi_10.")            then { doi: id[4..-1].gsub("_", "/").upcase }
      else { doi: CGI.unescape(id).upcase }
      end
    end

    def get_clean_id(id)
      if id.starts_with? "10."
        Addressable::URI.unencode(id)
      elsif id.starts_with? "PMC"
        id[3..-1]
      else
        id
      end
    end
  end
end
