module Fl::Framework::Controller
  # Mixin module to add methods that generate status and error reports.

  module StatusError
    protected

    # Build an error info hash from a service and object.
    #
    # @param service [Fl::Service::Base] The service that may have generated a failure code.
    # @param obj [Object, nil] The object that triggered a failure.
    #
    # @return [Hash] Returns a hash containing the following keys:
    #  - *:status* A symbol containing the error status.
    #  - *:message* A messge associated with the error.
    #  - *:details* A hash containing error details. This is typically the value of the +errors+ from
    #    _obj_.

    def generate_error_info(service, obj = nil)
      rv = { }

      if service.success?
        if obj && !obj.valid?
          rv[:status] = Fl::Service::UNPROCESSABLE_ENTITY
          rv[:message] = I18n.tx('fl.controller.unprocessable_entity')
          rv[:details] = obj.errors.messages
        else
          rv[:status] = Fl::Service::OK
        end
      else
        s = service.status
        sk = s[:status].to_sym
        rv[:status] = sk
        rv[:code] = s[:code] if s.has_key?(:code)
        rv[:message] = s[sk][:message] if s.has_key?(sk)
        rv[:details] = s[sk][:details] if s.has_key?(sk)
      end

      rv
    end

    # @!visibility private
    ERROR_PAGE_JSON = [ :status, :code, :message, :details ]

    # @!visibility private
    ERROR_PAGE_LOCALS = [ :status, :code, :message, :details, :links, :with_default_links ]

    # Generate an error page.
    # This method generates an error page based on the format:
    # - For JSON, create a hash containing the following keys:
    #   - *:status* from *:status* in _info_
    #   - *:code* from *:code* in _info_
    #   - *:message* from *:message* in _info_
    #   - *:details* from *:details* in _info_
    #   It then sets up the render options to render this hash as JSON, inside the +:_error+ key.
    # - For other formats, it creates a locals context using:
    #   - :status, :code, :message, :details, :links, :with_default_links from _info_.
    #   Then, set the flash keys :error and :details from :message and :details in _info_.
    #   It then sets up to render the templates/error_page template.
    # Once things are set up, it adds a :status option if _info_ contains the :status key, and then
    # calls render to generate the response page.
    # After the rendering, the flash is discarded.
    #
    # @param info [Hash] A hash containing error information.

    def error_page(info = {})
      format = (params.has_key?(:format)) ? params[:format].to_sym : :html

      case format
      when :json
        e = { }
        ERROR_PAGE_LOCALS.each { |k| e[k] = info[k] if info.has_key?(k) }

        e[:status] = Fl::Service::UNPROCESSABLE_ENTITY unless info.has_key?(:status)
        render_opts = { :json => { _error: e } }
      else
        locals = {}
        ERROR_PAGE_LOCALS.each { |k| locals[k] = info[k] if info.has_key?(k) }

        flash.clear
        render_opts = { :file => 'error_page', :locals => locals }
        layout = layout_from_layout_style(propagated_params[:layout_style])
        render_opts[:layout] = layout if layout
      end

      render_opts[:status] = (info.has_key?(:status)) ? info[:status] : Fl::Service::UNPROCESSABLE_ENTITY
      render render_opts
    end

    # Render a test error response.
    # Used for testing and debugging purposes, this method renders a JSON response containing an error.
    #
    # @param status [Symbol, Integer] The HTTP status to return; either a symbol like :forbidden, or an integer
    #  value like 403.

    def render_test_error(status = :forbidden)
      render(json: {
               _error: {
                 status: status.to_s,
                 message: "test error: #{status}",
                 details: {
                   one: [ 'message one (1)', 'message one (2)' ],
                   two: [ 'message two' ]
                 }
               }
             },
             status: status)
    end

    # @!visibility private
    STATUS_PAGE_JSON = [ :status, :code, :message, :details ]

    # @!visibility private
    STATUS_PAGE_LOCALS = [ :status, :code, :message, :details, :links, :with_default_links ]

    # Generate a status page.
    # This method generates a status page based on the format:
    # - For JSON, create a hash containing the following keys:
    #   - *:status* from *:status* in _info_
    #   - *:code* from *:code* in _info_
    #   - *:message* from *:message* _info_
    #   - *:details* from *:details* in _info_
    #   It then sets up the render options to render this hash as JSON, inside the +:_status+ key.
    # - For other formats, it creates a locals context using:
    #   - :status, :code, :message, :details, :links, :with_default_links from _info_.
    #   Then, set the flash key :notice from :message in _info_.
    #   It then sets up to render the templates/status_page template.
    #
    # @param info [Hash] A hash containing status information.

    def status_page(info = {})
      format = (params.has_key?(:format)) ? params[:format].to_sym : :html

      case format
      when :json
        e = { }
        STATUS_PAGE_JSON.each { |k| e[k] = info[k] if info.has_key?(k) }

        render_opts = { :json => { _status: e } }
      else
        locals = {}
        STATUS_PAGE_LOCALS.each { |k| locals[k] = info[k] if info.has_key?(k) }

        flash.clear
        render_opts = { :file => 'status_page', :locals => locals }
        layout = layout_from_layout_style(propagated_params[:layout_style])
        render_opts[:layout] = layout if layout
      end

      render_opts[:status] = info[:status] if info.has_key?(:status)
      render render_opts
    end

    # Generate an error response.
    # This method splits the two cases of HTML format and all other formats.
    # For HTML format:
    # - set the flash keys :error and :details from :message and :details in _info_.
    # - If _info_ contains the key :render, call render using the value of the :render key as options.
    #   The flash contents are discared after the call to render.
    # - Otherwise, if _info_ contains the key :redirect_url, call redirect_to using the value of :redirect_url
    #   for the options.
    # - Finally, discard the contents of flash and call {#error_page}.
    # For all other formats, call {#error_page}.
    #
    # This method overrides the session's :return_to key, since on an error we want to force the redirection
    # either to the requested place, or to an error page. Leaving :return_to in the session object, we may
    # end up with infinite relocation loops
    #
    # @param info [Hash] A hash containing status information.

    def error_response(info = {})
      session[:return_to] = nil

      if html_format?
        flash[:error] = info[:error_message]
        flash[:details] = info[:error_details]

        if info.has_key?(:render)
          render info[:render]
          flash.clear
        elsif info.has_key?(:redirect_url)
          redirect_to(info[:redirect_url])
        else
          flash.clear
          error_page(info)
        end
      else
        error_page(info)
      end
    end

    # Generate a status (success) response.
    # This method splits the two cases of HTML format and all other formats.
    # For HTML format:
    # - set the flash key :notice from :message in _opts_.
    # - If _opts_ contains the key :render, call render using the value of the :render key as options.
    #   The flash contents are discared after the call to render.
    # - Otherwise, if _opts_ contains the key :redirect_url, call redirect_to using the value of :redirect_url
    #   for the options.
    # - Finally, discard the contents of flash and call {#status_page}.
    # For all other formats, call status_page.

    def status_response(info = {})
      if html_format?
        flash[:notice] = info[:message]

        if info.has_key?(:render)
          render info[:render]
          flash.clear
        elsif info.has_key?(:redirect_url)
          redirect_to(info[:redirect_url])
        else
          flash.clear
          status_page(info)
        end
      else
        status_page(info)
      end
    end
  end
end
