class <%=@data_c[:plural_full_name]%>Controller < ApplicationController
  # before_action :authenticate_user!, except: [ :index, :show ]

  # GET /<%=@data_c[:plural_full_name].underscore%>
  # GET /<%=@data_c[:plural_full_name].underscore%>.json
  def index
    service = <%=@service_c[:full_name]%>.new(current_user, params)
    r = service.index({ includes: [ :k1, :k2 ] }, query_params, pagination_params)
    respond_to do |format|
      format.html do
      end

      format.json do
        if r
          render :json => { :<%=@data_c[:plural_name].underscore%> => hash_objects(r[:result], service.to_hash_params), :_pg => r[:_pg] }
        else
          error_response(generate_error_info(service))
        end
      end
    end
  end

  # GET /<%=@data_c[:plural_full_name].underscore%>/1
  # GET /<%=@data_c[:plural_full_name].underscore%>/1.json
  def show
    service = <%=@service_c[:full_name]%>.new(current_user, params)
    @<%=@data_c[:name].underscore%> = service.get_and_check(Fl::Framework::Access::Grants::READ)
    respond_to do |format|
      format.html do
      end

      format.json do
        if service.success?
          render :json => { :<%=@data_c[:name].underscore%> => hash_one_object(@<%=@data_c[:name].underscore%>, service.to_hash_params) }
        else
          error_response(generate_error_info(service, @<%=@data_c[:name].underscore%>))
        end
      end
    end
  end

  # POST /<%=@data_c[:plural_full_name].underscore%>
  def create
    service = <%=@service_c[:full_name]%>.new(current_user, params)
    @<%=@data_c[:name].underscore%> = service.create()
    respond_to do |format|
      format.json do
        if service.success?
          render :json => { :<%=@data_c[:name].underscore%> => hash_one_object(@<%=@data_c[:name].underscore%>, service.to_hash_params) }
        else
          error_response(generate_error_info(service, @<%=@data_c[:name].underscore%>))
        end
      end
    end
  end

  # PATCH/PUT /<%=@data_c[:plural_full_name].underscore%>/1
  # PATCH/PUT /<%=@data_c[:plural_full_name].underscore%>1.json
  def update
    service = <%=@service_c[:full_name]%>.new(current_user, params)
    @<%=@data_c[:name].underscore%> = service.update()
    respond_to do |format|
      format.json do
        if @<%=@data_c[:name].underscore%> && service.success?
          render :json => { :<%=@data_c[:name].underscore%> => hash_one_object(@<%=@data_c[:name].underscore%>, service.to_hash_params) }
        else
          error_response(generate_error_info(service, @<%=@data_c[:name].underscore%>))
        end
      end
    end
  end

  # DELETE /<%=@data_c[:plural_full_name].underscore%>/1
  # DELETE /<%=@data_c[:plural_full_name].underscore%>1.json
  def destroy
    service = <%=@service_c[:full_name]%>.new(current_user, params)
    @<%=@data_c[:name].underscore%> = service.get_and_check(Fl::Framework::Access::Grants::DESTROY, :id)
    if @<%=@data_c[:name].underscore%> && service.success?
      fingerprint = @<%=@data_c[:name].underscore%>.fingerprint
      if @<%=@data_c[:name].underscore%>.destroy
        respond_to do |format|
          format.json do
            status_response({
                              status: Fl::Framework::Service::OK,
                              message: tx('<%=@data_c[:full_name].underscore.gsub('/', '.')%>.controller.destroy.deleted',
                                          fingerprint: fingerprint)
                            })
          end
        end
      end
    else
      respond_to do |format|
        format.json do
          error_response(generate_error_info(service, @<%=@data_c[:name].underscore%>))
        end
      end
    end
  end

  private

  # Never trust parameters from the scary internet, only allow the white list through.

  def query_params
    params.fetch(:_q, {}).permit(:p1, :p2)
  end
end
