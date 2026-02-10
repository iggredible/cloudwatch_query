# frozen_string_literal: true

RSpec.describe CloudwatchQuery::Parsers::RailsParser do
  describe "class methods" do
    describe ".matches?" do
      it "matches Rails log with request UUID" do
        message = '[c3784123-8ce1-4b7e-8583-3e6f61ef5676] Started GET "/path" for 1.2.3.4 at 2026-02-04'
        expect(described_class.matches?(message)).to be true
      end

      it "does not match Sidekiq logs" do
        message = "2026-02-04T20:46:15.201Z pid=4022623 tid=c8kxf7 class=Job jid=abc123 INFO: done"
        expect(described_class.matches?(message)).to be false
      end
    end

    describe ".available_sub_parsers" do
      it "lists all built-in sub-parsers" do
        expect(described_class.available_sub_parsers).to include(:request, :parameters, :redirect, :active_job)
      end
    end
  end

  describe "instance with default sub-parsers" do
    subject(:parser) { described_class.new }

    it "parses request lines" do
      message = 'Feb  4 22:37:47 ip-10-15-1-216 cryo[1030829]: [c3784123-8ce1-4b7e-8583-3e6f61ef5676] Started GET "/shipments/443155" for 45.77.120.91 at 2026-02-04 22:37:47 +0000'
      result = parser.parse(message)

      expect(result).to be_a(CloudwatchQuery::Parsers::Rails::RailsLog)
      expect(result.type).to eq(:rails)
      expect(result.line_type).to eq(:request)
      expect(result.request_id).to eq("c3784123-8ce1-4b7e-8583-3e6f61ef5676")
      expect(result.http_method).to eq("GET")
      expect(result.path).to eq("/shipments/443155")
      expect(result.ip_address).to eq("45.77.120.91")
      expect(result.server).to eq("ip-10-15-1-216")
      expect(result.process_id).to eq("1030829")
    end

    it "parses parameters lines" do
      message = '[c3784123-8ce1-4b7e-8583-3e6f61ef5676] Parameters: {"id"=>"123", "name"=>"test"}'
      result = parser.parse(message)

      expect(result.line_type).to eq(:parameters)
      expect(result.request_id).to eq("c3784123-8ce1-4b7e-8583-3e6f61ef5676")
      expect(result.params).to be_a(Hash)
    end

    it "parses redirect lines" do
      message = '[c3784123-8ce1-4b7e-8583-3e6f61ef5676] Redirected to https://example.com/path'
      result = parser.parse(message)

      expect(result.line_type).to eq(:redirect)
      expect(result.redirect_url).to eq("https://example.com/path")
    end

    it "parses active job lines" do
      message = '[c3784123-8ce1-4b7e-8583-3e6f61ef5676] [ActiveJob] Enqueued MyJob (Job ID: job-123) to Sidekiq(default) with arguments: "arg1"'
      result = parser.parse(message)

      expect(result.line_type).to eq(:active_job)
      expect(result.job_class).to eq("MyJob")
      expect(result.job_id).to eq("job-123")
      expect(result.queue).to eq("default")
    end

    it "returns unknown line_type for unrecognized messages" do
      message = '[c3784123-8ce1-4b7e-8583-3e6f61ef5676] Some random log message'
      result = parser.parse(message)

      expect(result.line_type).to eq(:unknown)
      expect(result.request_id).to eq("c3784123-8ce1-4b7e-8583-3e6f61ef5676")
      expect(result.raw_message).to eq(message)
    end
  end

  describe "instance with specific sub-parsers" do
    subject(:parser) { described_class.new(:request, :parameters) }

    it "only uses specified sub-parsers" do
      expect(parser.sub_parsers.size).to eq(2)
    end

    it "parses request lines" do
      message = '[c3784123-8ce1-4b7e-8583-3e6f61ef5676] Started GET "/path" for 1.2.3.4 at 2026-02-04'
      result = parser.parse(message)
      expect(result.line_type).to eq(:request)
    end

    it "marks redirect as unknown (sub-parser not included)" do
      message = '[c3784123-8ce1-4b7e-8583-3e6f61ef5676] Redirected to https://example.com'
      result = parser.parse(message)
      expect(result.line_type).to eq(:unknown)
    end
  end

  describe "instance with :all plus custom parser" do
    let(:custom_parser) do
      Class.new do
        def self.matches?(message)
          message.include?("CUSTOM:")
        end

        def self.parse(_message, _base_data)
          { line_type: :custom, custom_field: "value" }
        end
      end
    end

    subject(:parser) { described_class.new(:all, custom_parser) }

    it "includes all default sub-parsers plus custom" do
      expect(parser.sub_parsers.size).to eq(7) # 6 built-in + 1 custom
    end

    it "parses custom messages" do
      message = '[c3784123-8ce1-4b7e-8583-3e6f61ef5676] CUSTOM: my message'
      result = parser.parse(message)
      expect(result.line_type).to eq(:custom)
    end
  end

  describe "error handling" do
    it "raises error for unknown sub-parser symbol" do
      expect { described_class.new(:unknown_parser) }.to raise_error(ArgumentError, /Unknown sub-parser/)
    end

    it "raises error for invalid custom parser" do
      invalid_parser = Class.new
      expect { described_class.new(invalid_parser) }.to raise_error(ArgumentError, /must respond to/)
    end
  end
end
