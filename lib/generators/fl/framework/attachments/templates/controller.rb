<%= @open_module %>
  class <%=@class_name%>AttachmentsController < ApplicationController
    # GET /attachments
    def index
      respond_to do |format|
        format.json do
          service = Fl::Framework::Service::Attachment::ActiveRecord.new(<%=@full_class_name%>, current_user, params)
          @<%=@label%> = service.get_and_check_attachable(Fl::Framework::Attachment::Attachable::ACCESS_ATTACHMENT_INDEX, :<%=@label%>_id)
          if @<%=@label%> && service.success?
            r = service.index(@<%=@label%>)
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

    # GET /attachments/1
    def show
    end

    # GET /attachments/new
    def new
    end

    # GET /attachments/1/edit
    def edit
    end

    # POST /attachments
    def create
      service = Fl::Framework::Service::Attachment::ActiveRecord.new(<%=@full_class_name%>, current_user, params)
      cp = attachment_params.dup
      @attachment = service.create(cp.to_h, :<%=@label%>_id)
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

    # PATCH/PUT /attachments/1
    def update
      if @attachment.update(attachment_params)
        redirect_to @attachment, notice: 'Attachment was successfully updated.'
      else
        render :edit
      end
    end

    # DELETE /attachments/1
    def destroy
      @attachment.destroy
      redirect_to attachments_url, notice: 'Attachment was successfully destroyed.'
    end

    private
      # Only allow a trusted parameter "white list" through.
      def attachment_params
        params.require(:attachment).permit(:title, :caption, :attachment)
      end
  end
<%= @close_module %>
