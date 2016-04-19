#!/usr/bin/env ruby
require "open-uri"
require "fog"
require "everypolitician/popolo"

s3_connection = Fog::Storage.new(
  provider: "AWS",
  aws_access_key_id: ENV["MORPH_AWS_ACCESS_KEY_ID"],
  aws_secret_access_key: ENV["MORPH_AWS_SECRET_ACCESS_KEY"]
)
directory = s3_connection.directories.get(ENV['MORPH_S3_BUCKET'])

ENV["MORPH_POPOLO_URLS"].split.each do |url|
  people = EveryPolitician::Popolo.read(open(url)).persons

  people.each do |person|
    file_name = "#{person.id}.jpg"
    s3_url = "https://#{ENV['MORPH_S3_BUCKET']}.s3.amazonaws.com/#{file_name}"

    if ENV["MORPH_CLOBBER"] == "true" || directory.files.head(file_name).nil?
      puts "Saving #{s3_url}"
      directory.files.create(
        key: file_name,
        body: open(person.image).read,
        public: true
      )
    else
      puts "Skipping already saved #{s3_url}"
    end
  end
end

puts "All done."
