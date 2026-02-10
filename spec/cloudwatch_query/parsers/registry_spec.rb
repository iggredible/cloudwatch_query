# frozen_string_literal: true

RSpec.describe CloudwatchQuery::Parsers::Registry do
  subject(:registry) { described_class.new }

  let(:parser_a) do
    Class.new do
      def matches?(message)
        message.include?("PARSER_A")
      end

      def parse(message)
        OpenStruct.new(type: :a, message: message)
      end

      def self.parser_name
        "parser_a"
      end
    end.new
  end

  let(:parser_b) do
    Class.new do
      def matches?(message)
        message.include?("PARSER_B")
      end

      def parse(message)
        OpenStruct.new(type: :b, message: message)
      end

      def self.parser_name
        "parser_b"
      end
    end.new
  end

  describe "#register" do
    it "adds a single parser" do
      registry.register(parser_a)
      expect(registry.list).to eq([parser_a])
    end

    it "adds multiple parsers at once" do
      registry.register(parser_a, parser_b)
      expect(registry.list).to eq([parser_a, parser_b])
    end

    it "does not add duplicate parsers" do
      registry.register(parser_a)
      registry.register(parser_a)
      expect(registry.list).to eq([parser_a])
    end

    it "returns self for chaining" do
      expect(registry.register(parser_a)).to eq(registry)
    end
  end

  describe "#prepend" do
    it "adds parser at the beginning" do
      registry.register(parser_a)
      registry.prepend(parser_b)
      expect(registry.list).to eq([parser_b, parser_a])
    end

    it "moves existing parser to the beginning" do
      registry.register(parser_a, parser_b)
      registry.prepend(parser_b)
      expect(registry.list).to eq([parser_b, parser_a])
    end
  end

  describe "#unregister" do
    it "removes a parser" do
      registry.register(parser_a, parser_b)
      registry.unregister(parser_a)
      expect(registry.list).to eq([parser_b])
    end
  end

  describe "#clear" do
    it "removes all parsers" do
      registry.register(parser_a, parser_b)
      registry.clear
      expect(registry.list).to be_empty
    end
  end

  describe "#parse" do
    before do
      registry.register(parser_a, parser_b)
    end

    it "returns parsed result from first matching parser" do
      parsed, name = registry.parse("test PARSER_A message")
      expect(parsed.type).to eq(:a)
      expect(name).to eq("parser_a")
    end

    it "tries parsers in order" do
      parsed, name = registry.parse("test PARSER_B message")
      expect(parsed.type).to eq(:b)
      expect(name).to eq("parser_b")
    end

    it "returns nil when no parser matches" do
      parsed, name = registry.parse("no match")
      expect(parsed).to be_nil
      expect(name).to be_nil
    end

    it "returns nil for empty message" do
      parsed, name = registry.parse("")
      expect(parsed).to be_nil
      expect(name).to be_nil
    end

    it "returns nil for nil message" do
      parsed, name = registry.parse(nil)
      expect(parsed).to be_nil
      expect(name).to be_nil
    end
  end

  describe "integration with RailsParser and SidekiqParser" do
    before do
      registry.register(
        CloudwatchQuery::Parsers::RailsParser.new,
        CloudwatchQuery::Parsers::SidekiqParser.new
      )
    end

    it "parses Rails logs" do
      message = '[c3784123-8ce1-4b7e-8583-3e6f61ef5676] Started GET "/path" for 1.2.3.4 at 2026-02-04'
      parsed, name = registry.parse(message)

      expect(parsed.type).to eq(:rails)
      expect(name).to eq("rails")
    end

    it "parses Sidekiq logs" do
      message = "2026-02-04T20:46:15.201Z pid=123 tid=abc class=Job jid=xyz elapsed=0.1 INFO: done"
      parsed, name = registry.parse(message)

      expect(parsed.type).to eq(:sidekiq)
      expect(name).to eq("sidekiq")
    end
  end
end
