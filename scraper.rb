#!/usr/bin/env ruby
# Mechanize is totally overkill for what we need but it supports malformed
# URLs that some councils have for their images and I'm too lazy to work out
# how Mechanize is getting around that
require "mechanize"
require "fog"
require "everypolitician/popolo"
require "erb"
include ERB::Util

def s3_url(path)
  "https://#{ENV['MORPH_S3_BUCKET']}.s3.amazonaws.com/#{path}"
end

def fetch_and_save_image(agent, directory, source_url, file_name)
  puts "Fetching #{source_url}"
  file_body = agent.get(source_url).body

  puts "Saving image to #{s3_url(file_name)}"
  directory.files.create(
    key: file_name,
    body: file_body,
    public: true
  )
end

# TODO: Make the url, width and height configurable with ENV variables
def image_proccessing_proxy_url(image_source_url)
  "http://floating-refuge-38180.herokuapp.com/" +
   url_encode(image_source_url) +
   "/#{ENV["MORPH_RESIZE_WIDTH"]}/" +
   "#{ENV["MORPH_RESIZE_HEIGHT"]}.jpg"
end

agent = Mechanize.new
s3_connection = Fog::Storage.new(
  provider: "AWS",
  aws_access_key_id: ENV["MORPH_AWS_ACCESS_KEY_ID"],
  aws_secret_access_key: ENV["MORPH_AWS_SECRET_ACCESS_KEY"],
  region: ENV["MORPH_AWS_REGION"]
)
directory = s3_connection.directories.get(ENV['MORPH_S3_BUCKET'])

popolo_urls = [
  "https://github.com/openaustralia/australian_local_councillors_popolo/raw/master/nsw_local_councillor_popolo.json",
  "https://github.com/openaustralia/australian_local_councillors_popolo/raw/master/vic_local_councillor_popolo.json",
  "https://github.com/openaustralia/australian_local_councillors_popolo/raw/master/qld_local_councillor_popolo.json",
  "https://github.com/openaustralia/australian_local_councillors_popolo/raw/master/wa_local_councillor_popolo.json",
  "https://github.com/openaustralia/australian_local_councillors_popolo/raw/master/tas_local_councillor_popolo.json",
  "https://github.com/openaustralia/australian_local_councillors_popolo/raw/master/act_local_councillor_popolo.json",
  "https://github.com/openaustralia/australian_local_councillors_popolo/raw/master/nt_local_councillor_popolo.json",
  "https://github.com/openaustralia/australian_local_councillors_popolo/raw/master/sa_local_councillor_popolo.json"
]

popolo_urls.select! {|url| url.include? ENV['MORPH_TARGET_STATE'] } if ENV['MORPH_TARGET_STATE']

popolo_urls.each do |url|
  puts "Fetching Popolo data from: #{url}"
  popolo = EveryPolitician::Popolo.parse(agent.get(url).body)
  organization_id = ENV["MORPH_TARGET_ORGANIZATION"]

  people = if organization_id
    puts "Searching for organization #{organization_id}"
    memberships = popolo.memberships.where(organization_id: organization_id)
    memberships.map { |m| popolo.persons.find_by(id: m.person_id) }
  else
    popolo.persons
  end

  people.each do |person|
    if person.image.nil?
      puts "WARN: No image found for #{person.id}"
      next
    end

    file_name = "#{person.id}.jpg"
    resized_file_name = "#{person.id}-#{ENV["MORPH_RESIZE_WIDTH"]}x#{ENV["MORPH_RESIZE_HEIGHT"]}.jpg"

    if ENV["MORPH_CLOBBER"] == "true" || directory.files.head(file_name).nil?
      fetch_and_save_image(agent, directory, person.image, file_name)
    else
      puts "Skipping already saved #{s3_url(file_name)}"
    end

    if ENV["MORPH_RESIZE_IMAGES"] == "true"
      if ENV["MORPH_CLOBBER"] == "true" || ENV["MORPH_CLOBBER_RESIZED_IMAGES"] == "true" || directory.files.head(resized_file_name).nil?
        fetch_and_save_image(
          agent,
          directory,
          image_proccessing_proxy_url(s3_url(file_name)),
          resized_file_name
        )
      else
        puts "Skipping already saved resized image #{s3_url(resized_file_name)}"
      end
    end
  end
end

puts "All done."
