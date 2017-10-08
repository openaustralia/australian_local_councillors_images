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

def fetch_and_save_image(agent:, directory:, source_url:, file_name:)
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

def organization_id
  ENV['MORPH_TARGET_ORGANIZATION']
end

def popolo
  @popolo ||= EveryPolitician::Popolo.parse(agent.get(url).body)
end

def people
  if organization_id
    puts "Searching for organization #{organization_id}"
    memberships = popolo.memberships.where(organization_id: organization_id)
    memberships.map { |m| popolo.persons.find_by(id: m.person_id) }
  else
    popolo.persons
  end
end

popolo_urls.each do |url|
  puts "Fetching Popolo data from: #{url}"

  people.each do |person|
    if person.image.nil?
      puts "WARN: No image found for #{person.id}"
      next
    end

    file_name = "#{person.id}.jpg"
    resized_file_name = "#{person.id}-#{ENV['MORPH_RESIZE_WIDTH']}x#{ENV['MORPH_RESIZE_HEIGHT']}.jpg"

    if morph_clobber? || directory.files.head(file_name).nil?
      fetch_and_save_image(agent: agent, directory: directory, source_url: person.image, file_name: file_name)
    else
      puts "Skipping already saved #{s3_url(file_name)}"
    end

    if morph_resize_images?
      if clobber_resized_image? || directory.files.head(resized_file_name).nil?
        source_url = image_proccessing_proxy_url(s3_url(file_name))
        fetch_and_save_image(agent: agent, directory: directory, source_url: source_url, file_name: resized_file_name)
      else
        puts "Skipping already saved resized image #{s3_url(resized_file_name)}"
      end
    end
  end
end

puts 'All done.'
