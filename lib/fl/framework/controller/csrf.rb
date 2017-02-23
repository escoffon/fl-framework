module Fl::Framework::Controller
  # Mixin module to add utilities for managing CSRF.

  module CSRF
    # The default name of the CSRF cookie.
    # Different applications should call {ClassMethods#csrf_cookie_name=} to use an application-specific
    # value (which should be consistent with the one defined in the Angular app).

    DEFAULT_CSRF_COOKIE_NAME = '_FL-XSRF-TOKEN'

    # The default name of the CSRF header name.
    # Different applications should call {ClassMethods#csrf_header_name=} to use an application-specific
    # value (which should be consistent with the one defined in the Angular app).

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

      # The current value of the CSRF cookie name.
      #
      # @return [String] Returns the current value of the CSRF cookie name.

      def csrf_cookie_name()
        @@csrf_cookie_name
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
      # Set the CSRF cookie for Angular.
      # The value is set to the +form_authenticity_token+.

      def set_csrf_cookie_for_ng
        # Not sure if this should be done unconditionally. The Rails security guide indicates that
        # using CSRF protection with JSON APIs may not be needed, since the client typically manages state
        # and therefore the API calls are stateless.

        if protect_against_forgery?
          csrf_cookie_name = self.class.csrf_cookie_name
          cookies[csrf_cookie_name] = form_authenticity_token
        end
      end
    end

    # Perform actions when the module is included.
    # - Injects the class and instance methods.
    # - Calls +:protect_from_forgery+ to trigger an exception.
    # - Calls +after_filter+ to add {InstanceMethods#set_csrf_cookie_for_ng} to place the CSRF token in a
    #   cookie for use by Angular.

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

        # Angular will look for a cookie that contains the CSRF token, and send it down the pipe in a header

        after_action :set_csrf_cookie_for_ng
      end
    end
  end
end
