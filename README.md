# Ukraine Verkhovna Rada Deputy Images

This repository is a copy of the official portraits of deputies in the Ukraine parliament. It's here so that there's a copy available that's no dependent on the parliament site and also so the images can be reliably served over HTTPS to sites like the Ukraine version of They Vote For You.

## Usage

There is a script that fetches the latest copy of the EveryPolician Popolo data and then fetches images for every deputy:

    # Download the images
    ./fetch_images.rb

    # Now commit any changes and push to the repo

It puts these images into `images/#{official_id_of_deputy}.jpg` so you can reliably fetch them from:

    https://raw.githubusercontent.com/OPORA/ukraine_verkhovna_rada_deputy_images/master/#{official_id_of_deputy}.jpg
