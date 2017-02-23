module Fl::Framework
  # Visibility namespace.

  module Visibility
    # Private visibility: object is accessible only by its owners.
    PRIVATE = :private

    # Group visibility: object is accessible only by members of groups to which the owners belong.
    # The access layer implemented in {Fl::Framework::Access} and its modules makes it possible to select a
    # subset of the owners' groups to further restrict access. See {Fl::Framework::Access::Grants} and
    # {Fl::Framework::Access::Access}.
    GROUP = :group

    # Friends visibility: object is accessible only by members of groups to which the owners belong, or of
    # groups linked to the owners' groups.
    # The access layer implemented in {Fl::Framework::Access} and its modules makes it possible to select a
    # subset of the owners' groups and linked groups to further restrict access.
    # See {Fl::Framework::Access::Grants} and {Fl::Framework::Access::Access}.
    FRIENDS = :friends

    # Public visibility: object is accessible to anyone
    PUBLIC = :public

    # Direct visibility: object manages an arbitrary list of access grants to deliver fine granularity
    # of access (for example, to a single user).
    DIRECT = :direct

    # The possible value of a visibility property:
    # - *:private* visible only to the owners of an object.
    # - *:group* also visible to members of groups of which the owners are members.
    # - *:friends* also visible to members of groups linked to groups of which the owners are members.
    # - *:public* visible to anyone.
    # - *:direct* manages an arbitrary list of access grants.
    # Note that *:group* and *:friends* visibility can be further restricted by providing a list of groups
    # that have been granted visibility.

    VALUES = { private: 1, group: 2, friends: 3, public: 4, direct: 5 }

    # The methods in this module will be installed as class methods of the including class.

    module ClassMethods
    end

    # The methods in this module will be installed as instance methods of the including class.

    module InstanceMethods
    end

    # Perform actions when the module is included.
    # - Injects the class and instance methods.

    def self.included(base)
      base.extend ClassMethods

      base.instance_eval do
      end

      base.class_eval do
        include InstanceMethods
      end
    end
  end
end
