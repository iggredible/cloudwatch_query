# frozen_string_literal: true

RSpec.describe CloudwatchQuery::Result do
  subject(:result) { described_class.new(data) }

  let(:data) do
    {
      "timestamp" => "2024-01-15T10:30:00.000Z",
      "message" => "Error: Connection timeout",
      "logStream" => "ecs/api/abc123",
      "log" => "/aws/lambda/api",
      "requestId" => "req-456"
    }
  end

  describe "#timestamp" do
    it "returns the timestamp" do
      expect(result.timestamp).to eq("2024-01-15T10:30:00.000Z")
    end
  end

  describe "#message" do
    it "returns the message" do
      expect(result.message).to eq("Error: Connection timeout")
    end
  end

  describe "#log_stream" do
    it "returns the log stream" do
      expect(result.log_stream).to eq("ecs/api/abc123")
    end
  end

  describe "#[]" do
    it "accesses fields by symbol" do
      expect(result[:requestId]).to eq("req-456")
    end

    it "accesses fields by string" do
      expect(result["requestId"]).to eq("req-456")
    end
  end

  describe "#to_h" do
    it "returns hash representation" do
      hash = result.to_h
      expect(hash[:timestamp]).to eq("2024-01-15T10:30:00.000Z")
      expect(hash[:message]).to eq("Error: Connection timeout")
    end
  end

  describe "dynamic field access" do
    it "allows accessing custom fields as methods" do
      expect(result.requestId).to eq("req-456")
    end

    it "responds to custom fields" do
      expect(result).to respond_to(:requestId)
    end
  end
end
