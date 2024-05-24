# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  git_source(:github) { |repo| "https://github.com/#{repo}.git" }

  gem "activerecord", "7.1.2"
  gem "pg"
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
  adapter: "postgresql",
  encoding: "unicode",
  database: ENV["DB_NAME"],
  username: "postgres",
  password: "",
  host: ENV["DB_HOST"],
)

ActiveRecord::Base.logger = Logger.new(STDOUT)

ActiveRecord::Schema.define do
  create_table :items, id: :serial, force: true do |t|
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
  def test_async_task
    items = []
    start_time = Time.now

    Async do |task|
      tasks = []

      CSV.foreach('items.csv', encoding: 'utf-8', headers: true, skip_blanks: true, col_sep: ',').with_index(1) do |row, index|
        tasks << task.async do
          item = Item.new(title: row['title'])
          item.description = OpenAILib.new.generate_description
          items << item
        end
      end

      tasks.each(&:wait)
    end

    Item.transaction do
      items.each(&:save!)
    end

    end_time = Time.now
    elapsed_time = end_time - start_time
    puts "Elapsed time: #{elapsed_time} seconds"

    puts "Items count: #{Item.count}"

    assert_equal 1000, Item.count
  end
end
