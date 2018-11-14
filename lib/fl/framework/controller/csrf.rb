module Fl::Framework::Controller
  # Mixin module to add utilities for managing CSRF.
  # This module adds functionaity to send CSRF authenticity tokens back to the client, and get them
  # back on subsequent requests. It requires that the client send back in a header the token that was sent 
  # to the client in a cookie.
  #
  # To use this module:
  #   class ApplicationController < ActionController::Base
  #     include Fl::Framework::Controller::CSRF
  #
  #     self.csrf_cookie_name = '_MYAPP-XSRF-TOKEN'
  #     self.csrf_header_name = 'X-MYAPP-XSRF-TOKEN'
  #   end
  # Where +MYAPP+ is a tag that identifies the Rails application. (Technically, you can override the full
  # names, but keeping a consistent format may help in identifying the purpose of the headers and cookies.)
  # This adds the CSRF support methods, and registers {InstanceMethods#set_custom_csrf_cookie} as an
  # +after_action+, so that the custom CSRF cookie is set automatically.
  #
  # A byproduct of loading this module is that the +request_authenticity_tokens+ in ApplicationController::Base
  # is extended to add the authenticity token from the custom header to the list of authenticity tokens
  # available to the controller. As a consequence, the custom header's token is made available throughout
  # the application, including to packages like Devise that run as a Rails engine.

  module CSRF
    # The default name of the CSRF cookie.
    # Different applications should call {ClassMethods#csrf_cookie_name=} to use an application-specific
    # value (which should be consistent with the one defined in the client).

    DEFAULT_CSRF_COOKIE_NAME = '_FL-XSRF-TOKEN'

    # The default name of the CSRF header name.
    # Different applications should call {ClassMethods#csrf_header_name=} to use an application-specific
    # value (which should be consistent with the one defined in the client).

    DEFAULT_CSRF_HEADER_NAME = 'X-FL-XSRF-TOKEN'

    # Class methods for CSRF support.

    module ClassMethods
      # The current value of the CSRF cookie name.
      #
      # @return [String] Returns the current value of the CSRF cookie name.

      def csrf_cookie_name()
        @@csrf_cookie_name
      end
      
      # Set the current value of the CSRF cookie name.
      #
      # @param name [String] The new value of the CSRF cookie name.

      def csrf_cookie_name=(name)
        @@csrf_cookie_name = name
      end

      # The current value of the CSRF header name.
      #
      # @return [String] Returns the current value of the CSRF header name.

      def csrf_header_name()
        @@csrf_header_name
      end

      # Set the current value of the CSRF header name.
      #
      # @param name [String] The new value of the CSRF header name.

      def csrf_header_name=(name)
        @@csrf_header_name = name
      end
    end

    # The methods in this module are installed as instance method of the including class.

    module InstanceMethods
      # Place an authenticity token in the custom CSRF cookie.
      # The value is obtained from a call to +form_authenticity_token+.
      # Note that the cookie is set only if +protect_against_forgery?+ returns +true+.

      def set_custom_csrf_cookie
        # Not sure if this should be done unconditionally. The Rails security guide indicates that
        # using CSRF protection with JSON APIs may not be needed, since the client typically manages state
        # and therefore the API calls are stateless. However, the same security guide also states that CSRF
        # protection should be turned on for all calls.

        if protect_against_forgery?
          csrf_cookie_name = self.class.csrf_cookie_name
          cookies[csrf_cookie_name] = form_authenticity_token
        end
      end

      # Check the authenticity token from the custom CSRF header.
      # This method extracts the authenticity token that was passed in the CSRF header, and checks
      # if it is consistent with what is stored in the session.

      def validate_custom_authenticity_token
        valid_authenticity_token?(session, custom_authenticity_token())
      end

      # Get the authenticity token from the custom CSRF header.
      # This method extracts the authenticity token that was passed in the CSRF header and returns it.
      #
      # @return [String,nil] The authenticity token stored in the CSRF header, if one is present.
      #  Returns +nil+ if the header is not present.

      def custom_authenticity_token
        csrf_header_name = self.class.csrf_header_name
        request.headers[csrf_header_name]
      end
    end

    # Perform actions when the module is included.
    # - Injects the class and instance methods.
    # - Calls +:protect_from_forgery+ to trigger an exception.
    # - Calls +after_filter+ to add {InstanceMethods#set_custom_csrf_cookie} to place an authentication
    #   token in a custom cookie.

    def self.included(base)
      base.extend ClassMethods

      base.instance_eval do
        @@csrf_cookie_name = DEFAULT_CSRF_COOKIE_NAME
        @@csrf_header_name = DEFAULT_CSRF_HEADER_NAME
      end

      base.class_eval do
        include InstanceMethods

        # Prevent CSRF attacks by raising an exception.
        # For APIs, you may want to use :null_session instead.

        protect_from_forgery with: :exception

        # The client is expected to look for a cookie that contains the CSRF token, and send it down the pipe
        # in a header on subsequent requests.

#        after_action :set_custom_csrf_cookie
      end
    end
  end
end

# Base class for controllers.

class ActionController::Base
  # @!visibility private
  alias _cf_request_authenticity_tokens request_authenticity_tokens

  # Extends the standard implementation to add the custom header's token.
  # If the controller responds to
  # {Fl::Framework::Controller::CSRF::InstanceMethods#custom_authenticity_token},
  # the value returned by that method is appended to the list of available tokens.
  #
  # @return [Array<String,nil>] Returns an array or strings (or +nil+ values) containing the available
  #  authenticity tokens.

  def request_authenticity_tokens
    rv = _cf_request_authenticity_tokens()

    if self.respond_to?(:custom_authenticity_token)
      rv << self.custom_authenticity_token
    end

    rv
  end
end
