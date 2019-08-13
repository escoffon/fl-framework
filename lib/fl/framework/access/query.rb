module Fl::Framework::Access
  # A module used to inject access query functionality.
  # Include this module in classes that want support for access control in their query methods.
  #
  # The module 
  
  module Query
    # The instance methods injected into the including class.

    module InstanceMethods
    end

    # The class methods injected into the including class.

    module ClassMethods
      # @!visibility private
      PERMISSION_OPS = [ :or, :OR, :and, :AND, 'or', 'OR', 'and', 'AND' ]

      # @!visibility private
      GRANTS_TABLE_ALIAS = 'grants'
      
      # Joins the grants table.
      # You will have to join the grant table in order to use {#add_granted_to_clause} and
      # {#add_permission_clauses}.
      # The method calls the `joins` ActiveRecord query method to generate a join between
      # the access grant table and the model's table. The grants table will be accessible in the query
      # with the alias specified by *opts[:table_alias]*.
      #
      # The method assumes that `self` is an `ActiveRecord::Relation` or behaves as one.
      #
      # #### Join conditions
      #
      # The method generates join conditions on the table assuming that the two tables are to be joined
      # through the **target_type** and **target_id** fields in the grants table (through the
      # polymorphic {Fl::Framework::Access::Grant#target} association).
      # It sets up a `ON` clause where **target_type** is the name of the including class, and
      # **target_id** matches the **id** of the model table.
      #
      # For example, consider a `MyDatum` model that has registered as a target. The model table includes
      # the **id** field. A call to {Fl::Framework::Access::Target::InstanceMethods#grant_permission_to} by
      # `MyDatum` instance `d` creates a grant record where **target_id** is `d.id` and **target_type**
      # is `'MyDatum'` (because {Fl::Framework::Access::Grant#target} is a polymorphic association).
      #
      # You can override this default behavior by providing a string value for the *opts[:op]* option, which
      # will be used as the body of the `ON` clause.
      #
      # @param opts [Hash] Options for the method.
      #
      # @option opts [String] :on The descriptor for how the table is to be joined. See above.
      # @option opts [String] :table_alias The alias to use for the grants table.
      #  Defaults to `grants`.
      #
      # @return [ActiveRecord::Relation] Returns the modified relation.
      
      def join_grants_table(opts = { })
        gname = Fl::Framework::Access::Grant.table_name
        galias = (opts[:table_alias].is_a?(String)) ? opts[:table_alias] : GRANTS_TABLE_ALIAS
        
        if opts[:on].is_a?(String)
          self.joins("INNER JOIN #{gname} AS #{galias} ON #{on}")
        else
          tname = self.table_name
          cname = (self.is_a?(Class)) ? self.name : self.class.name

          self.joins("INNER JOIN #{gname} AS #{galias} ON ((#{tname}.id = #{galias}.target_id) AND (#{galias}.target_type = '#{cname}'))")
        end
      end

      # Adds a clause to select records associated to a list of actors.
      # This method assumes that {#join_grants_table} has been called to set up the join.
      # It generates a call to `where` that selects records where the **granted_to** field in the
      # grants table is one of the values in *granted_to*.
      #
      # The method assumes that `self` is an `ActiveRecord::Relation` or behaves as one.
      #
      # @param granted_to [String,ActiveRecord::Base,Array<String,ActiveRecord::Base>] The actors to
      #  which permissions were granted. A string value is assumed to be a fingerprint.
      # @param opts [Hash] Options for the method.
      #
      # @option opts [String] :table_alias The name to use for the grants table. By default, this is
      #  `grants`, for consistency with {#join_grants_table}. For no table name, use `nil`.
      #
      # @return [ActiveRecord::Relation] Returns the modified relation.
      
      def add_granted_to_clause(granted_to, opts = { })
        gl = (granted_to.is_a?(Array)) ? granted_to : [ granted_to ]
        glist = gl.reduce([ ]) do |acc, g|
          if g.is_a?(String)
            cn, cid = ActiveRecord::Base.split_fingerprint(g)
            acc << g if cn && cid
          elsif g.respond_to?(:fingerprint)
            acc << g.fingerprint
          end

          acc
        end

        galias = if opts.has_key?(:table_alias)
                   (opts[:table_alias].nil?) ? nil : "#{opts[:table_alias]}."
                 else
                   GRANTS_TABLE_ALIAS + '.'
                 end
        self.where("(#{galias}granted_to_fingerprint IN (:gfp))", gfp: glist)
      end

      # Get a permission mask from a permission descriptor.
      #
      # @param desc [Hash] The permission descriptor; it is a hash that contains the **:all** or
      #  **:any** keys. The key values are permission lists as descibed in {#add_permission_clauses}.
      # @param pk [Symbol] The key name (**:all** or **:any**).
      #
      # @return [Integer] Returns an integer containing the permission mask.
      
      def get_permissions_mask(opts, pk)
        if opts.has_key?(pk)
          v = (opts[pk].is_a?(Array)) ? opts[pk] : [ opts[pk] ]

          v.reduce(0) do |acc, e|
            if e.nil?
            elsif e.is_a?(Integer)
              acc |= e
            elsif e.is_a?(String)
              if e =~ /^[0-9]+$/
                acc |= e.to_i
              elsif e =~ /^0x[0-9a-f]+/i
                acc |= e.to_i(16)
              else
                n = Fl::Framework::Access::Helper.permission_name(e)
                acc |= Fl::Framework::Access::Permission.permission_mask(n) if n
              end
            elsif e.is_a?(Symbol) || (e < Fl::Framework::Access::Permission)
              n = Fl::Framework::Access::Helper.permission_name(e)
              acc |= Fl::Framework::Access::Permission.permission_mask(n) if n
            end

            acc
          end
        else
          nil
        end
      end

      # Normalize permissions.
      # This method converts *permissions* into a normalized value:
      #
      # - If *permissions* is not an array, it is converted to a one-element array.
      # - Elements that contain operators are converted to uppercase strings.
      # - In elements that contain A Hash (or ActionController::Parameters) with **:all** or **:any**
      #   keys, the key's value is converted to a permission mask via a call to {#get_permissions_mask}.
      # - Scalar element values are converted to a permission mask via a call to {#get_permissions_mask}.
      #
      # @param permissions The permissions to normalize; see {#add_permission_clauses}.
      #
      # @return [Array] Returns an array containing the normalized permissions.

      def normalize_permissions(permissions)
        pl = (permissions.is_a?(Array)) ? permissions : [ permissions ]

        pl.reduce([ ]) do |acc, p|
          if (p.is_a?(String) || p.is_a?(Symbol)) && PERMISSION_OPS.include?(p)
            acc << p.to_s.upcase
          else
            if p.is_a?(Hash) || p.is_a?(ActionController::Parameters)
              if p.has_key?(:all)
                acc << { all: get_permissions_mask(p, :all) }
              elsif p.has_key?(:any)
                acc << { any: get_permissions_mask(p, :any) }
              else
                acc << p
              end
            else
              acc << { all: get_permissions_mask({ all: p }, :all) }
            end
          end

          acc
        end
      end

      # Adds a clause to select records associated to a set of permissions.
      # This method assumes that {#join_grants_table} has been called to set up the join.
      # It generates a call to `where` that selects records where the **grants** field in the
      # grants table matches the permissions from *permissions*.
      #
      # The method assumes that `self` is an `ActiveRecord::Relation` or behaves as one.
      #
      # The *permissions* parameter defines filters (WHERE clauses, really) for permissions.
      # The canonical form of the value is an array of clause descriptors and logical operators,
      # in the form `[ <clause>, <op>, <clause>, <op>, <clause>...]`: a sequence of clauses joined by
      # the logical operators `:or` and `:and`. Clauses are hashes containing the keys **:all** or **:any**,
      # whose values are permission descriptors. The **:all** key generates a clause that accepts grants
      # where *all* the permissions in the value are granted; the **:any* key generates a clause that
      # accepts grants where *at least one* permission in the value is granted.
      # The permission descriptors can have the following forms:
      #
      # - An integer containing the bitmask of the requested permissions; for example: `0x0000000c`.
      # - A string or symbol is the name of a registered permission; this name is used to obtain the
      #   corresponding permission mask. For example: `Fl::Framework::Access::Permission::Edit::NAME`
      #   (which is converted to the bitmask value `0x0000000c`).
      # - A class object for a registered permission, from which the bitmask is generated.
      #   For example: `Fl::Framework::Access::Permission::Edit`.
      # - An instance of (a subclass of) {Fl::Framework::Access::Permission}, from which the bitmask is
      #   generated. This is an uncommon form to use.
      # - An array whose elements are one of the forms described above. The final value is the OR
      #   combination of the bitmasks from each element in the array.
      #
      # A clause value can be simplified to be one of the forms listed above, rather than a hash; in this
      # case it is assumed to behave as a **:all** permission mask. Similarly, the value for *permissions*
      # can be simplified to one of the forms listed above: `Fl::Framework::Access::Permission::Edit`
      # is equivaluent to `[ { all: Fl::Framework::Access::Permission::Edit } ]`.
      #
      # For example, to select objects that grant either a `Read` or `Write` permission, use
      #
      # ```
      #   MyClass.add_permission_clauses(MyClass, [
      #     { all: Fl::Framework::Access::Read }, :or, { all: Fl::Framework::Access::Write }
      #   ])
      # ```
      #
      # This is better written as:
      #
      # ```
      #   MyClass.add_permission_clauses(MyClass, [
      #     { any: [ Fl::Framework::Access::Read, Fl::Framework::Access::Write ] }
      #   ])
      # ```
      #
      # or
      #
      # ```
      #   MyClass.add_permission_clauses(MyClass, [
      #     { any: Fl::Framework::Access::Read::BIT | Fl::Framework::Access::Write::BIT }
      #   ])
      # ```
      #
      # (Note that this last form does not work for composite permissions, whose `BIT` value is 0;
      # use a permission name or permission class to avoid this pitfall.)
      #
      # To select objects that grant `Edit` permission (and therefore both `Read` *and* `Write`, use
      #
      # ```
      #   MyClass.add_permission_clauses(MyClass, [ { all: Fl::Framework::Access::Edit } ])
      # ```
      #
      # which can be collapsed to
      #
      # ```
      #   MyClass.add_permission_clauses(MyClass, Fl::Framework::Access::Edit)
      # ```
      #
      # To get targets where user `u` has write permission, we need to select those grants that include the
      # `Write` permission, as well as those owned by `u`; this is where a `:or` operator comes in handy:
      #
      # ```
      # q = MyClass.add_granted_to_clause(MyClass, u)
      # q = q.add_permission_clauses(q, [ Fl::Framework::Access::Write, :or, Fl::Framework::Access::Owner ])
      # ```
      #
      # Note that the generated clauses use only the values in *permissions*; since ownership involves
      # full access to an object, when check ing for pretty much any permission you should also add the
      # {Fl::Framework::Access::Owner} permission, using `:or`, as shown in the example above.
      # This is what {Fl::Framework::Access::Grant.accessible_query} does.
      # This behavior gives you full control over what permissions to check, but it does require that
      # you add the ownership grant in typical checks.
      #
      # @param permissions The permissions to place in the clause. See above for details.
      # @param opts [Hash] Options for the method.
      #
      # @option opts [String] :table_alias The name to use for the grants table. By default, this is
      #  `grants`, for consistency with {#join_grants_table}. For no table name, use `nil`.
      #
      # @return [ActiveRecord::Relation] Returns the modified relation.

      def add_permission_clauses(permissions, opts = { })
        galias = if opts.has_key?(:table_alias)
                   (opts[:table_alias].nil?) ? nil : "#{opts[:table_alias]}."
                 else
                   GRANTS_TABLE_ALIAS + '.'
                 end

        prev = nil
        wh = { }
        wi = 0
        ws = normalize_permissions(permissions).reduce('(') do |acc, p|
          if (p.is_a?(String) || p.is_a?(Symbol)) && PERMISSION_OPS.include?(p)
            prev = p.to_sym
            acc << " #{p.to_s.upcase} "
          else
            acc << ' AND ' if !prev.nil? && !prev.is_a?(Symbol)

            if p.is_a?(Hash)
              if p.has_key?(:all)
                k = "pm#{wi}".to_sym
                prev = "((#{galias}grants & :#{k}) = :#{k})"
                acc << prev
                wh[k] = p[:all]
                wi += 1
              elsif p.has_key?(:any)
                k = "pm#{wi}".to_sym
                prev = "((#{galias}grants & :#{k}) != 0)"
                acc << prev
                wh[k] = p[:any]
                wi += 1
              else
                # if the hash does not contain :all or :any, we just shut down the query here

                k = "pm#{wi}".to_sym
                prev = "((#{galias}grants & :#{k}) = :#{k})"
                acc << prev
                wh[k] = 0
                wi += 1
              end
            end
          end

          acc
        end

        # OK we have built the clauses

        self.where(ws + ')', wh)
      end
      
      # Adds clauses for access control.
      # This method calls {#join_grants_table}, {##add_granted_to_clause}, and {#add_permission_clauses}
      # to add the table join and clauses used by selecting records based on access gants.
      #
      # @param granted_to [String,ActiveRecord::Base,Array<String,ActiveRecord::Base>] The actors to
      #  which permissions were granted. A string value is assumed to be a fingerprint.
      # @param permissions The permissions to place in the clause. See {#add_permission_clauses}.
      # @param opts [Hash] Options for the method.
      #
      # @option opts [String] :on The descriptor for how the table is to be joined. See {#join_grants_table}.
      # @option opts [String] :table_alias The alias to use for the grants table.
      #  Defaults to `grants`.
      #
      # @return [ActiveRecord::Relation] Returns the modified relation.
      
      def add_access_clauses(granted_to, permissions, opts = { })
        self.join_grants_table(opts).add_granted_to_clause(granted_to, opts).add_permission_clauses(permissions, opts)
      end
    end

    # Perform actions when the module is included.
    # - Injects the class methods that provide support for access control in queries.
    
    def self.included(base)
      base.extend ClassMethods
      base.include InstanceMethods

      base.instance_eval do
      end

      base.class_eval do
      end
    end
  end
end
