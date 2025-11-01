class GeniusService
  BASE_URL = ENV.fetch("GENIUS_API_BASE_URL", "https://api.genius.com")
  TIMEOUT = 10
  CACHE_TTL = 1.hour.to_i
  PER_PAGE = 50  # Genius API maximum
  CACHE_VERSION = "v1"  # Increment when response format changes

  class ArtistNotFoundError < StandardError; end
  class ApiError < StandardError; end
  class TimeoutError < StandardError; end

  def initialize
    @client = Faraday.new(BASE_URL) do |f|
      f.request :authorization, "Bearer", ENV.fetch("GENIUS_API_KEY")
      f.request :json
      f.request :retry, max: 3, interval: 0.5, backoff_factor: 2, exceptions: [ Faraday::TimeoutError, Faraday::ConnectionFailed ]
      f.response :raise_error
      f.adapter Faraday.default_adapter

      f.options.timeout = TIMEOUT
      f.options.open_timeout = 5
    end
  end

  def search_artist_songs(artist_name, page: 1, per_page: PER_PAGE)
    validate_input!(artist_name, page, per_page)

    # Find artist first to get canonical ID
    artist = find_artist(artist_name)

    # Check cache by artist ID (prevents collisions for artists with same name)
    cached = fetch_from_cache(artist["id"], page, per_page)
    return cached.merge(artist: { name: artist["name"], id: artist["id"] }) if cached

    # Fetch from API
    songs_data = fetch_songs_page(artist["id"], page, per_page)

    result = format_response(artist, songs_data, page, per_page)
    store_in_cache(artist["id"], page, per_page, result)

    result
  end

  private

    def validate_input!(name, page, per_page)
      raise ArgumentError, "Artist name required" if name.blank?
      raise ArgumentError, "Artist name too long (max 100 chars)" if name.length > 100
      raise ArgumentError, "Page must be positive" if page < 1
      raise ArgumentError, "Per page must be 1-#{PER_PAGE}" unless (1..PER_PAGE).cover?(per_page)
    end

  def cache_key(artist_id, page, per_page)
    # Cache by artist ID to prevent collisions (e.g., multiple artists with same name)
    "#{CACHE_VERSION}:genius:artist:id:#{artist_id}:p#{page}:pp#{per_page}"
  end

  def fetch_from_cache(artist_id, page, per_page)
    key = cache_key(artist_id, page, per_page)
    cached_data = Rails.cache.read(key)
    return nil unless cached_data

    result = cached_data.deep_symbolize_keys
    result[:meta][:cached] = true
    result
  rescue => e
    Rails.logger.warn("Cache read error: #{e.message}")
    nil  # Graceful degradation
  end

  def store_in_cache(artist_id, page, per_page, data)
    key = cache_key(artist_id, page, per_page)
    Rails.cache.write(key, data, expires_in: CACHE_TTL)
  rescue => e
    Rails.logger.warn("Failed to cache: #{e.message}")
    # Don't fail the request if caching fails
  end

  def find_artist(name)
    response = @client.get("/search", q: name)
    data = JSON.parse(response.body)
    hits = data.dig("response", "hits") || []

    raise ArtistNotFoundError, "Artist '#{name}' not found" if hits.empty?

    # Try exact match first (case-insensitive)
    artist_hit = hits.find { |hit|
      hit.dig("result", "primary_artist", "name")&.downcase == name.downcase
    }

    # Fall back to first result if no exact match (Genius search is usually accurate)
    artist_hit ||= hits.first

    artist_hit.dig("result", "primary_artist")
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse Genius API response: #{e.message}")
    raise ApiError, "Invalid response from Genius API"
  rescue Faraday::ClientError => e
    handle_client_error(e)
  rescue Faraday::TimeoutError
    raise TimeoutError, "Request timed out after #{TIMEOUT} seconds"
  rescue Faraday::ServerError => e
    Rails.logger.error("Genius server error: #{e.message}")
    raise ApiError, "Genius API temporarily unavailable"
  rescue Faraday::Error => e
    Rails.logger.error("Genius API error: #{e.class} - #{e.message}")
    raise ApiError, "Unable to connect to Genius API"
  end

  def fetch_songs_page(artist_id, page, per_page)
    response = @client.get("/artists/#{artist_id}/songs", {
      per_page: per_page,
      page: page,
      sort: "popularity"
    })

    data = JSON.parse(response.body)
    songs = data.dig("response", "songs") || []
    next_page = data.dig("response", "next_page")

    { songs: songs, has_next: next_page.present? }
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse Genius API response: #{e.message}")
    raise ApiError, "Invalid response from Genius API"
  rescue Faraday::ClientError => e
    handle_client_error(e)
  rescue Faraday::TimeoutError
    raise TimeoutError, "Request timed out after #{TIMEOUT} seconds"
  rescue Faraday::ServerError => e
    Rails.logger.error("Genius server error: #{e.message}")
    raise ApiError, "Genius API temporarily unavailable"
  rescue Faraday::Error => e
    Rails.logger.error("Genius API error: #{e.class} - #{e.message}")
    raise ApiError, "Unable to connect to Genius API"
  end

  def handle_client_error(error)
    status = error.response[:status]
    case status
    when 401 then raise ApiError, "Invalid API credentials"
    when 429 then raise ApiError, "Rate limit exceeded"
    else raise ApiError, "API request failed (#{status})"
    end
  end

  def format_response(artist, songs_data, page, per_page)
    {
      artist: {
        name: artist["name"],
        id: artist["id"]
      },
      songs: format_songs(songs_data[:songs]),
      pagination: {
        page: page,
        per_page: per_page,
        has_next: songs_data[:has_next]
      },
      meta: {
        fetched_at: Time.current,
        cached: false
      }
    }
  end

  def format_songs(songs)
    songs.map do |song|
      {
        id: song["id"],
        title: song["title"],
        url: song["url"],
        release_date: song["release_date_for_display"]
      }
    end
  end
end
