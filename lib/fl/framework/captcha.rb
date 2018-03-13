# Namespace for CAPTCHA support.
# This namespace defines APIs to manage the implementation of CAPTCHA used by the framework.

module Fl::Framework::CAPTCHA
  # Base class for CAPTCHA verifiers.

  class Base
    # Initializer.
    #
    # @param [Hash] config A hash containing configuration options.

    def initialize(config = {})
      @config = {
      }

      config.each { |k, v| @config[k] = v }
    end

    # Validate the CAPTCHA response.
    #
    # @param [String] response The response as submitted by the form.
    # @param [String] ip An optional IP address for the requestor.
    #
    # @return [Hash] Returns a hash containing the {Fl::Google::RECAPTCHA} API's response.
    #  In addition to the key/value pairs
    #  returned by the API, `error-messages` contains an array of error messages mapped from the
    #  error codes. Note that we use the {Fl::Google::RECAPTCHA} return value, because it is the typical
    #  implementation used; others will just have to conform.
    #
    # @raise Raises an exception to force subclasses to override it.

    def verify(response, ip = nil)
      raise "please implement #{self.class.name}#verify"
    end
  end
end

require 'fl/google/recaptcha'

module Fl::Framework::CAPTCHA
  # Factory for the framework CAPTCHA implementation.
  # We use a factory so that we can override the CAPTCHA implementation, for example for testing.
  #
  # @param [Hash] config A hash containing configuration options for the CAPTCHA object.
  #
  # @return [Object] Returns an instance of the CAPTCHA implementation. This implementation returns
  #  an instance of {Fl::Google::RECAPTCHA}.
  
  def self.factory(config = {})
    Fl::Google::RECAPTCHA.new(config)
  end
end
