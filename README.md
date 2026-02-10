# CloudwatchQuery

A Ruby gem for querying AWS CloudWatch Logs with a simple, chainable interface.

## Installation

Add to your Gemfile:

```ruby
gem "cloudwatch_query"
```

Or install directly:

```bash
gem install cloudwatch_query
```

## Prerequisites

AWS credentials must be configured. This gem uses the standard AWS credential chain:

1. Environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`)
2. Shared credentials file (`~/.aws/credentials`)
3. EC2 instance metadata

## Configuration

```ruby
CloudwatchQuery.configure do |config|
  config.region = "us-west-1"           # Default: ENV["AWS_REGION"] or "us-west-1"
  config.default_limit = 100            # Default result limit
  config.default_time_range = 3600      # Default lookback in seconds
end
```

## Usage

### Basic Query

```ruby
CloudwatchQuery
  .logs("my-app-rails-log")
  .where(level: "ERROR")
  .last(30, :minutes)
  .each { |event| puts event.message }
```

### Quick Search

```ruby
CloudwatchQuery.search(
  "OutOfMemoryError",
  groups: "my-app-rails-log",
  since: 2.hours.ago,
  limit: 50
)
```

### Multiple Log Groups

```ruby
CloudwatchQuery
  .logs(
    "my-app-rails-log",
    "my-app-sidekiq-log"
  )
  .contains("database")
  .where(level: "ERROR")
  .last(1, :hours)
  .execute
```

### Time Range Options

```ruby
query = CloudwatchQuery.logs("my-app-rails-log")

# Relative time
query.last(30, :minutes)
query.last(2, :hours)
query.last(7, :days)

# Absolute time
query.since(Time.now - 3600)
query.since(1.hour.ago)            # With ActiveSupport
query.between(start_time, end_time)
```

### Field Selection

```ruby
CloudwatchQuery
  .logs("my-app-rails-log")
  .fields(:timestamp, :message, :logStream)
  .last(1, :hours)
  .execute
```

### Query Inspection

```ruby
query = CloudwatchQuery
  .logs("my-app-rails-log")
  .where(level: "ERROR")
  .contains("timeout")
  .limit(50)

puts query.to_insights_query
# => fields @timestamp, @message, @logStream, @log | filter level = 'ERROR' | filter @message like /timeout/ | sort @timestamp desc | limit 50
```

### Working with Results

```ruby
results = CloudwatchQuery
  .logs("my-app-rails-log")
  .last(1, :hours)
  .execute

# Enumerable methods
results.each { |r| puts r.message }
results.count
results.empty?

# Access fields
results.first.timestamp
results.first.message
results.first[:logStream]
results.first.to_h
```

### Parsers

Results can be automatically parsed into structured objects. The gem ships with two built-in parsers: `RailsParser` and `SidekiqParser`. Parsers are registered globally and run automatically when results are returned.

#### How It Works

Each `Result` has a `parsed` attribute. When a query executes, every result's `message` is passed through the parser registry. The first parser whose `matches?` returns true parses the message into a structured log object (`RailsLog` or `SidekiqLog`).

```ruby
results = CloudwatchQuery
  .logs("my-app-rails-log")
  .last(30, :minutes)
  .execute

result = results.first
result.parsed?       # => true
result.parser_name   # => "rails"
result.log_type      # => :rails
result.parsed        # => RailsLog instance
```

#### Rails Parser

Recognizes log lines containing a Rails request UUID (`[abc-123-def-456]`). Each line is further classified by sub-parsers:

| Sub-parser | Matches | Fields |
|------------|---------|--------|
| `:request` | `Started GET "/path" for 1.2.3.4` | `http_method`, `path`, `ip_address` |
| `:parameters` | `Parameters: {...}` | `params` |
| `:processing` | `Processing by Controller#action as HTML` | `controller`, `action`, `format` |
| `:completed` | `Completed 200 OK in 123ms` | `status_code`, `duration_ms` |
| `:redirect` | `Redirected to https://...` | `redirect_url` |
| `:active_job` | `[ActiveJob] Enqueued JobClass (Job ID: ...)` | `job_class`, `job_id`, `queue` |

```ruby
result.parsed.line_type    # => :request
result.parsed.http_method  # => "GET"
result.parsed.path         # => "/users/1"
result.parsed.request_id   # => "abc-123-def-456"
```

Use only specific sub-parsers:

```ruby
CloudwatchQuery.parsers.clear
CloudwatchQuery.parsers.register(
  CloudwatchQuery::Parsers::RailsParser.new(:request, :completed)
)
```

#### Sidekiq Parser

Recognizes Sidekiq log lines (`2026-02-04T20:46:15.201Z pid=123 tid=abc class=Job jid=xyz`). Sub-parsers:

| Sub-parser | Matches | Fields |
|------------|---------|--------|
| `:start` | `INFO: start` | `status` |
| `:done` | `INFO: done` | `status`, `elapsed` |
| `:fail` | `INFO: fail` or `ERROR:` | `status` |

```ruby
result.parsed.line_type  # => :done
result.parsed.job_class  # => "SendEmailJob"
result.parsed.elapsed    # => 0.152
result.parsed.jid        # => "abc123"
```

#### Filtering Parsed Results

```ruby
results.parsed                    # only successfully parsed results
results.unparsed                  # results that no parser matched
results.by_type(:rails)           # filter by log type
results.group_by_request          # group Rails logs by request_id
```

#### Custom Parsers

Create a parser that responds to `matches?` and `parse`:

```ruby
class MyParser
  def matches?(message)
    message.include?("[CUSTOM]")
  end

  def parse(message)
    OpenStruct.new(type: :custom, body: message)
  end

  def parser_name
    "custom"
  end
end

CloudwatchQuery.parsers.register(MyParser.new)
```

Registry methods: `register`, `prepend`, `insert`, `unregister`, `clear`, `list`.

### List Log Groups

```ruby
CloudwatchQuery.list_log_groups(prefix: "production-")
```

## API Reference

### Query Builder Methods

| Method | Description |
|--------|-------------|
| `.logs(*groups)` | Select log groups to query |
| `.where(**conditions)` | Filter by field equality |
| `.contains(text)` | Filter messages containing text |
| `.matches(pattern)` | Filter messages matching regex |
| `.since(time)` | Set start time |
| `.before(time)` | Set end time |
| `.between(start, end)` | Set time range |
| `.last(amount, unit)` | Relative time (e.g., `last(30, :minutes)`) |
| `.fields(*fields)` | Select fields to return |
| `.limit(n)` | Limit number of results |
| `.execute` | Run query and return ResultSet |
| `.to_insights_query` | Return generated query string |

### Result Methods

| Method | Description |
|--------|-------------|
| `.timestamp` | Log event timestamp |
| `.message` | Log message content |
| `.[](key)` | Access field by name |
| `.to_h` | Convert to hash |

## Error Handling

```ruby
begin
  results = CloudwatchQuery
    .logs("my-log-group")
    .last(1, :hours)
    .execute
rescue CloudwatchQuery::AuthError => e
  puts "Authentication failed: #{e.message}"
rescue CloudwatchQuery::QueryError => e
  puts "Query failed: #{e.message}"
rescue CloudwatchQuery::TimeoutError => e
  puts "Query timed out: #{e.message}"
rescue CloudwatchQuery::Error => e
  puts "Error: #{e.message}"
end
```

## License

MIT
