# frozen_string_literal: true

require "optparse"
require "json"

module CloudwatchQuery
  class CLI
    FORMATS = %w[table json raw].freeze

    def self.start(argv)
      new.run(argv)
    end

    def run(argv)
      return show_help if argv.empty?

      command = argv.shift
      case command
      when "search"
        search(argv)
      when "groups"
        groups(argv)
      when "query"
        query(argv)
      when "help", "-h", "--help"
        show_help
      when "version", "-v", "--version"
        puts "cwq #{CloudwatchQuery::VERSION}"
      else
        puts "Unknown command: #{command}"
        show_help
        exit 1
      end
    end

    private

    def search(argv)
      options = parse_search_options(argv)
      term = argv.shift

      unless term
        puts "Error: Search term required"
        exit 1
      end

      unless options[:groups]
        puts "Error: Log groups required (-g)"
        exit 1
      end

      configure_from_options(options)

      query = CloudwatchQuery.logs(*options[:groups]).contains(term)
      query = query.since(options[:since]) if options[:since]
      query = query.limit(options[:limit]) if options[:limit]

      results = query.execute
      output_results(results, options[:format])
    rescue CloudwatchQuery::Error => e
      puts "Error: #{e.message}"
      exit 1
    end

    def groups(argv)
      options = parse_groups_options(argv)
      prefix = argv.shift

      configure_from_options(options)

      groups = CloudwatchQuery.list_log_groups(prefix: prefix)
      groups.each { |g| puts g }
    rescue CloudwatchQuery::Error => e
      puts "Error: #{e.message}"
      exit 1
    end

    def query(argv)
      options = parse_query_options(argv)
      query_string = argv.shift

      unless query_string
        puts "Error: Query string required"
        exit 1
      end

      unless options[:groups]
        puts "Error: Log groups required (-g)"
        exit 1
      end

      configure_from_options(options)

      client = CloudwatchQuery::Client.new
      start_time = options[:since] ? TimeHelpers.to_epoch(options[:since]) : (Time.now - 3600).to_i
      end_time = options[:until] ? TimeHelpers.to_epoch(options[:until]) : Time.now.to_i

      results = client.execute(
        query_string: query_string,
        log_group_names: options[:groups],
        start_time: start_time,
        end_time: end_time,
        limit: options[:limit] || 100
      )

      output_results(results, options[:format])
    rescue CloudwatchQuery::Error => e
      puts "Error: #{e.message}"
      exit 1
    end

    def parse_search_options(argv)
      options = { format: "table" }
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: cwq search <term> [options]"
        add_common_options(opts, options)
      end
      parser.parse!(argv)
      options
    end

    def parse_groups_options(argv)
      options = {}
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: cwq groups [prefix] [options]"
        opts.on("-r", "--region REGION", "AWS region") { |v| options[:region] = v }
        opts.on("-p", "--profile PROFILE", "AWS profile") { |v| options[:profile] = v }
      end
      parser.parse!(argv)
      options
    end

    def parse_query_options(argv)
      options = { format: "table" }
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: cwq query <insights_query> [options]"
        add_common_options(opts, options)
      end
      parser.parse!(argv)
      options
    end

    def add_common_options(opts, options)
      opts.on("-g", "--groups GROUPS", "Log groups (comma-separated)") do |v|
        options[:groups] = v.split(",").map(&:strip)
      end
      opts.on("-s", "--since TIME", "Start time (e.g., 1h, 30m, 2d)") do |v|
        options[:since] = parse_time(v)
      end
      opts.on("-u", "--until TIME", "End time") do |v|
        options[:until] = parse_time(v)
      end
      opts.on("-l", "--limit N", Integer, "Max results") { |v| options[:limit] = v }
      opts.on("-f", "--format FORMAT", FORMATS, "Output format (table, json, raw)") do |v|
        options[:format] = v
      end
      opts.on("-r", "--region REGION", "AWS region") { |v| options[:region] = v }
      opts.on("-p", "--profile PROFILE", "AWS profile") { |v| options[:profile] = v }
    end

    def parse_time(str)
      parsed = TimeHelpers.parse_relative_time(str)
      return parsed if parsed

      Time.parse(str)
    rescue ArgumentError
      puts "Error: Invalid time format: #{str}"
      exit 1
    end

    def configure_from_options(options)
      CloudwatchQuery.configure do |config|
        config.region = options[:region] if options[:region]
        config.profile = options[:profile] if options[:profile]
      end
    end

    def output_results(results, format)
      case format
      when "json"
        output_json(results)
      when "raw"
        output_raw(results)
      else
        output_table(results)
      end
    end

    def output_json(results)
      data = results.map(&:to_h)
      puts JSON.pretty_generate(data)
    end

    def output_raw(results)
      results.each { |r| puts r.message }
    end

    def output_table(results)
      return puts "No results found" if results.empty?

      results.each do |result|
        timestamp = result.timestamp || ""
        message = result.message || ""
        puts "#{timestamp}  #{message}"
      end

      puts "\n#{results.count} results"
    end

    def show_help
      puts <<~HELP
        CloudWatch Query CLI

        Usage: cwq <command> [options]

        Commands:
          search <term>     Search logs for a term
          groups [prefix]   List available log groups
          query <query>     Run raw Insights query
          help              Show this help
          version           Show version

        Search Options:
          -g, --groups GROUPS   Log groups (comma-separated, required)
          -s, --since TIME      Start time (e.g., 1h, 30m, 2d)
          -u, --until TIME      End time
          -l, --limit N         Max results (default: 100)
          -f, --format FORMAT   Output format: table, json, raw
          -r, --region REGION   AWS region
          -p, --profile PROFILE AWS profile

        Examples:
          cwq search "ERROR" -g /aws/lambda/api -s 1h
          cwq groups /aws/lambda/
          cwq search "timeout" -g /aws/lambda/api -f json
      HELP
    end
  end
end
