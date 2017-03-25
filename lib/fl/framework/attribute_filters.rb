module Fl::Framework
  # A module designed for inclusion to provide a general API for processing attribute string values.
  # This module sets up the API for supporting and implementing filters to be applied to an attribute's
  # value to perform some kind of transformation; multiple filters per attribute can be registered,
  # and are called in the order in which they are registered, thus providing a filter pipeline.

  module AttributeFilters
    # Class methods injected in the including class.
    # Of the methods defined in this module, the important one is {#filtered_attribute}, which is used
    # in the including class to register attributes with the filter processor.
    #
    # The other methods are mainly for support of the filter pipeline, and are extremely unlikely to
    # be called explicitly.
    #
    # When including Fl::AttributeFilters in a Neo4j::ActiveNode (or Neo4j::ActiveRel) class,
    # the filter declaration *must* follow the corresponding property declararion in order to be effective;
    # this is due to the way that Neo4j.rb implements property setters.
    # So, for example:
    #   class MyNode
    #     include Neo4j::ActiveNode
    #     include Fl::AttributFilters
    #
    #     property :myProp, type: String
    #
    #     filtered_attribute :myProp, [ FILTER_HTML_STRIP_DANGEROUS_ELEMENTS, :my_filter ]
    #
    #     def my_filter(value)
    #      # process *value* and return the filtered value.
    #     end
    #   end

    module ClassMethods
      # Register filter methods for an attribute.
      # This method is meant to be called in a class definition block to register attribute filtering.
      # See the {Fl::AttributeFilters::ClassMethods} module documentation for an example.
      #
      # @param name [Symbol] The attribute name (in ActiveNode parlance, this is a property).
      # @param filters [Array] An array of filters to apply (or a single filter). The filters can be:
      #  - Symbol or String instances, in which case they are the names of methods that take two arguments
      #    (the attribute name and the attribute value) and return a filtered (modified) value.
      #  - Proc instances, which take three arguments (the model object, the attribute name, and the
      #    attribute value) and return a filtered (modified) value.

      def filtered_attribute(name, filters)
        unless self.instance_variable_defined?(:@attr_filters)
          @attr_filters = {}
        end
        filters = [ filters ] unless filters.is_a?(Array)
        @attr_filters[name.to_sym] = filters

        # If we are filtering a Neo4j::ActiveNode property, we need to extend the setter here,
        # because the ActiveNode setters don't seem to go through :write_attribute

        begin
          active_node = Module::const_get('Neo4j::ActiveNode')
          if include?(active_node)
            setter = "#{name}="
            if self.instance_methods.find { |m| m.to_sym == setter.to_sym }
              pre_setter = "_prefilter_#{setter}"
              alias_method pre_setter.to_sym, setter.to_sym
              define_method setter do |value|
                send(pre_setter, filter_one_attribute(name, value))
              end
            end
          end
        rescue NameError
        end
      end

      # Get the attribute filters.
      #
      # @return [Hash] Returns a hash containing the registered attribute filters. The keys are
      #  attribute names (as passed to the +name+ parameter of {#filtered_attribute}), and the
      #  values are array of filetrs (as passed to the +filters+ parameter of {#filtered_attribute}).

      def attr_filters()
        unless self.instance_variable_defined?(:@attr_filters)
          @attr_filters = {}
        end
        @attr_filters
      end

      # Filter and convert the attributes for a bulk update call (+update_attributes+).
      #
      # @param obj The model object.
      # @param attrs [Hash] A hash containing the attributes to update.
      #
      # @return [Hash] Returns the converted hash.

      def filter_bulk_attributes(obj, attrs = {})
        fattrs = {}
        attrs.each do |a, v|
          fattrs[a] = filter_one_attribute(obj, a, v)
        end

        fattrs
      end

      # Find the filters for an attribute.
      # This method walks up the inheritance hierarchy until ActiveRecord::Base or a root class, looking for
      # a filter entry for +attr+.
      #
      # @param attr [Symbol, String] The attribute name.
      #
      # @return [Array] Returns a filter entry if found, +nil+ otherwise.

      def lookup_filter(attr)
        ck = self
        a = attr.to_sym
        while ck
          if ck.respond_to?(:attr_filters)
            return ck.attr_filters[a] if ck.attr_filters.has_key?(a)
          end

          ck = ck.superclass
        end

        nil
      end

      # Filter a single attribute.
      # This method applies all the registered filters for +attr+ to the initial value +value+, as a
      # pipeline (the output of filter N is the input of filter N+1), and returns the final value.
      #
      # @param obj The target object.
      # @param attr [Symbol, String] The attribute name.
      # @param value The initial value.
      #
      # @return Returns the filtered value.
      #
      # @raise if the attribute has registered an invalid set of filters.

      def filter_one_attribute(obj, attr, value)
        filters = lookup_filter(attr)
        if filters
          filters.each do |p|
            value = case p
                    when Symbol
                      obj.send(p, attr, value)
                    when String
                      obj.send(p.to_sym, attr, value)
                    when Proc
                      p.call(obj, attr, value)
                    else
                      raise "internal error: bad attribute filter class #{p.class}"
                    end
          end
        end

        value
      end
    end

    # The methods in this model are registered as instance methods in the including class, and are
    # therefore available to object instances.

    module InstanceMethods
      # Filter and convert the attributes for a bulk update call (+update_attributes+).
      # Note that {Fl::AttributeFilters.included} creates an aliased method as shown in the example,
      # so that there is no need to do what's shown there: that functionality is available automatically.
      #
      # @param attrs [Hash] The attributes to filter.
      #
      # @return [Hash] Returns the converted hash.
      #
      # @example Wrapping the +update_attributes+ call
      #   class MyClass
      #     include Neo4j::ActiveNode
      #     include Fl::AttributeFiters
      #
      #     alias original_update_attributes update_attributes
      #     def update_attributes(attrs = {})
      #       original_update_attributes(filter_bulk_attributes(attrs))
      #     end
      #   end

      def filter_bulk_attributes(attrs = {})
        self.class.filter_bulk_attributes(self, attrs)
      end

      # Filter a single attribute.
      # Because {Fl::AttributeFilters::ClassMethods#filtered_attribute} sets things up so that the
      # value is filtered automatically in the setter, there is not a lot of use for this method.
      #
      # @param attr [Symbol, String] The attribute name.
      # @param value The initial value.
      #
      # @return Returns the filtered value.

      def filter_one_attribute(attr, value)
        self.class.filter_one_attribute(self, attr, value)
      end

      # HTML filter to strip dangerous elements.
      # This filter wraps the {Fl::Framework::HtmlHelper.strip_dangerous_elements} helper method.
      #
      # @param attr [Symbol, String] The attribute name.
      # @param value [String] The initial value.
      #
      # @return [String] Returns the value, where all dangerous elements have been stripped as described above.

      def html_strip_dangerous_elements(attr, value)
        Fl::Framework::HtmlHelper.strip_dangerous_elements(value)
      end

      # HTML filter to return text only.
      # This filter wraps the {Fl::Framework::HtmlHelper.text_only} helper method.
      #
      # @param attr [Symbol, String] The attribute name.
      # @param value [String] The initial value.
      #
      # @return [String] Returns the value, where all HTML tags have been stripped (well, technically,
      #  where all text nodes have been contatenated).

      def html_text_only(attr, value)
        Fl::Framework::HtmlHelper.text_only(value)
      end
    end

    # Include actions.
    # This method performs the following actions when the module is included:
    # - Registers the methods in Fl::AttributeFilters::ClassMethods as class methods of the including class.
    # - Registers the methods in Fl::AttributeFilters::InstanceMethods as instance methods in the
    #   including class.
    # - Defines the two constants +FILTER_HTML_TEXT_ONLY+ and +FILTER_HTML_STRIP_DANGEROUS_ELEMENTS+ to
    #   hold the Symbol values for the two predefined filter methods.
    # - Extends the functionality of +:write_attribute+ and +:update_attributes+ to filter registered
    #   attributes automatically. It also defines the +:filtered_update_attributes+ alias for the extended
    #   +:update_attributes+ method.

    def self.included(base)
      base.extend ClassMethods
      base.class_eval do
        include InstanceMethods

        const_set(:FILTER_HTML_TEXT_ONLY, :html_text_only)
        const_set(:FILTER_HTML_STRIP_DANGEROUS_ELEMENTS, :html_strip_dangerous_elements)

        # OK, so if we have Neo4j::ActiveNode, we decorate the setters in the :filtered_attribute
        # method, so we don't need to do anything here.
        # If not, we override :write_attribute instead

        unless Module::const_defined?('Neo4j::ActiveNode')
          if self.instance_methods.find { |m| m.to_sym == :write_attribute }
            alias base_write_attribute write_attribute

            def write_attribute(attr, value)
              # as a semi-hack, if the attribute does not exist, but there is a setter method by that name,
              # call that instead of the base method. This supports, for example, assets and the :updated_at
              # attribute: assets don't have the :updated_at attribute (which is in the attached resource
              # instead), but they do define :updated_at=

              attrs = self.attributes
              if attrs.has_key?(attr) || attrs.has_key?(attr.to_sym) || attrs.has_key?(attr.to_s)
                base_write_attribute(attr, filter_one_attribute(attr, value))
              elsif respond_to?("#{attr}=")
                self.send("#{attr}=", value)
              else
                raise "cannot write attribute '#{attr}'"
              end
            end
          end
        end

        alias base_update_attributes update_attributes

        # @!visibility private
        def update_attributes(attrs)
          base_update_attributes(filter_bulk_attributes(attrs))
        end

        alias filtered_update_attributes update_attributes
      end
    end
  end
end
