# The base class for Active Record objects.

class ActiveRecord::Base
  # Generate a "fingerprint" for the object.
  # A fingerprint is a string that contains enough information to find the object from the database.
  # It has the form _cname_/_id_, where _cname_ is the class name, and _id_ the object identifier.
  #
  # @return [String] Returns a string containing the class name and object identifier, as described above.

  def fingerprint()
    "#{self.class.name}/#{self.id}"
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
