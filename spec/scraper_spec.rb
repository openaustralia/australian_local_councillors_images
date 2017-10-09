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
end
