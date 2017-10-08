# frozen_string_literal: true

# Mechanize is totally overkill for what we need but it supports malformed
# URLs that some councils have for their images and I'm too lazy to work out
# how Mechanize is getting around that
require 'mechanize'
require 'fog'
require 'everypolitician/popolo'
require 'erb'
include ERB::Util

def s3_url(path)
  "https://#{ENV['MORPH_S3_BUCKET']}.s3.amazonaws.com/#{path}"
end

def fetch_and_save_image(source_url:, file_name:)
  puts "Fetching #{source_url}"
  file_body = agent.get(source_url).body

  puts "Saving image to #{s3_url(file_name)}"
  directory.files.create(
    key: file_name,
    body: file_body,
    public: true
  )
end

def clobber_resized_image?
  %w[MORPH_CLOBBER MORPH_CLOBBER_RESIZED_IMAGES].any? { |e| ENV[e] == 'true' }
end

def morph_clobber?
  ENV['MORPH_CLOBBER'] == 'true'
end

def morph_resize_images?
  ENV['MORPH_RESIZE_IMAGES'] == 'true'
end

# TODO: Make the url, width and height configurable with ENV variables
def image_proccessing_proxy_url(image_source_url)
  [
    'http://floating-refuge-38180.herokuapp.com/',
    url_encode(image_source_url),
    "/#{ENV['MORPH_RESIZE_WIDTH']}/",
    "#{ENV['MORPH_RESIZE_HEIGHT']}.jpg"
  ].join
end

def agent
  @agent ||= Mechanize.new
end

def s3_connection
  @s3_connection ||= Fog::Storage.new(
    provider: 'AWS',
    aws_access_key_id: ENV['MORPH_AWS_ACCESS_KEY_ID'],
    aws_secret_access_key: ENV['MORPH_AWS_SECRET_ACCESS_KEY'],
    region: ENV['MORPH_AWS_REGION']
  )
end

def directory
  @directory ||= s3_connection.directories.get(ENV['MORPH_S3_BUCKET'])
end

# rubocop:disable Metrics/LineLength
def popolo_urls
  return @urls if @urls
  @urls = %w[ACT QLD NSW NT SA TAS VIC WA].map do |state|
    "https://github.com/openaustralia/australian_local_councillors_popolo/raw/master/data/#{state}/local_councillor_popolo.json"
  end
  if ENV['MORPH_TARGET_STATE']
    @urls.select! { |url| url.include? ENV['MORPH_TARGET_STATE'] }
  else
    @urls
  end
end
# rubocop:enable Metrics/LineLength

def org_id
  ENV['MORPH_TARGET_ORGANIZATION']
end

def popolo(url:)
  EveryPolitician::Popolo.parse(agent.get(url).body)
end

def people(at:)
  return popolo(url: at).persons unless org_id
  popolo(url: at).memberships.where(org_id: org_id).map do |m|
    popolo(url: at).persons.find_by(id: m.person_id)
  end
rescue Mechanize::ResponseCodeError => e
  puts "WARNING: #{e.message}"
  []
end

def file_names_for(person:)
  file_name = "#{person.id}.jpg"
  resized_file_name = "#{person.id}-#{ENV['MORPH_RESIZE_WIDTH']}x#{ENV['MORPH_RESIZE_HEIGHT']}.jpg"
  [file_name, resized_file_name]
end

def fetch_and_save_original_image(person:)
  file_name, = file_names_for(person: person)

  if morph_clobber? || directory.files.head(file_name).nil?
    fetch_and_save_image(source_url: person.image, file_name: file_name)
  else
    puts "Skipping already saved #{s3_url(file_name)}"
  end
end

def fetch_and_save_resized_image(person:)
  return unless morph_resize_images?

  file_name, resized_file_name = file_names_for(person: person)

  if clobber_resized_image? || directory.files.head(resized_file_name).nil?
    source_url = image_proccessing_proxy_url(s3_url(file_name))
    fetch_and_save_image(source_url: source_url, file_name: resized_file_name)
  else
    puts "Skipping already saved resized image #{s3_url(resized_file_name)}"
  end
end

def no_image?(person:)
  if person.image.nil?
    puts "WARN: No image found for #{person.id}"
    true
  else
    false
  end
end

def main
  popolo_urls.each do |url|
    puts "Fetching Popolo data from: #{url}"
    people(at: url).each do |person|
      next if no_image?(person: person)
      fetch_and_save_original_image(person: person)
      fetch_and_save_resized_image(person: person)
    end
  end
  puts 'All done.'
end

main if $PROGRAM_NAME == __FILE__
