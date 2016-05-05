#!/usr/bin/env ruby
# Mechanize is totally overkill for what we need but it supports malformed
# URLs that some councils have for their images and I'm too lazy to work out
# how Mechanize is getting around that
require "mechanize"
require "fog"
require "everypolitician/popolo"
require "erb"
include ERB::Util

# TODO: Make the url, width and height configurable with ENV variables
def image_proccessing_proxy_url(image_source_url)
  "http://floating-refuge-38180.herokuapp.com/" + url_encode(image_source_url) + "/80/88.jpg"
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
    resized_file_name = "#{person.id}-80x88.jpg"
    s3_url = "https://#{ENV['MORPH_S3_BUCKET']}.s3.amazonaws.com/#{file_name}"
    s3_resized_url = "https://#{ENV['MORPH_S3_BUCKET']}.s3.amazonaws.com/#{resized_file_name}"

    if ENV["MORPH_CLOBBER"] == "true" || directory.files.head(file_name).nil?
      puts "Fetching #{person.image}"
      image = agent.get(person.image).body
      puts "Saving #{s3_url}"
      directory.files.create(
        key: file_name,
        body: image,
        public: true
      )
    else
      puts "Skipping already saved #{s3_url}"
    end

    # TODO: Add option to reprocess/clobber these files
    if directory.files.head(resized_file_name).nil?
      puts "Fetching #{image_proccessing_proxy_url(s3_url)}"
      resized_image = agent.get(image_proccessing_proxy_url(s3_url)).body
      puts "Saving resized image to #{s3_url}"
      directory.files.create(
        key: resized_file_name,
        body: resized_image,
        public: true
      )
    else
      puts "Skipping already saved resized image #{s3_resized_url}"
    end
  end
end

puts "All done."
