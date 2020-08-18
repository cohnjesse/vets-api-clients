class VeteranVerification
  attr_reader :errors

  def initialize(access_token)
    @authed_header = { Authorization: "Bearer #{access_token}" }
    @env_prefix = 'dev-' # dev is only supported in sample, but an arg could be used to open this up
    @errors = []
  end

  def confirmed_status
    return nil if confirmed_status_response.code != 200
    confirmed_status_response['data']['attributes']['veteran_status'] == 'confirmed'
  end

  def confirmed_status_response
    @confirmed_status_response ||= get('status')
  end

  def service_histories
    return @service_histories if @service_histories
    @service_histories =
      if service_histories_response.code == 200
        service_histories_response['data'].collect { |data| ServiceHistory.new(data) }
      else
        []
      end
  end

  def service_histories_response
    @service_histories_response ||= get('service_history')
  end

  def disability_ratings
    return @disability_ratings if @disability_ratings

    @disability_ratings = []
    return @disability_ratings if disability_ratings_response.code != 200
    Rails.logger.warn disability_ratings_response['data']
    disability_ratings_response['data']["attributes"].each do |key, value|
      modified_rating = {}
      modified_rating[key] =
        if key == 'effective_date'
          Time.zone.parse(value)
        else
          value
        end

      @disability_ratings << modified_rating
    end
    @disability_ratings
  end

  def individual_disability_ratings
    return @individual_disability_ratings if @individual_disability_ratings

    @individual_disability_ratings = []
    return @individual_disability_ratings if disability_ratings_response.code != 200
    disability_ratings_response['data']["attributes"]["individual_ratings"].each do |individual_rating|
      individual_rating.each do |key, value|
          if key == 'effective_date'
            value = Time.zone.parse(value)
          else
            value
          end
      end
      @individual_disability_ratings << individual_rating
    end 
    Rails.logger.warn @individual_disability_ratings
    @individual_disability_ratings
  end

  def disability_ratings_response
    @disability_ratings_response = get('disability_rating', allow: [402])
  end

private
  def get(endpoint, version: 0, allow: [])
    response = HTTParty.get("https://#{@env_prefix}api.va.gov/services/veteran_verification/v#{version}/#{endpoint}", { headers: @authed_header })
    if response.code != 200 && allow.exclude?(response.code)
      @errors << {message: "Accessing #{endpoint} API returned #{Rack::Utils::HTTP_STATUS_CODES[response.code]}", error_objects: response['errors']}
    end
    response
  end
end