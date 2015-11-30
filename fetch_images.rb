#!/usr/bin/env ruby
require "json"
require "open-uri"
require "fog"

EVERYPOLITICIAN_URL = "https://raw.githubusercontent.com/everypolitician/everypolitician-data/master/data/Ukraine/Verkhovna_Rada/ep-popolo-v1.0.json"
S3_BUCKET = "ukraine-verkhovna-rada-deputy-images"

s3_connection = Fog::Storage.new(
  provider: "AWS",
  aws_access_key_id: ENV["MORPH_AWS_ACCESS_KEY_ID"],
  aws_secret_access_key: ENV["MORPH_AWS_SECRET_ACCESS_KEY"]
)
directory = s3_connection.directories.get(S3_BUCKET)

people = JSON.parse(open(EVERYPOLITICIAN_URL).read)["persons"]

people.each do |person|
  rada_id = person["identifiers"].find { |i| i["scheme"] == "rada" }["identifier"]
  file_name = "#{rada_id}.jpg"

  puts "Saving https://s3.amazonaws.com/ukraine-verkhovna-rada-deputy-images/#{file_name}"
  directory.files.create(
    key: file_name,
    body: open(person["image"]).read,
    public: true
  )
end

puts "All done."
