require 'rails_helper'

RSpec.describe GeniusService do
  let(:service) { described_class.new }

  describe '#search_artist_songs' do
    context 'with valid artist' do
      it 'returns artist and songs', :vcr do
        result = service.search_artist_songs('Kendrick Lamar')

        expect(result[:artist][:name]).to eq('Kendrick Lamar')
        expect(result[:artist][:id]).to be_a(Integer)
        expect(result[:songs]).to be_an(Array)
        expect(result[:songs].first).to have_key(:title)
        expect(result[:songs].first).to have_key(:url)
        expect(result[:pagination]).to include(:page, :per_page, :has_next)
        expect(result[:meta]).to include(:fetched_at, :cached)
        expect(result[:meta][:cached]).to be false
      end

      it 'returns paginated results', :vcr do
        result = service.search_artist_songs('Taylor Swift', page: 1, per_page: 10)

        expect(result[:songs].length).to eq(10)
        expect(result[:pagination][:page]).to eq(1)
        expect(result[:pagination][:per_page]).to eq(10)
      end

      it 'caches results on second call' do
        # Clear cache first
        Rails.cache.clear

        # First call - cache miss
        VCR.use_cassette('genius_service/search_artist_songs/with_valid_artist') do
          result1 = service.search_artist_songs('Kendrick Lamar')
          expect(result1[:meta][:cached]).to be false
        end

        # Second call - cache hit (requires VCR for artist lookup, but songs come from cache)
        VCR.use_cassette('genius_service/search_artist_songs/with_valid_artist') do
          result2 = service.search_artist_songs('Kendrick Lamar')
          expect(result2[:meta][:cached]).to be true
        end
      end
    end

    context 'with invalid artist' do
      it 'raises ArtistNotFoundError', :vcr do
        expect {
          service.search_artist_songs('asdfghjklzxcvbnm')
        }.to raise_error(GeniusService::ArtistNotFoundError, /not found/)
      end
    end

    context 'with invalid input' do
      it 'raises ArgumentError for blank name' do
        expect {
          service.search_artist_songs('')
        }.to raise_error(ArgumentError, /required/)
      end

      it 'raises ArgumentError for too long name' do
        expect {
          service.search_artist_songs('a' * 101)
        }.to raise_error(ArgumentError, /too long/)
      end

      it 'raises ArgumentError for invalid page' do
        expect {
          service.search_artist_songs('Test', page: 0)
        }.to raise_error(ArgumentError, /positive/)
      end

      it 'raises ArgumentError for invalid per_page' do
        expect {
          service.search_artist_songs('Test', per_page: 0)
        }.to raise_error(ArgumentError, /1-50/)

        expect {
          service.search_artist_songs('Test', per_page: 51)
        }.to raise_error(ArgumentError, /1-50/)
      end
    end

    context 'when cache is down' do
      it 'still works without caching', :vcr do
        # Simulate cache failure
        allow(Rails.cache).to receive(:read).and_raise(StandardError, "Cache error")
        allow(Rails.cache).to receive(:write).and_raise(StandardError, "Cache error")
        allow(Rails.logger).to receive(:warn)

        result = service.search_artist_songs('Kendrick Lamar')

        expect(result[:artist][:name]).to eq('Kendrick Lamar')
        expect(Rails.logger).to have_received(:warn).at_least(:once)
      end
    end

    context 'when API returns errors' do
      let(:client) { instance_double(Faraday::Connection) }

      before do
        allow(Faraday).to receive(:new).and_return(client)
        allow(Rails.cache).to receive(:read).and_return(nil)
      end

      it 'raises ApiError for 401 unauthorized' do
        error = Faraday::UnauthorizedError.new('Unauthorized')
        error.instance_variable_set(:@response, { status: 401 })
        allow(client).to receive(:get).and_raise(error)

        expect {
          service.search_artist_songs('Drake')
        }.to raise_error(GeniusService::ApiError, /Invalid API credentials/)
      end

      it 'raises ApiError for 429 rate limit' do
        error = Faraday::TooManyRequestsError.new('Rate limited')
        error.instance_variable_set(:@response, { status: 429 })
        allow(client).to receive(:get).and_raise(error)

        expect {
          service.search_artist_songs('Drake')
        }.to raise_error(GeniusService::ApiError, /Rate limit exceeded/)
      end

      it 'raises ApiError for 500 server error' do
        allow(client).to receive(:get).and_raise(
          Faraday::ServerError.new('Server error')
        )

        expect {
          service.search_artist_songs('Drake')
        }.to raise_error(GeniusService::ApiError, /temporarily unavailable/)
      end

      it 'raises TimeoutError on request timeout' do
        allow(client).to receive(:get).and_raise(Faraday::TimeoutError.new('timeout'))

        expect {
          service.search_artist_songs('Drake')
        }.to raise_error(GeniusService::TimeoutError, /timed out/)
      end

      it 'raises ApiError on connection failure' do
        allow(client).to receive(:get).and_raise(Faraday::ConnectionFailed.new('connection failed'))

        expect {
          service.search_artist_songs('Drake')
        }.to raise_error(GeniusService::ApiError, /Unable to connect/)
      end
    end
  end
end
