#!/usr/bin/env ruby
require "json"
require "open-uri"

EVERYPOLITICIAN_URL = "https://raw.githubusercontent.com/everypolitician/everypolitician-data/master/data/Ukraine/Verkhovna_Rada/ep-popolo-v1.0.json"

people = JSON.parse(open(EVERYPOLITICIAN_URL).read)["persons"]

people.each do |person|
  rada_id = person["identifiers"].find { |i| i["scheme"] == "rada" }["identifier"]

  puts "Saving image for person with official ID: #{rada_id}..."
  open("images/#{rada_id}.jpg", "wb") do |file|
    file << open(person["image"]).read
  end
end

puts "All done."
