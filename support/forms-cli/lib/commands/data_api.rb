# frozen_string_literal: true

require "colorize"
require_relative "../utilities/data_api_connection"
require_relative "../utilities/helpers"

# Executes statements on AWS RDS using the Data API.
class DataApi
  include Helpers

  def run
    @options = {}
    parse_options
    return unless aws_authenticated? && valid_options?

    @connection = DataApiConnection.new(fetch_environment, @options[:database], @options[:cluster], @options[:user])

    begin
      print execute_statement
    rescue RuntimeError => e
      puts "Something went wrong: #{e.message}".red
    end
  end

private

  def print(results)
    puts JSON.pretty_generate({
      updated: results.number_of_records_updated,
      records: results.records,
    })
  end

  def valid_options?
    %i[statement database].each do |arg|
      if @options[arg].nil?
        puts "#{arg} must be provided".red
        return false
      end
    end

    unless %w[forms-admin forms-runner].include? @options[:database]
      puts "database must be either 'forms-admin' or 'forms-runner'".red
      return false
    end

    true
  end

  def parse_options
    OptionParser.new { |opts|
      opts.banner = "
      Executes the provided statement on the provide database for the currently
      authenticated shell.

      Run in a authorized shell using gds-cli or aws-vault.

      Example:
      gds aws forms-dev-support -- forms data_api --database forms-admin --cluster aurora-v2-cluster-dev --statement 'select * from forms;'\n\n"

      opts.on("-h", "--help", "Prints help") do
        puts opts
        exit
      end

      opts.on("-dDATABASE", "--database=DATABASE", "[Mandatory] database to query, forms-runner forms-admin") do |database|
        @options[:database] = database
      end

      opts.on("-cCLUSTER", "--cluster=CLUSTER", "The cluster the database is in") do |cluster|
        @options[:cluster] = cluster
      end

      opts.on("-sSTATEMENT", "--statement=STATEMENT", "[Mandatory] The statement to execute") do |statement|
        @options[:statement] = statement
      end

      opts.on("-uUSER", "--user=USER", "The database user to connect as") do |user|
        @options[:user] = user
      end
    }.parse!
  end

  def execute_statement
    @connection.execute_statement(@options[:statement])
  end
end
