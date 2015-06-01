require "rails_helper"

describe "/api/v6/sources", :type => :api do
  let(:headers) do
    { "HTTP_ACCEPT" => "application/json; version=6",
      "HTTP_AUTHORIZATION" => "Token token=#{user.api_key}" }
  end
  let(:jsonp_headers) do
    { "HTTP_ACCEPT" => "application/javascript; version=6",
      "HTTP_AUTHORIZATION" => "Token token=#{user.api_key}" }
  end

  context "index" do
    let(:user) { FactoryGirl.create(:admin_user) }
    let(:uri) { "/api/sources" }

    context "get events" do
      let!(:source) { FactoryGirl.create(:source) }
      let!(:works) { FactoryGirl.create_list(:work_with_events, 10) }

      it "JSON" do
        get uri, nil, headers
        expect(last_response.status).to eq(200)

        response = JSON.parse(last_response.body)
        data = response["sources"]
        item = data.first
        expect(item["id"]).to eq(source.name)
        expect(item["state"]).to eq("active")
        expect(item["work_count"]).to eq(10)
        expect(item["event_count"]).to eq(500)
      end

      it "JSONP" do
        get "#{uri}?callback=_func", nil, jsonp_headers
        expect(last_response.status).to eql(200)

        # remove jsonp wrapper
        response = JSON.parse(last_response.body[6...-1])
        data = response["sources"]
        item = data.first
        expect(item["id"]).to eq(source.name)
        expect(item["state"]).to eq("active")
        expect(item["work_count"]).to eq(10)
        expect(item["event_count"]).to eq(500)
      end
    end
  end

  context "show" do
    context "get response" do
      let(:source) { FactoryGirl.create(:source_with_changes) }
      let!(:works) { FactoryGirl.create_list(:work_with_events, 5) }
      let(:user) { FactoryGirl.create(:admin_user) }
      let(:uri) { "/api/sources/#{source.name}" }

      it "JSON" do
        get uri, nil, 'HTTP_ACCEPT' => headers
        expect(last_response.status).to eq(200)

        response = JSON.parse(last_response.body)
        data = response["source"]
        expect(data["id"]).to eq(source.name)
        expect(data["state"]).to eq("active")
        expect(data["work_count"]).to eq(5)
        expect(data["event_count"]).to eq(250)
      end

      it "JSONP" do
        get "#{uri}?callback=_func", nil, jsonp_headers
        expect(last_response.status).to eql(200)

        # remove jsonp wrapper
        response = JSON.parse(last_response.body[6...-1])
        data = response["source"]
        expect(data["id"]).to eq(source.name)
        expect(data["state"]).to eq("active")
        expect(data["work_count"]).to eq(5)
        expect(data["event_count"]).to eq(250)
      end
    end
  end
end
