module Fl::Framework
  # Attachment support.
  # This module contains a number of mixin modules used to manage file attachments via the Paperclip gem
  # ({https://github.com/thoughtbot/paperclip})
  # There are roughly two classes of modules in this package:
  # - Those that provide an infrastructure to manage attachment registrations.
  #   This includes {Fl::Framework::Attachment::Configuration} and
  #   {Fl::Framework::Attachment::ConfigurationDispatcher}, a configuration registry
  #   where clients can define classes of attachments and their Paperclip parameters.
  #   It also includes wrappers for the Paperclip <tt>has_attached_file</tt> method that sets up
  #   Paperclip attachments in a model. There are currently two flavors for this:
  #   {Fl::Framework::Attachment::ActiveRecord::Registration}, which is used with models stored in 
  #   an ActiveRecord database, and {Fl::Framework::Attachment::Neo4j::Registration}, which is used
  #   with models stored in a Neo4j database.
  # - A set of higher level attachment classes to manage collections of attachments outside of the
  #   context of an enclosing object. These attachment objects are stored separately from the models
  #   with which they are associated. There are ActiveRecord and Neo4j versions of these.
  #   {Fl::Framework::Attachment::Neo4j::Master} defines the API used by objects with attachments
  #   (master objects) to manage collections of {Fl::Framework::Attachment::Neo4j::Base} instances.
  #   Subclasses of {Fl::Framework::Attachment::ActiveRecord::Base}
  #   wrap low level attachments into an object so that it can be managed in a collection.
  #   There are equivalent classes for ActiveRecord.
  #
  # It also contains classes (subclasses of {Fl::Attachment::Base}) that implement attachments of a
  # specific type; for example,
  # {Fl::Attachment::Image} is an object with a low level file attachment that contains an image.
  #
  # For example, a user object may include an *avatar* low level attachment that contains the user's avatar 
  # image:
  #   class User
  #     include Neo4j::ActiveNode
  #     include Fl::Attachment::Registration
  #
  #     attachment :avatar, _type: :avatar
  #     validates_attachment_content_type :avatar, content_type: /\Aimage/
  #   end
  # The avatar is accessed using the Paperclip::Attachment API:
  #   u = get_user()
  #   default_url = u.avatar.url
  #   large_url = u.avatat.url(:large)
  #
  # An object that manages collections of attachments uses the {Fl::Attachment::Master} module:
  #   class Asset
  #     include Neo4j::ActiveNode
  #     include Fl::Attachment::Master
  #
  #     has_attachments :attachments
  #   end
  # In this case, *attachments* is an +:in+ association that uses the default {Fl::Rel::Attachment::AttachedTo}
  # relationship, and therefore manages all attachment types.

  module Attachment
    # The download operation; used by the access layer to check for download permissions.

    ACCESS_DOWNLOAD = :download
  end
end

require 'fl/framework/attachment/configuration'
