module Fl::Framework::Test
  # Object helpers for testing.
  
  module ObjectHelpers
    # Get object identifiers.
    # Given an array of objects or hashes in _ol_, map it to an array of object identifiers.
    #
    # @param [Array<Object,Hash>] ol An array of objects or hashes.
    #
    # @return [Array<Number,nil>] Returns an array whose elements are the identifiers for the
    #  corresponding elements in _ol_. Elements in _ol_ that don't have an identifier are mapped to +nil+.

    def obj_ids(ol)
      ol.map do |o|
        case o
        when Hash
          (o[:id]) ? o[:id] : o['id']
        else
          (o.respond_to?(:id)) ? o.id : nil
        end
      end
    end

    # Get object fingerprints.
    # Given an array of objects or hashes in _ol_, map it to an array of object fingerprints.
    #
    # @param [Array<Object,Hash>] ol An array of objects or hashes.
    #
    # @return [Array<Number,nil>] Returns an array whose elements are the identifiers for the
    #  corresponding elements in _ol_. Elements in _ol_ that don't have an identifier are mapped to +nil+.

    def obj_fingerprints(ol)
      ol.map do |o|
        case o
        when Hash
          type = (o[:type]) ? o[:type] : o['type']
          id = (o[:id]) ? o[:id] : o['id']
          "#{type}/#{id}"
        else
          (o.respond_to?(:fingerprint)) ? o.fingerprint : nil
        end
      end
    end

    # Get object names.
    # Given an array of objects or hashes in _ol_, map it to an array of names.
    #
    # @param [Array<Object,Hash>] ol An array of objects or hashes.
    #
    # @return [Array<String,nil>] Returns an array whose elements are the names for the
    #  corresponding elements in _ol_. Elements in _ol_ that don't have a name are mapped to +nil+.

    def obj_names(ol)
      ol.map do |o|
        case o
        when Hash
          (o[:name]) ? o[:name] : o['name']
        else
          (o.respond_to?(:name)) ? o.name : nil
        end
      end
    end
  end
end
