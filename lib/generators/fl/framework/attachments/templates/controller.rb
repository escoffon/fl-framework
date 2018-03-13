<%= @open_module %>
  class <%=@class_name%>AttachmentsController < ApplicationController
    # GET /attachments
    def index
      respond_to do |format|
        format.json do
          service = Fl::Framework::Service::Attachment::ActiveRecord.new(<%=@full_class_name%>, current_user, params)
          @<%=@label%> = service.get_and_check_attachable(Fl::Framework::Attachment::Attachable::ACCESS_ATTACHMENT_INDEX, :<%=@label%>_id)
          if @<%=@label%> && service.success?
            r = service.index(@<%=@label%>, { includes: [ :author, :attachable ] }, query_params, pagination_params)
            if r
              render :json => {
                :attachments => hash_objects(r[:result], service.params[:to_hash]),
                :_pg => r[:_pg]
              }
            else
              error_response(generate_error_info(service))
            end
          else
            error_response(generate_error_info(service))
          end
        end
      end
    end

    # POST /attachments
    def create
      service = Fl::Framework::Service::Attachment::ActiveRecord.new(<%=@full_class_name%>, current_user, nil, self)
      @attachment = service.create(attachable_id_name: :<%=@label%>_id)
      respond_to do |format|
        format.json do
          if service.success?
            render :json => { :attachment => hash_one_object(@attachment, params[:to_hash]) }
          else
            error_response(generate_error_info(service, @attachment))
          end
        end
      end
    end

    private

    def query_params
      params.fetch(:_q, {}).permit(:order, :limit, :offset,
                                   { only_authors: [] }, { except_authors: [] },
                                   { only_types: [] }, { except_types: [] })
    end

    def pagination_params()
      params.fetch(:_pg, {}).permit(:_s, :_p, :_c)
    end
  end
<%= @close_module %>
