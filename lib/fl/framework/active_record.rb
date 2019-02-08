# The base class for Active Record objects.

class ActiveRecord::Base
  # Split a fingerprint into class name and identifier, and optionally check the class name.
  #
  # @param f [String] The fingerprint.
  # @param cn [String,Class,Boolean,nil] A class name or a class object to check; if `nil`, this check is not
  #  performed. If *cn* is the boolean value `true`, the class name from the fingerprint is comverted to
  #  a class object; if a class by that name is not available, an array of `nil` elements is returned.
  #
  # @return [Array] Returns a two-element array containing the class name and object identifier
  #  components for *f*. If *f* does not look like a fingerprint, or if the class name is not consistent
  #  with *cn*, the array contains two `nil` elements.
  
  def self.split_fingerprint(f, cn = nil)
    c, id = f.split('/')
    return [ nil, nil ] if (cn.is_a?(String) && (c != cn)) || (cn.is_a?(Class) && (c != cn.name))
    return [ nil, nil ] if id !~ /^[0-9]+$/

    if cn == true
      begin
        c = Object.const_get(c)
      rescue => exc
        c = nil
        id = nil
      end
    end
    
    [ c, id ]
  end

  # Generate a "fingerprint" for a given object.
  # A fingerprint is a string that contains enough information to find the object from the database.
  # It has the form *cname*/*id*, where *cname* is the class name, and *id* the object identifier.
  #
  # @param obj [ActiveRecord::Base] The object whose fingerprint to generate.
  #
  # @return [String] Returns a string containing the class name and object identifier, as described above.

  def self.fingerprint(obj)
    "#{obj.class.name}/#{obj.id}"
  end

  # Generate a "fingerprint" for `self`.
  # This method wraps a call to {.fingerprint}.
  #
  # @return [String] Returns a string containing the class name and object identifier.

  def fingerprint()
    ActiveRecord::Base.fingerprint(self)
  end

  # Find an object by fingerprint.
  #
  # @param [String] fingerprint The object's fingerprint; see {#fingerprint}.
  #
  # @return [ActiveRecord::Base] Returns the object. If the class in the fingerprint does not exist,
  #  or if no object exists with the given identifier, returns nil.

  def self.find_by_fingerprint(fingerprint)
    obj = nil
    cname, id = fingerprint.split('/')

    begin
      cl = Object.const_get(cname)
      obj = cl.find(id)
    rescue => exc
    end

    obj
  end
end
