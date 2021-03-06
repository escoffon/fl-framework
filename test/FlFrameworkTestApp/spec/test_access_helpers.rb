module TestAccess
  class P1 < Fl::Framework::Access::Permission
    NAME = :p1
    BIT = 0x01000000
    GRANTS = [ ]
    
    def initialize()
      super(NAME, BIT, GRANTS)
    end
  end

  class P2 < Fl::Framework::Access::Permission
    NAME = :p2
    BIT = 0x02000000
    GRANTS = [ ]
    
    def initialize()
      super(NAME, BIT, GRANTS)
    end
  end

  class P3 < Fl::Framework::Access::Permission
    NAME = :p3
    BIT = 0x04000000
    GRANTS = [ ]
    
    def initialize()
      super(NAME, BIT, GRANTS)
    end
  end

  class P4 < Fl::Framework::Access::Permission
    NAME = :p4
    BIT = 0x00000000
    GRANTS = [ P1::NAME, P2::NAME]
    
    def initialize()
      super(NAME, BIT, GRANTS)
    end
  end

  class P5 < Fl::Framework::Access::Permission
    NAME = :p5
    BIT = 0x00000000
    GRANTS = [ P4::NAME, P3::NAME ]
    
    def initialize()
      super(NAME, BIT, GRANTS)
    end
  end

  class P6 < Fl::Framework::Access::Permission
    NAME = :p6
    BIT = 0x00000000
    GRANTS = [ P5::NAME ]
    
    def initialize()
      super(NAME, BIT, GRANTS)
    end
  end
end

module Fl::Framework::Test
  # Helpers for testing the access control functionality.
  
  module AccessHelpers
    # Cleanup the access control registry.
    # This method drops a given list of permissions from the permission registry.
    #
    # @param plist [Array<Symbol,String>] An array containing the registered names of permissions to
    #  drop. If *plist* is not an array, the value of {#test_permission_names} is used.
    
    def cleanup_permission_registry(plist = nil)
      plist = [ ] unless plist.is_a?(Array)
      plist.each { |p| Fl::Framework::Access::Permission.unregister(p) }
    end
  end
end

