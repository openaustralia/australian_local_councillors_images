# frozen_string_literal: true

require 'spec_helper'

describe 'australian_local_councillors_images' do
  describe '.people' do
    context 'missing data' do
      it 'does not raise an exception' do
        VCR.use_cassette('popolo_urls') do
          popolo_urls.each do |url|
            expect { people(at: url) }.to_not raise_error
          end
        end
      end

      it 'returns an empty array' do
        VCR.use_cassette('popolo_urls') do
          people = popolo_urls.map { |url| people(at: url) }
          expect(people.any?(&:empty?)).to be true
        end
      end
    end
  end

  describe '.directory' do
    context 'invalid environment variables' do
      before(:each) do
        set_environment_variable('MORPH_AWS_ACCESS_KEY_ID', 'xxxxxx')
        set_environment_variable('MORPH_AWS_SECRET_ACCESS_KEY', 'xxxxxx')
        set_environment_variable('MORPH_S3_BUCKET', 'xxxxxx')
      end

      it 'raises a helpful message' do
        VCR.use_cassette('s3_invalid_credentials') do
          expect { directory }.to raise_error(SystemExit)
        end
      end

      after(:each) { restore_env }
    end
  end
end
