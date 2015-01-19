class Status < ActiveRecord::Base
  # include HTTP request helpers
  include Networkable

  RELEASES_URL = "https://api.github.com/repos/articlemetrics/lagotto/releases"

  before_create :collect_status_info

  def self.per_page
    1000
  end

  def collect_status_info
    self.works_count = works_count || Work.count
    self.works_new_count = works_new_count || Work.last_x_days(0).count
    self.events_count = events_count || RetrievalStatus.joins(:source).where("state > ?", 0)
      .where("name != ?", "relativemetric").sum(:event_count)
    self.responses_count = responses_count || ApiResponse.total(0).count
    self.requests_count = requests_count || ApiRequest.total(0).count
    self.requests_average = requests_average || ApiRequest.total(0).average("duration").to_i
    self.alerts_count = alerts_count || Alert.total_errors(0).count
    self.db_size = db_size || get_db_size
    self.sources_working_count = sources_working_count || Source.working.count
    self.sources_waiting_count = sources_waiting_count || Source.waiting.count
    self.sources_disabled_count = sources_disabled_count || Source.disabled.count
    self.version = version || Rails.application.config.version
    self.current_version = current_version || get_current_version
  end

  def sources
    { "working" => sources_working_count,
      "waiting" => sources_waiting_count,
      "disabled" => sources_disabled_count }
  end

  def get_current_version
    result = get_result(RELEASES_URL)
    result = result.is_a?(Array) ? result.first : {}
    result.fetch("tag_name", "v.#{version}")[2..-1]
  end

  def get_db_size
    sql = " SELECT table_rows FROM information_schema.TABLES where table_name='retrieval_statuses';"
    result = ActiveRecord::Base.connection.exec_query(sql).first
    result && result.is_a?(Hash) && result.fetch("table_rows", 0)
  end

  def outdated_version?
    Gem::Version.new(current_version) > Gem::Version.new(version)
  end

  def update_date
    updated_at.utc.iso8601
  end

  def cache_key
    "status/#{update_date}"
  end

  def write_cache
    # update cache_key as last step so that old version works until we are done
    timestamp = Time.zone.now.utc.iso8601

    # loop through cached attributes we want to update
    [:works_count,
     :works_last_day_count,
     :events_count,
     :alerts_count,
     :responses_count,
     :requests_count,
     :requests_average,
     :current_version,
     :update_date].each { |cached_attr| send("#{cached_attr}=", timestamp) }
  end
end
