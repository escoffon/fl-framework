require 'fl/framework/service/attachment'

module Fl::Framework::Service::Attachment
  # Service object for attachments that use an Active Record database.
  # This service manages attachments associated with a attachable; one of the constructor arguments is the
  # actual class of the attachable.

  class ActiveRecord < Fl::Framework::Service::Base
    self.model_class = Fl::Framework::Attachment::ActiveRecord::Base

    # Initializer.
    #
    # @param attachable_class [Class] The class object for the attachable.
    # @param actor [Object] The actor on whose behalf the service operates. It may be +nil+.
    # @param params [Hash] Processing parameters; this is typically the +params+ hash from a controller.
    # @param controller [ActionController::Base] The controller (if any) that created the service object;
    #  this parameter gives access to the request context.
    # @param cfg [Hash] Configuration options. See {Fl::Framework::Service::Base#initialize}.

    def initialize(attachable_class, actor, params = {}, controller = nil, cfg = {})
      @attachable_class = attachable_class

      super(actor, params, controller, cfg)
    end

    # @attribute [r] attachable_class
    #
    # @return [Class] Returns the class object for the attachable.

    def attachable_class()
      @attachable_class
    end

    # Look up a attachable in the database, and check if the service's actor has permissions on it.
    # This method uses the attachable id entry in the {#params} to look up the object in the database
    # (using the attachable model class as the context for +find+, and the value of _idname_ as the lookup
    # key).
    # If it does not find the object, it sets the status to {Fl::Framework::Service::NOT_FOUND} and
    # returns +nil+.
    # If it finds the object, it then calls {Fl::Framework::Access::Access::InstanceMethods#permission?} to
    # confirm that the actor has _op_ access to the object.
    # If the permission call fails, it sets the status to {Fl::Framework::Service::FORBIDDEN} and returns the
    # object.
    # Otherwise, it sets the status to {Fl::Framework::Service::OK} and returns the object.
    #
    # @param [Symbol] op The operation for which to request permission. If +nil+, no access check is performed
    #  and the call is the equivalent of a simple database lookup.
    # @param [Symbol, Array<Symbol>] idname The name or names of the key in _params_ that contain the object
    #  identifier for the attachable. A +nil+ value defaults to +:attachable_id+.
    # @param [Hash] params The parameters where to look up the +:id+ key used to fetch the object.
    #  If +nil+, use the _params_ value that was passed to the constructor.
    #
    # @return [Object, nil] Returns an object, or +nil+. Note that a non-nil return value is not a guarantee
    #  that the check operation succeded.

    def get_and_check_attachable(op, idname = nil, params = nil)
      idname = idname || :attachable_id
      idname = [ idname ] unless idname.is_a?(Array)
      params = params || self.params

      obj = nil
      idname.each do |idn|
        if params.has_key?(idn)
          begin
            obj = self.attachable_class.find(params[idn])
            break
          rescue ActiveRecord::RecordNotFound => ex
            obj = nil
          end
        end
      end

      if obj.nil?
        self.set_status(Fl::Framework::Service::NOT_FOUND,
                        I18n.tx(localization_key('not_found'), id: idname.join(',')))
        return nil
      end

      self.clear_status if allow_op?(obj, op)
      obj
    end

    # Build a query to list attachments.
    # This method uses the _attachable_ {Fl::Framework::Attachment::Query#attachment_query} to build a query to
    # return attachments associated with the attachable.
    # It uses the value of _query\\_opts_ merged with the value of +:query_opts+ in {#params}. (And therefore
    # +:query_opts+ in {#params} is a set of default values for the query.)
    # Note that this means that service clients can customize the query to return a subset of the available
    # attachments, for example to return just the attachments from a specific author.
    #
    # @param attachable [Object] An attachable object that is expected to respond to +attachments+.
    # @param query_opts [Hash] A hash of query options that will be merged into the defaults from
    #  {#params}, if any.
    #  The method also processes the following.
    # @option query_opts [String] :order The +ORDER BY+ clause. Because the query returns objects in the
    #  +c+ variable, each entry in the clause is scoped to +c.+ if necessary. For example, a value of
    #  <tt>title ASC, updated_at DESC</tt> is converted to <tt>c.title ASC, c.updated_at DESC</tt>.
    # @option query_opts [String, Integer] :limit The +LIMIT+ clause.
    # @option query_opts [String, Integer] :skip The +SKIP+ clause.
    #
    # @return If the query options are empty, the method returns the +attachments+ association; if they are
    #  not empty, it returns an association relation.
    #  If the {#actor} does not have +:attachment_index+ access, the return value is +nil+.

    def index_query(attachable, query_opts = {})
      return nil unless attachable.permission?(self.actor,
                                               Fl::Framework::Attachment::Attachable::ACCESS_ATTACHMENT_INDEX)

      attachable.attachments_query(_init_query_opts(query_opts))
    end

    # Build a query to count attachments.
    # This method uses the _attachable_ association +attachments+ to build a query to return a count of
    # attachments associated with the attachable.
    # It uses the value of _query\\_opts_ merged with the value of +:query_opts+ in {#params}. (And therefore
    # +:query_opts+ in {#params} is a set of default values for the query.)
    # However, it strips any *:offset*, *:limit*, and *:order* keys from the query options before generating
    # the query object via a call to {#index_query}.
    # It then and adds a +count+ clause to the query.
    #
    # @param attachable [Object] A attachable object that is expected to respond to +attachments+.
    # @param query_opts [Hash] A hash of query options that will be merged into the defaults from
    #  {#params}, if any.
    #
    # @return Returns a Neo4j Query object or query proxy containing the following variables:
    #  - +ccount+ (Note the double 'c') is the count of attachments.
    # If the {#actor} does not have +:attachment_index+ access, the return value is +nil+.

    def count_query(attachable, query_opts = {})
      return nil unless attachable.permission?(self.actor, Fl::Framework::Attachment::Attachable::ACCESS_ATTACHMENT_INDEX)
      attachable.attachments_count(_init_query_opts(query_opts))
    end

    # Run a query and return results and pagination controls.
    # This method calls {Fl::Framework::Service::Base#init_query_opts} to build the query parameters, and then
    # {#index_query} to generate the query to use.
    #
    # @param [Object] attachable The attachable for which to get attachments.
    #
    # @return [Hash, nil] If a query is generated, it returns a Hash containing two keys:
    #  - *:results* are the results from the query.
    #  - *:count* is the number of attachments actually available; the query results may be limited by
    #    pagination.
    #  - *:_pg* are the pagination controls returned by {Fl::Framework::Service::Base#pagination_controls}.
    #  If no query is generated (in other words, if {#index_query} fails), it returns +nil+.

    def index(attachable)
      qo = init_query_opts(nil, self.params)
      q = index_query(attachable, qo)
      if q
        r = q.to_a
        {
          result: r,
          _pg: pagination_controls(r, qo, self.params)
        }
      else
        nil
      end
    end

    # Create a attachment for a attachable object.
    # This method looks up the attachable by id, using the {#attachable_class} value, and checks that
    # the current user has +:attachment_create+ privileges on it, and then creates a attachment for it.
    #
    # @param data [Hash] Attachment data.
    # @option data [ActionDispatch::Http::UploadedFile] attachment The attached file; this is a required value.
    # @option data [String] :caption The attachment caption.
    # @option data [String] :title The attachment title; if not present, the title is extracted from the
    #  first 40 character of the caption.
    # @param idname [Symbol] The name of the key in _params_ that contains the attachable's identifier.
    #  A value of +nil+ is converted to +:attachable_id+.
    # @param params [Hash] The parameters to use; if +nil+, the parameters that were passed to the
    #  constructor are used.
    #
    # @return [Object] Returns an attachment object (for example, an instance of
    #  {Fl::Framework::Attachment::ActiveRecord::Base}. Note that a non-nil
    #  return value here does not indicate a successful call: clients need to check the object's status
    #  to confirm that it was created (for example, call +valid?+).

    def create(data, idname = nil, params = nil)
      idname = idname || :attachable_id
      params = params || self.params
      adata = data.dup
      attachment = nil

      # Creating an attachment requires a number of checks:
      # 1. confirm that the actor has permission to attach.

      attachable = get_and_check_attachable(Fl::Framework::Attachment::Attachable::ACCESS_ATTACHMENT_CREATE, idname)
      if success?
        # 2. Confirm that the submitted file's content type is consistent with the declared type

        afile = adata[:attachment]
        mtype = MimeMagic.by_magic(afile.tempfile)
        if mtype.type != afile.content_type
          set_status(Fl::Framework::Service::UNPROCESSABLE_ENTITY,
                     I18n.tx('fl.framework.service.attachment.type_mismatch',
                             declared_type: afile.content_type, detected_type: mtype.type))
        else
          # 3. Confirm that the attachable can create this type of attachment

          unless attachable.attachments.allow?(afile.content_type)
            set_status(Fl::Framework::Service::UNPROCESSABLE_ENTITY,
                       I18n.tx('fl.framework.service.attachment.type_not_allowed',
                               type: afile.content_type, fingerprint: attachable.fingerprint))
          else
            # 4. get the attachment class

            cr = Fl::Framework::Attachment::ClassRegistry.registry
            aclass = cr.lookup(afile.content_type, Fl::Framework::Attachment::ClassRegistry::ORM_ACTIVE_RECORD)
            if aclass
              # 5. Finally! Create the attachment and save it

              adata[:author] = self.actor
              adata[:attachable] = attachable
              attachment = aclass.new(adata)
              if attachment.save
                # adding an attachment is considered an update

                attachable.updated_at = Time.now
                attachable.save
              else
                attachment.errors.each do |ek, ev|
                  ak = "attachment.#{ek}"
                  if ev.is_a?(Array)
                    ev.each { |e| attachable.errors.add(ak, e) }
                  else
                    attachable.errors.add(ak, ev)
                  end
                end
                attachment = nil
                set_status(Fl::Framework::Service::UNPROCESSABLE_ENTITY,
                           I18n.tx('fl.framework.service.attachment.cannot_create',
                                   fingerprint: attachable.fingerprint),
                           attachable.errors)
              end
            else
              set_status(Fl::Framework::Service::UNPROCESSABLE_ENTITY,
                         I18n.tx('fl.framework.service.attachment.no_class', type: afile.content_type))
            end
          end
        end
      end

      attachment
    end

    private

    def _init_query_opts(query_opts)
      q_opts = (self.params[:query_opts]) ? self.params[:query_opts].merge(query_opts) : query_opts.dup

      q_opts.delete(:limit) if q_opts.has_key?(:limit) && (q_opts[:limit].to_i < 0)

      q_opts
    end
  end
end
