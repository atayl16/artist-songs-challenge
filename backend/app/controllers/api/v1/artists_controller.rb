# frozen_string_literal: true

module Api
  module V1
    class ArtistsController < ApplicationController
      def songs
        page = params[:page]&.to_i || 1
        per_page = (params[:per_page]&.to_i || GeniusService::PER_PAGE).clamp(1, GeniusService::PER_PAGE)

        result = genius_service.search_artist_songs(params[:name], page: page, per_page: per_page)

        render json: result, status: :ok
      rescue ArgumentError => e
        render json: { error: e.message }, status: :unprocessable_content
      rescue GeniusService::ArtistNotFoundError => e
        render json: { error: e.message }, status: :not_found
      rescue GeniusService::TimeoutError => e
        render json: { error: e.message }, status: :gateway_timeout
      rescue GeniusService::ApiError => e
        render json: { error: e.message }, status: :bad_gateway
      rescue StandardError => e
        Rails.logger.error("Unexpected error: #{e.class} - #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))

        render json: {
          error: 'An unexpected error occurred. Please try again later.'
        }, status: :internal_server_error
      end

      private

      def genius_service
        @genius_service ||= GeniusService.new
      end
    end
  end
end
