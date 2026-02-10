# frozen_string_literal: true

RSpec.describe CloudwatchQuery::Parsers::SidekiqParser do
  describe "class methods" do
    describe ".matches?" do
      it "matches Sidekiq log format" do
        message = "2026-02-04T20:46:15.201Z pid=4022623 tid=c8kxf7 class=Logging::Broadcast::Job jid=abc123 INFO: done"
        expect(described_class.matches?(message)).to be true
      end

      it "does not match Rails logs" do
        message = '[abc-123] Started GET "/path" for 1.2.3.4 at 2026-02-04'
        expect(described_class.matches?(message)).to be false
      end
    end

    describe ".available_sub_parsers" do
      it "lists all built-in sub-parsers" do
        expect(described_class.available_sub_parsers).to include(:start, :done, :fail)
      end
    end
  end

  describe "instance with default sub-parsers" do
    subject(:parser) { described_class.new }

    it "parses job done log" do
      message = "2026-02-04T20:46:15.201Z pid=4022623 tid=c8kxf7 class=Logging::Broadcast::Job jid=9480cf0b927e443155f15a3f elapsed=0.152 INFO: done"
      result = parser.parse(message)

      expect(result).to be_a(CloudwatchQuery::Parsers::Sidekiq::SidekiqLog)
      expect(result.type).to eq(:sidekiq)
      expect(result.line_type).to eq(:done)
      expect(result.timestamp).to eq("2026-02-04T20:46:15.201Z")
      expect(result.pid).to eq("4022623")
      expect(result.tid).to eq("c8kxf7")
      expect(result.job_class).to eq("Logging::Broadcast::Job")
      expect(result.jid).to eq("9480cf0b927e443155f15a3f")
      expect(result.elapsed).to eq(0.152)
      expect(result.status).to eq("done")
    end

    it "parses job start log" do
      message = "2026-02-04T20:46:15.049Z pid=4022623 tid=c8kxf7 class=Logging::Broadcast::Job jid=abc123 INFO: start"
      result = parser.parse(message)

      expect(result.line_type).to eq(:start)
      expect(result.status).to eq("start")
      expect(result.elapsed).to be_nil
    end

    it "provides duration alias for elapsed" do
      message = "2026-02-04T20:46:15.201Z pid=4022623 tid=c8kxf7 class=Job jid=abc123 elapsed=1.5 INFO: done"
      result = parser.parse(message)

      expect(result.duration).to eq(1.5)
    end

    it "has convenience methods" do
      done_msg = "2026-02-04T20:46:15.201Z pid=123 tid=abc class=Job jid=xyz elapsed=0.1 INFO: done"
      start_msg = "2026-02-04T20:46:15.201Z pid=123 tid=abc class=Job jid=xyz INFO: start"

      done_result = parser.parse(done_msg)
      start_result = parser.parse(start_msg)

      expect(done_result.done?).to be true
      expect(done_result.start?).to be false
      expect(start_result.start?).to be true
      expect(start_result.done?).to be false
    end
  end

  describe "instance with specific sub-parsers" do
    subject(:parser) { described_class.new(:done) }

    it "only uses specified sub-parsers" do
      expect(parser.sub_parsers.size).to eq(1)
    end

    it "parses done logs" do
      message = "2026-02-04T20:46:15.201Z pid=123 tid=abc class=Job jid=xyz elapsed=0.1 INFO: done"
      result = parser.parse(message)
      expect(result.line_type).to eq(:done)
    end

    it "marks start as unknown (sub-parser not included)" do
      message = "2026-02-04T20:46:15.201Z pid=123 tid=abc class=Job jid=xyz INFO: start"
      result = parser.parse(message)
      expect(result.line_type).to eq(:unknown)
    end
  end

  describe "instance with :all plus custom parser" do
    let(:custom_parser) do
      Class.new do
        def self.matches?(message)
          message.include?("CUSTOM")
        end

        def self.parse(_message, _base_data)
          { line_type: :custom }
        end
      end
    end

    subject(:parser) { described_class.new(:all, custom_parser) }

    it "includes all default sub-parsers plus custom" do
      expect(parser.sub_parsers.size).to eq(4) # 3 built-in + 1 custom
    end
  end

  describe "error handling" do
    it "raises error for unknown sub-parser symbol" do
      expect { described_class.new(:unknown_parser) }.to raise_error(ArgumentError, /Unknown sub-parser/)
    end
  end
end
