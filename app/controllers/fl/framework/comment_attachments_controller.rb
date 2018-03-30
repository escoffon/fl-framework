module Fl::Framework
  class CommentAttachmentsController < ApplicationController
    # GET /attachments
    def index
      respond_to do |format|
        format.json do
          service = Fl::Framework::Service::Attachment::ActiveRecord.new(Fl::Framework::Comment::ActiveRecord::Comment, current_user, params)
          @comment = service.get_and_check_attachable(Fl::Framework::Attachment::Attachable::ACCESS_ATTACHMENT_INDEX, :comment_id)
          if @comment && service.success?
            r = service.index(@comment, { includes: [ :author, :attachable ] }, query_params, pagination_params)
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
      service = Fl::Framework::Service::Attachment::ActiveRecord.new(Fl::Framework::Comment::ActiveRecord::Comment, current_user, nil, self)
      @attachment = service.create_nested(attachable_id_name: :comment_id,
                                          attachable_attribute_name: :attachable,
                                          permission: Fl::Framework::Attachment::Attachable::ACCESS_ATTACHMENT_CREATE)
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
end
