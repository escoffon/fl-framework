
  class TestDatumOneCommentsController < ApplicationController
    # GET /comments
    def index
      respond_to do |format|
        format.json do
          service = Fl::Framework::Service::Comment::ActiveRecord.new(TestDatumOne, current_user, params)
          @test_datum_one = service.get_and_check_commentable(Fl::Framework::Comment::Commentable::ACCESS_COMMENT_INDEX, :test_datum_one_id)
          if @test_datum_one && service.success?
            r = service.index(@test_datum_one)
            if r
              render :json => {
                :comments => hash_objects(r[:result], service.params[:to_hash]),
                :_pg => r[:_pg]
              }
            else
              error_response(generate_error_info(service))
            end
          end
        end
      end
    end

    # GET /comments/1
    def show
    end

    # GET /comments/new
    def new
    end

    # GET /comments/1/edit
    def edit
    end

    # POST /comments
    def create
      service = Fl::Framework::Service::Comment::ActiveRecord.new(TestDatumOne, current_user, params)
      cp = comment_params.dup
      @comment = service.create(cp, :test_datum_one_id)
      respond_to do |format|
        format.json do
          if service.success?
            render :json => { :comment => hash_one_object(@comment, params[:to_hash]) }
          else
            error_response(generate_error_info(service, @comment))
          end
        end
      end
    end

    # PATCH/PUT /comments/1
    def update
      if @comment.update(comment_params)
        redirect_to @comment, notice: 'Comment was successfully updated.'
      else
        render :edit
      end
    end

    # DELETE /comments/1
    def destroy
      @comment.destroy
      redirect_to comments_url, notice: 'Comment was successfully destroyed.'
    end

    private
      # Only allow a trusted parameter "white list" through.
      def comment_params
        params.require(:comment).permit(:title, :contents)
      end
  end

