require "rails_helper"

describe "/api/v3/articles", :type => :api do
  let(:user) { FactoryGirl.create(:user) }
  let(:api_key) { user.authentication_token }

  context "caching", :caching => true do

    context "index" do
      let(:articles) { FactoryGirl.create_list(:article_with_events, 2) }
      let(:article_list) { articles.map { |article| "#{article.doi_escaped}" }.join(",") }

      before(:each) do
        @uri = "/api/v3/articles?ids=#{article_list}&type=doi&api_key=#{api_key}"
      end

      it "can cache articles" do
        articles.all? do |article|
          key = article.decorate.cache_key
          expect(Rails.cache.exist?("jbuilder/v3/#{key}")).to be false
        end
        get @uri, nil, 'HTTP_ACCEPT' => 'application/json'
        expect(last_response.status).to eq(200)

        sleep 1

        article = articles.first
        key = article.decorate.cache_key
        response = Rails.cache.read("jbuilder/v3/#{key}")
        response_source = response["sources"][0]
        expect(response["doi"]).to eql(article.doi)
        expect(response["publication_date"]).to eql(article.published_on.to_time.utc.iso8601)
        expect(response_source["metrics"][:total].to_i).to eql(article.retrieval_statuses.first.event_count)
        expect(response_source["events"]).to be_nil
      end
    end

    context "show" do
      let(:article) { FactoryGirl.create(:article_with_events) }
      let(:uri) { "/api/v3/articles/info:doi/#{article.doi}?api_key=#{api_key}" }
      let(:key) { "jbuilder/v3/#{ArticleDecorator.decorate(article).cache_key}" }
      let(:title) { "Foo" }
      let(:event_count) { 75 }

      it "can cache an article" do
        expect(Rails.cache.exist?(key)).not_to be true
        get uri, nil, 'HTTP_ACCEPT' => 'application/json'
        expect(last_response.status).to eq(200)

        sleep 1

        expect(Rails.cache.exist?(key)).to be true

        response = Rails.cache.read(key)
        response_source = response["sources"][0]
        expect(response["doi"]).to eql(article.doi)
        expect(response["publication_date"]).to eql(article.published_on.to_time.utc.iso8601)
        expect(response_source["metrics"][:total].to_i).to eql(article.retrieval_statuses.first.event_count)
        expect(response_source["events"]).to be_nil
      end

      it "can make API requests 1.5x faster" do
        expect(Rails.cache.exist?(key)).not_to be true
        get uri, nil, 'HTTP_ACCEPT' => 'application/json'
        expect(last_response.status).to eq(200)

        sleep 1

        expect(Rails.cache.exist?(key)).to be true

        get uri, nil, 'HTTP_ACCEPT' => 'application/json'
        expect(last_response.status).to eq(200)
        expect(ApiRequest.count).to eql(2)
        expect(ApiRequest.last.view_duration).to be < 0.67 * ApiRequest.first.view_duration
      end

      it "does not use a stale cache when an article is updated" do
        expect(Rails.cache.exist?(key)).not_to be true
        get uri, nil, 'HTTP_ACCEPT' => 'application/json'
        expect(last_response.status).to eq(200)

        sleep 1

        expect(Rails.cache.exist?(key)).to be true
        response = Rails.cache.read(key)
        expect(response["title"]).to eql(article.title)
        expect(response["title"]).not_to eql(title)

        # wait a second so that the timestamp for cache_key is different
        sleep 1
        article.update_attributes!(title: title)

        get uri, nil, 'HTTP_ACCEPT' => 'application/json'
        expect(last_response.status).to eq(200)
        cache_key = "jbuilder/v3/#{ArticleDecorator.decorate(article).cache_key}"
        expect(cache_key).not_to eql(key)
        expect(Rails.cache.exist?(cache_key)).to be true
        response = Rails.cache.read(cache_key)
        expect(response["title"]).to eql(article.title)
        expect(response["title"]).to eql(title)
      end

      it "does not use a stale cache when a source is updated" do
        expect(Rails.cache.exist?(key)).not_to be true
        get uri, nil, 'HTTP_ACCEPT' => 'application/json'
        expect(last_response.status).to eq(200)

        sleep 1

        expect(Rails.cache.exist?(key)).to be true
        response = Rails.cache.read(key)
        update_date = response["update_date"]

        # wait a second so that the timestamp for cache_key is different
        sleep 1
        article.retrieval_statuses.first.update_attributes!(event_count: event_count)
        # TODO: make sure that touch works in production
        article.touch

        get uri, nil, 'HTTP_ACCEPT' => 'application/json'
        expect(last_response.status).to eq(200)
        cache_key = "jbuilder/v3/#{ArticleDecorator.decorate(article).cache_key}"
        expect(cache_key).not_to eql(key)
        expect(Rails.cache.exist?(cache_key)).to be true
        response = Rails.cache.read(cache_key)
        expect(response["update_date"]).to be > update_date
      end

      it "does not use a stale cache when the source query parameter changes" do
        expect(Rails.cache.exist?(key)).not_to be true
        get uri, nil, 'HTTP_ACCEPT' => 'application/json'
        expect(last_response.status).to eq(200)

        sleep 1

        expect(Rails.cache.exist?(key)).to be true
        response = Rails.cache.read(key)
        expect(response["sources"].size).to eql(1)

        source_uri = "#{uri}&source=crossref"
        get source_uri, nil, 'HTTP_ACCEPT' => 'application/json'
        expect(last_response.status).to eql(404)
        expect(JSON.parse(last_response.body)).to eql("error" => "Source not found.")
      end

      it "does not use a stale cache when the info query parameter changes" do
        expect(Rails.cache.exist?(key)).not_to be true
        get uri, nil, 'HTTP_ACCEPT' => 'application/json'
        expect(last_response.status).to eq(200)

        sleep 1

        expect(Rails.cache.exist?(key)).to be true

        history_uri = "#{uri}&info=history"
        get history_uri, nil, 'HTTP_ACCEPT' => 'application/json'
        expect(last_response.status).to eq(200)

        response = JSON.parse(last_response.body)
        response_source = response["sources"][0]
        expect(response["doi"]).to eql(article.doi)
        expect(response["publication_date"]).to eql(article.published_on.to_time.utc.iso8601)
        expect(response_source["metrics"]["total"]).to eq(article.retrieval_statuses.first.event_count)
        expect(response_source["metrics"]["shares"]).to eq(article.retrieval_statuses.first.event_count)
        expect(response_source["events"]).to be_nil

        summary_uri = "#{uri}&info=summary"
        get summary_uri, nil, 'HTTP_ACCEPT' => 'application/json'
        expect(last_response.status).to eq(200)

        response = JSON.parse(last_response.body)
        expect(response["sources"]).to be_nil
        expect(response["doi"]).to eql(article.doi)
        expect(response["publication_date"]).to eql(article.published_on.to_time.utc.iso8601)
      end
    end
  end
end
