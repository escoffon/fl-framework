module Fl::Framework::List
  # Permissions defined by the list package.

  module Permission
    # The **:manage_list_items** permission class.
    # This permission grants actors the ability to add or remove items in a list.
  
    class ManageItems < Fl::Framework::Access::Permission
      # The permission name.
      NAME = :manage_list_items

      # The permission bit.
      BIT = 0x00000020

      # dependent permissions granted by **:manage_list_items**.
      GRANTS = [ ]

      # Initializer.
      def initialize()
        super(NAME, BIT, GRANTS)
      end
    end

    ManageItems.new.register
  end
end
