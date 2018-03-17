require 'fl/framework/service/attachment'

module Fl::Framework::Service::Attachment
  # Service object for attachments that use an Active Record database.
  # This service manages attachments associated with an attachable; one of the constructor arguments is the
  # actual class of the attachable.

  class ActiveRecord < Fl::Framework::Service::Nested
    self.model_class = Fl::Framework::Attachment::ActiveRecord::Base

    # Initializer.
    #
    # @param attachable_class [Class] The class object for the attachable.
    # @param actor [Object] The actor on whose behalf the service operates. It may be +nil+.
    # @param params [Hash] Processing parameters; this is typically the +params+ hash from a controller.
    # @param controller [ActionController::Base] The controller (if any) that created the service object;
    #  this parameter gives access to the request context.
    # @param cfg [Hash] Configuration options. See {Fl::Framework::Service::Base#initialize}.

    def initialize(attachable_class, actor, params = nil, controller = nil, cfg = {})
      super(attachable_class, actor, params, controller, cfg)
    end

    # @attribute [r] attachable_class
    # This is synctactic sugar that wraps {#owner_class}.
    # @return [Class] Returns the class object for the attachable.

    alias attachable_class owner_class

    # Get and check the attachable.
    # This is synctactic sugar that wraps {#get_and_check_owner}.
    #
    # @param [Symbol,nil] op The operation for which to request permission.
    # @param [Symbol, Array<Symbol>] idname The name or names of the key in _params_ that contain the object
    #  identifier for the owner.
    # @param [Hash] params The parameters where to look up the +:id+ key used to fetch the object.
    #
    # @return [Object, nil] Returns an object, or +nil+.

    alias get_and_check_attachable get_and_check_owner

    # Run a query and return results and pagination controls.
    # This method calls {Fl::Framework::Service::Base#init_query_opts} to build the query parameters, and then
    # {#index_query} to generate the query to use.
    #
    # @param [Object] attachable The attachable for which to get attachments.
    # @param query_opts [Hash] Query options to merge with the contents of <i>_q</i> and <i>_pg</i>.
    #  This is used to define service-specific defaults.
    # @param _q [Hash, ActionController::Parameters] The query parameters.
    # @param _pg [Hash, ActionController::Parameters] The pagination parameters.
    #
    # @return [Hash, nil] If a query is generated, it returns a Hash containing two keys:
    #  - *:results* are the results from the query.
    #  - *:count* is the number of attachments actually available; the query results may be limited by
    #    pagination.
    #  - *:_pg* are the pagination controls returned by {Fl::Framework::Service::Base#pagination_controls}.
    #  If no query is generated (in other words, if {#index_query} fails), it returns +nil+.

    def index(attachable, query_opts = {}, _q = {}, _pg = {})
      qo = init_query_opts(query_opts, _q, _pg)
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

    # Create an attachment for an attachable object.
    # Overrides the superclass implementation to add attachment-specific checks and adjustments.
    #
    # @param opts [Hash] Options to the method. See {Fl::Framework::Service::Attachment::Nested#create_nested}
    #  for details of the common options.
    # @option opts [Symbol,String] :attachable_id_name The name of the parameter in {#params} that
    #  contains the object identifier for the attachable; this is an alias for *:owner_id_name*.
    #  Defaults to +:attachable_id+.
    # @option opts [Symbol,String] :attachable_attribute_name The name of the attribute passed to the
    #  initializer that contains the attachable object; this is an alias for *:owner_attribute_name*.
    #  Defaults to +:attachable+.
    #
    # @return [Object] Returns the created attachment on success, +nil+ on error.
    #  Note that a non-nil return value does not indicate that the call was successful; for that, you should
    #  call #success? or check if the instance is valid.

    def create_nested(opts = {})
      idname = (opts.has_key?(:attachable_id_name)) ? [ opts[:attachable_id_name].to_sym ] : :attachable_id
      idname << ((opts.has_key?(:owner_id_name)) ? opts[:owner_id_name].to_sym : :owner_id)
      if opts.has_key?(:attachable_attribute_name)
        attrname = opts[:attachable_attribute_name].to_sym
      else
        attrname = (opts.has_key?(:owner_attribute_name)) ? opts[:owner_attribute_name].to_sym : :attachable
      end
      p = (opts[:params]) ? opts[:params].to_h : create_params(self.params).to_h
      op = (opts[:permission]) ? opts[:permission].to_sym : Fl::Framework::Attachment::Attachable::ACCESS_ATTACHMENT_CREATE

      # Creating an attachment requires a number of checks:
      # 1. confirm that the actor has permission to attach.

      attachable = get_and_check_attachable(op, idname)
      attachment = nil
      if attachable && success?
        rs = verify_captcha(opts[:captcha], p)
        if rs['success']
          # 2. Confirm that the submitted file's content type is consistent with the declared type

          afile = p[:attachment]
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

                p[:attachable] = attachable
                attachment = aclass.new(p)
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
      end

      attachment
    end

    # Get create parameters.
    #
    # @param p [Hash,ActionController::Parameters] The parameters from which to extract the create parameters
    #  subset.
    #
    # @return [ActionController::Parameters] Returns the create parameters.

    def create_params(p)
      # The actor is the attachment's author

      cp = strong_params(p).require(:attachment).permit(:title, :caption, :attachment, :watermarked)
      cp[:author] = actor
      cp
    end

    # Get update parameters.
    #
    # @param p [Hash,ActionController::Parameters] The parameters from which to extract the update parameters
    #  subset. if +nil+, use {#params}.
    #
    # @return [ActionController::Parameters] Returns the update parameters.

    def update_params(p = nil)
      strong_params(p).require(:attachment).permit(:attachable, :author, :title, :caption, :watermarked)
    end

    protected

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

      attachable.attachments_query(query_opts)
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
      attachable.attachments_count(query_opts)
    end
  end
end
