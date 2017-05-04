require_dependency "fl/framework/application_controller"

module Fl::Framework
  class AttachmentsController < ApplicationController
    include Fl::Framework::Controller::Helper
    include Fl::Framework::Controller::Access

    # This method is a placeholder for access control. Applications that support a notion of a logged-in
    # users will provide their own implementation, and must remove this one.
    # For example:
    # before_action :authenticate_user!, except: [ :index, :show ]

    def current_user()
      nil
    end

    # GET /attachments
    def index
      @attachments = Attachment.all
    end

    # GET /attachments/1
    def show
      p = normalize_params(params)
      service = Fl::Framework::Service::Attachment::ActiveRecord.new(Fl::Framework::Comment::ActiveRecord::Comment, current_user, p)
      if get_and_check(service, Fl::Framework::Access::Grants::READ, '@attachment')
        respond_to do |format|
          format.json do
            render(:json => { :attachment => hash_one_object(@attachment, p[:to_hash]) },
                   status: :ok)
          end
        end
      else
        respond_to do |format|
          format.html
          format.json do
            error_response(generate_error_info(service))
          end
        end
      end
    end

    # GET /attachments/new
    def new
      @attachment = Attachment.new
    end

    # GET /attachments/1/edit
    def edit
    end

    # POST /attachments
    def create
      @attachment = Attachment.new(attachment_params)

      if @attachment.save
        redirect_to @attachment, notice: 'Attachment was successfully created.'
      else
        render :new
      end
    end

    # PATCH/PUT /attachments/1
    def update
      p = normalize_params(params)
      service = Fl::Framework::Service::Attachment::ActiveRecord.new(Fl::Framework::Comment::ActiveRecord::Comment, current_user, p)
      if get_and_check(service, Fl::Framework::Access::Grants::WRITE, '@attachment')
        if @attachment.update_attributes(p[:attachment])
          respond_to do |format|
            format.json do
              render(:json => { :attachment => hash_one_object(@attachment, p[:to_hash]) },
                     status: :ok)
            end
          end
        else
          respond_to do |format|
            format.html
            format.json do
              error_response(generate_error_info(service))
            end
          end
        end
      end
    end

    # DELETE /attachments/1
    def destroy
      p = normalize_params(params)
      service = Fl::Framework::Service::Attachment::ActiveRecord.new(Fl::Framework::Comment::ActiveRecord::Comment, current_user, p)
      if get_and_check(service, Fl::Framework::Access::Grants::DESTROY, '@attachment')
        fingerprint = @attachment.fingerprint
        if @attachment.destroy
          respond_to do |format|
            format.json do
              status_response({
                                status: Fl::Framework::Service::OK,
                                message: tx('fl.framework.attachment.controller.actions.destroy.deleted',
                                            fingerprint: fingerprint)
                              })
            end
          end
        else
          respond_to do |format|
            format.html
            format.json do
              error_response(generate_error_info(service))
            end
          end
        end
      end
    end

    private
      # Only allow a trusted parameter "white list" through.
      def attachment_params
        params.require(:attachment).permit(:attachable, :author, :title, :caption)
      end
  end
end
