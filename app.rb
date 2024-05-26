# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  git_source(:github) { |repo| "https://github.com/#{repo}.git" }

  gem "activerecord", "7.1.2"
  gem "pg", "1.5.6"
  gem 'async'
  gem "faker"
  gem "csv" # will be deprecated in Ruby 3.4 
end

require "active_record"
require "minitest/autorun"
require "logger"
require "csv"
require "async"

# Establish connection to PostgreSQL
ActiveRecord::Base.establish_connection(
  adapter: "postgresql",
  encoding: "unicode",
  database: "test",
  username: "postgres",
  password: "",
  host: "database",
)

# Create a new database if the current database is not 'db1' and set the connection to 'db1'
db_name = 'db1'
# Drop the database if it exists
puts "Dropping database #{db_name}"
ActiveRecord::Base.connection.drop_database db_name

# Create the database
puts "Creating database #{db_name}"
ActiveRecord::Base.connection.create_database db_name

# Change database connection to the new database
ActiveRecord::Base.establish_connection(
  adapter: "postgresql",
  encoding: "unicode",
  database: db_name,
  username: "postgres",
  password: "",
  host: "database",
)

ActiveRecord::Base.logger = Logger.new(STDOUT)

ActiveRecord::Schema.define do
  create_table :items, force: true do |t|
    t.string :title
    t.string :description
  end
end

class Item < ActiveRecord::Base
end

class OpenAILib
  def generate_description
    sleep(rand(1..10))
    Faker::Lorem.paragraph
  end
end

class BugTest < Minitest::Test
  def test_create_unverified_user
    items = []
    start_time = Time.now

    # Ensure the CSV file exists
    unless File.exist?('items.csv')
      raise "CSV file not found"
    end

    # Use Async to run the generation tasks concurrently
    Async do |task|
      tasks = []

      CSV.foreach('items.csv', encoding: 'utf-8', headers: true, skip_blanks: true, col_sep: ',').with_index(1) do |row, index|
        tasks << task.async do
          item = { title: row['title'], description: OpenAILib.new.generate_description }
          items << item
        end
      end

      # Await all tasks to complete
      tasks.each(&:wait)
    end

    # Check if there are any items to save
    if items.empty?
      puts "No items to save"
      return
    end

    # Save all items to the database within a transaction
    ActiveRecord::Base.transaction do
      items.each do |item|
        Item.create!(item)
      end
    end

    end_time = Time.now
    elapsed_time = end_time - start_time
    puts "Elapsed time: #{elapsed_time} seconds"

    # Assert the item count equals 1000
    total_items = Item.count
    puts "Total items: #{total_items}"
    assert_equal 1000, total_items
  end
end