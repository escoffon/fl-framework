module Fl::Framework::Asset
  # Permissions defined by the asset package.

  module Permission
    # The **:owner** permission class.
    # This permission is used by the asset-based access code as an optimization for queries that list
    # assets accessible to a user.
  
    class Owner < Fl::Framework::Access::Permission
      # The permission name.
      NAME = :owner

      # dependent permissions granted by **:owner**.
      GRANTS = [ ]

      # Initializer.
      def initialize()
        super(NAME, GRANTS)
      end
    end

    Owner.new
  end
end
