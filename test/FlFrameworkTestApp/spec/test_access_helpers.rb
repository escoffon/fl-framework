class TestPermissionOne < Fl::Framework::Access::Permission
  NAME = :one
  
  def initialize()
    super(NAME)
  end
end

class TestPermissionTwo < Fl::Framework::Access::Permission
  NAME = :two
  GRANTS = [ TestPermissionOne::NAME ]
  
  def initialize()
    super(NAME, GRANTS)
  end
end

class TestPermissionThree < Fl::Framework::Access::Permission
  NAME = :three
  GRANTS = [ TestPermissionTwo::NAME ]
  
  def initialize()
    super(NAME, GRANTS)
  end
end

class TestPermissionFour < Fl::Framework::Access::Permission
  NAME = :four
  GRANTS = [ TestPermissionOne::NAME, TestPermissionTwo::NAME ]
  
  def initialize()
    super(NAME, GRANTS)
  end
end

class TestPermissionFive < Fl::Framework::Access::Permission
  NAME = :five
  GRANTS = [ ]
  
  def initialize()
    super(NAME, GRANTS)
  end
end

class TestPermissionSix < Fl::Framework::Access::Permission
  NAME = :six
  GRANTS = [ TestPermissionOne::NAME, TestPermissionTwo::NAME, TestPermissionFive::NAME ]
  
  def initialize()
    super(NAME, GRANTS)
  end
end

module Fl::Framework::Test
  # Helpers for testing the access control functionality.
  
  module AccessHelpers
    # Get the list of test permissions.
    #
    # @return [Array<Symbol>] Returns an array containing the names under which the test permissions
    #  were registered.
    
    def test_permission_names()
      [ TestPermissionOne::NAME, TestPermissionTwo::NAME, TestPermissionThree::NAME,
        TestPermissionFour::NAME, TestPermissionFive::NAME, TestPermissionSix::NAME ]
    end

    # Cleanup the access control registry.
    # This method drops a given list of permissions from the permission registry.
    #
    # @param plist [Array<Symbol,String>] An array containing the registered names of permissions to
    #  drop. If *plist* is not an array, the value of {#test_permission_names} is used.
    
    def cleanup_permission_registry(plist = nil)
      plist = test_permission_names() unless plist.is_a?(Array)
      names = plist.map { |p| p.to_sym }
  
      r = Fl::Framework::Access::Permission.class_variable_get(:@@_permission_registry)
      nr = r.reduce({ }) do |acc, kv|
        k, v = kv
        acc[k] = v unless names.include?(k)
        acc
      end
      Fl::Framework::Access::Permission.class_variable_set(:@@_permission_registry, nr)
    end
  end
end

