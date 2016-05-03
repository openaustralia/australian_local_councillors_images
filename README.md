# Australia Local Councillors Images

This downloads a copy of images from Popolo data and saves them to S3. This is so the images are available over HTTPS and reliably available.

This runs on morph.io to ensure the images are always up to date.

The images are publicy available at:

    https://australian-local-councillors-images.s3.amazonaws.com/#{Popolo ID}.jpg

## Usage

The code is fairly generic and all the configuration is stored in environment variable so you should be able to repurpose this quite easily.

All the expected environment variables are documented in `.env.example`. To test locally, copy this to `.env` and replace values with real ones. To run the script first install gems:

    bundle

Then run:

    bundle exec dotenv ruby scraper.rb

To speed things up, you can specify an Australian state or territory to target
using the environment variable `ENV["MORPH_TARGET_STATE"]`, e.g.:

    MORPH_TARGET_STATE=sa

You can also target a specific organization by id using `ENV["MORPH_TARGET_ORGANIZATION"]`, e.g.:

    MORPH_TARGET_ORGANIZATION=legislature/city_of_unley
