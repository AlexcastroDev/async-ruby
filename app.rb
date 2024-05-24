# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  git_source(:github) { |repo| "https://github.com/#{repo}.git" }

  gem "activerecord", "7.1.2"
  gem "sqlite3", "1.4.2"
  gem 'async'
  gem "faker"
end

require "active_record"
require "minitest/autorun"
require "logger"
require "csv"
require "async"

# This connection will do for database-independent bug reports.
ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  encoding: "unicode",
  database: ":memory:",
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

    # Save all items to the database after generating descriptions in a single insert
    Item.create!(items)

    end_time = Time.now
    elapsed_time = end_time - start_time
    puts "Elapsed time: #{elapsed_time} seconds"

    # Assert the item count equals 1000
    total_items = Item.count
    puts "Total items: #{total_items}"
    assert_equal 1000, total_items
  end
end