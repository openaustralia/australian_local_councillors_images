# frozen_string_literal: true

require_relative('../scraper')
require 'pry'
require 'webmock/rspec'
require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir = 'spec/vcr_cassettes'
  c.hook_into :webmock
end

RSpec.configure do |config|
  # Use color not only in STDOUT but also in pagers and files
  config.tty = true
end

def puts(*args); end

def restore_env
  ENV.replace(@original) if @original
  @original = nil
end

def unset_environment_variable(name)
  @original ||= ENV.to_hash
  ENV.delete(name)
end

def set_environment_variable(name, value)
  @original ||= ENV.to_hash
  ENV[name] = value
end
