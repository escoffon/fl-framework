module Fl::Framework
  # Helper methods for generators.

  module GeneratorHelper
    protected
    
    # Split a class name into its components.
    # The name is split with the `::` separator, and a hash is returned with the following properties:
    # - **full_class_name** is the value of *cname*.
    # - **class_name** is the last component in *cname*.
    # - **plural_class_name** is the pluralized value of **class_name**.
    # - **module_name** is the concatenation of all other components, separated by `::`.
    # - **modules** is an array containing the names of all the other components.
    # - **open_module** is the statement that declares the enclosing module. For example, a class
    #   name `My::Mod::Name` results in the value `module My::Mod`. If no module is present in the
    #   class name, this value is an empty string.
    # - **close_module** is the statement that terminates the module declaration. It is `end` if there
    #   is a nonempty module, and an empty string otherwise.
    #
    # @param cname [String] The class name.
    #
    # @return [Hash] Returns a hash as described above.
    
    def split_class_name(cname)
      parts = cname.split('::')
      class_name = parts.pop

      rv = {
        full_name: cname,
        plural_full_name: ActiveSupport::Inflector.pluralize(cname),
        name: class_name,
        plural_name: ActiveSupport::Inflector.pluralize(class_name),
        module_name: parts.join('::'),
        modules: parts
      }

      if rv[:module_name].length > 0
        rv[:open_module] = "module #{rv[:module_name]}"
        rv[:close_module] = 'end'
      else
        rv[:open_module] = ''
        rv[:close_module] = ''
      end

      return rv
    end
  end
end
