require 'net/http'
require 'uri'

module Fl::Google
  # Client for the Google reCAPTCHA API.

  class RECAPTCHA < Fl::Framework::CAPTCHA::Base
    # The environment variable that contains the secret.

    SECRET_KEY = 'RECAPTCHA_SECRET'

    # The default URL to the verification API.

    RECAPTCHA_API_URL = 'https://www.google.com/recaptcha/api/siteverify'

    # Initializer.
    #
    # @param [Hash] config A hash containing configuration options.
    # @option config [String] :api_url The URL to the API; defaults to {RECAPTCHA_API_URL}.
    # @option config [String] :secret The secret to pass to the API; if not provided, the
    #  object uses the value stored in the environment value {SECRET_KEY}.

    def initialize(config = {})
      @config = {
      }

      config.each { |k, v| @config[k] = v }

      @config[:api_url] = RECAPTCHA_API_URL unless @config.has_key?(:api_url)
      @config[:secret] = ENV[SECRET_KEY] unless @config.has_key?(:secret)
    end

    # Validate the response.
    #
    # @param [String] response The response as submitted by the form.
    # @param [String] ip An optional IP address for the requestor.
    #
    # @return [Hash] Returns a hash containing the API's response. In addition to the key/value pairs
    #  returned by the API, `error-messages` contains an array of error messages mapped from the
    #  error codes.

    def verify(response, ip = nil)
      if @config[:secret].is_a?(String)
        data = {
          secret: @config[:secret],
          response: response
        }
        data[:remoteip] = ip if ip

        parsed_url = URI.parse(@config[:api_url])
        http = Net::HTTP.new(parsed_url.host, parsed_url.port)
        if parsed_url.scheme.to_sym == :https
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
          
        request = Net::HTTP::Post.new(parsed_url.request_uri)
        request.set_form_data(data)
        begin
          response = http.request(request)

          if response.is_a?(Net::HTTPOK)
            json = ActiveSupport::JSON.decode(response.body)
          else
            json = { 'success' => false, 'error-codes' => [ 'bad-request' ] }
          end
        rescue => ex
            json = { 'success' => false, 'error-codes' => [ 'no-server' ] }
        end
      else
        json = { 'success' => false, 'error-codes' => [ 'no-secret' ] }
      end

      json['error-messages'] = map_error_codes(json) unless json['success']
      json
    end

    # Set the CAPTCHA factory to return an instnce of {RECAPTCHA}.

    def self.register_factory()
      Fl::Framework::CAPTCHA.class_eval do
        def self.factory(config = {})
          RECAPTCHA.new(config)
        end
      end
    end

    private

    def map_error_codes(json)
      if json.has_key?('error-codes')
        json['error-codes'].map do |ec|
          begin
            I18n.tx("fl.google.recaptcha.error-codes.#{ec}")
          rescue => ex
            ec
          end
        end
      else
        [ ]
      end
    end
  end
end
