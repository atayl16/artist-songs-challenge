require 'rails_helper'

RSpec.describe 'Artists API', type: :request do
  # Helper method to stub service responses for parameter tests
  def stub_service_response(per_page:)
    allow_any_instance_of(GeniusService).to receive(:search_artist_songs).and_return({
      artist: { name: 'Drake', id: 1 },
      songs: [],
      pagination: { page: 1, per_page: per_page, has_next: false },
      meta: { fetched_at: Time.current, cached: false }
    })
  end

  describe 'GET /api/v1/artists/:name/songs' do
    context 'with valid artist' do
      it 'returns songs', :vcr do
        # URL encode the artist name
        get '/api/v1/artists/Kendrick%20Lamar/songs'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)

        expect(json).to have_key(:artist)
        expect(json).to have_key(:songs)
        expect(json).to have_key(:pagination)
        expect(json).to have_key(:meta)

        expect(json[:artist][:name]).to eq('Kendrick Lamar')
        expect(json[:songs]).to be_an(Array)
      end

      it 'supports pagination', :vcr do
        get '/api/v1/artists/Taylor%20Swift/songs', params: { page: 1, per_page: 10 }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)

        expect(json[:pagination][:page]).to eq(1)
        expect(json[:pagination][:per_page]).to eq(10)
      end

      it 'clamps per_page to 50', :vcr do
        get '/api/v1/artists/Drake/songs', params: { per_page: 100 }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)

        expect(json[:pagination][:per_page]).to eq(50)
      end

      it 'defaults to 50 when per_page is missing' do
        stub_service_response(per_page: 50)
        get '/api/v1/artists/Drake/songs'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)

        expect(json[:pagination][:per_page]).to eq(50)
      end

      it 'defaults to 50 when per_page is 0' do
        stub_service_response(per_page: 50)
        get '/api/v1/artists/Drake/songs', params: { per_page: 0 }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)

        expect(json[:pagination][:per_page]).to eq(50)
      end

      it 'defaults to 50 when per_page is negative' do
        stub_service_response(per_page: 50)
        get '/api/v1/artists/Drake/songs', params: { per_page: -5 }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)

        expect(json[:pagination][:per_page]).to eq(50)
      end

      it 'defaults to 50 when per_page is empty string' do
        stub_service_response(per_page: 50)
        get '/api/v1/artists/Drake/songs', params: { per_page: '' }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)

        expect(json[:pagination][:per_page]).to eq(50)
      end
    end

    context 'with invalid artist' do
      it 'returns 404', :vcr do
        get '/api/v1/artists/asdfghjklzxcvbnm/songs'

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body, symbolize_names: true)

        expect(json[:error]).to include('not found')
      end
    end

    context 'with missing parameters' do
      it 'returns 422 for blank name' do
        # Use empty string encoded as %20 (space)
        get '/api/v1/artists/%20/songs'

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body, symbolize_names: true)

        expect(json[:error]).to include('required')
      end
    end

    context 'when external API fails' do
      before do
        allow_any_instance_of(GeniusService).to receive(:search_artist_songs)
      end

      it 'returns 502 for API errors' do
        allow_any_instance_of(GeniusService).to receive(:search_artist_songs)
          .and_raise(GeniusService::ApiError, 'API is down')

        get '/api/v1/artists/Drake/songs'

        expect(response).to have_http_status(:bad_gateway)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:error]).to eq('API is down')
      end

      it 'returns 504 for timeout errors' do
        allow_any_instance_of(GeniusService).to receive(:search_artist_songs)
          .and_raise(GeniusService::TimeoutError, 'Request timed out')

        get '/api/v1/artists/Drake/songs'

        expect(response).to have_http_status(:gateway_timeout)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:error]).to eq('Request timed out')
      end
    end

    context 'rate limiting' do
      it 'returns 429 after exceeding rate limit' do
        # Stub the service to avoid VCR/API calls
        allow_any_instance_of(GeniusService).to receive(:search_artist_songs).and_return({
          artist: { name: 'Drake', id: 1 },
          songs: [],
          pagination: { page: 1, per_page: 50, has_next: false },
          meta: { fetched_at: Time.current, cached: false }
        })

        # Rack::Attack throttles to 10 requests per minute for song searches
        # Make 10 successful requests
        10.times do
          get '/api/v1/artists/Drake/songs'
          expect(response).to have_http_status(:ok)
        end

        # 11th request should be rate limited
        get '/api/v1/artists/Drake/songs'
        expect(response).to have_http_status(:too_many_requests)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:error]).to include('Rate limit exceeded')
      end
    end
  end
end
