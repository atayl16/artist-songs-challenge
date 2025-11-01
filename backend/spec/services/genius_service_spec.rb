# frozen_string_literal: true

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
        expect do
          service.search_artist_songs('asdfghjklzxcvbnm')
        end.to raise_error(GeniusService::ArtistNotFoundError, /not found/)
      end
    end

    context 'with invalid input' do
      it 'raises ArgumentError for blank name' do
        expect do
          service.search_artist_songs('')
        end.to raise_error(ArgumentError, /required/)
      end

      it 'raises ArgumentError for too long name' do
        expect do
          service.search_artist_songs('a' * 101)
        end.to raise_error(ArgumentError, /too long/)
      end

      it 'raises ArgumentError for invalid page' do
        expect do
          service.search_artist_songs('Test', page: 0)
        end.to raise_error(ArgumentError, /positive/)
      end

      it 'raises ArgumentError for invalid per_page' do
        expect do
          service.search_artist_songs('Test', per_page: 0)
        end.to raise_error(ArgumentError, /1-50/)

        expect do
          service.search_artist_songs('Test', per_page: 51)
        end.to raise_error(ArgumentError, /1-50/)
      end
    end

    context 'when cache is down' do
      it 'still works without caching', :vcr do
        # Simulate cache failure
        allow(Rails.cache).to receive(:read).and_raise(StandardError, 'Cache error')
        allow(Rails.cache).to receive(:write).and_raise(StandardError, 'Cache error')
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

        expect do
          service.search_artist_songs('Drake')
        end.to raise_error(GeniusService::ApiError, /Invalid API credentials/)
      end

      it 'raises ApiError for 429 rate limit' do
        error = Faraday::TooManyRequestsError.new('Rate limited')
        error.instance_variable_set(:@response, { status: 429 })
        allow(client).to receive(:get).and_raise(error)

        expect do
          service.search_artist_songs('Drake')
        end.to raise_error(GeniusService::ApiError, /Rate limit exceeded/)
      end

      it 'raises ApiError for 500 server error' do
        allow(client).to receive(:get).and_raise(
          Faraday::ServerError.new('Server error')
        )

        expect do
          service.search_artist_songs('Drake')
        end.to raise_error(GeniusService::ApiError, /temporarily unavailable/)
      end

      it 'raises TimeoutError on request timeout' do
        allow(client).to receive(:get).and_raise(Faraday::TimeoutError.new('timeout'))

        expect do
          service.search_artist_songs('Drake')
        end.to raise_error(GeniusService::TimeoutError, /timed out/)
      end

      it 'raises ApiError on connection failure' do
        allow(client).to receive(:get).and_raise(Faraday::ConnectionFailed.new('connection failed'))

        expect do
          service.search_artist_songs('Drake')
        end.to raise_error(GeniusService::ApiError, /Unable to connect/)
      end
    end

    context 'API resilience with name→ID mapping cache' do
      it 'serves stale cache when API is down but cache exists' do
        Rails.cache.clear

        # First request - populate both caches (name→ID mapping and songs cache)
        VCR.use_cassette('genius_service/search_artist_songs/with_valid_artist') do
          result1 = service.search_artist_songs('Kendrick Lamar')
          expect(result1[:meta][:cached]).to be false
          expect(result1[:meta][:stale]).to be false
          expect(result1[:meta][:api_unavailable]).to be false
        end

        # Simulate API outage by stubbing the find_artist call to raise an error
        allow_any_instance_of(Faraday::Connection).to receive(:get)
          .and_raise(Faraday::ServerError.new('API is down'))

        # Second request - should serve stale cache despite API outage
        result2 = service.search_artist_songs('Kendrick Lamar')

        expect(result2[:artist][:name]).to eq('Kendrick Lamar')
        expect(result2[:songs]).to be_an(Array)
        expect(result2[:songs].length).to be > 0
        expect(result2[:meta][:cached]).to be true
        expect(result2[:meta][:stale]).to be true
        expect(result2[:meta][:api_unavailable]).to be true
      end

      it 'raises error when API is down and no cache exists' do
        Rails.cache.clear

        # Stub API to raise error
        allow_any_instance_of(Faraday::Connection).to receive(:get)
          .and_raise(Faraday::ServerError.new('API is down'))

        # First request with no cache should fail
        expect do
          service.search_artist_songs('Drake')
        end.to raise_error(GeniusService::ApiError, /temporarily unavailable/)
      end

      it 'serves stale cache on timeout errors' do
        Rails.cache.clear

        # First request - populate caches
        VCR.use_cassette('genius_service/search_artist_songs/with_valid_artist') do
          service.search_artist_songs('Kendrick Lamar')
        end

        # Simulate timeout
        allow_any_instance_of(Faraday::Connection).to receive(:get)
          .and_raise(Faraday::TimeoutError.new('timeout'))

        # Should serve stale cache
        result = service.search_artist_songs('Kendrick Lamar')
        expect(result[:meta][:stale]).to be true
        expect(result[:meta][:api_unavailable]).to be true
      end

      it 'normalizes artist names in name→ID cache' do
        Rails.cache.clear

        # First request with normal case
        VCR.use_cassette('genius_service/search_artist_songs/with_valid_artist') do
          service.search_artist_songs('Kendrick Lamar')
        end

        # Simulate API outage
        allow_any_instance_of(Faraday::Connection).to receive(:get)
          .and_raise(Faraday::ServerError.new('API is down'))

        # Second request with different case should still find cached mapping
        result = service.search_artist_songs('KENDRICK LAMAR')
        expect(result[:artist][:name]).to eq('Kendrick Lamar')
        expect(result[:meta][:stale]).to be true
      end

      it 'returns fresh data when API recovers' do
        Rails.cache.clear

        # First request - populate caches
        VCR.use_cassette('genius_service/search_artist_songs/with_valid_artist') do
          result1 = service.search_artist_songs('Kendrick Lamar')
          expect(result1[:meta][:stale]).to be false
        end

        # API should work normally with cached songs (from cache) but fresh artist data
        VCR.use_cassette('genius_service/search_artist_songs/with_valid_artist') do
          result2 = service.search_artist_songs('Kendrick Lamar')
          expect(result2[:meta][:cached]).to be true  # Songs from cache
          expect(result2[:meta][:stale]).to be false  # Not stale (API is up)
          expect(result2[:meta][:api_unavailable]).to be false
        end
      end
    end
  end
end
